import 'package:flutter/material.dart';
import '../../../models/attendance_record.dart';

class AttendanceHistoryList extends StatelessWidget {
  final List<AttendanceRecord> records;
  const AttendanceHistoryList({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('No attendance records found.'));
    }
    return ListView.separated(
      itemCount: records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = records[index];
        return ListTile(
          leading: Icon(
            record.status.toLowerCase() == 'present' ? Icons.check_circle : Icons.cancel,
            color: record.status.toLowerCase() == 'present' ? Colors.green : Colors.red,
          ),
          title: Text(
            '${record.timestamp.day}/${record.timestamp.month}/${record.timestamp.year}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text('Class: ${record.classId}'),
          trailing: Text(record.status),
        );
      },
    );
  }
}
