import '../../models/app_settings.dart';
import 'background_attendance_service.dart';
import 'alert_service.dart';

class SettingsService {
  AppSettings _settings = AppSettings();

  AppSettings getSettings() => _settings;

  void updateSettings(AppSettings settings) {
    _settings = settings;
    // TODO: Persist settings
  }

  void toggleDarkMode(bool value) {
    _settings.darkMode = value;
    // TODO: Persist change
  }

  void toggleBackgroundTracking(bool value) async {
    _settings.backgroundTracking = value;
    
    // Start or stop the actual background service
    final backgroundService = BackgroundAttendanceService();
    final alertService = AlertService();
    
    try {
      if (value) {
        await backgroundService.startBackgroundAttendance();
        await alertService.showBackgroundServiceNotification();
      } else {
        await backgroundService.stopBackgroundAttendance();
      }
    } catch (e) {
      print('Error toggling background tracking: $e');
    }
    
    // TODO: Persist change
  }

  void toggleNotificationEnabled(bool value) {
    _settings.notificationEnabled = value;
    // TODO: Persist change
  }

  void toggleSystemTheme(bool value) {
    _settings.systemTheme = value;
    // TODO: Persist change
  }

  void toggleSoundEnabled(bool value) {
    _settings.soundEnabled = value;
    // TODO: Persist change
  }

  void toggleVibrationEnabled(bool value) {
    _settings.vibrationEnabled = value;
    // TODO: Persist change
  }
}
