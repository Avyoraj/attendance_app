import 'dart:async';
// import 'dart:math'; // removed: no longer used
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'http_service.dart';
import 'beacon_service.dart'; // For proximity verification
import 'device_id_service.dart';
import '../config/log_config.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';

/// Service for handling two-step attendance confirmation
/// Step 1: Provisional check-in (immediate)
/// Step 2: Confirmed check-in (after 10 minutes if still in range)
class AttendanceConfirmationService {
  static final AttendanceConfirmationService _instance =
      AttendanceConfirmationService._internal();
  factory AttendanceConfirmationService() => _instance;
  AttendanceConfirmationService._internal();

  final _logger = Logger();
  final _httpService = HttpService();

  // Lazy-initialized to avoid circular dependency with BeaconService
  BeaconService? _beaconService;
  BeaconService get beaconService {
    _beaconService ??= BeaconService();
    return _beaconService!;
  }

  Timer? _confirmationTimer;
  String? _pendingAttendanceId;
  String? _pendingStudentId;
  String? _pendingClassId; // NEW: Store classId for confirmation
  DateTime? _provisionalCheckInTime;
  // Track scheduling metadata to avoid accidental timer resets
  DateTime? _scheduledAt;
  Duration? _scheduledDelay;

  // Callback for confirmation success
  Function(String studentId, String classId)? onConfirmationSuccess;
  // Callback for confirmation failure
  Function(String studentId, String classId)? onConfirmationFailure;
  // Callback for confirmation queued (offline retry)
  Function(String studentId, String classId)? onConfirmationQueued;

  /// Schedule confirmation for a provisional attendance
  /// Will auto-confirm after 10 minutes if still in beacon range
  void scheduleConfirmation({
    required String attendanceId,
    required String studentId,
    required String classId, // NEW: Required classId
    Duration? delayOverride, // NEW: Optional remaining time when resuming
  }) {
    // If a confirmation is already pending, decide whether to keep or override
    if (_confirmationTimer != null) {
      final existingRemaining = _computeRemaining();

      // If this call is a fresh scheduling (no override provided) and we already
      // have a pending confirmation (likely resumed from sync), DO NOT reset
      // the timer back to full duration.
      if (delayOverride == null) {
        _logger.i(
            '⏸️ Existing pending confirmation detected; ignoring re-schedule without override (remaining: ${existingRemaining?.inSeconds ?? 'unknown'}s)');
        return;
      }

      // If an override is provided (resume path), only override when the new
      // remaining time is LESS than the existing remaining (i.e., tighter deadline).
      if (existingRemaining != null && delayOverride >= existingRemaining) {
        _logger.i(
            '⏸️ Keeping existing confirmation timer (${existingRemaining.inSeconds}s) — override (${delayOverride.inSeconds}s) is not tighter');
        return;
      }

      // Otherwise, cancel and re-schedule with the tighter override
      cancelPendingConfirmation();
    }

    _pendingAttendanceId = attendanceId;
    _pendingStudentId = studentId;
    _pendingClassId = classId; // NEW: Store classId
    _provisionalCheckInTime = DateTime.now();

    // Decide actual delay (override for resume path)
    Duration delay = AppConstants.secondCheckDelay;
    if (delayOverride != null) {
      // Sanitize override: clamp between 1s and configured delay
      if (delayOverride <= Duration.zero) {
        _logger.w(
            '⚠️ delayOverride <= 0 supplied. Skipping scheduling & executing immediately.');
        // Execute immediately (edge case: app resumed with almost no time left)
        _executeConfirmation();
        return;
      }
      if (delayOverride < delay) {
        delay = delayOverride;
      }
    }

    _logger.i(
        '📅 Scheduled confirmation for $studentId in ${delay.inSeconds} seconds${delayOverride != null ? ' (resume override)' : ''}');
    _logger.i(
        '⏳ Will verify beacon proximity at END of timer (not continuously checking)');

    _confirmationTimer = Timer(
      delay,
      () => _executeConfirmation(),
    );

  // Save scheduling metadata
  _scheduledAt = DateTime.now();
  _scheduledDelay = delay;

    // ❌ REMOVED: Continuous monitoring was too aggressive!
    // Student can move/sit/adjust position without losing attendance
    // We only check proximity at t=0 (check-in) and t=60 (confirmation)
  }

