import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/schedule_utils.dart';
import './home_screen_state.dart';

/// 📡 HomeScreen Beacon Module
/// 
/// Handles beacon scanning orchestration and ranging result processing.
/// Manages the core beacon detection and check-in logic.
/// 
/// Features:
/// - Initialize beacon scanning
/// - Process ranging results
/// - Handle beacon detection/loss
/// - Update notification with beacon status
/// - Manage check-in logic
class HomeScreenBeacon {
  final HomeScreenState state;
  final String studentId;
  final Function(VoidCallback) setStateCallback;
  final Function checkIn;
  final Function cancelProvisionalAttendance;
  
  HomeScreenBeacon({
    required this.state,
    required this.studentId,
    required this.setStateCallback,
    required this.checkIn,
    required this.cancelProvisionalAttendance,
  });
  
  /// Initialize beacon scanning and set up ranging stream
  Future<void> initializeBeaconScanner() async {
    try {
      await state.beaconService.initializeBeaconScanning();
      
      // Start ranging and listen for beacon updates
      state.streamRanging = state.beaconService.startRanging().listen(
        (RangingResult result) => _handleRangingResult(result),
        onError: (e) => _handleRangingError(e),
      );
    } catch (e) {
      print("FATAL ERROR initializing beacon scanner: $e");
      setStateCallback(() {
        state.beaconStatus = 'Error: Beacon scanner failed to start.';
      });
    }
  }
  
  /// Handle ranging result (beacon detection)
  Future<void> _handleRangingResult(RangingResult result) async {
    if (result.beacons.isNotEmpty) {
      await _processBeaconDetected(result);
    } else {
      await _processNoBeaconsDetected();
    }
  }
  
  /// Process when beacon is detected
  Future<void> _processBeaconDetected(RangingResult result) async {
    final beacon = result.beacons.first;
    final classId = state.beaconService.getClassIdFromBeacon(beacon);
    final rssi = beacon.rssi;
    final distance = _calculateDistance(rssi, beacon.txPower ?? -59);
    
    // Track when beacon was last seen (for exit detection)
    state.lastBeaconSeen = DateTime.now();
    
    // ALWAYS feed RSSI to beacon service (even during confirmation wait)
    state.beaconService.feedRssiSample(rssi);
    
    // Debounce notification updates (max 1 per second)
    _updateNotificationIfNeeded(classId, rssi, distance);
    
    // Block further processing during confirmation period
    if (state.isAwaitingConfirmation) {
      print('🔒 Ranging blocked: Awaiting confirmation (${state.remainingSeconds} seconds remaining)');
      return;
    }
    
    // Block status updates during active attendance process
    if (state.isStatusLocked()) {
      print('🔒 Status locked: ${state.beaconStatus}');
      return;
    }
    
    // Process beacon for check-in logic
    _processBeaconForCheckIn(beacon, classId);
  }
  
  /// Process beacon for check-in logic
  void _processBeaconForCheckIn(Beacon beacon, String classId) {
    // Use advanced beacon analysis
    final shouldCheckIn = state.beaconService.analyzeBeacon(
      beacon,
      studentId,
      classId,
    );
    
    if (!shouldCheckIn) {
      // Update status based on RSSI level
      if (beacon.rssi <= AppConstants.rssiThreshold) {
        setStateCallback(() {
          state.beaconStatus = 'Move closer to the classroom beacon.';
        });
      } else {
        setStateCallback(() {
          state.beaconStatus = 'Classroom detected! Getting ready...';
        });
      }
    }
  }
  
  /// Process when no beacons are detected
  Future<void> _processNoBeaconsDetected() async {
    // Check for beacon loss during provisional period
    if (state.isAwaitingConfirmation && 
        state.remainingSeconds > 0 && 
        state.lastBeaconSeen != null) {
      final timeSinceLastBeacon = DateTime.now().difference(state.lastBeaconSeen!);
      
      // If no beacon for 10 seconds during countdown, cancel attendance
      if (timeSinceLastBeacon.inSeconds >= 10) {
        await _handleBeaconLossDuringConfirmation();
      }
    }
    
    // Update status if not in critical state
    if (!state.isAwaitingConfirmation && 
        !state.beaconStatus.contains('CONFIRMED') &&
        !state.beaconStatus.contains('Cancelled') &&
        !state.beaconStatus.contains('Already Checked In') &&
        !state.beaconStatus.contains('Check-in recorded')) {
      setStateCallback(() {
        state.beaconStatus = '🔍 Searching for classroom beacon...\nMove closer to the classroom.';
      });
      
      // Update notification when no beacons (debounced)
      _updateNoBeaconNotification();
    }
  }
  
  /// Handle beacon loss during confirmation period
  Future<void> _handleBeaconLossDuringConfirmation() async {
    print('⚠️ BEACON LOST during provisional period!');
    print('⚠️ Last seen: ${DateTime.now().difference(state.lastBeaconSeen!).inSeconds} seconds ago');
    print('⚠️ Cancelling provisional attendance...');
    
    // Cancel the confirmation
    state.confirmationTimer?.cancel();
    
    // Generate cancelled info
    final cancelledTime = DateTime.now();
    final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
      cancelledTime: cancelledTime,
      now: cancelledTime,
    );
    
    // Reset state
    setStateCallback(() {
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.beaconStatus = '❌ You left the classroom!\nProvisional attendance cancelled.';
      state.isCheckingIn = false;
      state.cooldownInfo = cancelledInfo;
    });
    
    // Call backend to cancel provisional attendance
    await cancelProvisionalAttendance();
    
    // Reset last beacon time
    state.lastBeaconSeen = null;
  }
  
  /// Update notification with beacon status (debounced)
  void _updateNotificationIfNeeded(String classId, int rssi, double distance) {
    final now = DateTime.now();
    if (state.lastNotificationUpdate == null || 
        now.difference(state.lastNotificationUpdate!).inMilliseconds >= 1000) {
      state.lastNotificationUpdate = now;
      
      // Fire and forget (don't await to avoid blocking)
      HomeScreenState.platform.invokeMethod('updateNotification', {
        'text': '📍 Found $classId | RSSI: $rssi | ${distance.toStringAsFixed(1)}m'
      }).catchError((e) {
        print('⚠️ Notification update failed: $e');
      });
      
      print('📲 Notification updated: $classId at ${distance.toStringAsFixed(1)}m (RSSI: $rssi)');
    }
  }
  
  /// Update notification for no beacon state (debounced)
  void _updateNoBeaconNotification() {
    final now = DateTime.now();
    if (state.lastNotificationUpdate == null || 
        now.difference(state.lastNotificationUpdate!).inMilliseconds >= 2000) {
      state.lastNotificationUpdate = now;
      
      HomeScreenState.platform.invokeMethod('updateNotification', {
        'text': '🔍 Searching for beacons...'
      }).catchError((e) {
        print('⚠️ Notification update failed: $e');
      });
    }
  }
  
  /// Handle ranging error
  void _handleRangingError(dynamic error) {
    print("ERROR from ranging stream: $error");
    setStateCallback(() {
      state.beaconStatus = 'Error scanning for beacons';
    });
  }
  
  /// Calculate distance from RSSI and TX power
  double _calculateDistance(int rssi, int txPower) {
    if (rssi == 0) return -1.0;
    final ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return 0.5; // Very close
    } else {
      return 0.89976 * (ratio * ratio * ratio * ratio) + 
             7.7095 * (ratio * ratio * ratio) + 
             0.111 * (ratio * ratio);
    }
  }
}
