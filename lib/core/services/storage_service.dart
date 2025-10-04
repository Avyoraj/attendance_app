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
}