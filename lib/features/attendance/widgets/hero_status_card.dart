import 'package:flutter/material.dart';
import 'package:attendance_app/features/attendance/screens/home_screen/home_screen_state.dart';
import 'package:attendance_app/core/constants/app_constants.dart';
import 'circular_confirmation_timer.dart';

class HeroStatusCard extends StatelessWidget {
  final HomeScreenState state;
  final String studentId;

  const HeroStatusCard(
      {super.key, required this.state, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildCard(context, colorScheme);
  }

  Widget _buildCard(BuildContext context, ColorScheme colorScheme) {
    final statusColor = _statusColor(colorScheme, state.beaconStatusType);
    final distance = state.lastDistance;
    final rssi = state.lastRssi;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.08),
              colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusIcon(colorScheme, state.beaconStatusType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusTitle(state.beaconStatusType),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.beaconStatus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
                if (state.isAwaitingConfirmation && state.remainingSeconds > 0)
                  CompactConfirmationTimer(
                    totalSeconds: AppConstants.secondCheckDelay.inSeconds,
                    remainingSeconds: state.remainingSeconds,
                    isActive: state.isAwaitingConfirmation,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _proximityMeter(context, colorScheme,
                      distance: distance, rssi: rssi),
                ),
                const SizedBox(width: 12),
                _studentChip(context, colorScheme, studentId),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(ColorScheme colorScheme, BeaconStatusType type) {
    final icon = _iconFor(type);
    final color = _statusColor(colorScheme, type);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _proximityMeter(BuildContext context, ColorScheme colorScheme,
      {double? distance, int? rssi}) {
    // Normalize distance (closer is better). We'll cap to 0-5m for UI.
    final dist = (distance ?? 5.0).clamp(0.0, 5.0);
    final progress = 1.0 - (dist / 5.0); // 1 when 0m, 0 when >=5m

    final barColor =
        Color.lerp(colorScheme.error, colorScheme.primary, progress) ??
            colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Proximity',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              dist.isFinite ? '${dist.toStringAsFixed(1)} m' : '—',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (rssi != null) ...[
              const SizedBox(width: 8),
              Text(
                'RSSI $rssi',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ]
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.isFinite ? progress : 0.0,
            minHeight: 10,
            color: barColor,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _studentChip(
      BuildContext context, ColorScheme colorScheme, String studentId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person, size: 16, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            studentId,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ColorScheme scheme, BeaconStatusType type) {
    switch (type) {
      case BeaconStatusType.scanning:
      case BeaconStatusType.info:
        return scheme.primary;
      case BeaconStatusType.provisional:
        return scheme.tertiary;
      case BeaconStatusType.confirming:
        return scheme.secondary;
      case BeaconStatusType.confirmed:
      case BeaconStatusType.success:
        return scheme.primary;
      case BeaconStatusType.cooldown:
        return scheme.outline;
      case BeaconStatusType.cancelled:
      case BeaconStatusType.failed:
      case BeaconStatusType.deviceLocked:
        return scheme.error;
    }
  }

  IconData _iconFor(BeaconStatusType type) {
    switch (type) {
      case BeaconStatusType.scanning:
        return Icons.radar;
      case BeaconStatusType.provisional:
        return Icons.hourglass_bottom;
      case BeaconStatusType.confirming:
        return Icons.task_alt;
      case BeaconStatusType.confirmed:
      case BeaconStatusType.success:
        return Icons.check_circle;
      case BeaconStatusType.cancelled:
        return Icons.cancel_outlined;
      case BeaconStatusType.failed:
        return Icons.error_outline;
      case BeaconStatusType.cooldown:
        return Icons.schedule;
      case BeaconStatusType.deviceLocked:
        return Icons.lock_outline;
      case BeaconStatusType.info:
        return Icons.bluetooth_searching;
    }
  }

  String _statusTitle(BeaconStatusType type) {
    switch (type) {
      case BeaconStatusType.scanning:
        return 'Scanning for Beacons';
      case BeaconStatusType.provisional:
        return 'Stay Nearby to Confirm';
      case BeaconStatusType.confirming:
        return 'Finalizing Your Check-in';
      case BeaconStatusType.confirmed:
        return 'Attendance Confirmed';
      case BeaconStatusType.success:
        return 'Attendance Recorded';
      case BeaconStatusType.cancelled:
        return 'Attendance Cancelled';
      case BeaconStatusType.failed:
        return 'Check-in Failed';
      case BeaconStatusType.cooldown:
        return 'Already Checked In';
      case BeaconStatusType.deviceLocked:
        return 'Device Locked';
      case BeaconStatusType.info:
        return 'Attendance Status';
    }
  }
}
