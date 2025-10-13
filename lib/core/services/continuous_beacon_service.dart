import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'logger_service.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'http_service.dart';
import '../constants/api_constants.dart';

/// Continuous foreground beacon scanning service
/// Works exactly like the home screen scanning but runs in background
class ContinuousBeaconService {
  static final ContinuousBeaconService _instance = ContinuousBeaconService._internal();
  factory ContinuousBeaconService() => _instance;
  ContinuousBeaconService._internal();

  static const platform = MethodChannel('com.example.attendance_app/beacon_service');
  
  final LoggerService _logger = LoggerService();
  final LocalDatabaseService _db = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _sync = SyncService();
  final HttpService _http = HttpService();

  StreamSubscription<RangingResult>? _rangingSubscription;
  bool _isScanning = false;
  String? _currentStudentId;
  DateTime? _lastAttendanceTime;
  
  bool get isScanning => _isScanning;

  /// Check if battery optimization is disabled
  Future<bool> checkBatteryOptimization() async {
    try {
      final result = await platform.invokeMethod('isIgnoringBatteryOptimizations');
      return result as bool? ?? false;
    } catch (e) {
      _logger.warning('Failed to check battery optimization: $e');
      return false;
    }
  }

  /// Request to disable battery optimization
  Future<void> requestDisableBatteryOptimization() async {
    try {
      await platform.invokeMethod('requestDisableBatteryOptimization');
      _logger.info('Requested battery optimization exemption');
    } catch (e) {
      _logger.error('Failed to request battery optimization exemption', e);
    }
  }

