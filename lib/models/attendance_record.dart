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
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'unknown',
      metadata: json['metadata'],
    );
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