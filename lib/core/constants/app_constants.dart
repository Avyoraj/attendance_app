class AppConstants {
  // Storage Keys
  static const String studentIdKey = 'student_id';
  static const String deviceIdKey =
      'unique_device_id'; // NEW: For device locking

  // Beacon Configuration
  static const String schoolIdentifier = 'MySchool';
  static const String proximityUUID = '215d0698-0b3d-34a6-a844-5ce2b2447f1a';
  static const String beaconUUID =
      '215d0698-0b3d-34a6-a844-5ce2b2447f1a'; // For background service

  // RSSI Threshold for attendance
  // 🎯 NEW: Dual-threshold system for better accuracy
  static const int checkInRssiThreshold =
      -75; // Strong signal required to START attendance
  static const int confirmationRssiThreshold =
      -82; // Weaker signal OK for STAYING (more lenient)
  static const int rssiThreshold =
      -75; // Legacy - kept for backward compatibility
  static const double rssiDistanceThreshold =
      5.0; // Distance in meters for auto attendance

  // Advanced RSSI Settings - Optimized for frictionless experience
  static const int minimumReadingsForStability = 2; // Reduced for speed
  static const int rssiVarianceThreshold = 25; // More elastic - allows movement
  static const Duration movementDetectionWindow = Duration(seconds: 2);
  static const Duration provisionalAttendanceDelay =
      Duration(milliseconds: 200); // Almost instant
  static const Duration confirmationWindow =
      Duration(seconds: 3); // Shorter validation

  // NEW: Two-Step Attendance Configuration
  static const Duration secondCheckDelay = Duration(
      minutes:
          3); // TESTING: 3 minutes (long enough for grace period to be negligible)
  static const Duration confirmationTimeout =
      Duration(minutes: 20); // Max time for confirmation

  // 🚨 NEW: Beacon Monitoring Configuration (Tune these if too aggressive/lenient)
  static const Duration beaconMonitoringInterval =
      Duration(seconds: 10); // How often to check (10s = balanced)
  static const Duration beaconLostTimeout = Duration(
      seconds: 45); // When to consider beacon "lost" (45s = very tolerant)
  // Note: If beacon not detected for 45 seconds → Attendance cancelled
  //       Lower value = more strict, Higher value = more lenient
  //       45s allows for BLE scanning gaps (Android power-saving, interference)

  // 🎯 NEW: RSSI Smoothing Configuration (Reduces noise from body movement)
  static const int rssiSmoothingWindow = 5; // Average last 5 readings
  static const Duration rssiSampleMaxAge = Duration(
      seconds:
          50); // Discard samples older than 50s (must be > beaconLostTimeout to handle BLE gaps)

  // 🎯 NEW: Exit Hysteresis Configuration (Prevents false cancellations)
  static const Duration exitGracePeriod =
      Duration(seconds: 30); // 30s grace for temporary signal loss
  // If signal weak for < 30s → Ignore (body movement, phone rotation)
  // If signal weak for > 30s → Student actually left classroom

  // NEW: RSSI Streaming Configuration (for Co-Location Detection)
  static const Duration rssiStreamDuration = Duration(
      minutes: 15); // PRODUCTION: 15 minutes (changed from 2 minutes testing)
  static const Duration rssiCaptureInterval =
      Duration(seconds: 5); // Capture every 5 seconds
  static const int rssiMaxBatchSize = 50; // Upload in batches of 50 readings
  static const Duration rssiBatchUploadInterval =
      Duration(minutes: 1); // Upload every minute

    // 🔒 Confirmation-time beacon visibility requirement
    // Require that a real beacon packet was seen very recently at the moment of confirmation
    // This prevents confirmations when the beacon is turned off or Bluetooth is disabled
    // 📱 Increased from 2s to 10s to handle locked screen scenarios where BLE scanning is throttled
    static const Duration confirmationBeaconVisibilityMaxAge = Duration(seconds: 10);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;

  // Timing
  static const Duration checkInCooldown = Duration(seconds: 30);

  // 🎓 NEW: College Schedule Configuration
  // College timing: 10:30 AM to 5:30 PM
  // 1-hour classes with 30-minute break from 1:30 PM to 2:00 PM
  static const int collegeStartHour = 10;
  static const int collegeStartMinute = 30;
  static const int collegeEndHour = 17;
  static const int collegeEndMinute = 30;

  static const int breakStartHour = 13;
  static const int breakStartMinute = 30;
  static const int breakEndHour = 14;
  static const int breakEndMinute = 0;

  static const Duration classDuration = Duration(hours: 1);
  static const Duration cooldownDuration = Duration(minutes: 15);
}
