import '../../../core/services/http_service.dart';
import '../../../core/constants/api_constants.dart';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  final HttpService _httpService = HttpService();

  Future<bool> checkIn(String studentId, String classId) async {
    try {
      final response = await _httpService.post(
        url: ApiConstants.checkInUrl,
        body: {
          'studentId': studentId,
          'classId': classId,
        },
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error during check-in: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getAttendanceHistory(String studentId) async {
    try {
      // This would be implemented when you have an endpoint for getting attendance history
      // final response = await _httpService.get(
      //   url: '${ApiConstants.baseUrl}/api/attendance/$studentId',
      // );
      
      // For now, return null as this endpoint doesn't exist yet
      return null;
    } catch (e) {
      print('Error getting attendance history: $e');
      return null;
    }
  }
}