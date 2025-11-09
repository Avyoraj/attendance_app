import 'dart:async';
import 'package:logger/logger.dart';
import 'beacon_state_manager.dart';

/// ✅ Confirmation Handler Module
///
/// Handles attendance confirmation logic:
/// - Final confirmation checks
/// - Success/failure callbacks
/// - State transitions after confirmation
class BeaconConfirmationHandler {
  final _logger = Logger();

  // Required dependency
  late BeaconStateManager _stateManager;

  /// Initialize with dependencies
  void init(BeaconStateManager stateManager) {
    _stateManager = stateManager;
  }

  /// Handle confirmation success from AttendanceConfirmationService
  ///
  /// Called when:
  /// - Student stayed in classroom for full confirmation period
  /// - Backend successfully confirmed attendance
  void handleConfirmationSuccess(String studentId, String classId) {
    _logger.i('🎉 Attendance confirmed for $studentId in $classId');

    // Change state to confirmed (don't reset to scanning)
    _stateManager.setState('confirmed', studentId: studentId, classId: classId);

    // Activate a brief lockout to avoid immediate re-entry caused by stale ranging callbacks
    _stateManager.setPostConfirmationLockout(const Duration(seconds: 10));

    // Notify UI
    _stateManager.notifyStateChange('confirmed', studentId, classId);

    // After 5 seconds, show persistent success message
    Future.delayed(const Duration(seconds: 5), () {
      if (_stateManager.isConfirmed) {
        // Reset to scanning but show success message
        _stateManager.resetToScanning();

        // Notify UI with persistent success state
        _stateManager.notifyStateChange('success', studentId, classId);
      }
    });
  }

  /// Handle confirmation failure from AttendanceConfirmationService
  ///
  /// Called when:
  /// - Student left classroom during confirmation period
  /// - Beacon signal lost for too long
  void handleConfirmationFailure(String studentId, String classId) {
    _logger.e('❌ Attendance confirmation failed for $studentId in $classId');
    _logger.e(
        '   Reason: Student left classroom during waiting period (out of beacon range)');

    // Change state to 'cancelled' (different from 'failed')
    _stateManager.setState('cancelled', studentId: studentId, classId: classId);

    // Notify UI with 'cancelled' state
    _stateManager.notifyStateChange('cancelled', studentId, classId);

    // Reset after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _stateManager.resetToScanning();
    });
  }

  /// Perform final RSSI check before confirmation
  ///
  /// Returns true if student is still in range
  bool performFinalCheck(int? rssi, int threshold) {
    if (rssi == null) {
      _logger.w('❌ Final check failed: No RSSI data');
      return false;
    }

    if (rssi >= threshold) {
      _logger.i('✅ Final check passed: RSSI $rssi >= $threshold');
      return true;
    } else {
      _logger.w('❌ Final check failed: RSSI $rssi < $threshold');
      return false;
    }
  }
}
