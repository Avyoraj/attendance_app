import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Global logging configuration
/// - verbose: when false, suppresses debug-level noise
/// - defaultLevel: overall logger level for the app (auto uses info in release)
/// - timerTickThrottleSeconds: how often to log timer ticks
/// - rssiThrottleMillis: how often to log high-frequency RSSI details
class LogConfig {
  /// Toggle verbose debug logs (timer ticks, RSSI smoothing details, etc.)
  static bool verbose = !kReleaseMode; // default: verbose in debug, quiet in release

  /// Quiet mode collapses output into single-line logs (no emojis, no stack/method lines)
  /// Can be enabled via --dart-define=LOG_QUIET=true
  static bool quiet = const String.fromEnvironment('LOG_QUIET', defaultValue: '')
      .toLowerCase() ==
    'true';

  /// Whether to print emojis in logs. Disabled automatically when quiet=true.
  /// Can be overridden via --dart-define=LOG_EMOJI=false
  static bool useEmojis = const String.fromEnvironment('LOG_EMOJI', defaultValue: '')
        .toLowerCase() !=
      'false';

  /// Optional explicit log level from env: trace|debug|info|warning|error|wtf|nothing
  /// Example: --dart-define=LOG_LEVEL=warning
  static final String _envLogLevel =
    const String.fromEnvironment('LOG_LEVEL', defaultValue: '').toLowerCase();

  /// Default/effective logger level used by LoggerService.initialize
  static Level get defaultLevel => verbose ? Level.debug : Level.info;

  /// If an env LOG_LEVEL is set, use it, otherwise fall back to defaultLevel
  static Level get effectiveLevel => _parseLevel(_envLogLevel) ?? defaultLevel;

  /// Throttle intervals for high-frequency logs
  static int timerTickThrottleSeconds = 5; // log timer every 5s
  static int rssiThrottleMillis = 3000; // log RSSI smoothing every 3s

  static Duration get defaultThrottleInterval => const Duration(seconds: 2);

  /// Helper to convert seconds to duration
  static Duration timerInterval() =>
      Duration(seconds: timerTickThrottleSeconds);
  static Duration rssiInterval() => Duration(milliseconds: rssiThrottleMillis);

  /// Map string to Level
  static Level? _parseLevel(String value) {
    switch (value) {
      case 'trace':
        return Level.trace;
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warning':
        return Level.warning;
      case 'error':
        return Level.error;
      case 'wtf':
      case 'fatal':
        return Level.fatal;
      case 'nothing':
      case 'off':
        return Level.off;
      default:
        return null;
    }
  }
}
