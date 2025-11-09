import 'dart:convert';

import '../../models/attendance_record.dart';
import '../constants/api_constants.dart';
import 'http_service.dart';
import 'logger_service.dart';
import 'local_database_service.dart';
import 'dart:async';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  final HttpService _httpService = HttpService();
  final LoggerService _logger = LoggerService();

  Future<List<AttendanceRecord>> getAttendanceHistory(
    String studentId, {
    int limit = 100,
    String? status,
  }) async {
    try {
      final query = <String, String>{
        'studentId': studentId,
        'limit': limit.toString(),
      };

      if (status != null && status.isNotEmpty) {
        query['status'] = status;
      }

      final uri = Uri.parse('${ApiConstants.apiBase}/attendance')
          .replace(queryParameters: query);

      final response = await _httpService.get(url: uri.toString());

      if (response.statusCode != 200) {
        _logger.error(
            'Failed to load attendance history (status=${response.statusCode})',
            response.body);
        // Fallback 1: Try today's attendance endpoint for at least partial data
        final todayResp = await _httpService.get(
            url: ApiConstants.todayAttendance(studentId));
        if (todayResp.statusCode == 200) {
          final todayData = jsonDecode(todayResp.body) as Map<String, dynamic>;
          final todayItems = (todayData['attendance'] as List?) ?? const [];
          return todayItems
              .map((item) => AttendanceRecord.fromBackendJson(
                  item as Map<String, dynamic>))
              .toList();
        }
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['attendance'] as List?) ?? const [];

      return items
          .map((item) =>
              AttendanceRecord.fromBackendJson(item as Map<String, dynamic>))
          .toList();
    } on TimeoutException catch (e, stack) {
      _logger.error(
          'Attendance history timed out. Falling back to local cache.',
          e,
          stack);
      return await _loadHistoryFromLocal(studentId: studentId, limit: limit);
    } catch (e, stack) {
      _logger.error(
          'Attendance history fetch error. Falling back to local cache.',
          e,
          stack);
      return await _loadHistoryFromLocal(studentId: studentId, limit: limit);
    }
  }

  Future<List<AttendanceRecord>> _loadHistoryFromLocal({
    required String studentId,
    int limit = 100,
  }) async {
    try {
      final local = await LocalDatabaseService().getAllRecords(limit: limit);
      return local.map((row) {
        final id = row['id']?.toString() ?? '0';
        final tsStr = row['timestamp'] as String?;
        final ts = (tsStr != null)
            ? DateTime.tryParse(tsStr) ?? DateTime.now()
            : DateTime.now();
        final synced = (row['synced'] == 1);
        final rssi = row['rssi'];
        final distance = row['distance'];
        return AttendanceRecord(
          id: 'local:$id',
          studentId: (row['student_id'] as String?) ?? studentId,
          classId: (row['class_id'] as String?) ?? '',
          timestamp: ts,
          status: synced ? 'cached' : 'pending',
          metadata: {
            'rssi': rssi,
            'distance': distance,
            'source': 'local-cache',
          }..removeWhere((k, v) => v == null),
        );
      }).toList();
    } catch (e, stack) {
      _logger.error('Failed to load local history', e, stack);
      return const [];
    }
  }

  Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    _logger.warning('saveAttendanceRecord is not implemented yet', record);
  }

  Future<void> syncWithBackend() async {
    _logger.warning('syncWithBackend is not implemented yet');
  }
}
