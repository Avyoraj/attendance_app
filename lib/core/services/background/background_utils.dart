/// Shared utilities for background attendance processing
library;

/// Calculate estimated distance from RSSI and TX power
/// Uses logarithmic path-loss model
double calculateDistanceFromRssi(int rssi, int txPower) {
  if (rssi == 0) return -1.0;

  final ratio = rssi * 1.0 / txPower;
  if (ratio < 1.0) {
    return (ratio * 10);
  } else {
    // Path-loss model approximation
    final accuracy =
        (0.89976) * (ratio * ratio * ratio * ratio * ratio * ratio * ratio) +
            0.111;
    return accuracy;
  }
}

/// Task identifiers for Workmanager
class BackgroundTaskIds {
  static const String beaconScanning = 'beaconScanning';
  static const String syncAttendance = 'syncAttendance';
  static const String beaconScanningTask = 'beaconScanningTask';
  static const String syncAttendanceTask = 'syncAttendanceTask';
}

/// Durations for background tasks
class BackgroundTaskDurations {
  static const Duration beaconScanFrequency = Duration(minutes: 15);
  static const Duration syncFrequency = Duration(minutes: 30);
  static const Duration initialDelay = Duration(seconds: 10);
  static const Duration scanTimeout = Duration(seconds: 10);
  static const Duration recentAttendanceWindow = Duration(minutes: 30);
}
