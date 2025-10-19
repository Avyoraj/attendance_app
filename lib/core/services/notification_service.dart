import 'package:flutter/services.dart';
import '../utils/schedule_utils.dart';
import 'logger_service.dart';
import 'dart:async';

/// Enhanced notification service with lock screen support and live cooldown notifications
class NotificationService {
  static const platform = MethodChannel('com.example.attendance_app/beacon_service');
  static final LoggerService _logger = LoggerService();
  
  static Timer? _cooldownNotificationTimer;
  static DateTime? _cooldownEndTime;
  
  /// Show success notification (visible on lock screen)
  static Future<void> showSuccessNotification({
    required String classId,
    required String message,
  }) async {
    try {
      await platform.invokeMethod('showSuccessNotificationEnhanced', {
        'title': '✅ Attendance Confirmed!',
        'message': '🎓 Class $classId\n$message',
        'classId': classId,
      });
      _logger.info('✅ Success notification shown (lock screen enabled)');
    } catch (e) {
      _logger.error('❌ Failed to show success notification', e);
    }
  }
  
  /// Show cooldown notification with live countdown
  static Future<void> showCooldownNotification({
    required String classId,
    required DateTime classStartTime,
  }) async {
    try {
      final now = DateTime.now();
      _cooldownEndTime = ScheduleUtils.getCooldownEndTime(classStartTime);
      final classEndTime = ScheduleUtils.getClassEndTime(classStartTime);
      
      // Show initial notification
      final scheduleInfo = ScheduleUtils.getScheduleAwareCooldownInfo(
        classStartTime: classStartTime,
        now: now,
      );
      
      await _updateCooldownNotification(scheduleInfo, classId, classEndTime);
      
      // Start live updates (every minute)
      _startCooldownNotificationUpdates(classStartTime, classId);
      
      _logger.info('🔔 Cooldown notification started for Class $classId');
    } catch (e) {
      _logger.error('❌ Failed to show cooldown notification', e);
    }
  }
  
  /// Start live cooldown notification updates
  static void _startCooldownNotificationUpdates(DateTime classStartTime, String classId) {
    // Cancel existing timer if any
    _cooldownNotificationTimer?.cancel();
    
    _cooldownNotificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        final now = DateTime.now();
        final classEndTime = ScheduleUtils.getClassEndTime(classStartTime);
        
        // Stop timer if cooldown ended
        if (_cooldownEndTime != null && now.isAfter(_cooldownEndTime!)) {
          _logger.info('⏱️ Cooldown ended, stopping notification updates');
          cancelCooldownNotification();
          return;
        }
        
        // Update notification with current time
        final scheduleInfo = ScheduleUtils.getScheduleAwareCooldownInfo(
          classStartTime: classStartTime,
          now: now,
        );
        
        await _updateCooldownNotification(scheduleInfo, classId, classEndTime);
      } catch (e) {
        _logger.error('❌ Error updating cooldown notification', e);
      }
    });
  }
  
  /// Update cooldown notification with current info
  static Future<void> _updateCooldownNotification(
    Map<String, dynamic> scheduleInfo,
    String classId,
    DateTime classEndTime,
  ) async {
    try {
      final now = DateTime.now();
      final nextClassTime = ScheduleUtils.getNextClassStartTime(classEndTime);
      
      String title;
      String message;
      
      if (scheduleInfo['classEnded'] == false) {
        // Class still ongoing
        title = '🕐 Cooldown Active';
        message = '🎓 Class $classId ends at ${scheduleInfo['classEndTimeFormatted']}\n'
                  '⏰ Next check-in: ${scheduleInfo['remainingTimeFormatted']}';
      } else {
        // Class ended, waiting for next class
        final timeUntilNext = nextClassTime.difference(now);
        final nextClassFormatted = ScheduleUtils.formatTime(nextClassTime);
        final timeUntilNextFormatted = ScheduleUtils.formatTimeRemaining(timeUntilNext);
        
        title = '⏳ Waiting for Next Class';
        message = '🎓 Next class at $nextClassFormatted\n'
                  '⏰ Available $timeUntilNextFormatted';
      }
      
      await platform.invokeMethod('showCooldownNotificationEnhanced', {
        'title': title,
        'message': message,
        'classId': classId,
        'remainingMinutes': scheduleInfo['remainingMinutes'],
      });
    } catch (e) {
      _logger.error('❌ Failed to update cooldown notification', e);
    }
  }
  
  /// Show cancelled notification with next class info
  static Future<void> showCancelledNotification({
    required String classId,
    required DateTime cancelledTime,
  }) async {
    try {
      final now = DateTime.now();
      final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
        cancelledTime: cancelledTime,
        now: now,
      );
      
      String message;
      if (cancelledInfo['classEnded'] == false) {
        message = '❌ Current class ends at ${cancelledInfo['classEndTimeFormatted']}\n'
                  '🎓 Try again in next class at ${cancelledInfo['nextClassTimeFormatted']}\n'
                  '⏰ ${cancelledInfo['timeUntilNextFormatted']}';
      } else {
        message = '🎓 Next class at ${cancelledInfo['nextClassTimeFormatted']}\n'
                  '⏰ ${cancelledInfo['timeUntilNextFormatted']}';
      }
      
      await platform.invokeMethod('showCancelledNotificationEnhanced', {
        'title': '❌ Attendance Cancelled',
        'message': message,
        'classId': classId,
      });
      
      _logger.info('🔔 Cancelled notification shown for Class $classId');
    } catch (e) {
      _logger.error('❌ Failed to show cancelled notification', e);
    }
  }
  
  /// Cancel cooldown notification and stop updates
  static void cancelCooldownNotification() {
    _cooldownNotificationTimer?.cancel();
    _cooldownNotificationTimer = null;
    _cooldownEndTime = null;
    _logger.info('🔕 Cooldown notification cancelled');
  }
  
  /// Check if cooldown notification is active
  static bool isCooldownNotificationActive() {
    return _cooldownNotificationTimer != null && _cooldownNotificationTimer!.isActive;
  }
}
