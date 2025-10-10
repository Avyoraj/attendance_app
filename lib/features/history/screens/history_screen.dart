import 'package:flutter/material.dart';
import '../../../core/services/attendance_service.dart';
import '../../../models/attendance_record.dart';
import '../widgets/attendance_history_list.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<AttendanceRecord>> _getHistory() async {
    // Replace with actual studentId from auth context if available
    const studentId = '123456';
    return await AttendanceService().getAttendanceHistory(studentId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AttendanceRecord>>(
      future: _getHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: AttendanceHistoryList(records: records),
        );
      },
    );
  }
}
