import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import '../services/attendance_service.dart';
import '../widgets/beacon_status_widget.dart';
import '../widgets/background_status_widget.dart';
import '../../../core/services/beacon_service.dart';
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
  
  StreamSubscription<RangingResult>? _streamRanging;
  String _beaconStatus = 'Initializing...';
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _initializeBeaconScanner();
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
        (RangingResult result) {
          if (!mounted) return;

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
            setState(() {
              _beaconStatus = 'Scanning for classroom beacon...';
            });
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
      print('Logout error: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
            // Background Status Widget
            const BackgroundStatusWidget(),
            const SizedBox(height: 16),
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