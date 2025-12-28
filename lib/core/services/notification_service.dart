import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'logger_service.dart';
import 'dart:async';

/// Simplified notification service - only essential notifications
/// Removed: live cooldown updates, constant spam
/// Kept: success, cancelled, error notifications (one-time)
class NotificationService {
  static final LoggerService _logger = LoggerService();
  static FlutterLocalNotificationsPlugin? _notifications;
  static bool _initialized = false;

  /// Initialize the notification plugin
  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    
    _notifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications!.initialize(initSettings);
    
    // Create notification channels
    final androidPlugin = _notifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    // Success channel (high importance for confirmed attendance)
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'attendance_success',
      'Attendance Success',
      description: 'Attendance confirmation notifications',
      importance: Importance.high,
      playSound: true,
    ));
    
    // Info channel (low importance for status updates)
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'attendance_info',
      'Attendance Info',
      description: 'Attendance status notifications',
      importance: Importance.low,
      playSound: false,
    ));
    
    _initialized = true;
  }

  /// Show success notification when attendance is confirmed
  static Future<void> showSuccessNotification({
    required String classId,
    required String message,
  }) async {
    try {
      await _ensureInitialized();
      
      const androidDetails = AndroidNotificationDetails(
        'attendance_success',
        'Attendance Success',
        channelDescription: 'Attendance confirmation notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
      );
      
      await _notifications?.show(
        100, // Fixed ID for success
        '✅ Attendance Confirmed!',
        'Class $classId • $message',
        const NotificationDetails(android: androidDetails),
      );
      
      _logger.info('✅ Success notification shown for $classId');
    } catch (e) {
      _logger.error('❌ Failed to show success notification', e);
    }
  }

  /// Show cooldown notification - SIMPLIFIED: just one notification, no live updates
  static Future<void> showCooldownNotification({
    required String classId,
    required DateTime classStartTime,
  }) async {
    // DISABLED: No more cooldown notification spam
    // The success notification is enough
    _logger.info('ℹ️ Cooldown notification skipped (simplified)');
  }

  /// Show cancelled notification
  static Future<void> showCancelledNotification({
    required String classId,
    required DateTime cancelledTime,
  }) async {
    try {
      await _ensureInitialized();
      
      const androidDetails = AndroidNotificationDetails(
        'attendance_info',
        'Attendance Info',
        channelDescription: 'Attendance status notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
      );
      
      await _notifications?.show(
        101, // Fixed ID for cancelled
        '❌ Attendance Cancelled',
        'Class $classId • Left before confirmation',
        const NotificationDetails(android: androidDetails),
      );
      
      _logger.info('❌ Cancelled notification shown for $classId');
    } catch (e) {
      _logger.error('❌ Failed to show cancelled notification', e);
    }
  }

  /// Show error notification (proxy blocked, device mismatch)
  static Future<void> showErrorNotification({
    required String title,
    required String message,
  }) async {
    try {
      await _ensureInitialized();
      
      const androidDetails = AndroidNotificationDetails(
        'attendance_info',
        'Attendance Info',
        channelDescription: 'Attendance status notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
      );
      
      await _notifications?.show(
        102, // Fixed ID for errors
        title,
        message,
        const NotificationDetails(android: androidDetails),
      );
      
      _logger.info('🚫 Error notification shown: $title');
    } catch (e) {
      _logger.error('❌ Failed to show error notification', e);
    }
  }

  /// Cancel cooldown notification - no-op now
  static void cancelCooldownNotification() {
    // No-op - cooldown notifications disabled
  }

  /// Check if cooldown notification is active - always false now
  static bool isCooldownNotificationActive() {
    return false;
  }
}
