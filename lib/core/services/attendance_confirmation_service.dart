import 'dart:async';
import 'dart:math'; // For pow function
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'http_service.dart';
import 'beacon_service.dart'; // For proximity verification

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
  String? _pendingClassId;  // NEW: Store classId for confirmation
  DateTime? _provisionalCheckInTime;
  
  // Callback for confirmation success
  Function(String studentId, String classId)? onConfirmationSuccess;
  // Callback for confirmation failure
  Function(String studentId, String classId)? onConfirmationFailure;

  /// Schedule confirmation for a provisional attendance
  /// Will auto-confirm after 10 minutes if still in beacon range
  void scheduleConfirmation({
    required String attendanceId,
    required String studentId,
    required String classId,  // NEW: Required classId
  }) {
    // Cancel any existing timer
    cancelPendingConfirmation();

    _pendingAttendanceId = attendanceId;
    _pendingStudentId = studentId;
    _pendingClassId = classId;  // NEW: Store classId
    _provisionalCheckInTime = DateTime.now();

    _logger.i('📅 Scheduled confirmation for $studentId in ${AppConstants.secondCheckDelay.inSeconds} seconds');
    _logger.i('⏳ Will verify beacon proximity at END of timer (not continuously checking)');

    // Set timer for confirmation (60 seconds for testing, 10 minutes in production)
    _confirmationTimer = Timer(
      AppConstants.secondCheckDelay,
      () => _executeConfirmation(),
    );
    
    // ❌ REMOVED: Continuous monitoring was too aggressive!
    // Student can move/sit/adjust position without losing attendance
    // We only check proximity at t=0 (check-in) and t=60 (confirmation)
  }

  /// Execute the confirmation (called by timer)
  /// ✅ NEW: Validates RSSI before confirming
  Future<void> _executeConfirmation() async {
    if (_pendingStudentId == null || _pendingClassId == null) {
      _logger.w('⚠️ No pending confirmation to execute');
      return;
    }

    try {
      _logger.i('✅ Executing confirmation for $_pendingStudentId');

      // 🔍 CRITICAL: Verify student is STILL in beacon range
      final proximityCheck = await _verifyStudentProximity();
      
      if (!proximityCheck['inRange']) {
        _logger.w('⚠️ Student out of range during confirmation - CANCELLING attendance');
        _logger.w('   Reason: ${proximityCheck['reason']}');
        _logger.w('   RSSI: ${proximityCheck['rssi']} dBm (Required: > -75 dBm)');
        
        // Cancel the provisional attendance (student left early)
        await _cancelProvisionalAttendance();
        
        // Notify failure
        if (onConfirmationFailure != null) {
          onConfirmationFailure!(_pendingStudentId!, _pendingClassId!);
        }
        
        _clearPendingConfirmation();
        return;
      }

      _logger.i('✅ Proximity verified - Student still in range (RSSI: ${proximityCheck['rssi']} dBm)');

      // Call backend to confirm attendance
      final response = await _httpService.confirmAttendance(
        studentId: _pendingStudentId!,
        classId: _pendingClassId!,
      );

      if (response['success'] == true) {
        _logger.i('🎉 Attendance confirmed successfully!');
        
        // Notify via callback
        if (onConfirmationSuccess != null) {
          onConfirmationSuccess!(_pendingStudentId!, _pendingClassId!);
        }
        
        // TODO: Show notification to user
        // await _showConfirmationNotification();
        
        // TODO: Update local database status
        // await _updateLocalAttendanceStatus();
      } else {
        _logger.e('❌ Confirmation failed: ${response['error']}');
        // Notify via callback
        if (onConfirmationFailure != null) {
          onConfirmationFailure!(_pendingStudentId!, _pendingClassId!);
        }
      }
    } catch (e) {
      _logger.e('❌ Error confirming attendance: $e');
      // Notify via callback
      if (onConfirmationFailure != null) {
        onConfirmationFailure!(_pendingStudentId!, _pendingClassId!);
      }
    } finally {
      _clearPendingConfirmation();
    }
  }

  /// Verify student is still in acceptable beacon range
  /// Returns: { inRange: bool, rssi: int, distance: double, reason: string }
  Future<Map<String, dynamic>> _verifyStudentProximity() async {
    try {
      // Get current RSSI from BeaconService (use getter to avoid null)
      final currentRssi = beaconService.getCurrentRssi();
      
      // Check if beacon is detected
      if (currentRssi == null) {
        return {
          'inRange': false,
          'rssi': null,
          'distance': null,
          'reason': 'No beacon detected - student may have left classroom'
        };
      }
      
      // 🎯 ENHANCED: Use lenient threshold for CONFIRMATION (allows movement)
      // Entry requires -75 dBm, but staying only needs -82 dBm
      if (currentRssi < AppConstants.confirmationRssiThreshold) {
        final distance = _calculateDistance(currentRssi);
        return {
          'inRange': false,
          'rssi': currentRssi,
          'distance': distance,
          'reason': 'RSSI too weak ($currentRssi dBm) - student too far from beacon (Required: > ${AppConstants.confirmationRssiThreshold} dBm for confirmation)'
        };
      }
      
      // All checks passed - student is in range
      final distance = _calculateDistance(currentRssi);
      return {
        'inRange': true,
        'rssi': currentRssi,
        'distance': distance,
        'reason': 'Student in acceptable range'
      };
      
    } catch (e) {
      _logger.e('❌ Error verifying proximity: $e');
      return {
        'inRange': false,
        'rssi': null,
        'distance': null,
        'reason': 'Error checking beacon proximity: $e'
      };
    }
  }

  /// Calculate distance from RSSI
  double _calculateDistance(int rssi) {
    const int txPower = -59;
    if (rssi == 0) return -1.0;
    
    final ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return pow(ratio, 10).toDouble();
    } else {
      final distance = (0.89976) * pow(ratio, 7.7095) + 0.111;
      return distance;
    }
  }

  /// Cancel provisional attendance (student left before confirmation)
  Future<void> _cancelProvisionalAttendance() async {
    if (_pendingStudentId == null || _pendingClassId == null) {
      return;
    }

    try {
      _logger.w('🚫 Cancelling provisional attendance for $_pendingStudentId');
      
      // Call backend to delete provisional attendance
      await _httpService.cancelProvisionalAttendance(
        studentId: _pendingStudentId!,
        classId: _pendingClassId!,
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
      
      final response = await _httpService.confirmAttendance(
        studentId: studentId,
        classId: classId,
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
    _pendingClassId = null;  // NEW: Clear classId
    _provisionalCheckInTime = null;
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
      'classId': _pendingClassId,  // NEW: Include classId
      'checkInTime': _provisionalCheckInTime?.toIso8601String(),
      'timeUntilConfirmation': AppConstants.secondCheckDelay.inMinutes,
    };
  }

  /// Cleanup resources
  void dispose() {
    cancelPendingConfirmation();
  }
}
