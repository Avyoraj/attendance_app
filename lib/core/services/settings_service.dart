import '../../models/app_settings.dart';

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

  void toggleBackgroundTracking(bool value) {
    _settings.backgroundTracking = value;
    // TODO: Persist change
  }

  void toggleNotificationEnabled(bool value) {
    _settings.notificationEnabled = value;
    // TODO: Persist change
  }
}
