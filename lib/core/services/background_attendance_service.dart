/// Background Attendance Service - Barrel Export
/// 
/// This file re-exports the refactored background service modules
/// for backward compatibility with existing imports.
/// 
/// The service has been split into:
/// - background/background_attendance_service.dart - Main service class
/// - background/background_task_callbacks.dart - Workmanager callbacks
/// - background/background_utils.dart - Shared utilities
library;

export 'background/background_attendance_service.dart';
export 'background/background_task_callbacks.dart' show callbackDispatcher;
export 'background/background_utils.dart';

