import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import 'logger_service.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'alert_service.dart';
import 'http_service.dart';
import '../constants/api_constants.dart';

/// Background attendance service
/// Runs even when app is closed or phone is locked
/// Automatically logs attendance when near beacon
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final logger = LoggerService();
      logger.initialize();
      logger.backgroundServiceStatus('Background task started: $task');

      switch (task) {
        case 'beaconScanning':
          await _performBeaconScan();
          break;
        case 'syncAttendance':
          await _performSync();
          break;
        default:
          logger.warning('Unknown task: $task');
      }

      return true;
    } catch (e) {
      final logger = LoggerService();
      logger.error('Background task failed', e);
      return false;
    }
  });
}

Future<void> _performBeaconScan() async {
  final logger = LoggerService();
  logger.backgroundServiceStatus('Performing beacon scan');

  try {
    // Get student ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString(AppConstants.studentIdKey);

    if (studentId == null) {
      logger.warning('No student ID found, skipping scan');
      return;
    }

    // Check permissions
    final bluetoothStatus = await Permission.bluetooth.status;
    final locationStatus = await Permission.location.status;

    if (!bluetoothStatus.isGranted || !locationStatus.isGranted) {
      logger.warning('Permissions not granted for background scan');
      final alertService = AlertService();
      await alertService.initialize();
      await alertService.showBluetoothDisabledAlert();
      return;
    }

    // Initialize beacon scanning
    await flutterBeacon.initializeScanning;

    final regions = <Region>[
      Region(
        identifier: AppConstants.schoolIdentifier,
        proximityUUID: AppConstants.proximityUUID,
      ),
    ];

    // Scan for beacons for 10 seconds
    await for (final result in flutterBeacon.ranging(regions).timeout(
      const Duration(seconds: 10),
      onTimeout: (sink) {
        logger.debug('Beacon scan timeout');
        sink.close();
      },
    )) {
      if (result.beacons.isNotEmpty) {
        final beacon = result.beacons.first;
        logger.beaconDetected(
          'CS${beacon.major}',
          beacon.rssi,
          _calculateDistance(beacon.rssi, beacon.txPower ?? -59),
        );

        // Check if beacon is in range for attendance
        if (beacon.rssi > AppConstants.rssiThreshold) {
          await _recordBackgroundAttendance(
            studentId,
            'CS${beacon.major}',
            beacon.rssi,
            _calculateDistance(beacon.rssi, beacon.txPower ?? -59),
          );
          break; // Stop after recording
        }
      }
    }
  } catch (e, stackTrace) {
    logger.error('Error during beacon scan', e, stackTrace);
  }
}

Future<void> _performSync() async {
  final logger = LoggerService();
  logger.backgroundServiceStatus('Performing sync');

  try {
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();

    if (!connectivityService.isOnline) {
      logger.info('No internet, skipping sync');
      return;
    }

    final syncService = SyncService();
    await syncService.initialize();
    final synced = await syncService.syncPendingRecords();

    logger.info('Background sync completed: $synced records synced');
  } catch (e, stackTrace) {
    logger.error('Error during background sync', e, stackTrace);
  }
}

Future<void> _recordBackgroundAttendance(
  String studentId,
  String classId,
  int rssi,
  double distance,
) async {
  final logger = LoggerService();
  final prefs = await SharedPreferences.getInstance();

  // Check if attendance already recorded for this class today
  final lastRecordKey = 'last_attendance_$classId';
  final lastRecordTime = prefs.getString(lastRecordKey);
  final now = DateTime.now();

  if (lastRecordTime != null) {
    final lastTime = DateTime.parse(lastRecordTime);
    final diff = now.difference(lastTime);

    // Don't record again if less than 30 minutes
    if (diff.inMinutes < 30) {
      logger.info('Attendance already recorded recently for $classId');
      return;
    }
  }

  try {
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();

    if (connectivityService.isOnline) {
      // Try to send directly to server
      final httpService = HttpService();
      final response = await httpService.post(
        url: ApiConstants.checkInUrl,
        body: {
          'studentId': studentId,
          'classId': classId,
          'timestamp': now.toIso8601String(),
          'rssi': rssi,
          'distance': distance,
          'background': true,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        logger.attendanceRecorded(studentId, classId, true);
        await prefs.setString(lastRecordKey, now.toIso8601String());
        
        // Show notification
        final alertService = AlertService();
        await alertService.initialize();
        await alertService.showAttendanceRecordedNotification(classId);
        return;
      }
    }

    // If offline or server error, save locally
    final localDb = LocalDatabaseService();
    await localDb.saveAttendanceLocally(
      studentId: studentId,
      classId: classId,
      timestamp: now,
      rssi: rssi,
      distance: distance,
    );

    logger.info('Attendance saved locally for $classId (offline mode)');
    await prefs.setString(lastRecordKey, now.toIso8601String());

    // Show notification
    final alertService = AlertService();
    await alertService.initialize();
    await alertService.showInternetUnavailableAlert();
    
  } catch (e, stackTrace) {
    logger.error('Failed to record background attendance', e, stackTrace);
  }
}

double _calculateDistance(int rssi, int txPower) {
  if (rssi == 0) return -1.0;
  
  final ratio = rssi * 1.0 / txPower;
  if (ratio < 1.0) {
    return (ratio * 10);
  } else {
    final accuracy = (0.89976) * (ratio * ratio * ratio * ratio * ratio * ratio * ratio) + 0.111;
    return accuracy;
  }
}

/// Foreground background service manager
class BackgroundAttendanceService {
  static final BackgroundAttendanceService _instance = BackgroundAttendanceService._internal();
  factory BackgroundAttendanceService() => _instance;
  BackgroundAttendanceService._internal();

  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Initialize background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to false for production
      );

      _isInitialized = true;
      _logger.info('Background attendance service initialized');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize background service', e, stackTrace);
      rethrow;
    }
  }

  /// Start background attendance logging
  Future<void> startBackgroundAttendance() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isRunning) {
      _logger.info('Background service already running');
      return;
    }

    try {
      // Register beacon scanning task (every 15 minutes)
      await Workmanager().registerPeriodicTask(
        'beaconScanningTask',
        'beaconScanning',
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(seconds: 10),
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
        ),
      );

      // Register sync task (every 30 minutes)
      await Workmanager().registerPeriodicTask(
        'syncAttendanceTask',
        'syncAttendance',
        frequency: const Duration(minutes: 30),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      _isRunning = true;
      _logger.backgroundServiceStatus('Started');

      // Show notification
      final alertService = AlertService();
      await alertService.showBackgroundServiceNotification();
      
    } catch (e, stackTrace) {
      _logger.error('Failed to start background service', e, stackTrace);
      rethrow;
    }
  }

  /// Stop background attendance logging
  Future<void> stopBackgroundAttendance() async {
    if (!_isRunning) return;

    try {
      await Workmanager().cancelByUniqueName('beaconScanningTask');
      await Workmanager().cancelByUniqueName('syncAttendanceTask');

      _isRunning = false;
      _logger.backgroundServiceStatus('Stopped');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop background service', e, stackTrace);
    }
  }

  /// Cancel all background tasks
  Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    _isRunning = false;
    _logger.backgroundServiceStatus('All tasks cancelled');
  }
}
