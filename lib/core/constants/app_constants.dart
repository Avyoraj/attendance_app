class AppConstants {
  // Storage Keys
  static const String studentIdKey = 'student_id';
  
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
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  
  // Timing
  static const Duration checkInCooldown = Duration(seconds: 30);
}