  /// Open battery optimization settings
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await platform.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      _logger.error('Failed to open battery optimization settings', e);
    }
  }
  /// Start continuous beacon scanning with foreground service
  Future<void> startContinuousScanning() async {
    if (_isScanning) {
      _logger.info('Continuous scanning already running');
      return;
    }

    try {
      // Get student ID
      final prefs = await SharedPreferences.getInstance();
      _currentStudentId = prefs.getString(AppConstants.studentIdKey);

      if (_currentStudentId == null) {
        _logger.warning('No student ID found, cannot start scanning');
        return;
      }

      // Start Android foreground service
      await platform.invokeMethod('startForegroundService');
      _logger.info('✅ Foreground service started');

      // Initialize beacon scanning
      await flutterBeacon.initializeScanning;
      
      final regions = <Region>[
        Region(
          identifier: AppConstants.schoolIdentifier,
          proximityUUID: AppConstants.proximityUUID,
        ),
      ];

      // Start continuous ranging (same as home screen)
      _rangingSubscription = flutterBeacon.ranging(regions).listen(
        (result) => _handleBeaconResult(result),
        onError: (error) {
          _logger.error('Beacon ranging error', error);
        },
      );

      _isScanning = true;
      _logger.info('🔍 Continuous beacon scanning started (same as home screen)');
      
    } catch (e, stackTrace) {
      _logger.error('Failed to start continuous scanning', e, stackTrace);
      rethrow;
    }
  }

  /// Stop continuous beacon scanning
  Future<void> stopContinuousScanning() async {
    if (!_isScanning) return;

    try {
      // Cancel ranging subscription
      await _rangingSubscription?.cancel();
      _rangingSubscription = null;

      // Stop foreground service
      await platform.invokeMethod('stopForegroundService');

      _isScanning = false;
      _logger.info('⏹️ Continuous scanning stopped');
      
    } catch (e, stackTrace) {
      _logger.error('Failed to stop continuous scanning', e, stackTrace);
    }
  }

  /// Handle beacon detection (same logic as home screen)
  Future<void> _handleBeaconResult(RangingResult result) async {
    // Always update notification - even if no beacons
    if (result.beacons.isEmpty) {
      await platform.invokeMethod('updateNotification', {
        'text': '🔍 Searching for beacons... (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})'
      });
      return;
    }

    try {
      final beacon = result.beacons.first;
      final classId = 'CS${beacon.major}';
      final rssi = beacon.rssi;
      final distance = _calculateDistance(rssi, beacon.txPower ?? -59);

      _logger.beaconDetected(classId, rssi, distance);
      
      // ALWAYS update notification to show beacon detected
      print('🔔 Beacon detected, updating notification: $classId, RSSI: $rssi');
      await platform.invokeMethod('updateNotification', {
        'text': '📍 Found $classId | RSSI: $rssi | ${distance.toStringAsFixed(1)}m'
      });
      print('✅ Notification update called');

      // Check if in range for attendance (RSSI > -75 dBm)
      if (rssi > AppConstants.rssiThreshold) {
        print('✅ RSSI good ($rssi > ${AppConstants.rssiThreshold}), recording attendance...');
        await _recordAttendance(classId, rssi, distance);
      } else {
        // Show why attendance not recorded
        print('⚠️ RSSI too weak ($rssi <= ${AppConstants.rssiThreshold})');
        await platform.invokeMethod('updateNotification', {
          'text': '⚠️ $classId too far (RSSI: $rssi, need > ${AppConstants.rssiThreshold})'
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Error handling beacon result', e, stackTrace);
      print('❌ Error in _handleBeaconResult: $e');
    }
  }

  /// Record attendance (same logic as home screen)
  Future<void> _recordAttendance(String classId, int rssi, double distance) async {
    if (_currentStudentId == null) return;

    try {
      // Check if already recorded today
      if (_lastAttendanceTime != null) {
        final timeSinceLastLog = DateTime.now().difference(_lastAttendanceTime!);
        if (timeSinceLastLog.inMinutes < 30) {
          _logger.debug('Attendance already recorded recently (${timeSinceLastLog.inMinutes} minutes ago), skipping');
          
          // Show cooldown message
          await platform.invokeMethod('updateNotification', {
            'text': '⏳ Already logged $classId (${timeSinceLastLog.inMinutes}m ago, wait ${30 - timeSinceLastLog.inMinutes}m)'
          });
          return;
        }
      }

      _logger.info('📝 Recording attendance: $classId (RSSI: $rssi, Distance: ${distance.toStringAsFixed(2)}m)');
      print('🔔 RECORDING ATTENDANCE FOR: $classId'); // DEBUG

      // Check internet connectivity
      await _connectivity.initialize();
      final isOnline = _connectivity.isOnline;

      if (isOnline) {
        // Try to send directly to server
        try {
          final response = await _http.post(
            url: ApiConstants.checkInEndpoint,
            body: {
              'studentId': _currentStudentId!,
              'classId': classId,
              'timestamp': DateTime.now().toIso8601String(),
              'rssi': rssi,
              'distance': distance,
            },
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            _logger.info('✅ Attendance recorded successfully on server');
            _lastAttendanceTime = DateTime.now();
            
            // UPDATE foreground service notification to show success
            print('🔔 Updating foreground notification with success message');
            await platform.invokeMethod('updateNotification', {
              'text': '✅ Attendance logged for $classId at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'
            });
            
            return;
          }
        } catch (e) {
          _logger.warning('Failed to send to server, will save locally: $e');
        }
      }

      // Save locally if offline or server failed
      await _db.saveAttendanceLocally(
        studentId: _currentStudentId!,
        classId: classId,
        timestamp: DateTime.now(),
        rssi: rssi,
      );

      _lastAttendanceTime = DateTime.now();
      _logger.info('💾 Attendance saved locally');
      
      // UPDATE foreground service notification to show success (offline)
      print('🔔 Updating foreground notification with offline success message');
      await platform.invokeMethod('updateNotification', {
        'text': '✅ Attendance logged for $classId (offline) at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'
      });
      
      // Try to sync immediately
      if (isOnline) {
        await _sync.syncPendingRecords();
      }
      
    } catch (e, stackTrace) {
      _logger.error('Failed to record attendance', e, stackTrace);
    }
  }

  /// Calculate distance from RSSI
  double _calculateDistance(int rssi, int txPower) {
    if (rssi == 0) return -1.0;
    
    final ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return ratio * 10;
    } else {
      final accuracy = (0.89976) * (ratio * ratio * ratio * ratio * ratio * ratio * ratio) + 0.111;
      return accuracy;
    }
  }

  /// Dispose resources
  void dispose() {
    stopContinuousScanning();
  }
}
