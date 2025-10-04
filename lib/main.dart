import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/simple_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await SimpleNotificationService.initializeService();
  
  runApp(const MyApp());
}