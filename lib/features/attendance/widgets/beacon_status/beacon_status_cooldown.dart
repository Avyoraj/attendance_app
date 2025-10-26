import 'package:flutter/material.dart';
import 'beacon_status_helpers.dart';

/// Schedule-aware cooldown information widget for BeaconStatusWidget
/// Displays cooldown period with class schedule information
class BeaconStatusCooldown extends StatelessWidget {
  final Map<String, dynamic> cooldownInfo;
  final String? currentClassId;
  final String status;

  const BeaconStatusCooldown({
    super.key,
    required this.cooldownInfo,
    this.currentClassId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if cooldown is active and not in cancelled state
    if (!BeaconStatusHelpers.shouldShowCooldown(cooldownInfo, status)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, color: Colors.blue.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Cooldown Active',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          // Current class ID badge
          if (currentClassId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Class: $currentClassId',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(color: Colors.blue.shade300, height: 1),
          const SizedBox(height: 12),

          // Class end time (Schedule-aware)
          if (cooldownInfo.containsKey('classEndTimeFormatted') &&
              cooldownInfo['classEnded'] == false) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, color: Colors.blue.shade600, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Class ends at ',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  cooldownInfo['classEndTimeFormatted'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            if (cooldownInfo.containsKey('classTimeLeftFormatted')) ...[
              const SizedBox(height: 4),
              Text(
                '(${cooldownInfo['classTimeLeftFormatted']})',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],

          // Schedule message (if available)
          if (cooldownInfo.containsKey('message') &&
              cooldownInfo['message'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                cooldownInfo['message'],
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
