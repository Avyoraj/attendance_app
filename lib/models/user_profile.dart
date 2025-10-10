class UserProfile {
  final String studentId;
  final String name;
  final String? avatarUrl;
  final Map<String, dynamic> preferences;

  UserProfile({
    required this.studentId,
    required this.name,
    this.avatarUrl,
    required this.preferences,
  });
}
