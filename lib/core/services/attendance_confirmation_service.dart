import 'dart:async';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'http_service.dart';

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

    _logger.i('📅 Scheduled confirmation for $studentId in 10 minutes');

    // Set timer for 10 minutes
    _confirmationTimer = Timer(
      AppConstants.secondCheckDelay,
      () => _executeConfirmation(),
    );
  }

  /// Execute the confirmation (called by timer)
  Future<void> _executeConfirmation() async {
    if (_pendingStudentId == null || _pendingClassId == null) {
      _logger.w('⚠️ No pending confirmation to execute');
      return;
    }

    try {
      _logger.i('✅ Executing confirmation for $_pendingStudentId');

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
    _pendingAttendanceId = null;
    _pendingStudentId = null;
    _pendingClassId = null;  // NEW: Clear classId
    _provisionalCheckInTime = null;
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
