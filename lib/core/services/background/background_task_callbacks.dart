import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

import '../../constants/app_constants.dart';
import '../../constants/api_constants.dart';
import '../logger_service.dart';
import '../local_database_service.dart';
import '../connectivity_service.dart';
import '../sync_service.dart';
import '../alert_service.dart';
import '../http_service.dart';
import '../device_id_service.dart';
import 'background_utils.dart';

/// Workmanager callback dispatcher - MUST be top-level function
/// This is the entry point for all background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final logger = LoggerService();
      logger.initialize();
      logger.backgroundServiceStatus('Background task started: $task');

      switch (task) {
        case BackgroundTaskIds.beaconScanning:
          await performBeaconScan();
          break;
        case BackgroundTaskIds.syncAttendance:
          await performSync();
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

/// Perform background beacon scan
/// Scans for nearby beacons and records attendance if in range
Future<void> performBeaconScan() async {
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

    // Scan for beacons with timeout
    await for (final result in flutterBeacon.ranging(regions).timeout(
      BackgroundTaskDurations.scanTimeout,
      onTimeout: (sink) {
        logger.debug('Beacon scan timeout');
        sink.close();
      },
    )) {
      if (result.beacons.isNotEmpty) {
        final beacon = result.beacons.first;
        final distance = calculateDistanceFromRssi(
          beacon.rssi,
          beacon.txPower ?? -59,
        );

        logger.beaconDetected('CS${beacon.major}', beacon.rssi, distance);

        // Check if beacon is in range for attendance
        if (beacon.rssi > AppConstants.rssiThreshold) {
          await _recordBackgroundAttendance(
            studentId: studentId,
            classId: 'CS${beacon.major}',
            rssi: beacon.rssi,
            distance: distance,
          );
          break; // Stop after recording
        }
      }
    }
  } catch (e, stackTrace) {
    logger.error('Error during beacon scan', e, stackTrace);
  }
}

/// Perform background sync of pending records
Future<void> performSync() async {
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

/// Record attendance detected in background
/// Handles both online (direct API) and offline (local storage) scenarios
Future<void> _recordBackgroundAttendance({
  required String studentId,
  required String classId,
  required int rssi,
  required double distance,
}) async {
  final logger = LoggerService();
  final prefs = await SharedPreferences.getInstance();
  final deviceIdService = DeviceIdService();
  final deviceId = await deviceIdService.getDeviceId();

  // Check if attendance already recorded for this class recently
  final lastRecordKey = 'last_attendance_$classId';
  final lastRecordTime = prefs.getString(lastRecordKey);
  final now = DateTime.now();

  if (lastRecordTime != null) {
    final lastTime = DateTime.parse(lastRecordTime);
    final diff = now.difference(lastTime);

    // Don't record again within the recent attendance window
    if (diff < BackgroundTaskDurations.recentAttendanceWindow) {
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
        url: ApiConstants.checkIn,
        body: {
          'studentId': studentId,
          'classId': classId,
          'timestamp': now.toIso8601String(),
          'rssi': rssi,
          'distance': distance,
          'deviceId': deviceId,
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
