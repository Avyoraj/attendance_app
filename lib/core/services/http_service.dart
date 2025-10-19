import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  final _logger = Logger();

  // API Base URL - Production Vercel Deployment
  static const String _baseUrl = 'https://attendance-backend-omega.vercel.app/api';
  
  // Alternative URLs (comment/uncomment as needed):
  // For Local Testing: 'http://192.168.1.121:3000/api'
  // For Android Emulator: 'http://10.0.2.2:3000/api'
  // For iOS Simulator: 'http://localhost:3000/api'

  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  Future<http.Response> post({
    required String url,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = {..._defaultHeaders, ...?headers};
    
    return await http.post(
      Uri.parse(url),
      headers: mergedHeaders,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> get({
    required String url,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = {..._defaultHeaders, ...?headers};
    
    return await http.get(
      Uri.parse(url),
      headers: mergedHeaders,
    );
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
        url: '$_baseUrl/check-in',
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
  Future<Map<String, dynamic>> confirmAttendance({
    required String studentId,
    required String classId,
  }) async {
    try {
      final response = await post(
        url: '$_baseUrl/attendance/confirm',  // FIXED: Remove duplicate /api/
        body: {
          'studentId': studentId,
          'classId': classId,
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
  Future<Map<String, dynamic>> cancelProvisionalAttendance({
    required String studentId,
    required String classId,
  }) async {
    try {
      final response = await post(
        url: '$_baseUrl/attendance/cancel-provisional',
        body: {
          'studentId': studentId,
          'classId': classId,
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
      final response = await post(
        url: '$_baseUrl/check-in/stream',
        body: {
          'studentId': studentId,
          'classId': classId,
          'sessionDate': sessionDate.toIso8601String().split('T')[0],
          'rssiData': rssiData,
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