import 'dart:convert'; // For JSON decoding
import 'package:attendance_app/core/utils/app_logger.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/device_id_service.dart'; // Use persistent device ID
import '../../../core/services/http_service.dart'; // For backend validation
import '../../../core/constants/api_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final DeviceIdService _deviceIdService =
      DeviceIdService(); // Use persistent service
  final HttpService _httpService = HttpService();

  /// Get persistent device ID (survives app uninstall)
  Future<String> _getDeviceId() async {
    return await _deviceIdService.getDeviceId();
  }

  /// Validate device with backend BEFORE allowing login
  Future<Map<String, dynamic>> _validateDeviceWithBackend(
      String studentId, String deviceId) async {
    try {
      final response = await _httpService.post(
        url: ApiConstants.validateDevice,
        body: {
          'studentId': studentId,
          'deviceId': deviceId,
        },
      );

      AppLogger.debug('🔐 Backend validation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Login allowed
        final data = jsonDecode(response.body);
        return {'canLogin': true, 'message': data['message'] ?? 'Welcome!'};
      } else if (response.statusCode == 403) {
        // Device locked to another student
        final data = jsonDecode(response.body);
        return {
          'canLogin': false,
          'error': data['error'] ?? 'Device already registered',
          'message':
              data['message'] ?? 'This device is linked to another account',
          'lockedToStudent': data['lockedToStudent']
        };
      } else {
        return {
          'canLogin': false,
          'error': 'Validation failed',
          'message': 'Unable to validate device. Please try again.'
        };
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ Backend validation error',
          error: e, stackTrace: stackTrace);
      return {
        'canLogin': false,
        'error': 'Network error',
        'message':
            'Unable to connect to server. Please check your internet connection.'
      };
    }
  }

  /// Login with BACKEND device validation (blocks locked devices BEFORE app access)
  Future<Map<String, dynamic>> login(String studentId) async {
    if (studentId.isEmpty) {
      return {'success': false, 'message': 'Please enter your Student ID'};
    }

    try {
      final storageService = await StorageService.getInstance();

      // Get current device ID
      final currentDeviceId = await _getDeviceId();

      AppLogger.info('🔐 LOGIN ATTEMPT for $studentId');
      AppLogger.debug('   Current Device: $currentDeviceId');

      // ✅ CRITICAL: Validate with backend FIRST
      final validationResult =
          await _validateDeviceWithBackend(studentId, currentDeviceId);

      if (validationResult['canLogin'] != true) {
        // Backend blocked login - return detailed error
        AppLogger.warning(
            '❌ LOGIN BLOCKED BY BACKEND: ${validationResult['message']}');
        return {
          'success': false,
          'message': validationResult['message'] ?? 'Login blocked',
          'error': validationResult['error'],
          'lockedToStudent': validationResult['lockedToStudent']
        };
      }

      // Backend approved login - store credentials locally
      final studentIdSaved = await storageService.setStudentId(studentId);
      final deviceIdSaved = await storageService.setDeviceId(currentDeviceId);

      if (studentIdSaved && deviceIdSaved) {
        AppLogger.info(
            '✅ LOGIN SUCCESS: Student $studentId on device $currentDeviceId');
        return {
          'success': true,
          'message': validationResult['message'] ?? 'Login successful'
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to save login credentials'
        };
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ LOGIN ERROR', error: e, stackTrace: stackTrace);
      return {
        'success': false,
        'message': 'An error occurred during login. Please try again.'
      };
    }
  }

  Future<bool> logout() async {
    try {
      final storageService = await StorageService.getInstance();
      return await storageService.removeStudentId();
    } catch (e, stackTrace) {
      AppLogger.error('Error during logout', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<String?> getCurrentStudentId() async {
    try {
      final storageService = await StorageService.getInstance();
      return await storageService.getStudentId();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting student ID',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final storageService = await StorageService.getInstance();
      return await storageService.hasStudentId();
    } catch (e, stackTrace) {
      AppLogger.error('Error checking login status',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
