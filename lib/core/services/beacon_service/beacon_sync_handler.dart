import 'package:logger/logger.dart';
import '../http_service.dart';
import '../attendance_confirmation_service.dart';
import '../rssi_stream_service.dart';
import 'beacon_cooldown_manager.dart';
import 'beacon_state_manager.dart';

/// 🔄 Sync Handler Module
/// 
/// Handles synchronization with backend server:
/// - Restore attendance state on app startup
/// - Resume provisional countdown
/// - Restore cooldown periods
/// - Handle cancelled attendance
/// 
/// This prevents "already checked in" confusion after app restart.
class BeaconSyncHandler {
  final _logger = Logger();
  final HttpService _httpService = HttpService();
  final AttendanceConfirmationService _confirmationService = AttendanceConfirmationService();
  final RSSIStreamService _rssiStreamService = RSSIStreamService();
  
  // Required dependencies
  late BeaconCooldownManager _cooldownManager;
  late BeaconStateManager _stateManager;
  
  /// Initialize with dependencies
  void init(BeaconCooldownManager cooldownManager, BeaconStateManager stateManager) {
    _cooldownManager = cooldownManager;
    _stateManager = stateManager;
  }
  
  /// Sync attendance state from backend (called on app startup)
  /// 
  /// Fetches today's attendance and restores:
  /// - Confirmed attendance → Set cooldown
  /// - Provisional attendance → Resume countdown
  /// - Cancelled attendance → Clear cooldown
  Future<Map<String, dynamic>> syncStateFromBackend(String studentId) async {
    try {
      _logger.i('🔄 Syncing attendance state from backend for student: $studentId');
      
      // Fetch today's attendance from backend
      final result = await _httpService.getTodayAttendance(studentId: studentId);
      
      if (result['success'] != true) {
        _logger.e('❌ Failed to sync state: ${result['error']}');
        return {
          'success': false,
          'error': result['error'],
          'synced': 0,
        };
      }
      
      final attendance = result['attendance'] as List;
      _logger.i('📥 Received ${attendance.length} attendance records from backend');
      
      int syncedCount = 0;
      
      for (var record in attendance) {
        final classId = record['classId'] as String;
        final status = record['status'] as String;
        
        _logger.i('   Class $classId: $status');
        
        if (status == 'confirmed') {
          // Process confirmed attendance
          syncedCount += _processConfirmedRecord(studentId, classId, record) ? 1 : 0;
        } else if (status == 'provisional') {
          // Process provisional attendance
          syncedCount += _processProvisionalRecord(studentId, classId, record) ? 1 : 0;
        } else if (status == 'cancelled') {
          // Process cancelled attendance
          syncedCount += _processCancelledRecord(studentId, classId, record) ? 1 : 0;
        }
      }
      
      _logger.i('✅ State sync complete: $syncedCount records synced');
      
      return {
        'success': true,
        'synced': syncedCount,
        'total': attendance.length,
        'attendance': attendance,
      };
    } catch (e) {
      _logger.e('❌ State sync error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'synced': 0,
      };
    }
  }
  
  /// Process confirmed attendance record
  bool _processConfirmedRecord(String studentId, String classId, Map<String, dynamic> record) {
    final confirmedAt = record['confirmedAt'] != null 
        ? DateTime.parse(record['confirmedAt'] as String)
        : null;
    
    if (confirmedAt == null) {
      _logger.w('   ⚠️ No confirmedAt timestamp - skipping');
      return false;
    }
    
    // Restore cooldown for confirmed attendance
    _cooldownManager.restoreCooldown(studentId, classId, confirmedAt);
    
    final cooldownInfo = _cooldownManager.getCooldownInfo();
    if (cooldownInfo != null && cooldownInfo['isActive'] == true) {
      _logger.i('   ✅ Restored cooldown: ${cooldownInfo['minutesRemaining']} minutes remaining');
      return true;
    } else {
      _logger.i('   ⏰ Cooldown expired');
      return false;
    }
  }
  
  /// Process provisional attendance record
  bool _processProvisionalRecord(String studentId, String classId, Map<String, dynamic> record) {
    final remainingSeconds = record['remainingSeconds'] as int? ?? 0;
    final attendanceId = record['attendanceId'] as String?;
    
    if (remainingSeconds <= 0) {
      _logger.w('   ⚠️ Provisional time expired');
      return false;
    }
    
    if (attendanceId == null) {
      _logger.w('   ⚠️ No attendanceId - skipping');
      return false;
    }
    
    _logger.i('   ⏱️ Resuming provisional countdown: ${remainingSeconds}s remaining');
    
    // Set state to provisional
    _stateManager.setState('provisional', studentId: studentId, classId: classId);
    
    // Schedule confirmation with remaining time
    _confirmationService.scheduleConfirmation(
      attendanceId: attendanceId,
      studentId: studentId,
      classId: classId,
    );
    
    // Restart RSSI streaming for co-location detection
    _rssiStreamService.startStreaming(
      studentId: studentId,
      classId: classId,
      sessionDate: DateTime.now(),
    );
    
    _logger.i('   📡 RSSI streaming restarted for provisional attendance');
    
    // Notify UI about provisional state
    _stateManager.notifyStateChange('provisional', studentId, classId);
    
    return true;
  }
  
  /// Process cancelled attendance record
  bool _processCancelledRecord(String studentId, String classId, Map<String, dynamic> record) {
    // Clear cooldown for cancelled attendance
    // Cancelled attendance should NOT trigger cooldown - user can try again!
    _logger.i('   ❌ Found cancelled attendance - clearing cooldown');
    
    // Clear cooldown tracking so user can check in again
    _cooldownManager.clearCooldown();
    
    return true;
  }
}
