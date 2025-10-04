import 'package:http/http.dart' as http;
import 'dart:convert';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

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

  // Static method for background service
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