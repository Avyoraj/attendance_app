import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/core/utils/app_logger.dart';
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
    return await _preferences?.setString(
            AppConstants.studentIdKey, studentId) ??
        false;
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
      AppLogger.error('Error clearing attendance data', error: e);
      return false;
    }
  }

  // Generic bool storage methods
  Future<bool> setBool(String key, bool value) async {
    return await _preferences?.setBool(key, value) ?? false;
  }

  Future<bool?> getBool(String key) async {
    return _preferences?.getBool(key);
  }

  // Generic string storage methods
  Future<bool> setString(String key, String value) async {
    return await _preferences?.setString(key, value) ?? false;
  }

  Future<String?> getString(String key) async {
    return _preferences?.getString(key);
  }
}
