import 'package:workmanager/workmanager.dart';
import '../services/logger_service.dart';
import '../services/sync_service.dart';
import '../services/confirmation_timer_service.dart';
import '../services/http_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
// Removed unused imports

/// BackgroundTaskRegistrar
/// Central place to initialize and register Workmanager tasks.
/// Keeps background logic small and auditable.
class BackgroundTaskRegistrar {
  static final BackgroundTaskRegistrar _instance = BackgroundTaskRegistrar._internal();
  factory BackgroundTaskRegistrar() => _instance;
  BackgroundTaskRegistrar._internal();

  final LoggerService _logger = LoggerService();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Workmanager().initialize(_dispatcher, isInDebugMode: false);
    _initialized = true;
    _logger.info('BackgroundTaskRegistrar initialized');
  }

  Future<void> registerCoreTasks() async {
    if (!_initialized) await init();

    // Beacon scanning already handled by BackgroundAttendanceService if used.
    // Here we only add confirmation heartbeat + sync if not already scheduled.
    await Workmanager().registerPeriodicTask(
      'confirmationHeartbeatTask',
      'confirmationHeartbeat',
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 1),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      'offlineSyncTask',
      'offlineSync',
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(minutes: 2),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    _logger.backgroundServiceStatus('Registered confirmationHeartbeat & offlineSync tasks');
  }
}

@pragma('vm:entry-point')
void _dispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final logger = LoggerService();
    logger.initialize();
    logger.backgroundServiceStatus('BG Task start: $task');

    try {
      switch (task) {
        case 'confirmationHeartbeat':
          await _runConfirmationHeartbeat(logger);
          break;
        case 'offlineSync':
          await _runOfflineSync(logger);
          break;
        default:
          logger.warning('Unknown background task: $task');
      }
      return true;
    } catch (e, st) {
      logger.error('Background task failed', e, st);
      return false;
    }
  });
}

Future<void> _runConfirmationHeartbeat(LoggerService logger) async {
  final timerService = ConfirmationTimerService();
  final remaining = timerService.getRemainingSeconds();
  if (remaining <= 0) {
    logger.debug('Heartbeat: No active confirmation timer');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final studentId = prefs.getString(AppConstants.studentIdKey);
  // Reuse existing key pattern; if not present we skip.
  final classId = prefs.getString('active_class_id');

  if (studentId == null || classId == null) {
    logger.debug('Heartbeat: Missing student/class id');
    return;
  }

  // Simple re-validation: fetch today attendance and ensure record still provisional.
  try {
    final http = HttpService();
    final result = await http.getTodayAttendance(studentId: studentId);
    if (result['success'] == true) {
      final list = (result['attendance'] as List);
      final record = list.firstWhere(
        (r) => r['classId'] == classId,
        orElse: () => {},
      );
      if (record.isEmpty) {
        logger.warning('Heartbeat: No record found for active class');
      } else {
        final status = record['status'];
        logger.debug('Heartbeat: status for $classId => $status (remaining=$remaining)');
      }
    } else {
      logger.warning('Heartbeat: today attendance fetch failed');
    }
  } catch (e, st) {
    logger.error('Heartbeat error', e, st);
  }
}

Future<void> _runOfflineSync(LoggerService logger) async {
  try {
    final sync = SyncService();
    final count = await sync.syncPendingRecords();
    logger.debug('OfflineSync: processed $count attendance records (plus actions)');
  } catch (e, st) {
    logger.error('OfflineSync error', e, st);
  }
}
