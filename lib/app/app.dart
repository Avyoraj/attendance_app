import 'package:flutter/material.dart';
import '../features/shared/screens/auth_check_screen.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: AppTheme.lightTheme,
      home: const AuthCheckScreen(),
    );
  }
}