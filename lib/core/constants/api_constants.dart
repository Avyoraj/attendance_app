import 'package:attendance_app/core/config/environment.dart';

class ApiConstants {
  // Base URL now provided via --dart-define=API_URL, see Environment.apiUrl.
  // Examples:
  //  - flutter run --dart-define=API_URL=http://10.0.2.2:3000/api
  //  - flutter build apk --dart-define=API_URL=https://prod.example.com/api
  static const String apiBase = Environment.apiUrl;

  // Core attendance endpoints
  // NOTE: server.js registers direct routes (/api/check-in) to match mobile client expectations.
  // Avoid '/api/attendance/check-in' unless backend routing changes.
  static const String checkIn = '$apiBase/check-in';
  static const String confirmAttendance = '$apiBase/attendance/confirm';
  static const String cancelProvisional =
      '$apiBase/attendance/cancel-provisional';
  static String todayAttendance(String studentId) =>
      '$apiBase/attendance/today/$studentId';

  // Device + RSSI endpoints
  static const String validateDevice = '$apiBase/validate-device';
  static const String rssiStream = '$apiBase/check-in/stream';
  static const String analyzeCorrelations = '$apiBase/rssi/analyze';

  // Admin endpoints (Teacher/Admin dashboard only)
  // These require Bearer token authentication
  static const String adminDeviceBindings = '$apiBase/students/admin/device-bindings';
  static String adminResetDevice(String studentId) =>
      '$apiBase/students/admin/reset-device/$studentId';
}
