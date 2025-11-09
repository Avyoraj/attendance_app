import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

/// 🧠 ConfirmationTimerService
///
/// Persists the provisional attendance confirmation countdown across
/// widget rebuilds, hot restarts, and app relaunches using SharedPreferences.
///
/// Keys stored:
/// - confirmation_start_epoch_ms (epoch millis when countdown began)
/// - confirmation_duration_secs (total countdown duration seconds)
///
/// The service is intentionally lightweight: no streams, callers poll
/// remaining time once per tick (UI layer already owns a periodic timer).
class ConfirmationTimerService {
  static final ConfirmationTimerService _instance =
      ConfirmationTimerService._internal();
  factory ConfirmationTimerService() => _instance;
  ConfirmationTimerService._internal();

  static const _startKey = 'confirmation_start_epoch_ms';
  static const _durationKey = 'confirmation_duration_secs';

  SharedPreferences? _prefs;
  final Logger _logger = Logger();

  Future<void> _ensurePrefs() async {
    // Ensure Flutter binding (safe & idempotent)
    WidgetsFlutterBinding.ensureInitialized();
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Start (or restart) the persistent timer with a given [duration].
  /// If a timer is already active it will be overwritten.
  Future<void> start(Duration duration) async {
    await _ensurePrefs();
    final start = DateTime.now().millisecondsSinceEpoch;
    await _prefs!.setInt(_startKey, start);
    await _prefs!.setInt(_durationKey, duration.inSeconds);
    _logger.i(
        '⏱️ Persistent confirmation timer started for ${duration.inSeconds}s');
  }

  /// Returns true if a timer is currently active and has remaining time.
  bool hasActiveTimer() {
    // Ensure prefs are loaded before checking
    // Note: this method can be called from UI tick without await; if prefs
    // are not yet loaded, treat as no active timer, but prefer to eagerly
    // initialize when possible via start()/clear().
    if (_prefs == null) {
      // Best-effort lazy init (non-blocking); actual state will be picked on next tick
      // ignore: unawaited_futures
      _ensurePrefs();
      return false;
    }
    if (!_prefs!.containsKey(_startKey) || !_prefs!.containsKey(_durationKey)) {
      return false;
    }
    return getRemainingSeconds() > 0;
  }

  /// Compute remaining seconds based on stored start time and duration.
  int getRemainingSeconds() {
    if (_prefs == null) {
      // Best-effort lazy init; return 0 for this call
      // ignore: unawaited_futures
      _ensurePrefs();
      return 0;
    }
    final start = _prefs!.getInt(_startKey);
    final durationSecs = _prefs!.getInt(_durationKey);
    if (start == null || durationSecs == null) {
      return 0;
    }
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - start;
    final elapsedSecs = (elapsedMs / 1000).floor();
    final remaining = durationSecs - elapsedSecs;
    return remaining > 0 ? remaining : 0;
  }

  /// Clear the stored timer state.
  Future<void> clear() async {
    await _ensurePrefs();
    await _prefs!.remove(_startKey);
    await _prefs!.remove(_durationKey);
    _logger.i('🧹 Persistent confirmation timer cleared');
  }
}
