import 'package:flutter/material.dart';
import 'beacon_status_helpers.dart';

/// Status badges widget for BeaconStatusWidget
/// Displays confirmed or cancelled badges based on attendance status
class BeaconStatusBadges extends StatelessWidget {
  final String status;
  final bool isAwaitingConfirmation;
  final Map<String, dynamic>? cooldownInfo;

  const BeaconStatusBadges({
    super.key,
    required this.status,
    required this.isAwaitingConfirmation,
    this.cooldownInfo,
  });

  @override
  Widget build(BuildContext context) {
    // Show confirmed badge
    if (BeaconStatusHelpers.isConfirmedStatus(status) && !isAwaitingConfirmation) {
      return _buildConfirmedBadge();
    }

    // Show cancelled badge with schedule info
    if (BeaconStatusHelpers.isCancelledStatus(status)) {
      return _buildCancelledBadge();
    }

    return const SizedBox.shrink();
  }

  /// Builds the green confirmed badge
  Widget _buildConfirmedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Text(
            'Attendance Confirmed',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the red cancelled badge with schedule information
  Widget _buildCancelledBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Column(
        children: [
          // Header with icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 10),
              Text(
                'Attendance Cancelled',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          // Enhanced: Show class schedule info if available in cooldownInfo
          if (cooldownInfo != null) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.red.shade300, height: 1),
            const SizedBox(height: 12),

            // Current class end time
            if (cooldownInfo!.containsKey('classEndTimeFormatted') &&
                cooldownInfo!.containsKey('classEnded') &&
                cooldownInfo!['classEnded'] == false) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Current class ends at ',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    cooldownInfo!['classEndTimeFormatted'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ],
              ),
              if (cooldownInfo!.containsKey('classTimeLeftFormatted')) ...[
                const SizedBox(height: 4),
                Text(
                  '(${cooldownInfo!['classTimeLeftFormatted']})',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Next class time
            if (cooldownInfo!.containsKey('nextClassTimeFormatted')) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Try again in next class:',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.class_, color: Colors.red.shade800, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          cooldownInfo!['nextClassTimeFormatted'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    if (cooldownInfo!.containsKey('timeUntilNextFormatted')) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(${cooldownInfo!['timeUntilNextFormatted']})',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Full message (if available)
            if (cooldownInfo!.containsKey('message') &&
                cooldownInfo!['message'] != null) ...[
              const SizedBox(height: 10),
              Text(
                cooldownInfo!['message'],
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 11,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ] else ...[
            // Fallback if no schedule info available
            const SizedBox(height: 8),
            Text(
              'Please try again in the next class',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
