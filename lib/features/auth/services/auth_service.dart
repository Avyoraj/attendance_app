import '../../../core/services/storage_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<bool> login(String studentId) async {
    if (studentId.isEmpty) return false;

    try {
      final storageService = await StorageService.getInstance();
      return await storageService.setStudentId(studentId);
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      final storageService = await StorageService.getInstance();
      return await storageService.removeStudentId();
    } catch (e) {
      print('Error during logout: $e');
      return false;
    }
  }

  Future<String?> getCurrentStudentId() async {
    try {
      final storageService = await StorageService.getInstance();
      return await storageService.getStudentId();
    } catch (e) {
      print('Error getting student ID: $e');
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final storageService = await StorageService.getInstance();
      return await storageService.hasStudentId();
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }
}