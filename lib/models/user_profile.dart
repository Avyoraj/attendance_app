class UserProfile {
  final String studentId;
  final String name;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final String? department;
  final String? year;
  final Map<String, dynamic> preferences;

  UserProfile({
    required this.studentId,
    required this.name,
    this.avatarUrl,
    this.email,
    this.phone,
    this.department,
    this.year,
    required this.preferences,
  });
}
