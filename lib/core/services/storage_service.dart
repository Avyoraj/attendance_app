import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _preferences;

  StorageService._();

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Student ID methods
  Future<String?> getStudentId() async {
    return _preferences?.getString(AppConstants.studentIdKey);
  }

  Future<bool> setStudentId(String studentId) async {
    return await _preferences?.setString(AppConstants.studentIdKey, studentId) ?? false;
  }

  Future<bool> removeStudentId() async {
    return await _preferences?.remove(AppConstants.studentIdKey) ?? false;
  }

  Future<bool> hasStudentId() async {
    return _preferences?.containsKey(AppConstants.studentIdKey) ?? false;
  }

  // Device ID methods (for device locking)
  Future<String?> getDeviceId() async {
    return _preferences?.getString('device_id');
  }

  Future<bool> setDeviceId(String deviceId) async {
    return await _preferences?.setString('device_id', deviceId) ?? false;
  }

  Future<bool> removeDeviceId() async {
    return await _preferences?.remove('device_id') ?? false;
  }

  // Clear attendance data (but keep device ID)
  Future<bool> clearAttendanceData() async {
    try {
      // Remove attendance-related keys but NOT device_id or student_id
      final keys = _preferences?.getKeys() ?? {};
      for (final key in keys) {
        if (key.startsWith('attendance_') || 
            key == 'attendance_records' || 
            key == 'last_check_in') {
          await _preferences?.remove(key);
        }
      }
      return true;
    } catch (e) {
      print('Error clearing attendance data: $e');
      return false;
    }
  }
}
