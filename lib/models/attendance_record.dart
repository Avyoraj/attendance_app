class AttendanceRecord {
  final String id;
  final String studentId;
  final String classId;
  final DateTime timestamp;
  final String status; // 'present', 'absent', 'late'
  final Map<String, dynamic>? metadata;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.timestamp,
    required this.status,
    this.metadata,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      classId: json['classId'] ?? '',
      timestamp: _parseTimestamp(json['timestamp']),
      status: json['status'] ?? 'unknown',
      metadata: json['metadata'],
    );
  }

  factory AttendanceRecord.fromBackendJson(Map<String, dynamic> json) {
    // Handle both snake_case (Supabase) and camelCase field names
    final checkInTime = json['check_in_time'] ?? json['checkInTime'] ?? json['timestamp'];
    final metadata = <String, dynamic>{
      'confirmedAt': json['confirmed_at'] ?? json['confirmedAt'],
      'cancelledAt': json['cancelled_at'] ?? json['cancelledAt'],
      'cancellationReason': json['cancellation_reason'] ?? json['cancellationReason'],
      'rssi': json['rssi'],
      'distance': json['distance'],
      'beaconMajor': json['beacon_major'] ?? json['beaconMajor'],
      'beaconMinor': json['beacon_minor'] ?? json['beaconMinor'],
      'remainingSeconds': json['remaining_seconds'] ?? json['remainingSeconds'],
      'confirmationExpiresAt': json['confirmation_expires_at'] ?? json['confirmationExpiresAt'],
      'cooldown': json['cooldown'],
      'deviceId': json['device_id'] ?? json['deviceId'],
      'sessionDate': json['session_date'] ?? json['sessionDate'],
    }..removeWhere((key, value) => value == null);

    return AttendanceRecord(
      id: json['attendanceId'] ?? json['_id'] ?? json['id'] ?? '',
      studentId: json['student_id'] ?? json['studentId'] ?? '',
      classId: json['class_id'] ?? json['classId'] ?? '',
      timestamp: _parseTimestamp(checkInTime),
      status: json['status'] ?? 'unknown',
      metadata: metadata.isEmpty ? null : metadata,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'classId': classId,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'AttendanceRecord{id: $id, studentId: $studentId, classId: $classId, status: $status, timestamp: $timestamp}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
