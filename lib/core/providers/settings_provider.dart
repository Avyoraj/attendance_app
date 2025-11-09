import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();
  AppSettings get settings => _service.getSettings();

  SettingsProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.init();
    notifyListeners();
  }

  void toggleDarkMode(bool value) {
    _service.toggleDarkMode(value);
    notifyListeners();
  }

  void toggleBackgroundTracking(bool value) {
    _service.toggleBackgroundTracking(value);
    notifyListeners();
  }

  void toggleNotificationEnabled(bool value) {
    _service.toggleNotificationEnabled(value);
    notifyListeners();
  }

  void toggleSystemTheme(bool value) {
    _service.toggleSystemTheme(value);
    notifyListeners();
  }

  void toggleSoundEnabled(bool value) {
    _service.toggleSoundEnabled(value);
    notifyListeners();
  }

  void toggleVibrationEnabled(bool value) {
    _service.toggleVibrationEnabled(value);
    notifyListeners();
  }

  // Feature Flags
  void toggleNewAttendancePipeline(bool value) {
    _service.toggleNewAttendancePipeline(value);
    notifyListeners();
  }
}
