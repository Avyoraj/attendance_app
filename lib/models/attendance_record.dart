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
    final checkInTime = json['checkInTime'] ?? json['timestamp'];
    final metadata = <String, dynamic>{
      'confirmedAt': json['confirmedAt'],
      'cancelledAt': json['cancelledAt'],
      'cancellationReason': json['cancellationReason'],
      'rssi': json['rssi'],
      'distance': json['distance'],
      'beaconMajor': json['beaconMajor'],
      'beaconMinor': json['beaconMinor'],
      'remainingSeconds': json['remainingSeconds'],
      'confirmationExpiresAt': json['confirmationExpiresAt'],
      'cooldown': json['cooldown'],
      'deviceId': json['deviceId'],
      'sessionDate': json['sessionDate'],
    }..removeWhere((key, value) => value == null);

    return AttendanceRecord(
      id: json['attendanceId'] ?? json['_id'] ?? json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      classId: json['classId'] ?? '',
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
