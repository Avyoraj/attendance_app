import 'package:flutter/material.dart';
import 'app/app.dart';
import 'package:provider/provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/simple_notification_service.dart';
import 'core/services/logger_service.dart';
import 'core/config/log_config.dart';
import 'package:flutter/foundation.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/alert_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/background_attendance_service.dart';
import 'core/background/background_task_registrar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger first
  final logger = LoggerService();
  // Initialize logger with level based on build mode & env overrides
  LogConfig.verbose = !kReleaseMode; // base default
  logger.initialize(level: LogConfig.effectiveLevel);
  logger.info('App starting... (verbose=${LogConfig.verbose}, quiet=${LogConfig.quiet}, level=${LogConfig.effectiveLevel.name})');

  try {
    // Initialize basic services WITHOUT requesting permissions yet
    // Permissions will be requested when user navigates to home screen

    // Initialize notification service
    await SimpleNotificationService.initializeService();
    logger.info('✓ Notification service initialized');

    // Initialize alert service
    final alertService = AlertService();
    await alertService.initialize();
    logger.info('✓ Alert service initialized');

    // Initialize connectivity service
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();
    logger.info('✓ Connectivity service initialized');

    // Initialize sync service
    final syncService = SyncService();
    await syncService.initialize();
    logger.info('✓ Sync service initialized');

    // Initialize background tasks (beacon scan + heartbeat + offline sync)
    try {
      final bg = BackgroundAttendanceService();
      await bg.initialize();
      await bg.startBackgroundAttendance();
      logger.info('✓ Background attendance scanning started');

      final registrar = BackgroundTaskRegistrar();
      await registrar.init();
      await registrar.registerCoreTasks();
      logger.info('✓ Background heartbeat/sync tasks registered');
    } catch (e, st) {
      logger.warning('Background tasks setup failed (non-fatal)', e, st);
    }

    // Initialize settings (load persisted preferences)
    final settingsService = SettingsService();
    await settingsService.init();
    logger.info('✓ Settings loaded (persisted preferences applied)');

    logger.info('✅ All services initialized successfully');
  } catch (e, stackTrace) {
    logger.error('Failed to initialize services', e, stackTrace);
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}
