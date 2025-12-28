class UserProfile {
  final String studentId;
  final String name;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final String? department;
  final String? year;
  final String? section;
  final Map<String, dynamic> preferences;
  
  // Attendance stats
  final int totalClasses;
  final int confirmedClasses;
  final int attendancePercentage;
  final List<Map<String, dynamic>> recentAttendance;

  UserProfile({
    required this.studentId,
    required this.name,
    this.avatarUrl,
    this.email,
    this.phone,
    this.department,
    this.year,
    this.section,
    required this.preferences,
    this.totalClasses = 0,
    this.confirmedClasses = 0,
    this.attendancePercentage = 0,
    this.recentAttendance = const [],
  });
}
