import 'package:flutter/material.dart';
import '../../../../core/utils/schedule_utils.dart';
import './home_screen_state.dart';
import '../../../auth/screens/login_screen.dart';
import '../../../../core/services/continuous_beacon_service.dart';
import '../../../../core/services/beacon_service.dart';

/// 🛠️ HomeScreen Helpers Module
///
/// Utility functions and helper methods for the HomeScreen.
/// Provides common operations used across different modules.
///
/// Features:
/// - Snackbar display
/// - Distance calculation
/// - Cooldown info loading
/// - Logout handling
/// - RSSI-to-distance conversion
class HomeScreenHelpers {
  final HomeScreenState state;
  final BuildContext context;
  final String studentId;

  HomeScreenHelpers({
    required this.state,
    required this.context,
    required this.studentId,
  });

  /// Resolve a messenger for snackbar display, guarding against disposed context
  ScaffoldMessengerState? _resolveMessenger() {
    try {
      final element = context as Element;
      if (!element.mounted) {
        state.logger.warning('⚠️ Skipping snackbar - context unmounted');
        return null;
      }
      return ScaffoldMessenger.maybeOf(context);
    } catch (e) {
      state.logger.error('⚠️ Unable to resolve ScaffoldMessenger', e);
      return null;
    }
  }

  /// Show a snackbar message when the messenger is available
  void showSnackBar(String message) {
    final messenger = _resolveMessenger();
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Calculate distance from RSSI and TX power
  ///
  /// Uses a logarithmic model to estimate distance in meters
  double calculateDistance(int rssi, int txPower) {
    if (rssi == 0) return -1.0;
    final ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return 0.5; // Very close
    } else {
      return 0.89976 * (ratio * ratio * ratio * ratio) +
          7.7095 * (ratio * ratio * ratio) +
          0.111 * (ratio * ratio);
    }
  }

  /// Load cooldown info with schedule awareness
  ///
  /// Fetches cooldown information from beacon service and enhances it
  /// with schedule-aware data (next class times, etc.)
  void loadCooldownInfo() async {
    // Don't show cooldown card during confirmation period
    if (state.isAwaitingConfirmation) {
      state.logger.info(
          '⏸️ Skipping cooldown info load - user is in confirmation period');
      return;
    }

    // Don't override cancelled state with cooldown check
    if (state.beaconStatusType == BeaconStatusType.cancelled) {
      state.logger.info(
          '⏸️ Skipping cooldown info load - user has cancelled attendance');
      return;
    }

    final cooldown = state.beaconService.getCooldownInfo();
    if (cooldown != null) {
      // Get basic cooldown data from BeaconService
      final lastCheckInTime = DateTime.parse(cooldown['lastCheckInTime']);
      final now = DateTime.now();

      // Enhance with schedule-aware information
      final scheduleInfo = ScheduleUtils.getScheduleAwareCooldownInfo(
        classStartTime: lastCheckInTime,
        now: now,
      );

      // Merge schedule info with basic cooldown info
      final enhancedInfo = {
        ...cooldown,
        ...scheduleInfo,
      };

      state.update((state) {
        state.cooldownInfo = enhancedInfo;
        state.currentClassId = cooldown['classId'];
      });

      state.logger.info('🎓 Cooldown info updated with schedule awareness');
    } else {
      // Check if there's a cancelled state that needs schedule info
      if (state.beaconStatusType == BeaconStatusType.cancelled) {
        try {
          final result = await state.httpService.getTodayAttendance(
            studentId: studentId,
          );

          if (result['success'] == true) {
            final attendance = result['attendance'] as List;

            // Look for cancelled attendance
            for (var record in attendance) {
              if (record['status'] == 'cancelled') {
                final cancelledTime = DateTime.parse(record['checkInTime']);
                final now = DateTime.now();

                // Add schedule-aware cancelled info
                final cancelledInfo =
                    ScheduleUtils.getScheduleAwareCancelledInfo(
                  cancelledTime: cancelledTime,
                  now: now,
                );

                state.update((state) {
                  state.cooldownInfo = cancelledInfo;
                  state.currentClassId = record['classId'];
                });

                state.logger
                    .info('🎓 Cancelled info updated with schedule awareness');
                break;
              }
            }
          }
        } catch (e) {
          state.logger.error('❌ Error loading cancelled state info', e);
        }
      } else {
        state.logger.info('ℹ️ No cooldown or cancelled state to display');
      }
    }
  }

  /// Handle logout
  ///
  /// Stops beacon scanning and navigates to login screen
  Future<void> handleLogout() async {
    try {
      // Stop centralized beacon scanning and foreground notification
      try {
        BeaconService().stopRanging();
        state.logger.info('🛑 BeaconService scanning stopped before logout');
      } catch (_) {}
      // Stop legacy continuous service if running (no-op if not started)
      final continuousService = ContinuousBeaconService();
      await continuousService.stopContinuousScanning();
      state.logger.info('🛑 Continuous scanning stopped before logout');

      // Then logout
      final success = await state.authService.logout();

      final messenger = _resolveMessenger();
      final element = context as Element;

      if (success && element.mounted) {
        Navigator.of(element).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Logout failed. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      final messenger = _resolveMessenger();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('An error occurred during logout.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      state.logger.error('Logout error', e);
    }
  }

  /// Format remaining seconds as MM:SS
  String formatRemainingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Check if beacon status indicates an active attendance process
  bool isAttendanceProcessActive() {
    return {
      BeaconStatusType.provisional,
      BeaconStatusType.confirming,
      BeaconStatusType.confirmed,
      BeaconStatusType.success,
      BeaconStatusType.cooldown,
      BeaconStatusType.cancelled,
    }.contains(state.beaconStatusType);
  }
}
