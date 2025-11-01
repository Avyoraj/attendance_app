import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import 'beacon_status_helpers.dart';

/// Confirmation timer widget for BeaconStatusWidget
/// Displays countdown timer with progress bar during attendance confirmation
class BeaconStatusTimer extends StatelessWidget {
  final int remainingSeconds;
  final bool isAwaitingConfirmation;

  const BeaconStatusTimer({
    super.key,
    required this.remainingSeconds,
    required this.isAwaitingConfirmation,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if awaiting confirmation and time remaining
    if (!isAwaitingConfirmation || remainingSeconds <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          // Timer display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 10),
              Text(
                BeaconStatusHelpers.formatTime(remainingSeconds),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Status message
          Text(
            'Confirming attendance...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: remainingSeconds / AppConstants.secondCheckDelay.inSeconds,
              minHeight: 6,
              backgroundColor: Colors.orange.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
