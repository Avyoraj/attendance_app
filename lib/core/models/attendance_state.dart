/// 📊 Attendance State Model
///
/// Represents the current state of attendance tracking.
/// Used by BeaconStateManager to emit state changes via Stream.
class AttendanceState {
  final AttendanceStatus status;
  final String? studentId;
  final String? classId;
  final DateTime timestamp;
  final String? message;
  final Map<String, dynamic>? metadata;

  const AttendanceState({
    required this.status,
    this.studentId,
    this.classId,
    required this.timestamp,
    this.message,
    this.metadata,
  });

  /// Create initial scanning state
  factory AttendanceState.scanning() {
    return AttendanceState(
      status: AttendanceStatus.scanning,
      timestamp: DateTime.now(),
      message: 'Scanning for classroom beacon...',
    );
  }

  /// Create provisional state
  factory AttendanceState.provisional({
    required String studentId,
    required String classId,
    String? attendanceId,
    int? remainingSeconds,
  }) {
    return AttendanceState(
      status: AttendanceStatus.provisional,
      studentId: studentId,
      classId: classId,
      timestamp: DateTime.now(),
      message: 'Check-in recorded. Stay in class to confirm.',
      metadata: {
        if (attendanceId != null) 'attendanceId': attendanceId,
        if (remainingSeconds != null) 'remainingSeconds': remainingSeconds,
      },
    );
  }

  /// Create confirmed state
  factory AttendanceState.confirmed({
    required String studentId,
    required String classId,
  }) {
    return AttendanceState(
      status: AttendanceStatus.confirmed,
      studentId: studentId,
      classId: classId,
      timestamp: DateTime.now(),
      message: 'Attendance confirmed!',
    );
  }

  /// Create success state
  factory AttendanceState.success({
    required String studentId,
    required String classId,
  }) {
    return AttendanceState(
      status: AttendanceStatus.success,
      studentId: studentId,
      classId: classId,
      timestamp: DateTime.now(),
      message: 'You\'re all set!',
    );
  }

  /// Create cancelled state
  factory AttendanceState.cancelled({
    required String studentId,
    required String classId,
    String? reason,
  }) {
    return AttendanceState(
      status: AttendanceStatus.cancelled,
      studentId: studentId,
      classId: classId,
      timestamp: DateTime.now(),
      message: reason ?? 'Attendance cancelled.',
    );
  }

  /// Create cooldown state
  factory AttendanceState.cooldown({
    required String studentId,
    required String classId,
    int? minutesRemaining,
  }) {
    return AttendanceState(
      status: AttendanceStatus.cooldown,
      studentId: studentId,
      classId: classId,
      timestamp: DateTime.now(),
      message: 'Already checked in.',
      metadata: {
        if (minutesRemaining != null) 'minutesRemaining': minutesRemaining,
      },
    );
  }

  /// Create failed state
  factory AttendanceState.failed({
    String? studentId,
    String? classId,
    String? error,
  }) {
    return AttendanceState(
      status: AttendanceStatus.failed,
      studentId: studentId,
      classId: classId,
      timestamp: DateTime.now(),
      message: error ?? 'Check-in failed.',
    );
  }

  /// Create device locked state
  factory AttendanceState.deviceLocked({
    required String studentId,
    String? lockedToStudent,
  }) {
    return AttendanceState(
      status: AttendanceStatus.deviceLocked,
      studentId: studentId,
      timestamp: DateTime.now(),
      message: 'Device is linked to another account.',
      metadata: {
        if (lockedToStudent != null) 'lockedToStudent': lockedToStudent,
      },
    );
  }

  /// Convert legacy string state to AttendanceStatus
  static AttendanceStatus statusFromString(String state) {
    switch (state) {
      case 'scanning':
        return AttendanceStatus.scanning;
      case 'provisional':
        return AttendanceStatus.provisional;
      case 'confirmed':
        return AttendanceStatus.confirmed;
      case 'success':
        return AttendanceStatus.success;
      case 'cancelled':
        return AttendanceStatus.cancelled;
      case 'cooldown':
        return AttendanceStatus.cooldown;
      case 'failed':
        return AttendanceStatus.failed;
      case 'device_mismatch':
        return AttendanceStatus.deviceLocked;
      default:
        return AttendanceStatus.scanning;
    }
  }

  /// Convert AttendanceStatus to legacy string
  String get statusString {
    switch (status) {
      case AttendanceStatus.scanning:
        return 'scanning';
      case AttendanceStatus.provisional:
        return 'provisional';
      case AttendanceStatus.confirmed:
        return 'confirmed';
      case AttendanceStatus.success:
        return 'success';
      case AttendanceStatus.cancelled:
        return 'cancelled';
      case AttendanceStatus.cooldown:
        return 'cooldown';
      case AttendanceStatus.failed:
        return 'failed';
      case AttendanceStatus.deviceLocked:
        return 'device_mismatch';
    }
  }

  @override
  String toString() =>
      'AttendanceState(status: $status, student: $studentId, class: $classId)';
}

/// Attendance status enum
enum AttendanceStatus {
  scanning,
  provisional,
  confirmed,
  success,
  cancelled,
  cooldown,
  failed,
  deviceLocked,
}
