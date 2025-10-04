import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/login_form.dart';
import '../../attendance/screens/home_screen.dart';
import '../../../core/constants/app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin(String studentId) async {
    if (studentId.isEmpty) {
      _showSnackBar('Please enter your Student ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _authService.login(studentId);
      
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(studentId: studentId),
          ),
        );
      } else {
        _showSnackBar('Login failed. Please try again.');
      }
    } catch (e) {
      _showSnackBar('An error occurred. Please try again.');
      print('Login error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: LoginForm(
          onLogin: _handleLogin,
          isLoading: _isLoading,
        ),
      ),
    );
  }
}