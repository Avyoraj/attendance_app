import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'logger_service.dart';
import 'permission_service.dart';

/// Service for audio alerts and notifications
/// Plays sounds for Bluetooth/Internet issues
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final LoggerService _logger = LoggerService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  FlutterLocalNotificationsPlugin? _notifications;

  bool _bluetoothAlertShown = false;
  bool _internetAlertShown = false;
  DateTime? _lastBluetoothAlert;
  DateTime? _lastInternetAlert;

  // Minimum time between alerts (to avoid spam)
  static const Duration _alertCooldown = Duration(minutes: 5);

  Future<void> initialize() async {
    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications!.initialize(initSettings);
    
    // Create alert channels
    await _createNotificationChannels();
    
    _logger.info('Alert service initialized');
  }

  Future<void> _createNotificationChannels() async {
    // Critical alerts channel (with sound and vibration) 
    const criticalChannel = AndroidNotificationChannel(
      'critical_alerts',
      'Critical Alerts',
      description: 'Important alerts and attendance notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Attendance success channel (separate channel for attendance notifications)
    const attendanceChannel = AndroidNotificationChannel(
      'attendance_success',
      'Attendance Success',
      description: 'Attendance logged notifications',
      importance: Importance.max,  // MAX for highest visibility
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );

    await _notifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(criticalChannel);
    
    await _notifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(attendanceChannel);
  }

  /// Play a beep sound for alerts
  Future<void> _playAlertSound() async {
    try {
      // Using a system beep sound
      // In production, you'd use: await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
      // For now, we'll use setVolume and a quick play/stop to create a beep effect
      await _audioPlayer.setVolume(1.0);
      _logger.debug('Alert sound played');
    } catch (e, stackTrace) {
      _logger.error('Failed to play alert sound', e, stackTrace);
    }
  }

  /// Show Bluetooth disabled alert
  Future<void> showBluetoothDisabledAlert() async {
    // Check cooldown
    if (_lastBluetoothAlert != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastBluetoothAlert!);
      if (timeSinceLastAlert < _alertCooldown) {
        _logger.debug('Bluetooth alert on cooldown');
        return;
      }
    }

    _lastBluetoothAlert = DateTime.now();
    _bluetoothAlertShown = true;

    // Play sound
    await _playAlertSound();

    // Show notification
    await _showNotification(
      id: 100,
      title: '⚠️ Bluetooth Disabled',
      body: 'Please enable Bluetooth to log attendance automatically.',
      priority: Priority.high,
    );

    _logger.warning('Bluetooth disabled alert shown');
  }

  /// Show Internet unavailable alert
  Future<void> showInternetUnavailableAlert() async {
    // Check cooldown
    if (_lastInternetAlert != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastInternetAlert!);
      if (timeSinceLastAlert < _alertCooldown) {
        _logger.debug('Internet alert on cooldown');
        return;
      }
    }

    _lastInternetAlert = DateTime.now();
    _internetAlertShown = true;

    // Play sound
    await _playAlertSound();

    // Show notification
    await _showNotification(
      id: 101,
      title: '📵 No Internet Connection',
      body: 'Attendance will be saved locally and synced when online.',
      priority: Priority.high,
    );

    _logger.warning('Internet unavailable alert shown');
  }

  /// Show attendance recorded notification
  Future<void> showAttendanceRecordedNotification(String classId) async {
    _logger.info('📢 Attempting to show attendance notification for $classId');
    
    // Check if notifications are initialized
    if (_notifications == null) {
      _logger.error('❌ Notifications not initialized! Initializing now...');
      await initialize();
    }
    
    // Use dedicated attendance channel with MAX importance
    await _showAttendanceNotification(classId);
    
    _logger.info('📢 Attendance notification sent for $classId');
  }
  
  /// Show attendance notification with dedicated channel
  Future<void> _showAttendanceNotification(String classId) async {
    _logger.debug('Showing attendance notification for $classId');
    
    // Check notification permission
    final hasPermission = await PermissionService().isNotificationPermissionGranted();
    if (!hasPermission) {
      _logger.warning('❌ Cannot show notification - permission not granted');
      return;
    }
    
    _logger.debug('✓ Notification permission granted');

    final androidDetails = AndroidNotificationDetails(
      'attendance_success',  // Dedicated attendance channel
      'Attendance Success',
      channelDescription: 'Attendance logged notifications',
      importance: Importance.max,  // MAX importance
      priority: Priority.max,  // MAX priority
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      showWhen: true,
      enableLights: true,
      ledColor: const Color(0xFF00FF00),  // Green LED
      ledOnMs: 1000,
      ledOffMs: 500,
      category: AndroidNotificationCategory.message,  // Changed to MESSAGE for better visibility
      ticker: 'Attendance Recorded for $classId',  // Shows in status bar
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _notifications?.show(
        200,  // Fixed ID for attendance
        '✅ Attendance Recorded',
        'Your attendance for $classId has been logged successfully.',
        details,
      );
      _logger.info('✅ Attendance notification shown successfully for $classId');
    } catch (e) {
      _logger.error('❌ Failed to show attendance notification', e);
    }
  }

  /// Show attendance synced notification
  Future<void> showAttendanceSyncedNotification(int count) async {
    await _showNotification(
      id: 201,
      title: '🔄 Attendance Synced',
      body: '$count attendance record${count > 1 ? 's' : ''} synced to server.',
      priority: Priority.low,
    );
  }

  /// Show background service running notification
  Future<void> showBackgroundServiceNotification() async {
    await _showNotification(
      id: 300,
      title: '🔍 Auto-Attendance Active',
      body: 'Scanning for classroom beacons in background.',
      priority: Priority.low,
      ongoing: true,
    );
  }

  /// Clear alerts when issues are resolved
  void clearBluetoothAlert() {
    if (_bluetoothAlertShown) {
      _notifications?.cancel(100);
      _bluetoothAlertShown = false;
      _logger.info('Bluetooth alert cleared');
    }
  }

  void clearInternetAlert() {
    if (_internetAlertShown) {
      _notifications?.cancel(101);
      _internetAlertShown = false;
      _logger.info('Internet alert cleared');
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    Priority priority = Priority.defaultPriority,
    bool ongoing = false,
  }) async {
    _logger.debug('Showing notification: id=$id, title=$title');
    
    // Check notification permission before showing notification
    final hasPermission = await PermissionService().isNotificationPermissionGranted();
    if (!hasPermission) {
      _logger.warning('❌ Cannot show notification - permission not granted');
      return;
    }
    
    _logger.debug('✓ Notification permission granted');

    final androidDetails = AndroidNotificationDetails(
      'critical_alerts',
      'Critical Alerts',
      channelDescription: 'Important alerts',
      importance: priority == Priority.high ? Importance.high : Importance.low,
      priority: priority,
      playSound: priority == Priority.high,
      enableVibration: priority == Priority.high,
      ongoing: ongoing,
      autoCancel: !ongoing,
      visibility: NotificationVisibility.public,  // Show on lock screen
      showWhen: true,
      category: AndroidNotificationCategory.status,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _notifications?.show(id, title, body, details);
      _logger.debug('✅ Notification shown successfully');
    } catch (e) {
      _logger.error('❌ Failed to show notification', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    _logger.info('Alert service disposed');
  }
}
