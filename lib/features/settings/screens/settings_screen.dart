import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final settings = settingsProvider.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.darkMode,
            onChanged: (value) {
              settingsProvider.toggleDarkMode(value);
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          SwitchListTile(
            title: const Text('Background Tracking'),
            value: settings.backgroundTracking,
            onChanged: (value) {
              settingsProvider.toggleBackgroundTracking(value);
            },
            secondary: const Icon(Icons.location_searching),
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            value: settings.notificationEnabled,
            onChanged: (value) {
              settingsProvider.toggleNotificationEnabled(value);
            },
            secondary: const Icon(Icons.notifications),
          ),
        ],
      ),
    );
  }
}
