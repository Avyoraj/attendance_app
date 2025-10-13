import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/login_form.dart';
import '../../../app/main_navigation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/continuous_beacon_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/permission_service.dart';

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
        // Auto-start background attendance service after successful login
        await _startBackgroundService();
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainNavigation(studentId: studentId),
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

  /// Auto-start background service after login
  Future<void> _startBackgroundService() async {
    try {
      final logger = LoggerService();
      
      // Request all required permissions (BLE, Location, Notification)
      final permissionService = PermissionService();
      await permissionService.requestBeaconPermissions();
      await permissionService.requestNotificationPermission();
      logger.info('✓ Permissions requested');
      
      // Start continuous beacon scanning (works for lock screen)
      final continuousService = ContinuousBeaconService();
      await continuousService.startContinuousScanning();
      logger.info('✅ Continuous scanning auto-started after login');
      
      // Show success message to user
      if (mounted) {
        _showSnackBar('✅ Auto-attendance enabled • Scanning continuously');
      }
    } catch (e) {
      final logger = LoggerService();
      logger.error('Failed to start continuous scanning', e);
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
        backgroundColor: Colors.transparent,
        elevation: 0,
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