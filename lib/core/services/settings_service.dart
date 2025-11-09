import '../../models/app_settings.dart';
import 'background_attendance_service.dart';
import 'alert_service.dart';
import 'package:attendance_app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  AppSettings _settings = AppSettings();

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _settings = AppSettings(
        darkMode: _prefs?.getBool(_Keys.darkMode) ?? false,
        backgroundTracking: _prefs?.getBool(_Keys.backgroundTracking) ?? false,
        notificationEnabled: _prefs?.getBool(_Keys.notificationEnabled) ?? true,
        systemTheme: _prefs?.getBool(_Keys.systemTheme) ?? false,
        soundEnabled: _prefs?.getBool(_Keys.soundEnabled) ?? true,
        vibrationEnabled: _prefs?.getBool(_Keys.vibrationEnabled) ?? true,
        newAttendancePipelineEnabled:
            _prefs?.getBool(_Keys.newAttendancePipelineEnabled) ?? true,
      );
      AppLogger.info('Settings loaded from persistence');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize SettingsService',
          error: e, stackTrace: stackTrace);
    }
  }

  AppSettings getSettings() => _settings;

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _persistAll();
  }

  // Individual toggle methods with persistence
  void toggleDarkMode(bool value) {
    _settings.darkMode = value;
    _prefs?.setBool(_Keys.darkMode, value);
  }

  void toggleBackgroundTracking(bool value) async {
    _settings.backgroundTracking = value;
    _prefs?.setBool(_Keys.backgroundTracking, value);

    final backgroundService = BackgroundAttendanceService();
    final alertService = AlertService();
    try {
      if (value) {
        await backgroundService.startBackgroundAttendance();
        await alertService.showBackgroundServiceNotification();
      } else {
        await backgroundService.stopBackgroundAttendance();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error toggling background tracking',
          error: e, stackTrace: stackTrace);
    }
  }

  void toggleNotificationEnabled(bool value) {
    _settings.notificationEnabled = value;
    _prefs?.setBool(_Keys.notificationEnabled, value);
  }

  void toggleSystemTheme(bool value) {
    _settings.systemTheme = value;
    _prefs?.setBool(_Keys.systemTheme, value);
  }

  void toggleSoundEnabled(bool value) {
    _settings.soundEnabled = value;
    _prefs?.setBool(_Keys.soundEnabled, value);
  }

  void toggleVibrationEnabled(bool value) {
    _settings.vibrationEnabled = value;
    _prefs?.setBool(_Keys.vibrationEnabled, value);
  }

  // Feature Flags
  void toggleNewAttendancePipeline(bool value) {
    _settings.newAttendancePipelineEnabled = value;
    _prefs?.setBool(_Keys.newAttendancePipelineEnabled, value);
  }

  void _persistAll() {
    if (_prefs == null) return;
    _prefs!.setBool(_Keys.darkMode, _settings.darkMode);
    _prefs!.setBool(_Keys.backgroundTracking, _settings.backgroundTracking);
    _prefs!.setBool(_Keys.notificationEnabled, _settings.notificationEnabled);
    _prefs!.setBool(_Keys.systemTheme, _settings.systemTheme);
    _prefs!.setBool(_Keys.soundEnabled, _settings.soundEnabled);
    _prefs!.setBool(_Keys.vibrationEnabled, _settings.vibrationEnabled);
    _prefs!.setBool(_Keys.newAttendancePipelineEnabled,
        _settings.newAttendancePipelineEnabled);
  }
}

class _Keys {
  static const darkMode = 'darkMode';
  static const backgroundTracking = 'backgroundTracking';
  static const notificationEnabled = 'notificationEnabled';
  static const systemTheme = 'systemTheme';
  static const soundEnabled = 'soundEnabled';
  static const vibrationEnabled = 'vibrationEnabled';
  static const newAttendancePipelineEnabled = 'newAttendancePipelineEnabled';
}
