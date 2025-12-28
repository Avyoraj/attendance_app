import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../widgets/login_form.dart';
import '../../../app/main_navigation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/beacon_service.dart';
import '../../../core/services/http_service.dart';
import '../../profile/screens/profile_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final LoggerService _logger = LoggerService();
  bool _isLoading = false;

  Future<void> _handleLogin(String studentId) async {
    if (studentId.isEmpty) {
      _showSnackBar('Please enter your Student ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call new login method that returns detailed result
      final loginResult = await _authService.login(studentId);

      if (!mounted) return;

      if (loginResult['success'] == true) {
        // Login successful - sync state from backend first
        await _syncAttendanceState(studentId);
        if (!mounted) return;

        // Then start background service
        await _startBackgroundService();
        if (!mounted) return;

        // Check if profile is complete
        final isProfileComplete = await _checkProfileComplete(studentId);
        if (!mounted) return;

        if (isProfileComplete) {
          // Profile complete - go to main app
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainNavigation(studentId: studentId),
            ),
          );
        } else {
          // Profile incomplete - show setup screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ProfileSetupScreen(
                studentId: studentId,
                onComplete: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => MainNavigation(studentId: studentId),
                    ),
                  );
                },
              ),
            ),
          );
        }
      } else {
        // Login failed - show specific error message
        final errorMessage = loginResult['message'] ?? 'Login failed';
        final lockedStudent = loginResult['lockedToStudent'];

        if (lockedStudent != null) {
          // Device is locked to another student
          _showErrorDialog(
            title: '🔒 Device Locked',
            message:
                'This device is already registered to Student ID: $lockedStudent\n\n'
                'Each device can only be used by one student.\n\n'
                'To use this device:\n'
                '1. Contact your administrator\n'
                '2. Ask them to reset device bindings\n'
                '3. Or use a different device',
          );
        } else {
          // General error
          _showSnackBar(errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An error occurred. Please try again.');
      }
      _logger.error('Login error', e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show error dialog with detailed message
  void _showErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Check if student profile is complete
  Future<bool> _checkProfileComplete(String studentId) async {
    try {
      final response = await HttpService().get(
        url: '${ApiConstants.apiBase}/students/$studentId/profile',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isProfileComplete'] == true;
      }
      // If error, assume profile is complete to not block login
      return true;
    } catch (e) {
      _logger.error('Error checking profile completion', e);
      // On error, assume complete to not block login
      return true;
    }
  }

  /// 🎯 NEW: Sync attendance state from backend after login
  Future<void> _syncAttendanceState(String studentId) async {
    try {
      final logger = LoggerService();
      logger.info('🔄 Syncing attendance state from backend...');

      final beaconService = BeaconService();
      final syncResult = await beaconService.syncStateFromBackend(studentId);

      if (syncResult['success'] == true) {
        final syncedCount = syncResult['synced'] ?? 0;
        final totalRecords = syncResult['total'] ?? 0;

        logger.info(
            '✅ State sync complete: $syncedCount/$totalRecords records synced');

        if (syncedCount > 0 && mounted) {
          _showSnackBar(
              '✅ Restored $syncedCount attendance record${syncedCount > 1 ? 's' : ''}');
        }
      } else {
        logger.warning('⚠️ State sync failed: ${syncResult['error']}');
        // Don't block login if sync fails - just log the error
      }
    } catch (e) {
      final logger = LoggerService();
      logger.error('❌ State sync error', e);
      // Don't block login if sync fails
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

      // Start centralized beacon scanning (singleton) with persistent notification
      final storage = await SharedPreferences.getInstance();
      final studentId = storage.getString(AppConstants.studentIdKey);
      if (studentId != null) {
        await BeaconService().startScanning(studentId: studentId);
        logger.info('✅ BeaconService scanning started after login');
      } else {
        logger.warning(
            '⚠️ No studentId in storage after login; skipping scan start');
      }

      // Show success message to user
      if (mounted) {
        _showSnackBar('✅ Auto-attendance enabled');
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
