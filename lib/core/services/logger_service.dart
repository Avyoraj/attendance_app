import 'package:logger/logger.dart';

/// Centralized logging service for the entire app
/// Replaces all print statements with proper logging
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  late final Logger _logger;

  void initialize() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: Level.debug, // Change to Level.info for production
    );
  }

  // Debug level - detailed information for debugging
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  // Info level - general informational messages
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  // Warning level - warning messages
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  // Error level - error messages
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  // Fatal level - very severe error messages
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // Beacon specific logging
  void beaconDetected(String classId, int rssi, double distance) {
    info('📡 Beacon detected: $classId | RSSI: $rssi | Distance: ${distance.toStringAsFixed(2)}m');
  }

  void attendanceRecorded(String studentId, String classId, bool success) {
    if (success) {
      info('✅ Attendance recorded: Student $studentId in $classId');
    } else {
      error('❌ Attendance failed: Student $studentId in $classId');
    }
  }

  void backgroundServiceStatus(String status) {
    info('🔄 Background service: $status');
  }

  void networkStatus(bool isOnline) {
    if (isOnline) {
      info('🌐 Network: ONLINE');
    } else {
      warning('📵 Network: OFFLINE');
    }
  }

  void bluetoothStatus(bool isEnabled) {
    if (isEnabled) {
      info('🔵 Bluetooth: ENABLED');
    } else {
      warning('❌ Bluetooth: DISABLED');
    }
  }
}
