import 'package:logger/logger.dart';

/// ⏱️ Cooldown Manager Module
/// 
/// Handles cooldown tracking to prevent duplicate check-ins.
/// After confirming attendance, user must wait 15 minutes before checking in again.
/// 
/// Features:
/// - Track last check-in time per student/class
/// - Calculate remaining cooldown time
/// - Check if student is in cooldown period
/// - Clear cooldown (for cancelled attendance or manual reset)
class BeaconCooldownManager {
  final _logger = Logger();
  
  // Cooldown tracking variables
  DateTime? _lastCheckInTime;
  String? _lastCheckedStudentId;
  String? _lastCheckedClassId;
  
  /// Check if student is in cooldown period for given class
  /// 
  /// Returns true if:
  /// - Student has checked in before
  /// - Check-in was for the same class
  /// - Less than 15 minutes have passed since last check-in
  bool isInCooldown(String studentId, String classId) {
    // No previous check-in = no cooldown
    if (_lastCheckInTime == null) {
      _logger.d('✅ No cooldown - first check-in');
      return false;
    }
    
    // Different student = no cooldown
    if (_lastCheckedStudentId != studentId) {
      _logger.d('✅ No cooldown - different student');
      return false;
    }
    
    // Different class = no cooldown (can check into multiple classes)
    if (_lastCheckedClassId != classId) {
      _logger.d('✅ No cooldown - different class');
      return false;
    }
    
    // Check time elapsed since last check-in
    final timeSinceLastCheckIn = DateTime.now().difference(_lastCheckInTime!);
    final minutesElapsed = timeSinceLastCheckIn.inMinutes;
    
    // Cooldown is 15 minutes
    if (minutesElapsed < 15) {
      final minutesRemaining = 15 - minutesElapsed;
      _logger.w('⏳ Cooldown active: $minutesRemaining minutes remaining');
      _logger.w('   Last check-in: $_lastCheckInTime');
      return true;
    }
    
    // Cooldown expired
    _logger.i('✅ Cooldown expired (${minutesElapsed} minutes since last check-in)');
    return false;
  }
  
  /// Set cooldown after successful attendance confirmation
  void setCooldown(String studentId, String classId, DateTime checkInTime) {
    _lastCheckInTime = checkInTime;
    _lastCheckedStudentId = studentId;
    _lastCheckedClassId = classId;
    
    _logger.i('⏱️ Cooldown set for student $studentId in class $classId');
    _logger.i('   Check-in time: $checkInTime');
    _logger.i('   Next check-in allowed: ${checkInTime.add(const Duration(minutes: 15))}');
  }
  
  /// Clear cooldown (allows immediate check-in)
  /// 
  /// Used when:
  /// - Attendance is cancelled (student left early)
  /// - Manual reset (testing/debugging)
  /// - Different student logs in
  void clearCooldown() {
    if (_lastCheckInTime != null) {
      _logger.i('🔄 Cooldown cleared');
      _logger.i('   Previous check-in: $_lastCheckInTime (student: $_lastCheckedStudentId, class: $_lastCheckedClassId)');
    }
    
    _lastCheckInTime = null;
    _lastCheckedStudentId = null;
    _lastCheckedClassId = null;
  }
  
  /// Get cooldown information (for UI display)
  /// 
  /// Returns null if no active cooldown.
  /// Otherwise returns map with cooldown details.
  Map<String, dynamic>? getCooldownInfo() {
    if (_lastCheckInTime == null) {
      return null;
    }
    
    final timeSinceLastCheckIn = DateTime.now().difference(_lastCheckInTime!);
    final minutesRemaining = 15 - timeSinceLastCheckIn.inMinutes;
    
    return {
      'lastCheckInTime': _lastCheckInTime!.toIso8601String(),
      'studentId': _lastCheckedStudentId,
      'classId': _lastCheckedClassId,
      'minutesRemaining': minutesRemaining > 0 ? minutesRemaining : 0,
      'isActive': minutesRemaining > 0,
    };
  }
  
  /// Restore cooldown from backend (after app restart)
  void restoreCooldown(String studentId, String classId, DateTime checkInTime) {
    final timeSinceConfirmation = DateTime.now().difference(checkInTime);
    final minutesRemaining = 15 - timeSinceConfirmation.inMinutes;
    
    if (minutesRemaining > 0) {
      _lastCheckInTime = checkInTime;
      _lastCheckedStudentId = studentId;
      _lastCheckedClassId = classId;
      
      _logger.i('✅ Cooldown restored: $minutesRemaining minutes remaining');
      _logger.i('   Check-in time: $checkInTime');
    } else {
      _logger.i('⏰ Cooldown expired (${timeSinceConfirmation.inMinutes} minutes ago)');
    }
  }
  
  /// Check if cooldown is currently active
  bool get isActive => _lastCheckInTime != null;
  
  /// Get last check-in time
  DateTime? get lastCheckInTime => _lastCheckInTime;
  
  /// Get last checked student ID
  String? get lastCheckedStudentId => _lastCheckedStudentId;
  
  /// Get last checked class ID
  String? get lastCheckedClassId => _lastCheckedClassId;
}
