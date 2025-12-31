// Backend smoke validation script
//
// Usage:
//   dart run --define=API_URL=http://localhost:3000/api bin/backend_smoke.dart --studentId S123 --classId CS101
//
// This script performs:
// 1. Provisional check-in (POST /api/check-in)
// 2. Confirmation (POST /api/attendance/confirm) if provisional
// 3. Fetch today's attendance (GET /api/attendance/today/:studentId)
//
// Exit codes:
// 0 = success end-to-end
// 1 = check-in failed
// 2 = confirmation failed
// 3 = today attendance fetch failed
//
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000/api');
const deviceSecret = String.fromEnvironment('DEVICE_SECRET', defaultValue: 'dev-device-secret');

Future<void> main(List<String> args) async {
  final argMap = _parseArgs(args);
  final studentId = argMap['studentId'] ?? 'S123';
  final classId = argMap['classId'] ?? 'CS101';
  final deviceId = argMap['deviceId'] ?? 'smokeDevice_${DateTime.now().millisecondsSinceEpoch}';
  final rssi = int.tryParse(argMap['rssi'] ?? '') ?? -55;

  _log('API base: $apiUrl');
  _log('Student: $studentId  Class: $classId  Device: $deviceId  RSSI: $rssi');

  // Generate signature
  final hmac = Hmac(sha256, utf8.encode(deviceSecret));
  final signature = hmac.convert(utf8.encode(deviceId)).toString();
  final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}';

  // 1. Check-in
  final checkInResult = await _post('$apiUrl/check-in', {
    'studentId': studentId,
    'classId': classId,
    'deviceId': deviceId,
    'rssi': rssi,
    'eventId': eventId,
    'deviceSignature': signature,
    'deviceSaltVersion': 'v1',
  });

  if (checkInResult == null) {
    _fail(1, 'No response body for check-in');
    return;
  }

  if (checkInResult['success'] != true) {
    _fail(1, 'Check-in failed: ${checkInResult['error'] ?? checkInResult['message']}');
    return;
  }

  final attendance = checkInResult['attendance'];
  final status = attendance?['status'];
  final attendanceId = attendance?['id'] ?? attendance?['_id'];
  _log('Check-in OK: id=$attendanceId status=$status');

  // If cooldown or confirmed already, skip confirmation step.
  if (status == 'cooldown' || status == 'confirmed') {
    _log('Skipping confirmation (status=$status)');
  } else if (status == 'provisional') {
    // 2. Confirm
    _log('Attempting confirmation...');
    final confirmEventId = 'evt_conf_${DateTime.now().millisecondsSinceEpoch}';
    final confirmResult = await _post('$apiUrl/attendance/confirm', {
      'studentId': studentId,
      'classId': classId,
      'deviceId': deviceId,
      'eventId': confirmEventId,
      'deviceSignature': signature,
      'deviceSaltVersion': 'v1',
    });

    if (confirmResult == null || confirmResult['success'] != true) {
      _fail(2, 'Confirmation failed: ${confirmResult?['error'] ?? confirmResult?['message']}');
      return;
    }
    final confAttendance = confirmResult['attendance'];
    _log('Confirmation OK: status=${confAttendance?['status']} confirmedAt=${confAttendance?['confirmedAt']}');
  } else {
    _log('Unexpected status after check-in: $status (continuing)');
  }

  // 3. Fetch today attendance
  _log('Fetching today attendance...');
  final todayRes = await _get('$apiUrl/attendance/today/$studentId');
  if (todayRes == null || todayRes['success'] != true) {
    _fail(3, 'Today attendance fetch failed: ${todayRes?['error'] ?? todayRes?['message']}');
    return;
  }

  final list = (todayRes['attendance'] as List?) ?? [];
  final found = list.any((a) => a['classId'] == classId && (a['status'] == 'confirmed' || a['status'] == 'cooldown' || a['status'] == 'provisional'));
  _log('Attendance records today: ${todayRes['count']} (found matching class: $found)');

  if (!found) {
    _fail(3, 'Attendance record for classId=$classId not found in today list');
    return;
  }

  _log('Smoke validation SUCCESS');
  exit(0);
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--')) {
      final key = arg.substring(2);
      final next = i + 1 < args.length ? args[i + 1] : '';
      if (!next.startsWith('--') && next.isNotEmpty) {
        map[key] = next;
        i++; // skip value
      } else {
        map[key] = 'true';
      }
    }
  }
  return map;
}

Future<Map<String, dynamic>?> _post(String url, Map<String, dynamic> body) async {
  try {
    final resp = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 10));
    final data = jsonDecode(resp.body);
    return data is Map<String, dynamic> ? data : {'raw': data};
  } catch (e) {
    _log('POST error $url: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> _get(String url) async {
  try {
    final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    final data = jsonDecode(resp.body);
    return data is Map<String, dynamic> ? data : {'raw': data};
  } catch (e) {
    _log('GET error $url: $e');
    return null;
  }
}

void _log(String msg) => stdout.writeln('[SMOKE] $msg');
void _fail(int code, String msg) {
  _log('FAIL(code=$code): $msg');
  exit(code);
}
