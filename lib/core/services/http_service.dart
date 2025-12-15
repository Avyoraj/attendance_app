import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:logger/logger.dart';

import '../constants/api_constants.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  final _logger = Logger();
  // Network timeout to prevent hanging requests (e.g., cold starts)
  static const Duration _requestTimeout = Duration(seconds: 8);

  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  Future<http.Response> post({
    required String url,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = {..._defaultHeaders, ...?headers};
    try {
      return await http
          .post(
            Uri.parse(url),
            headers: mergedHeaders,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (e) {
      _logger.w('HTTP POST timeout for $url: $e');
      rethrow;
    }
  }

  Future<http.Response> get({
    required String url,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = {..._defaultHeaders, ...?headers};
    try {
      return await http
          .get(
            Uri.parse(url),
            headers: mergedHeaders,
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (e) {
      _logger.w('HTTP GET timeout for $url: $e');
      rethrow;
    }
  }

  /// NEW: Check-in with device ID and RSSI
  Future<Map<String, dynamic>> checkIn({
    required String studentId,
    required String classId,
    required String deviceId,
    required int rssi,
  }) async {
    try {
      final response = await post(
        url: ApiConstants.checkIn,
        body: {
          'studentId': studentId,
          'classId': classId,
          'deviceId': deviceId,
          'rssi': rssi,
        },
      );

      _logger.i('Check-in response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'attendanceId': data['attendance']?['id'] ?? data['attendance']?['_id'] ?? 'unknown',
          'status': data['attendance']?['status'] ?? 'provisional',
        };
      } else if (response.statusCode == 403) {
        // Device mismatch - CRITICAL ERROR
        final error = jsonDecode(response.body);
        _logger.e('🔒 Device mismatch detected!');
        return {
          'success': false,
          'error': 'DEVICE_MISMATCH',
          'message': error['message'] ?? 'This account is linked to another device',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Unknown error',
          'message': error['message'] ?? 'Check-in failed',
        };
      }
    } catch (e) {
      _logger.e('Check-in error: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }

  /// NEW: Confirm attendance (two-step)
  /// Includes deviceId and optional attendanceId for backend integrity checks
  Future<Map<String, dynamic>> confirmAttendance({
    required String studentId,
    required String classId,
    required String deviceId,
    String? attendanceId,
  }) async {
    try {
      final body = <String, dynamic>{
        'studentId': studentId,
        'classId': classId,
        'deviceId': deviceId,
      };
      if (attendanceId != null) {
        body['attendanceId'] = attendanceId;
      }

      final response = await post(
        url: ApiConstants.confirmAttendance,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Confirmation failed',
        };
      }
    } catch (e) {
      _logger.e('Confirmation error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// NEW: Cancel provisional attendance (student left before confirmation)
  /// Includes deviceId for backend device-binding enforcement
  Future<Map<String, dynamic>> cancelProvisionalAttendance({
    required String studentId,
    required String classId,
    required String deviceId,
  }) async {
    try {
      final response = await post(
        url: ApiConstants.cancelProvisional,
        body: {
          'studentId': studentId,
          'classId': classId,
          'deviceId': deviceId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Cancellation failed',
        };
      }
    } catch (e) {
      _logger.e('Cancel provisional error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// NEW: Stream RSSI data for co-location detection
  Future<Map<String, dynamic>> streamRSSI({
    required String studentId,
    required String classId,
    required DateTime sessionDate,
    required List<Map<String, dynamic>> rssiData,
  }) async {
    try {
      // Add device timestamp for server-side time sync
      // This allows the backend to calculate clock offset and correct timestamps
      final deviceTimestamp = DateTime.now().toUtc().toIso8601String();
      
      final response = await post(
        url: ApiConstants.rssiStream,
        body: {
          'studentId': studentId,
          'classId': classId,
          'sessionDate': sessionDate.toIso8601String().split('T')[0],
          'rssiData': rssiData,
          'deviceTimestamp': deviceTimestamp, // For clock drift correction
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'RSSI data uploaded',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Upload failed',
        };
      }
    } catch (e) {
      _logger.e('RSSI stream error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// NEW: Get today's attendance status for a student
  /// Used for state synchronization on app startup/login
  Future<Map<String, dynamic>> getTodayAttendance({
    required String studentId,
  }) async {
    try {
      final response = await get(
        url: ApiConstants.todayAttendance(studentId),
      );

      _logger.i('Get today attendance response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'studentId': data['studentId'],
          'date': data['date'],
          'count': data['count'],
          'attendance': data['attendance'] as List,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to fetch attendance',
          'message': error['message'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      _logger.e('Get today attendance error: $e');
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
        'attendance': [], // Return empty array to prevent null errors
      };
    }
  }

  // Static method for background service (legacy)
  static Future<http.Response> submitAttendance(String studentId, String classId) async {
    const String apiUrl = 'https://your-backend-url.vercel.app/api/attendance';
    
    return await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': studentId,
        'class_id': classId,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }
}