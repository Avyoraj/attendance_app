import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();
  AppSettings get settings => _service.getSettings();

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
}
