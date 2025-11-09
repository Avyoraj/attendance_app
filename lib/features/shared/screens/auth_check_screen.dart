import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../../app/main_navigation.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  Future<String?> _getStudentId() async {
    final storageService = await StorageService.getInstance();
    return await storageService.getStudentId();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getStudentId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          return MainNavigation(studentId: snapshot.data!);
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
