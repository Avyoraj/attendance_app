import 'package:logger/logger.dart';
import 'http_service.dart';

/// SessionService - Handles session-related operations
/// 
/// This service queries the backend to check if there's an active
/// class session for a detected beacon. This is part of the
/// "Session Activator" flow where teachers must start a session
/// before students can check in.
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final _logger = Logger();
  final _httpService = HttpService();

  // Cache for active session to reduce API calls
  Map<String, dynamic>? _cachedSession;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(seconds: 30);

  /// Check if there's an active session for the detected beacon
  /// Returns session info if active, null otherwise
  Future<Map<String, dynamic>?> getActiveSession({
    required int beaconMajor,
    required int beaconMinor,
  }) async {
    // Check cache first
    if (_cachedSession != null && _cacheTime != null) {
      final cacheAge = DateTime.now().difference(_cacheTime!);
      if (cacheAge < _cacheDuration) {
        _logger.d('Using cached session data');
        return _cachedSession;
      }
    }

    try {
      final result = await _httpService.getActiveSessionByBeacon(
        major: beaconMajor,
        minor: beaconMinor,
      );

      if (result['success'] == true && result['hasActiveSession'] == true) {
        _cachedSession = result;
        _cacheTime = DateTime.now();
        _logger.i('✅ Active session found: ${result['className']}');
        return result;
      } else {
        _cachedSession = null;
        _cacheTime = null;
        _logger.i('ℹ️ No active session for beacon $beaconMajor:$beaconMinor');
        return null;
      }
    } catch (e) {
      _logger.e('Error checking active session: $e');
      return null;
    }
  }

  /// Get the class ID from an active session
  /// Returns null if no active session
  Future<String?> getActiveClassId({
    required int beaconMajor,
    required int beaconMinor,
  }) async {
    final session = await getActiveSession(
      beaconMajor: beaconMajor,
      beaconMinor: beaconMinor,
    );
    return session?['classId'] as String?;
  }

  /// Check if a session is currently active for the beacon
  Future<bool> hasActiveSession({
    required int beaconMajor,
    required int beaconMinor,
  }) async {
    final session = await getActiveSession(
      beaconMajor: beaconMajor,
      beaconMinor: beaconMinor,
    );
    return session != null;
  }

  /// Clear the session cache (call when beacon is lost)
  void clearCache() {
    _cachedSession = null;
    _cacheTime = null;
  }

  /// Get cached session info without making API call
  Map<String, dynamic>? get cachedSession => _cachedSession;
}
