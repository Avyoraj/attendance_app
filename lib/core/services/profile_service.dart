import 'dart:convert';
import '../../models/user_profile.dart';
import 'http_service.dart';
import 'storage_service.dart';
import '../constants/api_constants.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final HttpService _httpService = HttpService();

  /// Get user profile from backend
  Future<UserProfile> getUserProfile(String studentId) async {
    try {
      // Fetch profile data from backend
      final profileResponse = await _httpService.get(
        url: '${ApiConstants.apiBase}/students/$studentId/profile',
      );

      String name = 'Student $studentId';
      String? email;
      String? department;
      String? year;
      String? section;

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body) as Map<String, dynamic>;
        name = profileData['name'] ?? 'Student $studentId';
        email = profileData['email'];
        department = profileData['department'];
        year = profileData['year']?.toString();
        section = profileData['section'];
      }

      // Fetch student summary for attendance stats
      final summaryResponse = await _httpService.get(
        url: ApiConstants.studentSummary(studentId),
      );

      int totalClasses = 0;
      int confirmedClasses = 0;
      int attendancePercentage = 0;
      List<Map<String, dynamic>> recentAttendance = [];

      if (summaryResponse.statusCode == 200) {
        final summaryData = jsonDecode(summaryResponse.body) as Map<String, dynamic>;
        final weekStats = summaryData['weekStats'] as Map<String, dynamic>?;
        final recentHistory = summaryData['recentHistory'] as List? ?? [];
        
        totalClasses = weekStats?['total'] ?? 0;
        confirmedClasses = weekStats?['confirmed'] ?? 0;
        attendancePercentage = weekStats?['percentage'] ?? 0;
        recentAttendance = recentHistory.cast<Map<String, dynamic>>();
      }

      return UserProfile(
        studentId: studentId,
        name: name,
        email: email,
        department: department,
        year: year,
        preferences: {},
        totalClasses: totalClasses,
        confirmedClasses: confirmedClasses,
        attendancePercentage: attendancePercentage,
        recentAttendance: recentAttendance,
      );
    } catch (e) {
      // Return basic profile on error
      return UserProfile(
        studentId: studentId,
        name: 'Student $studentId',
        preferences: {},
      );
    }
  }

  /// Get current logged-in student's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final storage = await StorageService.getInstance();
      final studentId = await storage.getStudentId();
      
      if (studentId == null || studentId.isEmpty) {
        return null;
      }
      
      return getUserProfile(studentId);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    // TODO: Implement update logic when backend supports it
  }
}
