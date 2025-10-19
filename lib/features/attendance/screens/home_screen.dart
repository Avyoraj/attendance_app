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
import '../../../core/constants/app_constants.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeBeaconScanner();
    _checkBatteryOptimizationOnce();
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
        
        switch (state) {
          case 'provisional':
            setState(() {
              _beaconStatus = '⏳ Check-in recorded for Class $classId!\nStay in class for 10 minutes to confirm attendance.';
              _isCheckingIn = false; // Stop loading
            });
            _startConfirmationTimer();
            _showSnackBar('✅ Provisional check-in successful! Stay for 10 min.');
            print('✅ Provisional attendance recorded for $studentId in $classId');
            print('🔒 Status locked during confirmation period');
            print('� Current status: $_beaconStatus');
            break;
            
          case 'confirmed':
            setState(() {
              _beaconStatus = '✅ Attendance CONFIRMED for Class $classId!\nYou may now leave if needed.';
              _isAwaitingConfirmation = false;
              _confirmationTimer?.cancel();
              _isCheckingIn = false;
            });
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
            // Cooldown active - already checked in recently
            setState(() {
              _beaconStatus = '✅ You\'re Already Checked In for Class $classId\nEnjoy your class! Next check-in available in 15 minutes.';
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
            
            // 🔥 UPDATE NOTIFICATION with beacon status
            try {
              await platform.invokeMethod('updateNotification', {
                'text': '📍 Found $classId | RSSI: $rssi | ${distance.toStringAsFixed(1)}m'
              });
              print('📲 Notification updated: $classId at ${distance.toStringAsFixed(1)}m');
            } catch (e) {
              print('⚠️ Failed to update notification: $e');
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
            
            // NEW: Check if user left during provisional period
            if (_isAwaitingConfirmation && _lastBeaconSeen != null) {
              final timeSinceLastBeacon = DateTime.now().difference(_lastBeaconSeen!);
              
              // If no beacon for 10 seconds during countdown, cancel attendance
              if (timeSinceLastBeacon.inSeconds >= 10) {
                print('⚠️ BEACON LOST during provisional period!');
                print('⚠️ Last seen: ${timeSinceLastBeacon.inSeconds} seconds ago');
                print('⚠️ Cancelling provisional attendance...');
                
                // Cancel the confirmation
                _confirmationTimer?.cancel();
                
                // Reset state
                setState(() {
                  _isAwaitingConfirmation = false;
                  _remainingSeconds = 0;
                  _beaconStatus = '❌ You left the classroom!\nProvisional attendance cancelled.';
                  _isCheckingIn = false;
                });
                
                // Show user feedback
                _showSnackBar('❌ Attendance cancelled - you left the classroom');
                
                // TODO: Call backend API to delete provisional attendance
                // For now, it will just expire after 30 seconds
                
                // Reset last beacon time
                _lastBeaconSeen = null;
              }
            }
            
            setState(() {
              _beaconStatus = 'Scanning for classroom beacon...';
            });
            // Update notification when no beacons
            try {
              await platform.invokeMethod('updateNotification', {
                'text': '🔍 Searching for beacons...'
              });
            } catch (e) {
              print('⚠️ Failed to update notification: $e');
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
    // Use constant from app_constants (currently 60 seconds for testing)
    setState(() {
      _remainingSeconds = AppConstants.secondCheckDelay.inSeconds; // ✅ Use constant
      _isAwaitingConfirmation = true;
    });
    
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
          timer.cancel();
          setState(() {
            _isAwaitingConfirmation = false;
          });
        }
      },
    );
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}