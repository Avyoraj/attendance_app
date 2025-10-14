class AppConstants {

  // Storage Keys
  static const String studentIdKey = 'student_id';
  static const String deviceIdKey = 'unique_device_id'; // NEW: For device locking
  
  // Beacon Configuration
  static const String schoolIdentifier = 'MySchool';
  static const String proximityUUID = '215d0698-0b3d-34a6-a844-5ce2b2447f1a';
  static const String beaconUUID = '215d0698-0b3d-34a6-a844-5ce2b2447f1a'; // For background service
  
  // RSSI Threshold for attendance
  static const int rssiThreshold = -75;
  static const double rssiDistanceThreshold = 5.0; // Distance in meters for auto attendance
  
  // Advanced RSSI Settings - Optimized for frictionless experience
  static const int minimumReadingsForStability = 2; // Reduced for speed
  static const int rssiVarianceThreshold = 25; // More elastic - allows movement
  static const Duration movementDetectionWindow = Duration(seconds: 2);
  static const Duration provisionalAttendanceDelay = Duration(milliseconds: 200); // Almost instant
  static const Duration confirmationWindow = Duration(seconds: 3); // Shorter validation
  
  // NEW: Two-Step Attendance Configuration
  static const Duration secondCheckDelay = Duration(seconds: 30); // TESTING: Reduced from 10 minutes to 30 seconds
  static const Duration confirmationTimeout = Duration(minutes: 20); // Max time for confirmation
  
  // NEW: RSSI Streaming Configuration (for Co-Location Detection)
  static const Duration rssiStreamDuration = Duration(minutes: 2); // TESTING: Reduced from 15 minutes to 2 minutes
  static const Duration rssiCaptureInterval = Duration(seconds: 5); // Capture every 5 seconds
  static const int rssiMaxBatchSize = 50; // Upload in batches of 50 readings
  static const Duration rssiBatchUploadInterval = Duration(minutes: 1); // Upload every minute
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  
  // Timing
  static const Duration checkInCooldown = Duration(seconds: 30);

}