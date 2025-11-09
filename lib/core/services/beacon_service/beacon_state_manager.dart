import 'dart:async';
import 'package:logger/logger.dart';

/// 🎯 State Manager Module
///
/// Manages the beacon service state machine:
/// - scanning: Looking for beacons
/// - provisional: Check-in recorded, waiting for confirmation
/// - confirmed: Attendance confirmed
/// - cancelled: Attendance cancelled (left early)
/// - failed: Check-in failed
///
/// Also manages state callbacks to notify UI of state changes.
class BeaconStateManager {
  final _logger = Logger();

  // Current attendance state
  String _currentAttendanceState = 'scanning';

  // Current student/class being tracked
  String? _currentStudentId;
  String? _currentClassId;

  // Post-confirmation lockout to prevent immediate re-entry into provisional
  DateTime? _lockUntil;
  DateTime? _lastConfirmedAt;

  // State change callback
  Function(String state, String studentId, String classId)?
      _onAttendanceStateChanged;

  // Timers for state management
  Timer? _provisionalTimer;
  Timer? _confirmationTimer;
  Timer? _movementDetectionTimer;

  /// Get current state
  String get currentState => _currentAttendanceState;

  /// Get current student ID
  String? get currentStudentId => _currentStudentId;

  /// Get current class ID
  String? get currentClassId => _currentClassId;

  /// Set current state
  void setState(String state, {String? studentId, String? classId}) {
    _currentAttendanceState = state;

    if (studentId != null) _currentStudentId = studentId;
    if (classId != null) _currentClassId = classId;

    _logger
        .i('🎯 State changed: $state (student: $studentId, class: $classId)');

    // Track last confirmation time
    if (state == 'confirmed') {
      _lastConfirmedAt = DateTime.now();
    }
  }

  /// Notify UI of state change
  void notifyStateChange(String state, String studentId, String classId) {
    _onAttendanceStateChanged?.call(state, studentId, classId);
    _logger.i('📢 State notification sent: $state');
  }

  /// Set state and notify UI
  void setStateAndNotify(String state, String studentId, String classId) {
    setState(state, studentId: studentId, classId: classId);
    notifyStateChange(state, studentId, classId);
  }

  /// Reset to scanning state
  void resetToScanning() {
    _logger.i('🔄 Resetting to scanning state');

    _currentAttendanceState = 'scanning';
    _currentStudentId = null;
    _currentClassId = null;

    // Cancel all timers
    _provisionalTimer?.cancel();
    _confirmationTimer?.cancel();
    _movementDetectionTimer?.cancel();

    _provisionalTimer = null;
    _confirmationTimer = null;
    _movementDetectionTimer = null;
  }

  /// Set callback for state changes
  void setOnStateChanged(
      Function(String state, String studentId, String classId) callback) {
    _onAttendanceStateChanged = callback;
    _logger.d('✅ State change callback registered');
  }

  /// Clear state change callback (e.g., when UI is disposed)
  void clearOnStateChanged() {
    _onAttendanceStateChanged = null;
    _logger.d('🧹 State change callback cleared');
  }

  /// Check if in provisional state
  bool get isProvisional => _currentAttendanceState == 'provisional';

  /// Check if in confirmed state
  bool get isConfirmed => _currentAttendanceState == 'confirmed';

  /// Check if in scanning state
  bool get isScanning => _currentAttendanceState == 'scanning';

  /// Check if in cancelled state
  bool get isCancelled => _currentAttendanceState == 'cancelled';

  /// Check if in failed state
  bool get isFailed => _currentAttendanceState == 'failed';

  /// Enable a short lockout window after confirmation to avoid re-entry due to stale ranging
  void setPostConfirmationLockout(Duration duration) {
    _lockUntil = DateTime.now().add(duration);
    _logger.i('🔒 Post-confirmation lockout active for ${duration.inSeconds}s');
  }

  /// Whether currently within lockout window
  bool get isInLockout {
    if (_lockUntil == null) return false;
    final now = DateTime.now();
    if (now.isBefore(_lockUntil!)) return true;
    _lockUntil = null; // auto-clear after expiry
    return false;
  }

  DateTime? get lastConfirmedAt => _lastConfirmedAt;

  /// Set provisional timer
  void setProvisionalTimer(Timer timer) {
    _provisionalTimer?.cancel();
    _provisionalTimer = timer;
  }

  /// Set confirmation timer
  void setConfirmationTimer(Timer timer) {
    _confirmationTimer?.cancel();
    _confirmationTimer = timer;
  }

  /// Set movement detection timer
  void setMovementDetectionTimer(Timer timer) {
    _movementDetectionTimer?.cancel();
    _movementDetectionTimer = timer;
  }

  /// Cancel all timers
  void cancelAllTimers() {
    _provisionalTimer?.cancel();
    _confirmationTimer?.cancel();
    _movementDetectionTimer?.cancel();

    _logger.d('⏹️ All timers cancelled');
  }

  /// Dispose (cleanup)
  void dispose() {
    cancelAllTimers();
    _currentAttendanceState = 'scanning';
    _currentStudentId = null;
    _currentClassId = null;
    _onAttendanceStateChanged = null;

    _logger.d('🧹 State manager disposed');
  }
}
