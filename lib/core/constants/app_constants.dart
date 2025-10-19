class AppConstants {

  // Storage Keys
  static const String studentIdKey = 'student_id';
  static const String deviceIdKey = 'unique_device_id'; // NEW: For device locking
  
  // Beacon Configuration
  static const String schoolIdentifier = 'MySchool';
  static const String proximityUUID = '215d0698-0b3d-34a6-a844-5ce2b2447f1a';
  static const String beaconUUID = '215d0698-0b3d-34a6-a844-5ce2b2447f1a'; // For background service
  
  // RSSI Threshold for attendance
  // 🎯 NEW: Dual-threshold system for better accuracy
  static const int checkInRssiThreshold = -75;  // Strong signal required to START attendance
  static const int confirmationRssiThreshold = -82; // Weaker signal OK for STAYING (more lenient)
  static const int rssiThreshold = -75; // Legacy - kept for backward compatibility
  static const double rssiDistanceThreshold = 5.0; // Distance in meters for auto attendance
  
  // Advanced RSSI Settings - Optimized for frictionless experience
  static const int minimumReadingsForStability = 2; // Reduced for speed
  static const int rssiVarianceThreshold = 25; // More elastic - allows movement
  static const Duration movementDetectionWindow = Duration(seconds: 2);
  static const Duration provisionalAttendanceDelay = Duration(milliseconds: 200); // Almost instant
  static const Duration confirmationWindow = Duration(seconds: 3); // Shorter validation
  
  // NEW: Two-Step Attendance Configuration
  static const Duration secondCheckDelay = Duration(minutes: 3); // TESTING: 3 minutes (long enough for grace period to be negligible)
  static const Duration confirmationTimeout = Duration(minutes: 20); // Max time for confirmation
  
  // 🚨 NEW: Beacon Monitoring Configuration (Tune these if too aggressive/lenient)
  static const Duration beaconMonitoringInterval = Duration(seconds: 10); // How often to check (10s = balanced)
  static const Duration beaconLostTimeout = Duration(seconds: 45); // When to consider beacon "lost" (45s = very tolerant)
  // Note: If beacon not detected for 45 seconds → Attendance cancelled
  //       Lower value = more strict, Higher value = more lenient
  //       45s allows for BLE scanning gaps (Android power-saving, interference)
  
  // 🎯 NEW: RSSI Smoothing Configuration (Reduces noise from body movement)
  static const int rssiSmoothingWindow = 5; // Average last 5 readings
  static const Duration rssiSampleMaxAge = Duration(seconds: 50); // Discard samples older than 50s (must be > beaconLostTimeout to handle BLE gaps)
  
  // 🎯 NEW: Exit Hysteresis Configuration (Prevents false cancellations)
  static const Duration exitGracePeriod = Duration(seconds: 30); // 30s grace for temporary signal loss
  // If signal weak for < 30s → Ignore (body movement, phone rotation)
  // If signal weak for > 30s → Student actually left classroom
  
  // NEW: RSSI Streaming Configuration (for Co-Location Detection)
  static const Duration rssiStreamDuration = Duration(minutes: 15); // PRODUCTION: 15 minutes (changed from 2 minutes testing)
  static const Duration rssiCaptureInterval = Duration(seconds: 5); // Capture every 5 seconds
  static const int rssiMaxBatchSize = 50; // Upload in batches of 50 readings
  static const Duration rssiBatchUploadInterval = Duration(minutes: 1); // Upload every minute
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  
  // Timing
  static const Duration checkInCooldown = Duration(seconds: 30);

}