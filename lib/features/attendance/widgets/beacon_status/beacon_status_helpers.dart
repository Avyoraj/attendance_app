import 'package:flutter/material.dart';

/// Helper utilities for BeaconStatusWidget
/// Provides time formatting and status interpretation
class BeaconStatusHelpers {
  /// Formats seconds into MM:SS format
  /// Example: 125 seconds -> "02:05"
  static String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Determines icon based on status string
  static IconData getStatusIcon(String status, bool isCheckingIn) {
    if (isCheckingIn) {
      return Icons.hourglass_empty; // Placeholder, will show spinner
    }

    if (status.contains('CONFIRMED')) {
      return Icons.check_circle;
    } else if (status.contains('Check-in recorded') ||
        status.contains('recorded')) {
      return Icons.pending;
    } else if (status.contains('failed') ||
        status.contains('Error') ||
        status.contains('Device Locked')) {
      return Icons.error;
    } else if (status.contains('Scanning')) {
      return Icons.bluetooth_searching;
    } else if (status.contains('Move closer')) {
      return Icons.my_location;
    } else {
      return Icons.bluetooth;
    }
  }

  /// Determines color based on status string
  static Color getStatusColor(String status, bool isCheckingIn) {
    if (isCheckingIn) {
      return Colors.indigo;
    }

    if (status.contains('CONFIRMED')) {
      return Colors.green;
    } else if (status.contains('Check-in recorded') ||
        status.contains('recorded')) {
      return Colors.orange;
    } else if (status.contains('failed') ||
        status.contains('Error') ||
        status.contains('Device Locked')) {
      return Colors.red;
    } else if (status.contains('Scanning')) {
      return Colors.blue;
    } else if (status.contains('Move closer')) {
      return Colors.amber;
    } else {
      return Colors.grey;
    }
  }

  /// Checks if status indicates a confirmed state
  static bool isConfirmedStatus(String status) {
    return status.contains('CONFIRMED') ||
        status.contains('Already Checked In');
  }

  /// Checks if status indicates a cancelled state
  static bool isCancelledStatus(String status) {
    return status.contains('Cancelled') || status.contains('cancelled');
  }

  /// Checks if cooldown card should be shown
  static bool shouldShowCooldown(
      Map<String, dynamic>? cooldownInfo, String status) {
    return cooldownInfo != null &&
        cooldownInfo['inCooldown'] == true &&
        !isCancelledStatus(status);
  }
}
