import 'package:flutter/material.dart';
import '../../attendance/screens/home_screen.dart';

/// Material 3 Home Screen - Wrapper for existing HomeScreen
/// 
/// This simply wraps the existing HomeScreen which already has:
/// - Full beacon functionality
/// - Material 3 design
/// - All features working
class Material3HomeScreen extends StatelessWidget {
  final String studentId;

  const Material3HomeScreen({
    super.key,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    return HomeScreen(studentId: studentId);
  }
}