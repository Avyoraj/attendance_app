import 'package:workmanager/workmanager.dart';

import '../logger_service.dart';
import '../alert_service.dart';
import 'background_task_callbacks.dart';
import 'background_utils.dart';

/// Background Attendance Service
/// 
/// Manages Workmanager-based background tasks for:
/// - Periodic beacon scanning (every 15 minutes)
/// - Periodic sync of pending records (every 30 minutes)
/// 
/// Usage:
/// ```dart
/// final bgService = BackgroundAttendanceService();
/// await bgService.initialize();
/// await bgService.startBackgroundAttendance();
/// ```
class BackgroundAttendanceService {
  static final BackgroundAttendanceService _instance =
      BackgroundAttendanceService._internal();
  factory BackgroundAttendanceService() => _instance;
  BackgroundAttendanceService._internal();

  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;
  bool _isRunning = false;

  /// Whether the background service is currently running
  bool get isRunning => _isRunning;

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize background service with Workmanager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true for debugging
      );

      _isInitialized = true;
      _logger.info('Background attendance service initialized');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize background service', e, stackTrace);
      rethrow;
    }
  }

  /// Start background attendance logging
  /// Registers periodic tasks for beacon scanning and sync
  Future<void> startBackgroundAttendance() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isRunning) {
      _logger.info('Background service already running');
      return;
    }

    try {
      // Register beacon scanning task
      await Workmanager().registerPeriodicTask(
        BackgroundTaskIds.beaconScanningTask,
        BackgroundTaskIds.beaconScanning,
        frequency: BackgroundTaskDurations.beaconScanFrequency,
        initialDelay: BackgroundTaskDurations.initialDelay,
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
        ),
      );

      // Register sync task
      await Workmanager().registerPeriodicTask(
        BackgroundTaskIds.syncAttendanceTask,
        BackgroundTaskIds.syncAttendance,
        frequency: BackgroundTaskDurations.syncFrequency,
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
      await Workmanager().cancelByUniqueName(BackgroundTaskIds.beaconScanningTask);
      await Workmanager().cancelByUniqueName(BackgroundTaskIds.syncAttendanceTask);

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
