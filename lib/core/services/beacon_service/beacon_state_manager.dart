import 'dart:async';
import 'package:logger/logger.dart';
import '../../models/attendance_state.dart';

/// 🎯 State Manager Module
/// 
/// Manages the beacon service state machine:
/// - scanning: Looking for beacons
/// - provisional: Check-in recorded, waiting for confirmation
/// - confirmed: Attendance confirmed
/// - cancelled: Attendance cancelled (left early)
/// - failed: Check-in failed
/// 
/// Now uses Streams for reactive UI updates (prevents callback glitches).
/// Also maintains legacy callback support for backward compatibility.
class BeaconStateManager {
  final _logger = Logger();
  
  // Stream controller for reactive state updates
  final _stateController = StreamController<AttendanceState>.broadcast();
  
  /// Stream of attendance state changes
  /// Use StreamBuilder in UI for automatic lifecycle management
  Stream<AttendanceState> get stateStream => _stateController.stream;
  
  // Current state (cached for synchronous access)
  AttendanceState _currentState = AttendanceState.scanning();
  
  /// Get current state synchronously
  AttendanceState get currentStateSnapshot => _currentState;
  
  // Current attendance state (legacy string format)
  String _currentAttendanceState = 'scanning';
  
  // Current student/class being tracked
  String? _currentStudentId;
  String? _currentClassId;

  // Post-confirmation lockout to prevent immediate re-entry into provisional
  DateTime? _lockUntil;
  DateTime? _lastConfirmedAt;
  
  // Legacy state change callback (maintained for backward compatibility)
  Function(String state, String studentId, String classId)? _onAttendanceStateChanged;
  
  // Timers for state management
  Timer? _provisionalTimer;
  Timer? _confirmationTimer;
  Timer? _movementDetectionTimer;
  
  /// Get current state (legacy string)
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
    
    _logger.i('🎯 State changed: $state (student: $studentId, class: $classId)');

    // Track last confirmation time
    if (state == 'confirmed') {
      _lastConfirmedAt = DateTime.now();
    }
  }
  
  /// Notify UI of state change (both Stream and legacy callback)
  void notifyStateChange(String state, String studentId, String classId) {
    // Emit to Stream (new reactive approach)
    _emitState(state, studentId, classId);
    
    // Also call legacy callback if registered
    _onAttendanceStateChanged?.call(state, studentId, classId);
    _logger.i('📢 State notification sent: $state');
  }
  
  /// Emit state to stream
  void _emitState(String state, String studentId, String classId) {
    final status = AttendanceState.statusFromString(state);
    
    switch (status) {
      case AttendanceStatus.scanning:
        _currentState = AttendanceState.scanning();
        break;
      case AttendanceStatus.provisional:
        _currentState = AttendanceState.provisional(
          studentId: studentId,
          classId: classId,
        );
        break;
      case AttendanceStatus.confirmed:
        _currentState = AttendanceState.confirmed(
          studentId: studentId,
          classId: classId,
        );
        break;
      case AttendanceStatus.success:
        _currentState = AttendanceState.success(
          studentId: studentId,
          classId: classId,
        );
        break;
      case AttendanceStatus.cancelled:
        _currentState = AttendanceState.cancelled(
          studentId: studentId,
          classId: classId,
        );
        break;
      case AttendanceStatus.cooldown:
        _currentState = AttendanceState.cooldown(
          studentId: studentId,
          classId: classId,
        );
        break;
      case AttendanceStatus.failed:
        _currentState = AttendanceState.failed(
          studentId: studentId,
          classId: classId,
        );
        break;
      case AttendanceStatus.deviceLocked:
        _currentState = AttendanceState.deviceLocked(
          studentId: studentId,
        );
        break;
    }
    
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
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
    
    // Emit scanning state
    _currentState = AttendanceState.scanning();
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
    
    // Cancel all timers
    _provisionalTimer?.cancel();
    _confirmationTimer?.cancel();
    _movementDetectionTimer?.cancel();
    
    _provisionalTimer = null;
    _confirmationTimer = null;
    _movementDetectionTimer = null;
  }
  
  /// Set callback for state changes (legacy - use stateStream instead)
  void setOnStateChanged(Function(String state, String studentId, String classId) callback) {
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
    
    // Close the stream controller
    _stateController.close();
    
    _logger.d('🧹 State manager disposed');
  }
}
