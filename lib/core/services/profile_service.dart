import '../../models/user_profile.dart';

class ProfileService {
  Future<UserProfile> getUserProfile(String studentId) async {
    // TODO: Implement fetch from local storage or backend
    return UserProfile(studentId: studentId, name: 'Student', preferences: {});
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    // TODO: Implement update logic
  }
}
