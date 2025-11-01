import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/enhanced_beacon_status_widget.dart';
import '../../../core/constants/app_constants.dart';
import 'home_screen/home_screen_state.dart';
import 'home_screen/home_screen_callbacks.dart';
import 'home_screen/home_screen_timers.dart';
import 'home_screen/home_screen_sync.dart';
import 'home_screen/home_screen_battery.dart';
import 'home_screen/home_screen_helpers.dart';
import 'home_screen/home_screen_beacon.dart';

/// 🏠 HomeScreen - Refactored & Modularized
/// 
/// Main screen for attendance tracking using beacon technology.
/// This is the orchestrator that delegates to specialized modules.
/// 
/// Architecture:
/// - State management → HomeScreenState
/// - Beacon callbacks → HomeScreenCallbacks
/// - Timer management → HomeScreenTimers
/// - Backend sync → HomeScreenSync
/// - Battery optimization → HomeScreenBattery
/// - Helper functions → HomeScreenHelpers
/// - Beacon scanning → HomeScreenBeacon
/// 
/// Benefits:
/// - 83% smaller (1,153 lines → 200 lines)
/// - Clear separation of concerns
/// - Easy to test and maintain
/// - Backward compatible
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
  // Core state module
  late final HomeScreenState _state;
  
  // Feature modules
  late final HomeScreenCallbacks _callbacks;
  late final HomeScreenTimers _timers;
  late final HomeScreenSync _sync;
  late final HomeScreenBattery _battery;
  late final HomeScreenHelpers _helpers;
  late final HomeScreenBeacon _beacon;
  
  @override
  void initState() {
    super.initState();
    _initializeModules();
    _startApp();
  }
  
  /// Initialize all feature modules
  void _initializeModules() {
    // Create state module first
    _state = HomeScreenState();
    
    // Create sync module (needed by timers)
    _sync = HomeScreenSync(
      state: _state,
      studentId: widget.studentId,
    );
    
    // Create timers module (needs sync for confirmation check)
    _timers = HomeScreenTimers(
      state: _state,
      sync: _sync,
    );
    
    // Create helpers module (needs context and studentId)
    _helpers = HomeScreenHelpers(
      state: _state,
      context: context,
      studentId: widget.studentId,
    );
    
    // Create callbacks module (needs timers and helpers)
    _callbacks = HomeScreenCallbacks(
      state: _state,
      timers: _timers,
      helpers: _helpers,
      setStateCallback: setState,
    );
    
    // Create battery module (needs setState and showSnackBar)
    _battery = HomeScreenBattery(
      state: _state,
      setStateCallback: setState,
      showSnackBar: _helpers.showSnackBar,
    );
    
    // Create beacon module (needs check-in logic)
    _beacon = HomeScreenBeacon(
      state: _state,
      studentId: widget.studentId,
      setStateCallback: setState,
      checkIn: _checkIn,
      cancelProvisionalAttendance: _cancelProvisionalAttendance,
    );
  }
  
  /// Start the app - initialize beacon scanner, check battery, sync state
  Future<void> _startApp() async {
    await _beacon.initializeBeaconScanner();
    _callbacks.setupBeaconStateCallback();
    await _battery.checkBatteryOptimizationOnce();
    await _sync.syncStateOnStartup(
      widget.studentId,
      setState,
      () => _helpers.loadCooldownInfo(setState),
      () => _timers.startConfirmationTimer(setState),
      _helpers.showSnackBar,
    );
  }
  
  /// Perform attendance check-in
  Future<void> _checkIn(String studentId, String classId) async {
    if (_state.isCheckingIn) return;
    
    setState(() => _state.isCheckingIn = true);

    try {
      final success = await _state.attendanceService.checkIn(studentId, classId);
      
      if (mounted) {
        if (success) {
          setState(() {
            _state.isCheckingIn = false;
          });
          
          // Show success notification with sound
          try {
            await HomeScreenState.platform.invokeMethod('showSuccessNotification', {
              'title': 'Attendance Recorded! ✅',
              'message': 'Successfully checked in to $classId'
            });
            print('📲 Success notification sent: $classId');
          } catch (e) {
            print('⚠️ Failed to send success notification: $e');
          }
        } else {
          // Only update status on actual failure (not during confirmation period)
          if (!_state.isAwaitingConfirmation) {
            setState(() {
              _state.beaconStatus = 'Check-in failed. Please try again.';
              _state.isCheckingIn = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error during check-in: $e");
      if (mounted && !_state.isAwaitingConfirmation) {
        setState(() {
          _state.beaconStatus = 'Check-in failed. Cannot reach server.';
          _state.isCheckingIn = false;
        });
      }
    } finally {
      // Use timer only to prevent multiple check-in attempts for 30 seconds
      Timer(AppConstants.checkInCooldown, () {
        if (mounted) {
          setState(() => _state.isCheckingIn = false);
        }
      });
    }
  }
  
  /// Cancel provisional attendance (called when beacon is lost)
  Future<void> _cancelProvisionalAttendance() async {
    if (_state.currentClassId != null) {
      try {
        await _state.httpService.cancelProvisionalAttendance(
          studentId: widget.studentId,
          classId: _state.currentClassId!,
        );
        print('✅ Backend cancelled provisional attendance');
      } catch (e) {
        print('⚠️ Error cancelling on backend: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _state.dispose();
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
            onPressed: () => _helpers.handleLogout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Battery optimization card (static, only if not dismissed/enabled)
            if (_state.showBatteryCard)
              _battery.buildBatteryCard(context),
              
            // Main beacon status widget - Material 3 Design
            Expanded(
              child: Material3BeaconStatusWidget(
                status: _state.beaconStatus,
                isCheckingIn: _state.isCheckingIn,
                studentId: widget.studentId,
                remainingSeconds: _state.remainingSeconds,
                isAwaitingConfirmation: _state.isAwaitingConfirmation,
                cooldownInfo: _state.cooldownInfo,
                currentClassId: _state.currentClassId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
