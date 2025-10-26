import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/schedule_utils.dart';
import './home_screen_state.dart';
import './home_screen_timers.dart';
import './home_screen_helpers.dart';

/// 🎯 HomeScreen Callbacks Module
/// 
/// Handles all beacon state change callbacks.
/// This module processes state transitions from the BeaconService.
/// 
/// State Flow:
/// scanning → provisional → confirmed/cancelled → cooldown/success
/// 
/// Features:
/// - 8 state handlers (provisional, confirmed, success, cooldown, cancelled, device_mismatch, failed, default)
/// - State-specific UI updates
/// - Timer management
/// - Snackbar notifications
class HomeScreenCallbacks {
  final HomeScreenState state;
  final HomeScreenTimers timers;
  final HomeScreenHelpers helpers;
  final Function(VoidCallback) setStateCallback;
  
  HomeScreenCallbacks({
    required this.state,
    required this.timers,
    required this.helpers,
    required this.setStateCallback,
  });
  
  /// Setup the main callback that gets invoked on beacon state changes
  void setupBeaconStateCallback() {
    state.beaconService.setOnAttendanceStateChanged(
      (beaconState, studentId, classId) {
        // Always update current class ID when state changes
        setStateCallback(() {
          state.currentClassId = classId;
        });
        
        // Route to appropriate handler
        switch (beaconState) {
          case 'provisional':
            _handleProvisionalState(classId);
            break;
          case 'confirmed':
            _handleConfirmedState(classId);
            break;
          case 'success':
            _handleSuccessState(classId);
            break;
          case 'cooldown':
            _handleCooldownState(classId);
            break;
          case 'cancelled':
            _handleCancelledState(classId);
            break;
          case 'device_mismatch':
            _handleDeviceMismatchState();
            break;
          case 'failed':
            _handleFailedState(classId);
            break;
          default:
            _handleDefaultState();
        }
      },
    );
  }
  
  /// Handle provisional state (check-in recorded, waiting for confirmation)
  void _handleProvisionalState(String classId) {
    state.logger.info('⏳ Provisional state: $classId');
    
    setStateCallback(() {
      state.beaconStatus = '⏳ Check-in recorded for Class $classId!\nStay in class for 3 minutes to confirm attendance.';
      state.isCheckingIn = false; // Stop loading
    });
    
    timers.startConfirmationTimer(setStateCallback);
    timers.startCooldownRefreshTimer();
    helpers.showSnackBar('✅ Provisional check-in successful! Stay for 3 min.');
    
    print('✅ Provisional attendance recorded for Class $classId');
    print('🔒 Status locked during confirmation period');
    print('📍 Current status: ${state.beaconStatus}');
  }
  
  /// Handle confirmed state (attendance confirmed successfully)
  void _handleConfirmedState(String classId) {
    state.logger.info('✅ Confirmed state: $classId');
    
    setStateCallback(() {
      state.beaconStatus = '✅ Attendance CONFIRMED for Class $classId!\nYou may now leave if needed.';
      state.isAwaitingConfirmation = false;
      state.confirmationTimer?.cancel();
      state.isCheckingIn = false;
    });
    
    helpers.loadCooldownInfo(setStateCallback);
    helpers.showSnackBar('🎉 Attendance confirmed! You\'re marked present.');
    
    print('✅ Attendance confirmed for Class $classId');
    print('✅ Confirmation complete - status remains locked');
  }
  
  /// Handle success state (5-second delay after confirmation)
  void _handleSuccessState(String classId) {
    state.logger.info('🎉 Success state: $classId');
    
    setStateCallback(() {
      state.beaconStatus = '✅ Attendance Recorded for Class $classId\nYou\'re all set! Enjoy your class.';
    });
    
    helpers.showSnackBar('✅ Attendance confirmed. Enjoy your class!');
    print('✅ Success state - attendance recorded for Class $classId');
  }
  
  /// Handle cooldown state (already checked in, within 15-minute cooldown)
  void _handleCooldownState(String classId) {
    // Don't override cancelled state with cooldown
    if (state.beaconStatus.contains('Cancelled')) {
      print('🔒 Cooldown blocked: User has cancelled attendance');
      return;
    }
    
    state.logger.info('⏳ Cooldown state: $classId');
    
    helpers.loadCooldownInfo(setStateCallback);
    
    setStateCallback(() {
      final cooldown = state.beaconService.getCooldownInfo();
      final minutesRemaining = cooldown?['minutesRemaining'] ?? 15;
      state.beaconStatus = '✅ You\'re Already Checked In for Class $classId\nEnjoy your class! Next check-in available in $minutesRemaining minutes.';
    });
    
    helpers.showSnackBar('✅ You\'re already checked in. Enjoy your class!');
    print('⏳ Cooldown state - already checked in for Class $classId');
  }
  
  /// Handle cancelled state (user left during waiting period)
  void _handleCancelledState(String classId) {
    state.logger.info('❌ Cancelled state: $classId');
    
    setStateCallback(() {
      state.beaconStatus = '❌ Attendance Cancelled!\nYou left the classroom during the confirmation period.\n\nStay in class for the full ${AppConstants.secondCheckDelay.inSeconds} seconds next time.';
      state.isAwaitingConfirmation = false;
      state.confirmationTimer?.cancel();
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    });
    
    helpers.showSnackBar('❌ Attendance cancelled - you left the classroom too early!');
    print('🚫 Attendance cancelled for Class $classId (left during waiting period)');
  }
  
  /// Handle device mismatch (account linked to another device)
  void _handleDeviceMismatchState() {
    state.logger.warning('🔒 Device mismatch detected');
    
    setStateCallback(() {
      state.beaconStatus = '🔒 Device Locked: This account is linked to another device.';
      state.isCheckingIn = false;
    });
    
    helpers.showSnackBar('🔒 This account is linked to another device. Please contact admin.');
    print('🔒 Device mismatch detected');
  }
  
  /// Handle failed state (check-in failed)
  void _handleFailedState(String classId) {
    // Don't override if already checked in successfully
    if (state.isAwaitingConfirmation || 
        state.beaconStatus.contains('Check-in recorded') ||
        state.beaconStatus.contains('CONFIRMED')) {
      print('🔒 Ignoring failed state - already checked in successfully');
      return;
    }
    
    state.logger.error('❌ Failed state: $classId');
    
    setStateCallback(() {
      state.beaconStatus = '❌ Check-in failed. Please move closer to the beacon.';
      state.isCheckingIn = false;
    });
    
    helpers.showSnackBar('⚠️ Check-in failed. Try moving closer to the beacon.');
    print('❌ Check-in failed for Class $classId');
  }
  
  /// Handle default/scanning state
  void _handleDefaultState() {
    setStateCallback(() {
      state.beaconStatus = 'Scanning for classroom beacon...';
    });
  }
}
