import 'package:flutter/material.dart';
import '../features/shared/screens/auth_check_screen.dart';
import 'theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../core/providers/settings_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    return MaterialApp(
      title: 'Attendance App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthCheckScreen(),
    );
  }
}
