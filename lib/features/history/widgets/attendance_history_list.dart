import 'package:flutter/material.dart';
import '../../../models/attendance_record.dart';

class AttendanceHistoryList extends StatelessWidget {
  final List<AttendanceRecord> records;
  const AttendanceHistoryList({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No attendance records found.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final itemCount = records.length * 2 - 1;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) {
            return const Divider(height: 1);
          }

          final recordIndex = index ~/ 2;
          final record = records[recordIndex];
          final status = record.status.toLowerCase();
          final isSuccess = status == 'confirmed' || status == 'present';
          final isCancelled = status == 'cancelled';
          final icon = isSuccess
              ? Icons.check_circle
              : isCancelled
                  ? Icons.cancel
                  : Icons.hourglass_empty;
          final color = isSuccess
              ? Colors.green
              : isCancelled
                  ? Colors.red
                  : Theme.of(context).colorScheme.secondary;
          final subtitle = record.metadata != null &&
                  record.metadata!['cancellationReason'] != null
              ? '${record.classId} • ${record.metadata!['cancellationReason']}'
              : 'Class: ${record.classId}';

          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              '${record.timestamp.day}/${record.timestamp.month}/${record.timestamp.year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(subtitle),
            trailing: Text(record.status.toUpperCase()),
          );
        },
        childCount: itemCount,
      ),
    );
  }
}