  /// Execute the confirmation (called by timer)
  /// ✅ NEW: Validates RSSI before confirming
  /// ✅ ROBUST: Queues failed network requests for retry when connectivity returns
  Future<void> _executeConfirmation() async {
    if (_pendingStudentId == null || _pendingClassId == null) {
      _logger.w('⚠️ No pending confirmation to execute');
      return;
    }

    // Capture values before any async operation clears them
    final studentId = _pendingStudentId!;
    final classId = _pendingClassId!;
    final attendanceId = _pendingAttendanceId;

    try {
      _logger.i('✅ Executing confirmation for $studentId');

      // 🔒 Hard gate: require that a REAL beacon packet was seen very recently
      // This prevents confirmations when the beacon is turned off or Bluetooth is disabled
      final recentlyVisible = beaconService.wasBeaconSeenRecently(
        maxAge: AppConstants.confirmationBeaconVisibilityMaxAge,
      );
      if (!recentlyVisible) {
        _logger.w(
            '⚠️ Beacon not recently visible (>${AppConstants.confirmationBeaconVisibilityMaxAge.inSeconds}s) — cancelling provisional');
        await _cancelProvisionalAttendance();
        if (onConfirmationFailure != null) {
          onConfirmationFailure!(studentId, classId);
        }
        _clearPendingConfirmation();
        return;
      }

      // 🔍 CRITICAL: Run a short final proximity gate to avoid last-moment false positives
      // We sample RAW RSSI for ~2 seconds and require at least two consecutive valid samples.
      final gateOk = await _finalProximityGate(
        windowSeconds: 2,
        intervalMs: 300,
      );
      if (!gateOk) {
        _logger.w('⚠️ Final proximity gate FAILED — cancelling provisional');
        await _cancelProvisionalAttendance();
        if (onConfirmationFailure != null) {
          onConfirmationFailure!(studentId, classId);
        }
        _clearPendingConfirmation();
        return;
      }
      _logger.i('✅ Final proximity gate PASSED');

      // 🌐 NETWORK RESILIENCE: Check connectivity before attempting HTTP call
      final isOnline = ConnectivityService().isOnline;
      if (!isOnline) {
        _logger.w('⚠️ No network connectivity — queueing confirmation for retry');
        await _queueConfirmationForRetry(studentId: studentId, classId: classId, attendanceId: attendanceId);
        _clearPendingConfirmation();
        return;
      }

      // Retrieve deviceId for confirmation integrity
      final deviceId = await DeviceIdService().getDeviceId();

      final response = await _httpService.confirmAttendance(
        studentId: studentId,
        classId: classId,
        deviceId: deviceId,
        attendanceId: attendanceId,
      );

      if (response['success'] == true) {
        _logger.i('🎉 Attendance confirmed successfully!');

        // Notify via callback
        if (onConfirmationSuccess != null) {
          onConfirmationSuccess!(studentId, classId);
        }

        // TODO: Show notification to user
        // await _showConfirmationNotification();

        // TODO: Update local database status
        // await _updateLocalAttendanceStatus();
      } else {
        // Backend rejected the confirmation
        final errorCode = response['error'] as String?;
        
        if (errorCode == 'PROXY_DETECTED') {
          // 🚨 PROXY DETECTED - Student flagged for suspicious pattern
          final otherStudent = response['otherStudent'] ?? 'another student';
          final correlationScore = response['correlationScore'];
          _logger.e('🚫 PROXY DETECTED: $studentId flagged with $otherStudent (ρ=$correlationScore)');
          _logger.e('📛 Attendance BLOCKED - student must see teacher');
          
          // Notify failure with special proxy flag
          if (onConfirmationFailure != null) {
            onConfirmationFailure!(studentId, classId);
          }
          
          // The UI should show a special message for proxy detection
          // This is handled by the callback in home_screen_sync.dart
        } else if (errorCode == 'DEVICE_MISMATCH') {
          // Device binding violation
          _logger.e('🔒 DEVICE MISMATCH: $studentId tried from wrong device');
          if (onConfirmationFailure != null) {
            onConfirmationFailure!(studentId, classId);
          }
        } else {
          // Other backend rejection (e.g., already confirmed, invalid state)
          // This is NOT a network issue — don't retry
          _logger.e('❌ Confirmation rejected by backend: $errorCode');
          if (onConfirmationFailure != null) {
            onConfirmationFailure!(studentId, classId);
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error confirming attendance: $e');
      
      // 🌐 NETWORK RESILIENCE: Queue for retry if this looks like a network error
      // (Network errors: SocketException, TimeoutException, etc.)
      if (_isNetworkError(e)) {
        _logger.w('🔄 Network error detected — queueing confirmation for retry when online');
        await _queueConfirmationForRetry(studentId: studentId, classId: classId, attendanceId: attendanceId);
      } else {
        // Non-network error (parsing, unexpected response, etc.) — notify failure
        if (onConfirmationFailure != null) {
          onConfirmationFailure!(studentId, classId);
        }
      }
    } finally {
      _clearPendingConfirmation();
    }
  }

  /// Queue a failed confirmation to be retried when network is available
  /// Uses the existing LocalDatabaseService pending_actions infrastructure
  Future<void> _queueConfirmationForRetry({
    required String studentId,
    required String classId,
    String? attendanceId,
  }) async {
    try {
      await LocalDatabaseService().savePendingAction(
        actionType: 'confirm',
        studentId: studentId,
        classId: classId,
        payload: attendanceId != null ? {'attendanceId': attendanceId} : null,
      );
      _logger.i('📥 Confirmation queued for retry: $studentId / $classId');
      
      // Notify UI that confirmation was queued (not failed!)
      if (onConfirmationQueued != null) {
        onConfirmationQueued!(studentId, classId);
      }
      
      // Register a one-time listener to trigger sync when connectivity returns
      ConnectivityService().onNextReconnect(() async {
        _logger.i('🌐 Connectivity restored — SyncService will process queued confirmations');
        // SyncService already listens for connectivity changes and will auto-sync
        // No additional action needed here
      });
    } catch (e) {
      _logger.e('❌ Failed to queue confirmation for retry: $e');
      // Even if queueing fails, don't block — student can retry manually
    }
  }

  /// Determine if an exception is likely a network-related error
  bool _isNetworkError(dynamic e) {
    final errorString = e.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('unreachable') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('errno');
  }

  /// Verify student is still in acceptable beacon range
  /// Returns: { inRange: bool, rssi: int, distance: double, reason: string }
  /// 📱 Updated to be more lenient for locked screen scenarios
  Future<Map<String, dynamic>> _verifyStudentProximity() async {
    try {
      // Use RAW RSSI (no grace-period fallback) for strict end-of-window validation
      final raw = beaconService.getRawRssiData();
      final rssi = raw['rssi'] as int?; // may be null
      final ageSeconds = raw['ageSeconds'] as int?; // may be null
      final inGrace = raw['isInGracePeriod'] as bool? ?? false;

      // Failure: no beacon currently detected
      if (rssi == null) {
        return {
          'inRange': false,
          'rssi': null,
          'ageSeconds': ageSeconds,
          'inGrace': inGrace,
          'reason': 'No beacon detected (rssi=null)'
        };
      }

      // Failure: stale reading - 📱 Increased from 3s to 10s for locked screen
      if (ageSeconds != null && ageSeconds > 10) {
        return {
          'inRange': false,
          'rssi': rssi,
          'ageSeconds': ageSeconds,
          'inGrace': inGrace,
          'reason': 'RSSI stale (age ${ageSeconds}s > 10s)'
        };
      }

      // Failure: still in exit grace period (using cached good value)
      if (inGrace) {
        return {
          'inRange': false,
          'rssi': rssi,
          'ageSeconds': ageSeconds,
          'inGrace': inGrace,
          'reason': 'In grace period fallback; treat as out-of-range'
        };
      }

      // Failure: below confirmation threshold
      if (rssi < AppConstants.confirmationRssiThreshold) {
        return {
          'inRange': false,
          'rssi': rssi,
          'ageSeconds': ageSeconds,
          'inGrace': inGrace,
          'reason': 'RSSI too weak ($rssi < ${AppConstants.confirmationRssiThreshold})'
        };
      }

      // Pass
      return {
        'inRange': true,
        'rssi': rssi,
        'ageSeconds': ageSeconds,
        'inGrace': inGrace,
        'reason': 'OK'
      };
    } catch (e) {
      _logger.e('❌ Error verifying proximity: $e');
      return {
        'inRange': false,
        'rssi': null,
        'ageSeconds': null,
        'inGrace': false,
        'reason': 'Exception: $e'
      };
    }
  }

  /// Short gating window right at confirmation time.
  /// Samples RAW RSSI repeatedly for [windowSeconds] at [intervalMs] and
  /// requires either two consecutive valid samples or >=3 total passes.
  /// 📱 Updated to be more lenient for locked screen scenarios
  Future<bool> _finalProximityGate({int windowSeconds = 3, int intervalMs = 500}) async {
    _logger.i('🛂 Starting final proximity gate: ${windowSeconds}s');
    final int ticks = (windowSeconds * 1000 ~/ intervalMs).clamp(1, 50);
    int consecutivePass = 0;
    int totalPass = 0;

    for (int i = 0; i < ticks; i++) {
      // Require that a REAL ranging packet was seen within the visibility window
      final visible = beaconService.wasBeaconSeenRecently(
        maxAge: AppConstants.confirmationBeaconVisibilityMaxAge,
      );
      if (!visible) {
        consecutivePass = 0;
        _logger.d('🛂 Gate miss ${i + 1}/$ticks (reason=Beacon not recently visible)');
        await Future.delayed(Duration(milliseconds: intervalMs));
        continue;
      }

      final check = await _verifyStudentProximity();
      final inRange = (check['inRange'] as bool?) ?? false;
      final age = check['ageSeconds'] as int?;
      // 📱 Relaxed freshness: allow up to 5 seconds (was 1s) for locked screen scenarios
      final fresh = age != null ? age <= 5 : false;

      final pass = inRange && fresh && visible;
      if (pass) {
        consecutivePass += 1;
        totalPass += 1;
        if (LogConfig.verbose) {
          _logger.d('🛂 Gate pass ${i + 1}/$ticks (rssi=${check['rssi']} age=${age}s, consec=$consecutivePass, total=$totalPass)');
        }
      } else {
        consecutivePass = 0;
        _logger.d('🛂 Gate miss ${i + 1}/$ticks (reason=${check['reason']}, age=$age)');
      }

      if (consecutivePass >= 2) {
        _logger.i('🛂 Gate early PASS (2 consecutive)');
        return true;
      }
      await Future.delayed(Duration(milliseconds: intervalMs));
    }

    final ok = totalPass >= 2; // 📱 Reduced from 3 to 2 for locked screen
    _logger.i('🛂 Gate ${ok ? 'PASS' : 'FAIL'} (totalPass=$totalPass/$ticks)');
    return ok;
  }

  // Note: distance calc removed (unused) to keep the service lean

  /// Cancel provisional attendance (student left before confirmation)
  Future<void> _cancelProvisionalAttendance() async {
    if (_pendingStudentId == null || _pendingClassId == null) {
      return;
    }

    try {
      _logger.w('🚫 Cancelling provisional attendance for $_pendingStudentId');

      // Call backend to delete provisional attendance (include deviceId for integrity)
      final deviceId = await DeviceIdService().getDeviceId();
      await _httpService.cancelProvisionalAttendance(
        studentId: _pendingStudentId!,
        classId: _pendingClassId!,
        deviceId: deviceId,
      );

      _logger.i('✅ Provisional attendance cancelled successfully');
    } catch (e) {
      _logger.e('❌ Error cancelling provisional attendance: $e');
    }
  }

  /// Manually confirm attendance (if user leaves and re-enters)
  Future<Map<String, dynamic>> manualConfirm({
    required String studentId,
    required String classId,
  }) async {
    try {
      _logger.i('👆 Manual confirmation triggered');
      final deviceId = await DeviceIdService().getDeviceId();
      final response = await _httpService.confirmAttendance(
        studentId: studentId,
        classId: classId,
        deviceId: deviceId,
        attendanceId: _pendingAttendanceId,
      );

      if (response['success'] == true) {
        // Cancel scheduled confirmation if manual confirm succeeds
        cancelPendingConfirmation();
      }

      return response;
    } catch (e) {
      _logger.e('❌ Manual confirmation error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel pending confirmation (if student leaves early)
  void cancelPendingConfirmation() {
    if (_confirmationTimer != null) {
      _logger.i('🚫 Cancelling pending confirmation');
      _confirmationTimer!.cancel();
      _confirmationTimer = null;
    }
    _clearPendingConfirmation();
  }

  /// Clear pending confirmation data
  void _clearPendingConfirmation() {
    _confirmationTimer?.cancel();
    _pendingAttendanceId = null;
    _pendingStudentId = null;
    _pendingClassId = null; // NEW: Clear classId
    _provisionalCheckInTime = null;
    _scheduledAt = null;
    _scheduledDelay = null;
    _logger.i('🧹 Cleared pending confirmation state');
  }

  /// Check if there's a pending confirmation
  bool hasPendingConfirmation() {
    return _pendingAttendanceId != null;
  }

  /// Get pending confirmation info
  Map<String, dynamic>? getPendingInfo() {
    if (!hasPendingConfirmation()) return null;

    return {
      'attendanceId': _pendingAttendanceId,
      'studentId': _pendingStudentId,
      'classId': _pendingClassId, // NEW: Include classId
      'checkInTime': _provisionalCheckInTime?.toIso8601String(),
      'timeUntilConfirmation': AppConstants.secondCheckDelay.inMinutes,
    };
  }

  /// Cleanup resources
  void dispose() {
    cancelPendingConfirmation();
  }

  /// Compute remaining time for the current scheduled confirmation
  Duration? _computeRemaining() {
    if (_confirmationTimer == null || _scheduledAt == null || _scheduledDelay == null) {
      return null;
    }
    final elapsed = DateTime.now().difference(_scheduledAt!);
    final remaining = _scheduledDelay! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
