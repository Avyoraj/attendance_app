import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import '../constants/app_constants.dart';
import 'http_service.dart';

class SimpleNotificationService {
  static const String _channelId = 'beacon_tracking_channel';
  static const String _channelName = 'Beacon Distance Tracking';
  
  static FlutterLocalNotificationsPlugin? _notifications;
  static StreamSubscription<RangingResult>? _streamRanging;
  static double? _lastDistance;
  static String? _currentClassId;
  static bool _attendanceRecorded = false;
  static bool _isServiceRunning = false;
  static Timer? _notificationTimer;

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
    
    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Shows distance to classroom beacons',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    
    await _notifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> startBackgroundTracking() async {
    if (_isServiceRunning) return;
    
    _isServiceRunning = true;
    await _startBeaconScanning();
    await _showNotification('🔍 Background Tracking Started', 'Scanning for classroom beacons...');
  }

  static Future<void> stopBackgroundTracking() async {
    _isServiceRunning = false;
    await _streamRanging?.cancel();
    _notificationTimer?.cancel();
    await _notifications?.cancelAll();
    _streamRanging = null;
    _notificationTimer = null;
  }

  static Future<void> _startBeaconScanning() async {
    try {
      await flutterBeacon.initializeScanning;
      
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString('student_id');
      
      if (studentId == null) {
        await _showNotification('Please login first', 'Open app to authenticate');
        return;
      }

      final regions = <Region>[
        Region(
          identifier: 'Classroom_Beacon',
          proximityUUID: AppConstants.beaconUUID,
        ),
      ];

      _streamRanging = flutterBeacon.ranging(regions).listen((RangingResult result) {
        if (_isServiceRunning) {
          _handleBeaconRanging(result, studentId);
        }
      });
      
    } catch (e) {
      debugPrint('Error starting beacon scanning: $e');
    }
  }

  static void _handleBeaconRanging(RangingResult result, String studentId) {
    if (result.beacons.isEmpty) {
      _showNoBeaconNotification();
      return;
    }

    final beacon = result.beacons.first;
    final distance = _calculateDistance(beacon.rssi, beacon.txPower ?? -59);
    
    // Only update if distance changed significantly (reduce battery usage)
    if (_lastDistance == null || (distance - _lastDistance!).abs() > 2.0) {
      _lastDistance = distance;
      _currentClassId = 'CS${beacon.major}'; // Extract class from major
      
      _updateDistanceNotification(distance, _currentClassId!);
      
      // Auto attendance if in range and not already recorded
      if (distance <= AppConstants.rssiDistanceThreshold && !_attendanceRecorded) {
        _recordAttendance(studentId, _currentClassId!);
      } else if (distance > AppConstants.rssiDistanceThreshold) {
        _attendanceRecorded = false; // Reset when moving away
      }
    }
  }

  // Calculate approximate distance from RSSI
  static double _calculateDistance(int rssi, int txPower) {
    if (rssi == 0) return -1.0;
    
    double ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return math.pow(ratio, 10).toDouble();
    } else {
      double accuracy = (0.89976) * math.pow(ratio, 7.7095) + 0.111;
      return accuracy;
    }
  }

  static Future<void> _updateDistanceNotification(double distance, String classId) async {
    String title, content;
    
    if (distance <= AppConstants.rssiDistanceThreshold) {
      title = '✅ In Range - $classId';
      content = 'Ready for attendance • ${distance.toStringAsFixed(1)}m away';
    } else if (distance <= 20) {
      title = '📍 Approaching $classId';
      content = 'Move closer • ${distance.toStringAsFixed(1)}m away';
    } else {
      title = '🔍 $classId Detected';
      content = '${distance.toStringAsFixed(1)}m away • Keep moving closer';
    }
    
    await _showNotification(title, content);
  }

  static void _showNoBeaconNotification() {
    // Throttle "no beacon" notifications to every 30 seconds
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 30), () {
      _showNotification('🔍 Scanning...', 'Looking for classroom beacons');
    });
  }

  static Future<void> _recordAttendance(String studentId, String classId) async {
    if (_attendanceRecorded) return;
    
    _attendanceRecorded = true;
    await _showNotification('⏳ Recording...', 'Submitting attendance for $classId');
    
    try {
      final response = await HttpService.submitAttendance(studentId, classId);
      
      if (response.statusCode == 200) {
        await _showNotification('✅ Success!', 'Attendance recorded for $classId');
        // Auto-dismiss notification after 5 seconds
        Timer(const Duration(seconds: 5), () {
          _notifications?.cancel(1);
        });
      } else {
        await _showNotification('❌ Failed', 'Could not record attendance. Try again.');
        _attendanceRecorded = false;
      }
    } catch (e) {
      await _showNotification('❌ Error', 'Network error. Please try again.');
      _attendanceRecorded = false;
    }
  }

  static Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Distance tracking notifications',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _notifications?.show(1, title, body, notificationDetails);
  }
}