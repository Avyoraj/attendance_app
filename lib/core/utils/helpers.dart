import 'package:flutter/material.dart';

class AppHelpers {
  /// Shows a snackbar with a message
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Shows a success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Shows an error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Validates if a string is not empty
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  /// Validates student ID format (you can customize this)
  static String? validateStudentId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your Student ID';
    }
    if (value.trim().length < 3) {
      return 'Student ID must be at least 3 characters';
    }
    return null;
  }

  /// Formats RSSI value for display
  static String formatRssi(int rssi) {
    if (rssi > -50) return 'Excellent';
    if (rssi > -70) return 'Good';
    if (rssi > -80) return 'Fair';
    if (rssi > -90) return 'Weak';
    return 'Very Weak';
  }

  /// Gets signal strength color based on RSSI
  static Color getSignalStrengthColor(int rssi) {
    if (rssi > -50) return Colors.green;
    if (rssi > -70) return Colors.lightGreen;
    if (rssi > -80) return Colors.orange;
    if (rssi > -90) return Colors.deepOrange;
    return Colors.red;
  }
}