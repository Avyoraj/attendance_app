import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Simplified notification service - only shows essential notifications
/// Removed: constant RSSI updates, distance tracking spam
/// Kept: foreground service notification (required for background BLE)
class SimpleNotificationService {
  static const String _channelId = 'beacon_service_channel';
  static const String _channelName = 'Attendance Service';

  static FlutterLocalNotificationsPlugin? _notifications;
  static bool _isServiceRunning = false;

  static Future<void> initializeService() async {
    await _initializeNotifications();
  }

  static Future<void> _initializeNotifications() async {
    _notifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications!.initialize(initializationSettings);

    // Create a LOW importance channel - minimal distraction
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Background attendance service',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Start minimal foreground notification (required for background BLE on Android)
  static Future<void> startForegroundNotification() async {
    if (_isServiceRunning) return;
    _isServiceRunning = true;
    await initializeService();
    // Show a simple, non-intrusive notification
    await _showForegroundNotification();
  }

  /// Stop foreground notification
  static Future<void> stopForegroundNotification() async {
    _isServiceRunning = false;
    await _notifications?.cancel(1);
  }

  /// Update notification text - NOW DISABLED to reduce spam
  /// The foreground notification stays static
  static Future<void> updateStatusText(String title, String content) async {
    // DISABLED: No more constant updates
    // The notification stays as "Attendance Active" without RSSI spam
  }

  /// Show the minimal foreground notification
  static Future<void> _showForegroundNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Background attendance service',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications?.show(
      1,
      '📍 Attendance Active',
      'Monitoring classroom beacon',
      details,
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications?.cancelAll();
    _isServiceRunning = false;
  }

  // Legacy methods - kept for compatibility but do nothing
  static Future<void> startBackgroundTracking() async {
    await startForegroundNotification();
  }

  static Future<void> stopBackgroundTracking() async {
    await stopForegroundNotification();
  }
}
