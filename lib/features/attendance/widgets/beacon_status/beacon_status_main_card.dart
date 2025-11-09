import 'package:flutter/material.dart';
import 'beacon_status_timer.dart';
import 'beacon_status_badges.dart';
import 'beacon_status_cooldown.dart';

/// Main status card for BeaconStatusWidget
/// Orchestrates the display of status message, timer, badges, and cooldown info
class BeaconStatusMainCard extends StatelessWidget {
  final String status;
  final bool isCheckingIn;
  final int? remainingSeconds;
  final bool isAwaitingConfirmation;
  final Map<String, dynamic>? cooldownInfo;
  final String? currentClassId;

  const BeaconStatusMainCard({
    super.key,
    required this.status,
    required this.isCheckingIn,
    this.remainingSeconds,
    required this.isAwaitingConfirmation,
    this.cooldownInfo,
    this.currentClassId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Title
            Text(
              'Attendance Status',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            // Divider
            Divider(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            const SizedBox(height: 16),

            // Status Message
            Text(
              status,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),

            // Loading Indicator
            if (isCheckingIn) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],

            // Timer Countdown (if confirming)
            if (remainingSeconds != null) ...[
              const SizedBox(height: 20),
              BeaconStatusTimer(
                remainingSeconds: remainingSeconds!,
                isAwaitingConfirmation: isAwaitingConfirmation,
              ),
            ],

            // Confirmed or Cancelled Badge
            const SizedBox(height: 20),
            BeaconStatusBadges(
              status: status,
              isAwaitingConfirmation: isAwaitingConfirmation,
              cooldownInfo: cooldownInfo,
            ),

            // Schedule-Aware Cooldown Information
            if (cooldownInfo != null) ...[
              const SizedBox(height: 20),
              BeaconStatusCooldown(
                cooldownInfo: cooldownInfo!,
                currentClassId: currentClassId,
                status: status,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
