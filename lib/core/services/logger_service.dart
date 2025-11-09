import 'package:logger/logger.dart';
import '../config/log_config.dart';

/// Centralized logging service for the entire app
/// Replaces all print statements with proper logging
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal() {
    _initializeLogger();
  }

  late Logger _logger;
  Level _logLevel = Level.debug;
  final Map<String, DateTime> _lastCategoryLogTime = {};

  void _initializeLogger() {
    // Re-evaluate desired level when initializing
    final level = LogConfig.effectiveLevel;
    _logLevel = level;

    // When quiet mode is enabled we switch to a much more compact printer without
    // method traces or emojis to reduce line noise.
    final bool printEmojis = LogConfig.quiet ? false : LogConfig.useEmojis;
    final bool isQuiet = LogConfig.quiet;

    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: isQuiet ? 0 : 2,
        errorMethodCount: isQuiet ? 4 : 8,
        lineLength: isQuiet ? 90 : 120,
        colors: true,
        printEmojis: printEmojis,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: level,
    );
  }

  /// Optionally reconfigure the logger at runtime.
  void initialize({Level? level}) {
    // Allow explicit override but prefer environment effective level
    if (level != null) {
      _logLevel = level;
    }
    _initializeLogger();
    // Auto-adjust verbose flag: disable debug spam if level >= info or quiet mode
    if (LogConfig.quiet || _logLevel.index >= Level.info.index) {
      LogConfig.verbose = false;
    }
  }

  // Debug level - detailed information for debugging
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!LogConfig.verbose) return; // Suppress debug logs when verbose disabled
    _logger.d(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  // Info level - general informational messages
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  // Warning level - warning messages
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  // Error level - error messages
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  // Fatal level - very severe error messages
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  /// Throttled debug logging for high-frequency events (e.g. timer ticks, RSSI samples)
  void debugThrottled(String category, String message, {Duration? interval}) {
    if (!LogConfig.verbose) return;
    final effectiveInterval = interval ?? LogConfig.defaultThrottleInterval;
    final now = DateTime.now();
    final lastTime = _lastCategoryLogTime[category];
    if (lastTime == null || now.difference(lastTime) >= effectiveInterval) {
      _lastCategoryLogTime[category] = now;
      _logger.d(_sanitize(message));
    }
  }

  // Beacon specific logging
  void beaconDetected(String classId, int rssi, double distance) {
    if (!LogConfig.verbose) return; // treat as debug noise
    info('Beacon: $classId rssi=$rssi dist=${distance.toStringAsFixed(2)}m');
  }

  void attendanceRecorded(String studentId, String classId, bool success) {
    final base = 'Attendance student=$studentId class=$classId';
    if (success) {
      info('$base confirmed');
    } else {
      error('$base failed');
    }
  }

  void backgroundServiceStatus(String status) {
    if (!LogConfig.verbose) return; // reduce chatter
    info('BG: $status');
  }

  void networkStatus(bool isOnline) {
    if (!LogConfig.verbose && isOnline) return; // only log transitions to offline when quiet
    if (isOnline) {
      info('Network ONLINE');
    } else {
      warning('Network OFFLINE');
    }
  }

  void bluetoothStatus(bool isEnabled) {
    if (!LogConfig.verbose && isEnabled) return;
    if (isEnabled) {
      info('Bluetooth ENABLED');
    } else {
      warning('Bluetooth DISABLED');
    }
  }

  /// Remove emojis & trim whitespace when quiet mode active
  String _sanitize(String message) {
    if (!LogConfig.quiet) return message;
    // Basic emoji removal regex (covers common unicode ranges)
    final emojiRegex = RegExp(r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}]',
        unicode: true);
    return message.replaceAll(emojiRegex, '').trim();
  }
}
