import 'package:flutter/material.dart';
import 'package:attendance_app/features/attendance/screens/home_screen/home_screen_state.dart';
import 'package:attendance_app/core/constants/app_constants.dart';
import 'circular_confirmation_timer.dart';

/// A minimal, calm status banner with no animations.
/// Focuses on a single line status and an optional timer pill.
class CalmStatusBanner extends StatelessWidget {
  final HomeScreenState state;
  final String studentId;

  const CalmStatusBanner(
      {super.key, required this.state, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isBlocked = state.beaconStatusType == BeaconStatusType.failed ||
        state.beaconStatusType == BeaconStatusType.deviceLocked;
    final isCancelled = state.beaconStatusType == BeaconStatusType.cancelled;

    final backgroundColor = isCancelled ? colors.errorContainer : colors.surfaceContainerHighest;
    final contentColor = isCancelled ? colors.onErrorContainer : colors.onSurface;
    final iconColor = isCancelled ? colors.onErrorContainer : colors.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCancelled ? colors.error : colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(_iconFor(state.beaconStatusType),
              color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.beaconStatus,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: contentColor,
                    height: 1.3,
                    fontWeight: isCancelled ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (state.isAwaitingConfirmation && state.remainingSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Confirmation in progress',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (isBlocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Row(
                      children: [
                        Icon(Icons.shield, size: 14, color: colors.error),
                        const SizedBox(width: 6),
                        Text(
                          'Blocked — please see admin',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isCancelled && (state.beaconStatus.contains('Proxy') || state.beaconStatus.contains('Flagged')))
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FLAGGED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
    );
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
      case BeaconStatusType.noSession:
        return Icons.event_busy;
      case BeaconStatusType.info:
        return Icons.bluetooth_searching;
    }
  }
}
