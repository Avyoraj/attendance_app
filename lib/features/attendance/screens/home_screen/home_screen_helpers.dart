import 'package:flutter/material.dart';
import '../../../../core/utils/schedule_utils.dart';
import './home_screen_state.dart';
import '../../../auth/screens/login_screen.dart';
import '../../../../core/services/continuous_beacon_service.dart';

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
  
  /// Show a snackbar message
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
  void loadCooldownInfo(Function(VoidCallback) setStateCallback) async {
    // Don't show cooldown card during confirmation period
    if (state.isAwaitingConfirmation) {
      state.logger.info('⏸️ Skipping cooldown info load - user is in confirmation period');
      return;
    }
    
    // Don't override cancelled state with cooldown check
    if (state.beaconStatus.contains('Cancelled')) {
      state.logger.info('⏸️ Skipping cooldown info load - user has cancelled attendance');
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
      
      setStateCallback(() {
        state.cooldownInfo = enhancedInfo;
        state.currentClassId = cooldown['classId'];
      });
      
      state.logger.info('🎓 Cooldown info updated with schedule awareness');
    } else {
      // Check if there's a cancelled state that needs schedule info
      if (state.beaconStatus.contains('Cancelled')) {
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
                final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
                  cancelledTime: cancelledTime,
                  now: now,
                );
                
                setStateCallback(() {
                  state.cooldownInfo = cancelledInfo;
                  state.currentClassId = record['classId'];
                });
                
                state.logger.info('🎓 Cancelled info updated with schedule awareness');
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
      // Stop continuous beacon service first
      final continuousService = ContinuousBeaconService();
      await continuousService.stopContinuousScanning();
      state.logger.info('🛑 Continuous scanning stopped before logout');
      
      // Then logout
      final success = await state.authService.logout();
      
      if (success && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        showSnackBar('Logout failed. Please try again.');
      }
    } catch (e) {
      showSnackBar('An error occurred during logout.');
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
    return state.beaconStatus.contains('Check-in recorded') || 
           state.beaconStatus.contains('CONFIRMED') ||
           state.beaconStatus.contains('Attendance Recorded') ||
           state.beaconStatus.contains('Already Checked In') ||
           state.beaconStatus.contains('Cancelled') ||
           state.beaconStatus.contains('Processing') ||
           state.beaconStatus.contains('Recording your attendance');
  }
}
