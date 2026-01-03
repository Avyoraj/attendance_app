import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_logger.dart';
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
  final Function cancelProvisionalAttendance;

  HomeScreenBeacon({
    required this.state,
    required this.studentId,
    required this.cancelProvisionalAttendance,
  });

  /// Initialize beacon scanning and set up ranging stream
  Future<void> initializeBeaconScanner() async {
    try {
      // Start centralized scanning in BeaconService; UI only receives ranging callbacks for UX
      await state.beaconService.startScanning(
        studentId: studentId,
        onRanging: (RangingResult result) => _handleRangingResult(result),
      );
    } catch (e, stackTrace) {
      AppLogger.error('FATAL ERROR initializing beacon scanner',
          error: e, stackTrace: stackTrace);
      state.update((state) {
        state.beaconStatusType = BeaconStatusType.failed;
        state.beaconStatus = 'Error: Beacon scanner failed to start.';
      });
    }
  }

  /// Handle ranging result (beacon detection)
  Future<void> _handleRangingResult(RangingResult result) async {
    // If UI is disposed, ignore callbacks to avoid useless work
    if (state.isDisposed) return;
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
    // Update proximity for UI hero card
    state.updateProximity(rssi: rssi, distance: distance);

    // Debounce notification updates (max 1 per second)
    _updateNotificationIfNeeded(classId, rssi, distance);

    // Block further processing during confirmation period
    if (state.isAwaitingConfirmation) {
      AppLogger.debug(
          '🔒 Ranging blocked: Awaiting confirmation (${state.remainingSeconds} seconds remaining)');
      return;
    }

    // Block status updates during active attendance process
    if (state.isStatusLocked()) {
      AppLogger.debug('🔒 Status locked: ${state.beaconStatus}');
      return;
    }

    // Process beacon for check-in logic
    _processBeaconForCheckIn(beacon, classId);
  }

  /// Process beacon for check-in logic
  void _processBeaconForCheckIn(Beacon beacon, String classId) {
    // Don't process if status is locked (failed/cancelled/confirmed etc)
    if (state.isStatusLocked()) {
      return;
    }
    
    // Use advanced beacon analysis
    final shouldCheckIn = state.beaconService.analyzeBeacon(
      beacon,
      studentId,
      classId,
    );

    if (!shouldCheckIn) {
      // Update status based on RSSI level
      if (beacon.rssi <= AppConstants.rssiThreshold) {
        state.update((state) {
          state.beaconStatusType = BeaconStatusType.info;
          state.beaconStatus = 'Move closer to the classroom beacon.';
        });
      } else {
        state.update((state) {
          state.beaconStatusType = BeaconStatusType.info;
          state.beaconStatus = 'Classroom detected! Getting ready...';
        });
      }
    }
  }

  /// Process when no beacons are detected
  Future<void> _processNoBeaconsDetected() async {
    // Do NOT auto-cancel during provisional just because no beacons were seen briefly.
    // Background/app lifecycle can pause ranging; final confirmation is handled by services.

    // Update status if not in critical state
    if (!state.isAwaitingConfirmation && !state.isStatusLocked()) {
      state.update((state) {
        state.beaconStatusType = BeaconStatusType.scanning;
        state.beaconStatus =
            '🔍 Searching for classroom beacon...\nMove closer to the classroom.';
      });

      // Update notification when no beacons (debounced)
      _updateNoBeaconNotification();
    }
  }

  /// Update notification with beacon status (debounced)
  void _updateNotificationIfNeeded(String classId, int rssi, double distance) {
    if (state.isDisposed) return;
    final now = DateTime.now();
    if (state.lastNotificationUpdate == null ||
        now.difference(state.lastNotificationUpdate!).inMilliseconds >= 1000) {
      state.lastNotificationUpdate = now;

      // Fire and forget (don't await to avoid blocking)
      HomeScreenState.platform.invokeMethod('updateNotification', {
        'text':
            '📍 Found $classId | RSSI: $rssi | ${distance.toStringAsFixed(1)}m'
      }).catchError((e) {
        AppLogger.warning('⚠️ Notification update failed', error: e);
      });

      AppLogger.debug(
          '📲 Notification updated: $classId at ${distance.toStringAsFixed(1)}m (RSSI: $rssi)');
    }
  }

  /// Update notification for no beacon state (debounced)
  void _updateNoBeaconNotification() {
    if (state.isDisposed) return;
    final now = DateTime.now();
    if (state.lastNotificationUpdate == null ||
        now.difference(state.lastNotificationUpdate!).inMilliseconds >= 2000) {
      state.lastNotificationUpdate = now;

      HomeScreenState.platform.invokeMethod('updateNotification',
          {'text': '🔍 Searching for beacons...'}).catchError((e) {
        AppLogger.warning('⚠️ Notification update failed', error: e);
      });
    }
  }

  // NOTE: Removed unused ranging error handler to reduce analyzer warnings.

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
