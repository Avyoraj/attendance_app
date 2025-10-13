import 'package:flutter/material.dart';
import 'app/app.dart';
import 'package:provider/provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/simple_notification_service.dart';
import 'core/services/logger_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/alert_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger first
  final logger = LoggerService();
  logger.initialize();
  logger.info('🚀 App starting...');

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
