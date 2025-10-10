import 'package:flutter/material.dart';

class ProfileStatsCard extends StatelessWidget {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int streak;

  const ProfileStatsCard({
    super.key,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat(context, 'Total', totalDays, Icons.calendar_today),
            _buildStat(context, 'Present', presentDays, Icons.check_circle, color: Colors.green),
            _buildStat(context, 'Absent', absentDays, Icons.cancel, color: Colors.red),
            _buildStat(context, 'Streak', streak, Icons.local_fire_department, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, int value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
