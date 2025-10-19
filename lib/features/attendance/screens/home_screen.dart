import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/attendance_service.dart';
import '../widgets/beacon_status_widget.dart';
import '../../../core/services/beacon_service.dart';
import '../../../core/services/continuous_beacon_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/http_service.dart'; // 🎯 NEW: For backend API
import '../../../core/services/notification_service.dart'; // 🔔 NEW: Enhanced notifications
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/schedule_utils.dart'; // 🎓 NEW: Schedule utilities
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String studentId;

  const HomeScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BeaconService _beaconService = BeaconService();
  final AttendanceService _attendanceService = AttendanceService();
  final AuthService _authService = AuthService();
  final LoggerService _logger = LoggerService();
  final HttpService _httpService = HttpService(); // 🎯 NEW: For backend API calls
  
  // Platform channel for notification updates
  static const platform = MethodChannel('com.example.attendance_app/beacon_service');
  
  // Static flag to ensure battery check only happens once per app session
  static bool _hasCheckedBatteryOnce = false;
  static bool? _cachedBatteryCardState;
  
  StreamSubscription<RangingResult>? _streamRanging;
  String _beaconStatus = 'Initializing...';
  bool _isCheckingIn = false;
  bool _showBatteryCard = true;
  bool _isBatteryOptimizationDisabled = false;
  bool _isCheckingBatteryOptimization = false; // Prevent multiple checks
  
  // Timer state for confirmation countdown
  Timer? _confirmationTimer;
  int _remainingSeconds = 0;
  bool _isAwaitingConfirmation = false;
  String? _provisionalAttendanceId;  // NEW: Track provisional attendance ID
  DateTime? _lastBeaconSeen;         // NEW: Track when beacon was last detected
  DateTime? _lastNotificationUpdate; // ✅ NEW: Debounce notification updates
  
  // 🎯 NEW: State management for cooldown and class tracking
  String? _currentClassId;           // Track which class we're checking into
  Map<String, dynamic>? _cooldownInfo; // Cooldown information from BeaconService

  @override
  void initState() {
    super.initState();
    _initializeBeaconScanner();
    _checkBatteryOptimizationOnce();
    _syncStateOnStartup(); // 🎯 NEW: Sync state from backend on startup
  }
  
  /// 🎯 NEW: Sync state from backend on app startup
  /// ✅ FIXED: Added timeout, loading state, and error handling
  Future<void> _syncStateOnStartup() async {
    try {
      // Show loading state
      if (mounted) {
        setState(() {
          _beaconStatus = '🔄 Loading attendance state...';
          _isCheckingIn = true; // Show loading indicator
        });
      }
      
      _logger.info('🔄 Syncing attendance state from backend...');
      
      // ✅ FIX: Add 5-second timeout to prevent infinite waiting
      final syncResult = await _beaconService
          .syncStateFromBackend(widget.studentId)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _logger.warning('⏱️ Sync timeout (5s) - falling back to scanning mode');
              return {'success': false, 'error': 'timeout'};
            },
          );
      
      if (!mounted) return;
      
      if (syncResult['success'] == true) {
        final syncedCount = syncResult['synced'] ?? 0;
        
        if (syncedCount > 0) {
          _logger.info('✅ Synced $syncedCount attendance records on startup');
          
          // 🔴 FIX: Don't call _loadCooldownInfo() here - will be called after handling state
          // _loadCooldownInfo(); ← REMOVED (was clearing cancelled info!)
          
          // Check if we're in provisional state
          final attendance = syncResult['attendance'] as List?;
          if (attendance != null) {
            for (var record in attendance) {
              if (record['status'] == 'provisional') {
                final remainingSeconds = record['remainingSeconds'] as int? ?? 0;
                final classId = record['classId'] as String;
                
                if (remainingSeconds > 0) {
                  _logger.info('⏱️ Resuming provisional countdown: $remainingSeconds seconds for Class $classId');
                  
                  // Resume provisional countdown in UI
                  setState(() {
                    _isAwaitingConfirmation = true;
                    _remainingSeconds = remainingSeconds;
                    _currentClassId = classId;
                    _beaconStatus = '⏳ Check-in recorded for Class $classId!\n(Resumed) Stay in class to confirm attendance.';
                  });
                  
                  // Start UI countdown timer (won't reset _remainingSeconds since it's already set)
                  _startConfirmationTimer();
                  
                  // Show user feedback
                  _showSnackBar('⏱️ Resumed: ${(remainingSeconds ~/ 60)}:${(remainingSeconds % 60).toString().padLeft(2, '0')} remaining');
                  
                  _logger.info('✅ UI countdown resumed successfully');
                  break; // Only handle first provisional record
                }
              } else if (record['status'] == 'confirmed') {
                // Show cooldown state for confirmed attendance
                final classId = record['classId'] as String;
                _logger.info('✅ Found confirmed attendance for Class $classId');
                
                setState(() {
                  _currentClassId = classId;
                  _beaconStatus = '✅ You\'re Already Checked In for Class $classId\nEnjoy your class!';
                  // 🔒 FIX: Clear confirmation timer state when already confirmed
                  _isAwaitingConfirmation = false;
                  _remainingSeconds = 0;
                  _isCheckingIn = false;
                });
                
                // ✅ Load cooldown info ONLY for confirmed state
                _loadCooldownInfo();
                break; // Only handle first confirmed record
              } else if (record['status'] == 'cancelled') {
                // 🎓 NEW: Show cancelled state with schedule-aware info
                final classId = record['classId'] as String;
                final cancelledTime = DateTime.parse(record['checkInTime']);
                _logger.info('❌ Found cancelled attendance for Class $classId');
                
                // Generate schedule-aware cancelled info
                final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
                  cancelledTime: cancelledTime,
                  now: DateTime.now(),
                );
                
                setState(() {
                  _currentClassId = classId;
                  _beaconStatus = '❌ Attendance Cancelled for Class $classId\n${cancelledInfo['message']}';
                  _cooldownInfo = cancelledInfo;
                  // 🔒 FIX: Clear confirmation timer state when cancelled
                  _isAwaitingConfirmation = false;
                  _remainingSeconds = 0;
                  _isCheckingIn = false; // ✅ Clear loading state
                });
                
                _logger.info('🎓 Cancelled state loaded with schedule awareness');
                break; // Only handle first cancelled record
              }
            }
          }
        } else {
          _logger.info('📭 No attendance records to sync');
          // ✅ FIX: Clear loading state even if no records
          setState(() {
            _isCheckingIn = false;
            _beaconStatus = '📡 Scanning for classroom beacon...';
          });
        }
      } else {
        _logger.warning('⚠️ State sync failed: ${syncResult['error']}');
        // ✅ FIX: Fall back to scanning mode on error
        setState(() {
          _isCheckingIn = false;
          _beaconStatus = '📡 Scanning for classroom beacon...';
        });
      }
    } catch (e) {
      _logger.error('❌ State sync error on startup', e);
      // ✅ FIX: Don't block app on sync error
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
          _beaconStatus = '📡 Scanning for classroom beacon...';
        });
      }
    }
  }
  
  /// 🎯 ENHANCED: Load cooldown info with schedule awareness
  void _loadCooldownInfo() async {
    // 🔒 FIX: Don't show cooldown card during confirmation period
    if (_isAwaitingConfirmation) {
      _logger.info('⏸️ Skipping cooldown info load - user is in confirmation period');
      return;
    }
    
    // 🔴 FIX: Don't override cancelled state with cooldown check
    if (_beaconStatus.contains('Cancelled')) {
      _logger.info('⏸️ Skipping cooldown info load - user has cancelled attendance');
      return;
    }
    
    final cooldown = _beaconService.getCooldownInfo();
    if (cooldown != null && mounted) {
      // Get basic cooldown data from BeaconService
      final lastCheckInTime = DateTime.parse(cooldown['lastCheckInTime']);
      final now = DateTime.now();
      
      // 🎓 NEW: Enhance with schedule-aware information
      final scheduleInfo = ScheduleUtils.getScheduleAwareCooldownInfo(
        classStartTime: lastCheckInTime,
        now: now,
      );
      
      // Merge schedule info with basic cooldown info
      final enhancedInfo = {
        ...cooldown,
        ...scheduleInfo,
      };
      
      setState(() {
        _cooldownInfo = enhancedInfo;
        _currentClassId = cooldown['classId'];
      });
      
      _logger.info('🎓 Cooldown info updated with schedule awareness');
    } else {
      // 🔴 FIX: Only check for cancelled records if we're actually in a cancelled state
      // Don't override confirmed state by fetching old cancelled records from backend!
      if (_beaconStatus.contains('Cancelled')) {
        // 🎓 NEW: Check if there's a cancelled state that needs schedule info
        try {
          final result = await _httpService.getTodayAttendance(studentId: widget.studentId);
          if (result['success'] == true) {
            final attendance = result['attendance'] as List;
            
            // Look for cancelled attendance
            for (var record in attendance) {
              if (record['status'] == 'cancelled') {
                final cancelledTime = DateTime.parse(record['checkInTime']);
                final now = DateTime.now();
                
                // 🎓 NEW: Add schedule-aware cancelled info
                final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
                  cancelledTime: cancelledTime,
                  now: now,
                );
                
                setState(() {
                  _cooldownInfo = cancelledInfo;
                  _currentClassId = record['classId'];
                });
                
                _logger.info('🎓 Cancelled info updated with schedule awareness');
                break;
              }
            }
          }
        } catch (e) {
          _logger.error('❌ Error loading cancelled state info', e);
        }
      } else {
        // Not cancelled, no cooldown info from beacon service
        // This is fine - just means no active cooldown
        _logger.info('ℹ️ No cooldown or cancelled state to display');
      }
    }
  }
  
  /// 🎯 NEW: Refresh cooldown info periodically
  Timer? _cooldownRefreshTimer;
  
  void _startCooldownRefreshTimer() {
    _cooldownRefreshTimer?.cancel();
    _cooldownRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadCooldownInfo();
      }
    });
  }

  Future<void> _checkBatteryOptimizationOnce() async {
    // If we've already checked once this app session, use cached state
    if (_hasCheckedBatteryOnce && _cachedBatteryCardState != null) {
      if (mounted) {
        setState(() {
          _showBatteryCard = _cachedBatteryCardState!;
        });
      }
      return;
    }
    
    // Prevent multiple simultaneous checks
    if (_isCheckingBatteryOptimization) return;
    _isCheckingBatteryOptimization = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user has dismissed the card permanently
      final hasCardBeenDismissed = prefs.getBool('battery_card_dismissed') ?? false;
      if (hasCardBeenDismissed) {
        _cachedBatteryCardState = false;
        _hasCheckedBatteryOnce = true;
        if (mounted) {
          setState(() {
            _showBatteryCard = false;
          });
        }
        return;
      }
      
      // Check actual battery optimization status
      final continuousService = ContinuousBeaconService();
      final isIgnoring = await continuousService.checkBatteryOptimization();
      
      _cachedBatteryCardState = !isIgnoring;
      _hasCheckedBatteryOnce = true;
      
      if (mounted) {
        setState(() {
          _isBatteryOptimizationDisabled = isIgnoring;
          _showBatteryCard = !isIgnoring; // Only show if not already disabled
        });
        
        // If already disabled, remember that so we don't show card again
        if (isIgnoring) {
          await prefs.setBool('battery_card_dismissed', true);
        }
      }
    } finally {
      _isCheckingBatteryOptimization = false;
    }
  }

  Future<void> _enableScreenOffScanning() async {
    final continuousService = ContinuousBeaconService();
    await continuousService.requestDisableBatteryOptimization();
    
    // Keep checking every 500ms for up to 10 seconds until enabled
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final isIgnoring = await continuousService.checkBatteryOptimization();
      
      if (isIgnoring) {
        // Successfully enabled!
        if (mounted) {
          // Save to preferences so card doesn't show again
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('battery_card_dismissed', true);
          _cachedBatteryCardState = false;
          
          setState(() {
            _isBatteryOptimizationDisabled = true;
            _showBatteryCard = false;
          });
          _showSnackBar('✅ Screen-off scanning enabled!');
        }
        return;
      }
    }
    
    // If we reach here, user may have denied or dismissed the dialog
    // Just leave the card visible so they can try again later
  }

  Future<void> _initializeBeaconScanner() async {
    try {
      await _beaconService.initializeBeaconScanning();
      
      // Set up callback for attendance state changes
      _beaconService.setOnAttendanceStateChanged((state, studentId, classId) {
        if (!mounted) return;
        
        // 🎯 ALWAYS update current class ID when state changes
        setState(() {
          _currentClassId = classId;
        });
        
        switch (state) {
          case 'provisional':
            setState(() {
              _beaconStatus = '⏳ Check-in recorded for Class $classId!\nStay in class for 3 minutes to confirm attendance.';
              _isCheckingIn = false; // Stop loading
            });
            _startConfirmationTimer();
            _startCooldownRefreshTimer(); // Start refreshing cooldown
            _showSnackBar('✅ Provisional check-in successful! Stay for 3 min.');
            print('✅ Provisional attendance recorded for $studentId in $classId');
            print('🔒 Status locked during confirmation period');
            print('📍 Current status: $_beaconStatus');
            break;
            
          case 'confirmed':
            setState(() {
              _beaconStatus = '✅ Attendance CONFIRMED for Class $classId!\nYou may now leave if needed.';
              _isAwaitingConfirmation = false;
              _confirmationTimer?.cancel();
              _isCheckingIn = false;
            });
            _loadCooldownInfo(); // Refresh cooldown info after confirmation
            _showSnackBar('🎉 Attendance confirmed! You\'re marked present.');
            print('✅ Attendance confirmed for $studentId in $classId');
            // DON'T pause - status is already locked
            print('✅ Confirmation complete - status remains locked');
            break;
          
          case 'success':
            // After 5-second delay, show persistent success message
            setState(() {
              _beaconStatus = '✅ Attendance Recorded for Class $classId\nYou\'re all set! Enjoy your class.';
            });
            _showSnackBar('✅ Attendance confirmed. Enjoy your class!');
            print('✅ Success state - attendance recorded for $studentId in $classId');
            break;
          
          case 'cooldown':
            // 🔴 FIX: Don't override cancelled state with cooldown!
            if (_beaconStatus.contains('Cancelled')) {
              print('🔒 Cooldown blocked: User has cancelled attendance');
              return; // Don't override cancelled state
            }
            
            // Cooldown active - already checked in recently
            _loadCooldownInfo(); // Load cooldown details
            setState(() {
              final cooldown = _beaconService.getCooldownInfo();
              final minutesRemaining = cooldown?['minutesRemaining'] ?? 15;
              _beaconStatus = '✅ You\'re Already Checked In for Class $classId\nEnjoy your class! Next check-in available in $minutesRemaining minutes.';
            });
            _showSnackBar('✅ You\'re already checked in. Enjoy your class!');
            print('⏳ Cooldown state - already checked in for $studentId in $classId');
            break;
          
          case 'cancelled':
            // 🚨 NEW: Attendance cancelled because student left during waiting period
            setState(() {
              _beaconStatus = '❌ Attendance Cancelled!\nYou left the classroom during the confirmation period.\n\nStay in class for the full ${AppConstants.secondCheckDelay.inSeconds} seconds next time.';
              _isAwaitingConfirmation = false;
              _confirmationTimer?.cancel();
              _remainingSeconds = 0;
              _isCheckingIn = false;
            });
            _showSnackBar('❌ Attendance cancelled - you left the classroom too early!');
            print('🚫 Attendance cancelled for $studentId in $classId (left during waiting period)');
            break;
            
          case 'device_mismatch':
            setState(() {
              _beaconStatus = '🔒 Device Locked: This account is linked to another device.';
              _isCheckingIn = false;
            });
            _showSnackBar('🔒 This account is linked to another device. Please contact admin.');
            print('🔒 Device mismatch detected for $studentId');
            break;
            
          case 'failed':
            // DON'T override if we already have a successful check-in!
            if (_isAwaitingConfirmation || 
                _beaconStatus.contains('Check-in recorded') ||
                _beaconStatus.contains('CONFIRMED')) {
              print('🔒 Ignoring failed state - already checked in successfully');
              return;
            }
            
            setState(() {
              _beaconStatus = '❌ Check-in failed. Please move closer to the beacon.';
              _isCheckingIn = false;
            });
            _showSnackBar('⚠️ Check-in failed. Try moving closer to the beacon.');
            print('❌ Check-in failed for $studentId in $classId');
            break;
            
          default:
            setState(() {
              _beaconStatus = 'Scanning for classroom beacon...';
            });
        }
      });
      
      _streamRanging = _beaconService.startRanging().listen(
        (RangingResult result) async {
          if (!mounted) return;
          
          // 🎯 CRITICAL FIX: Still process beacon data during confirmation wait
          // to keep beacon service buffer alive, but don't trigger new check-ins
          if (result.beacons.isNotEmpty) {
            final beacon = result.beacons.first;
            final classId = _beaconService.getClassIdFromBeacon(beacon);
            final rssi = beacon.rssi;
            final distance = _calculateDistance(rssi, beacon.txPower ?? -59);
            
            // NEW: Track when beacon was last seen (for exit detection)
            _lastBeaconSeen = DateTime.now();
            
            // 🎯 ALWAYS feed RSSI to beacon service (even during confirmation wait)
            // This keeps the smoothing buffer alive for the final confirmation check
            _beaconService.feedRssiSample(rssi);
            
            // ✅ FIX: DEBOUNCE notification updates (max 1 per second)
            // Prevents lag from too-frequent method channel calls
            final now = DateTime.now();
            if (_lastNotificationUpdate == null || 
                now.difference(_lastNotificationUpdate!).inMilliseconds >= 1000) {
              _lastNotificationUpdate = now;
              
              // Fire and forget (don't await to avoid blocking)
              platform.invokeMethod('updateNotification', {
                'text': '📍 Found $classId | RSSI: $rssi | ${distance.toStringAsFixed(1)}m'
              }).catchError((e) {
                print('⚠️ Notification update failed: $e');
              });
              
              print('📲 Notification updated: $classId at ${distance.toStringAsFixed(1)}m (RSSI: $rssi)');
            }
          }
          
          // CRITICAL: DON'T update status or trigger check-ins during confirmation period
          if (_isAwaitingConfirmation) {
            // Still processing beacon data above, but block UI updates
            print('🔒 Ranging blocked: Awaiting confirmation ($_remainingSeconds seconds remaining)');
            return;
          }
          
          // DON'T update status during active attendance process
          // Check if status contains any of these locked states
          if (_beaconStatus.contains('Check-in recorded') || 
              _beaconStatus.contains('CONFIRMED') ||
              _beaconStatus.contains('Attendance Recorded') ||  // Protect "Attendance Recorded" message
              _beaconStatus.contains('Already Checked In') ||   // Protect "Already Checked In" message
              _beaconStatus.contains('Cancelled') ||            // 🔴 FIX: Protect "Cancelled" state too!
              _beaconStatus.contains('Processing') ||
              _beaconStatus.contains('Recording your attendance')) {
            // Status is locked - don't change it
            print('🔒 Status locked: $_beaconStatus');
            return;
          }

          // Process beacon for check-in logic (beacon data already captured above)
          if (result.beacons.isNotEmpty) {
            final beacon = result.beacons.first;
            final classId = _beaconService.getClassIdFromBeacon(beacon);
            
            // Use advanced beacon analysis
            final shouldCheckIn = _beaconService.analyzeBeacon(beacon, widget.studentId, classId);
            
            if (!shouldCheckIn) {
              // Update status based on RSSI level - user-friendly messages
              if (beacon.rssi <= AppConstants.rssiThreshold) {
                setState(() {
                  _beaconStatus = 'Move closer to the classroom beacon.';
                });
              } else {
                setState(() {
                  _beaconStatus = 'Classroom detected! Getting ready...';
                });
              }
            }
          } else {
            // NO BEACONS DETECTED
            
            // 🔒 FIX: Only check for beacon loss during provisional period (not after confirmation)
            if (_isAwaitingConfirmation && 
                _remainingSeconds > 0 && 
                _lastBeaconSeen != null) {
              final timeSinceLastBeacon = DateTime.now().difference(_lastBeaconSeen!);
              
              // If no beacon for 10 seconds during countdown, cancel attendance
              if (timeSinceLastBeacon.inSeconds >= 10) {
                print('⚠️ BEACON LOST during provisional period!');
                print('⚠️ Last seen: ${timeSinceLastBeacon.inSeconds} seconds ago');
                print('⚠️ Cancelling provisional attendance...');
                
                // Cancel the confirmation
                _confirmationTimer?.cancel();
                
                // 🔒 FIX: Generate cancelled info for the card
                final cancelledTime = DateTime.now();
                final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
                  cancelledTime: cancelledTime,
                  now: cancelledTime,
                );
                
                // Reset state
                setState(() {
                  _isAwaitingConfirmation = false;
                  _remainingSeconds = 0;
                  _beaconStatus = '❌ You left the classroom!\nProvisional attendance cancelled.';
                  _isCheckingIn = false;
                  _cooldownInfo = cancelledInfo; // 🔒 Set cancelled info for the badge
                });
                
                // Show user feedback
                _showSnackBar('❌ Attendance cancelled - you left the classroom');
                
                // Call backend to cancel provisional attendance
                if (_currentClassId != null) {
                  try {
                    await _httpService.cancelProvisionalAttendance(
                      studentId: widget.studentId,
                      classId: _currentClassId!,
                    );
                    print('✅ Backend cancelled provisional attendance');
                  } catch (e) {
                    print('⚠️ Error cancelling on backend: $e');
                  }
                }
                
                // Reset last beacon time
                _lastBeaconSeen = null;
              }
            }
            
            // ✅ FIX: Better "no beacon" feedback - only update if not in critical state
            if (!_isAwaitingConfirmation && 
                !_beaconStatus.contains('CONFIRMED') &&
                !_beaconStatus.contains('Cancelled') &&
                !_beaconStatus.contains('Already Checked In') &&
                !_beaconStatus.contains('Check-in recorded')) {
              setState(() {
                _beaconStatus = '🔍 Searching for classroom beacon...\nMove closer to the classroom.';
              });
              
              // Update notification when no beacons (debounced)
              final now = DateTime.now();
              if (_lastNotificationUpdate == null || 
                  now.difference(_lastNotificationUpdate!).inMilliseconds >= 2000) {
                _lastNotificationUpdate = now;
                
                platform.invokeMethod('updateNotification', {
                  'text': '🔍 Searching for beacons...'
                }).catchError((e) {
                  print('⚠️ Notification update failed: $e');
                });
              }
            }
          }
        },
        onError: (e) {
          print("ERROR from ranging stream: $e");
          if (mounted) {
            setState(() {
              _beaconStatus = 'Error scanning for beacons';
            });
          }
        },
      );
    } catch (e) {
      print("FATAL ERROR initializing beacon scanner: $e");
      if (mounted) {
        setState(() {
          _beaconStatus = 'Error: Beacon scanner failed to start.';
        });
      }
    }
  }

  Future<void> _checkIn(String studentId, String classId) async {
    if (_isCheckingIn) return;
    
    setState(() => _isCheckingIn = true);

    try {
      final success = await _attendanceService.checkIn(studentId, classId);
      
      if (mounted) {
        if (success) {
          // Don't update status here - the 'confirmed' callback already set it
          setState(() {
            _isCheckingIn = false; // Stop loading immediately on success
          });
          
          // 🎉 SHOW SUCCESS NOTIFICATION with SOUND
          try {
            await platform.invokeMethod('showSuccessNotification', {
              'title': 'Attendance Recorded! ✅',
              'message': 'Successfully checked in to $classId'
            });
            print('📲 Success notification sent: $classId');
          } catch (e) {
            print('⚠️ Failed to send success notification: $e');
          }
          
          // Keep scanning paused
        } else {
          // Only update status on actual failure (not during confirmation period)
          if (!_isAwaitingConfirmation) {
            setState(() {
              _beaconStatus = 'Check-in failed. Please try again.';
              _isCheckingIn = false; // Stop loading immediately on failure
            });
          }
        }
      }
    } catch (e) {
      print("Error during check-in: $e");
      if (mounted && !_isAwaitingConfirmation) {
        setState(() {
          _beaconStatus = 'Check-in failed. Cannot reach server.';
          _isCheckingIn = false; // Stop loading immediately on error
        });
      }
    } finally {
      // Use timer only to prevent multiple check-in attempts for 30 seconds
      Timer(AppConstants.checkInCooldown, () {
        if (mounted) {
          setState(() => _isCheckingIn = false);
        }
      });
    }
  }
  
  void _startConfirmationTimer() {
    // 🔒 FIX: Clear cooldown info when entering confirmation period
    setState(() {
      _cooldownInfo = null;
    });
    
    // 🎯 FIXED: Only set _remainingSeconds if it's not already set (for resume scenarios)
    // If _remainingSeconds is already set (from backend sync), use that value
    if (_remainingSeconds <= 0) {
      // New check-in: use full duration from constants
      setState(() {
        _remainingSeconds = AppConstants.secondCheckDelay.inSeconds; // ✅ Use constant
        _isAwaitingConfirmation = true;
      });
    } else {
      // Resume from backend: keep existing _remainingSeconds, just set flag
      setState(() {
        _isAwaitingConfirmation = true;
      });
    }
    
    print('🔍 TIMER DEBUG: Started - remaining=$_remainingSeconds seconds, awaiting=$_isAwaitingConfirmation');
    
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
            print('⏱️ Timer tick: $_remainingSeconds seconds remaining (awaiting: $_isAwaitingConfirmation)');
          });
        } else {
          // 🎯 Timer expired - time to confirm attendance!
          timer.cancel();
          print('🔔 Timer expired! Checking final RSSI for confirmation...');
          _performFinalConfirmationCheck();
        }
      },
    );
  }
  
  /// 🎯 NEW: Perform final RSSI check and confirm/cancel attendance
  /// 🔴 CRITICAL FIX: Use raw RSSI data (not cached) to prevent false confirmations
  Future<void> _performFinalConfirmationCheck() async {
    print('🔍 CONFIRMATION CHECK: Starting final RSSI verification...');
    
    // 🔴 CRITICAL: Get RAW RSSI data (bypasses grace period cache)
    // This prevents false confirmations when user has left but grace period is active
    final rssiData = _beaconService.getRawRssiData();
    final currentRssi = rssiData['rssi'] as int?;
    final rssiAge = rssiData['ageSeconds'] as int?;
    final isInGracePeriod = rssiData['isInGracePeriod'] as bool? ?? false;
    final threshold = AppConstants.confirmationRssiThreshold; // -82 dBm
    
    print('📊 CONFIRMATION CHECK:');
    print('   - Raw RSSI: $currentRssi dBm ${isInGracePeriod ? "(⚠️ IN GRACE PERIOD)" : ""}');
    print('   - RSSI Age: ${rssiAge ?? "N/A"}s');
    print('   - Threshold: $threshold dBm');
    print('   - Required: RSSI >= $threshold AND age <= 3s AND not in grace period');
    
    // 🔴 CRITICAL: Check RSSI staleness (must be fresh, within 3 seconds)
    if (currentRssi == null) {
      print('❌ CANCELLED: No RSSI data available - beacon lost');
      
      // Perform cancellation
      final cancelledTime = DateTime.now();
      final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
        cancelledTime: cancelledTime,
        now: cancelledTime,
      );
      
      setState(() {
        _beaconStatus = '❌ Attendance Cancelled!\nNo beacon detected during confirmation.';
        _isAwaitingConfirmation = false;
        _remainingSeconds = 0;
        _isCheckingIn = false;
        _cooldownInfo = cancelledInfo;
      });
      
      _showSnackBar('❌ Attendance cancelled - beacon lost!');
      
      if (_currentClassId != null) {
        await NotificationService.showCancelledNotification(
          classId: _currentClassId!,
          cancelledTime: cancelledTime,
        );
        
        try {
          await _httpService.cancelProvisionalAttendance(
            studentId: widget.studentId,
            classId: _currentClassId!,
          );
        } catch (e) {
          print('⚠️ Error cancelling on backend: $e');
        }
      }
      return;
    }
    
    if (rssiAge != null && rssiAge > 3) {
      print('❌ CANCELLED: RSSI data is stale (${rssiAge}s old) - not reliable');
      
      // Perform cancellation
      final cancelledTime = DateTime.now();
      final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
        cancelledTime: cancelledTime,
        now: cancelledTime,
      );
      
      setState(() {
        _beaconStatus = '❌ Attendance Cancelled!\nBeacon data is stale.';
        _isAwaitingConfirmation = false;
        _remainingSeconds = 0;
        _isCheckingIn = false;
        _cooldownInfo = cancelledInfo;
      });
      
      _showSnackBar('❌ Attendance cancelled - beacon signal lost!');
      
      if (_currentClassId != null) {
        await NotificationService.showCancelledNotification(
          classId: _currentClassId!,
          cancelledTime: cancelledTime,
        );
        
        try {
          await _httpService.cancelProvisionalAttendance(
            studentId: widget.studentId,
            classId: _currentClassId!,
          );
        } catch (e) {
          print('⚠️ Error cancelling on backend: $e');
        }
      }
      return;
    }
    
    // 🔴 CRITICAL: Reject if we're in grace period (using cached old values)
    if (isInGracePeriod) {
      print('❌ CANCELLED: In grace period - RSSI is cached (not real-time)');
      print('   This prevents false confirmations from cached "good" RSSI values');
      
      // Perform cancellation
      final cancelledTime = DateTime.now();
      final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
        cancelledTime: cancelledTime,
        now: cancelledTime,
      );
      
      setState(() {
        _beaconStatus = '❌ Attendance Cancelled!\nBeacon signal too weak.';
        _isAwaitingConfirmation = false;
        _remainingSeconds = 0;
        _isCheckingIn = false;
        _cooldownInfo = cancelledInfo;
      });
      
      _showSnackBar('❌ Attendance cancelled - you may have left!');
      
      if (_currentClassId != null) {
        await NotificationService.showCancelledNotification(
          classId: _currentClassId!,
          cancelledTime: cancelledTime,
        );
        
        try {
          await _httpService.cancelProvisionalAttendance(
            studentId: widget.studentId,
            classId: _currentClassId!,
          );
        } catch (e) {
          print('⚠️ Error cancelling on backend: $e');
        }
      }
      return;
    }
    
    // 🔴 CRITICAL: Strict RSSI threshold check
    if (currentRssi >= threshold) {
      // ✅ User is still in range - CONFIRM attendance
      print('✅ CONFIRMED: User is in range (RSSI: $currentRssi >= $threshold)');
      
      setState(() {
        _beaconStatus = '✅ Attendance CONFIRMED!\nYou stayed in the classroom.';
        _isAwaitingConfirmation = false;
        _remainingSeconds = 0;
      });
      
      // Call backend to confirm
      if (_currentClassId != null) {
        try {
          final result = await _httpService.confirmAttendance(
            studentId: widget.studentId,
            classId: _currentClassId!,
          );
          
          if (result['success'] == true) {
            _showSnackBar('✅ Attendance confirmed successfully!');
            print('✅ Backend confirmed attendance for ${widget.studentId} in $_currentClassId');
            
            // 🔔 Show success notification (lock screen + sound)
            await NotificationService.showSuccessNotification(
              classId: _currentClassId!,
              message: 'Logged at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            );
            
            // 🔔 Show cooldown notification with live countdown
            // Use current time as class start (notification service will calculate next class)
            await NotificationService.showCooldownNotification(
              classId: _currentClassId!,
              classStartTime: DateTime.now(),
            );
            
            // Load cooldown info for next check-in
            _loadCooldownInfo();
          } else {
            _showSnackBar('⚠️ Confirmation saved locally, will sync later');
            print('⚠️ Backend confirmation failed: ${result['message']}');
          }
        } catch (e) {
          _showSnackBar('⚠️ Confirmation saved locally, will sync later');
          print('❌ Error confirming attendance: $e');
        }
      } else {
        print('⚠️ Cannot confirm: _currentClassId is null');
        _showSnackBar('⚠️ Error: Class ID not available');
      }
      
    } else {
      // ❌ User left the classroom - CANCEL attendance
      print('❌ CANCELLED: User left classroom (RSSI: $currentRssi < $threshold)');
      
      // 🔒 FIX: Generate cancelled info for the card
      final cancelledTime = DateTime.now();
      final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
        cancelledTime: cancelledTime,
        now: cancelledTime,
      );
      
      setState(() {
        _beaconStatus = '❌ Attendance Cancelled!\nYou left the classroom during the confirmation period.';
        _isAwaitingConfirmation = false;
        _remainingSeconds = 0;
        _isCheckingIn = false;
        _cooldownInfo = cancelledInfo; // 🔒 Set cancelled info for the badge
      });
      
      _showSnackBar('❌ Attendance cancelled - you left too early!');
      
      // 🔔 Show cancelled notification with next class info
      if (_currentClassId != null) {
        await NotificationService.showCancelledNotification(
          classId: _currentClassId!,
          cancelledTime: cancelledTime,
        );
      }
      
      // Call backend to cancel provisional attendance
      if (_currentClassId != null) {
        try {
          final result = await _httpService.cancelProvisionalAttendance(
            studentId: widget.studentId,
            classId: _currentClassId!,
          );
          
          if (result['success'] == true) {
            print('✅ Backend cancelled provisional attendance for ${widget.studentId}');
          } else {
            print('⚠️ Backend cancel failed: ${result['message']}');
          }
        } catch (e) {
          print('⚠️ Error cancelling on backend: $e');
        }
      } else {
        print('⚠️ Cannot cancel: _currentClassId is null');
      }
    }
  }
  
  Future<void> _handleLogout() async {
    try {
      // Stop continuous beacon service first
      final continuousService = ContinuousBeaconService();
      await continuousService.stopContinuousScanning();
      _logger.info('🛑 Continuous scanning stopped before logout');
      
      // Then logout
      final success = await _authService.logout();
      
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        _showSnackBar('Logout failed. Please try again.');
      }
    } catch (e) {
      _showSnackBar('An error occurred during logout.');
      _logger.error('Logout error', e);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Calculate distance from RSSI
  double _calculateDistance(int rssi, int txPower) {
    if (rssi == 0) return -1.0;
    final ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return 0.5; // Very close
    } else {
      return 0.89976 * (ratio * ratio * ratio * ratio) + 7.7095 * (ratio * ratio * ratio) + 0.111 * (ratio * ratio);
    }
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    _cooldownRefreshTimer?.cancel(); // 🎯 NEW: Cancel cooldown refresh timer
    _streamRanging?.cancel();
    _beaconService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.studentId}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Battery optimization info card (only if not disabled)
            if (_showBatteryCard)
              Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.battery_alert, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Enable Screen-Off Scanning',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () async {
                              // Remember that user dismissed the card
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('battery_card_dismissed', true);
                              _cachedBatteryCardState = false;
                              setState(() => _showBatteryCard = false);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Allow the app to scan for beacons even when your screen is completely off. This helps log attendance automatically.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _enableScreenOffScanning,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Enable Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: BeaconStatusWidget(
                status: _beaconStatus,
                isCheckingIn: _isCheckingIn,
                studentId: widget.studentId,
                remainingSeconds: _remainingSeconds,
                isAwaitingConfirmation: _isAwaitingConfirmation,
                cooldownInfo: _cooldownInfo, // 🎯 Pass cooldown info
                currentClassId: _currentClassId, // 🎯 Pass current class ID
              ),
            ),
          ],
        ),
      ),
    );
  }
}