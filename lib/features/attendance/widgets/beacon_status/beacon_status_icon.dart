import 'package:flutter/material.dart';
import 'beacon_status_helpers.dart';

/// Status icon widget for BeaconStatusWidget
/// Displays animated icon based on current attendance status
class BeaconStatusIcon extends StatelessWidget {
  final String status;
  final bool isCheckingIn;

  const BeaconStatusIcon({
    super.key,
    required this.status,
    required this.isCheckingIn,
  });

  @override
  Widget build(BuildContext context) {
    // Show loading spinner when checking in
    if (isCheckingIn) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          shape: BoxShape.circle,
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
        ),
      );
    }

    // Get icon and color from helpers
    final icon = BeaconStatusHelpers.getStatusIcon(status, isCheckingIn);
    final color = BeaconStatusHelpers.getStatusColor(status, isCheckingIn);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 64,
        color: color,
      ),
    );
  }
}
