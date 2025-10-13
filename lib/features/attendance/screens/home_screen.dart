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
              _beaconStatus = 'Welcome to Class $classId! Processing attendance...';
            });
            // Show immediate positive feedback - no waiting instructions
            break;
          case 'confirmed':
            setState(() {
              _beaconStatus = 'Perfect! Recording your attendance...';
            });
            _checkIn(studentId, classId);
            break;
          case 'failed':
            setState(() {
              _beaconStatus = 'Please move closer to the classroom beacon.';
            });
            break;
        }
      });
      
      _streamRanging = _beaconService.startRanging().listen(
        (RangingResult result) async {
          if (!mounted) return;

          if (result.beacons.isNotEmpty) {
            final beacon = result.beacons.first;
            final classId = _beaconService.getClassIdFromBeacon(beacon);
            final rssi = beacon.rssi;
            final distance = _calculateDistance(rssi, beacon.txPower ?? -59);
            
            // 🔥 UPDATE NOTIFICATION with beacon status
            try {
              await platform.invokeMethod('updateNotification', {
                'text': '📍 Found $classId | RSSI: $rssi | ${distance.toStringAsFixed(1)}m'
              });
              print('📲 Notification updated: $classId at ${distance.toStringAsFixed(1)}m');
            } catch (e) {
              print('⚠️ Failed to update notification: $e');
            }
            
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
          setState(() {
            _beaconStatus = 'Check-in successful for Class $classId!';
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
          
          _streamRanging?.pause();
        } else {
          setState(() {
            _beaconStatus = 'Check-in failed. Please try again.';
            _isCheckingIn = false; // Stop loading immediately on failure
          });
        }
      }
    } catch (e) {
      print("Error during check-in: $e");
      if (mounted) {
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}