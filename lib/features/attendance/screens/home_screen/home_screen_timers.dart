import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import './home_screen_state.dart';
import './home_screen_sync.dart';

/// ⏱️ HomeScreen Timers Module
/// 
/// Manages all timer-related functionality for the HomeScreen.
/// Handles countdown timers and periodic refresh timers.
/// 
/// Features:
/// - Confirmation countdown timer (3 minutes)
/// - Cooldown refresh timer (1 minute intervals)
/// - Timer lifecycle management
/// - Resume support for app restarts
class HomeScreenTimers {
  final HomeScreenState state;
  final HomeScreenSync sync;
  
  HomeScreenTimers({
    required this.state,
    required this.sync,
  });
  
  /// Start the confirmation countdown timer
  /// 
  /// This timer counts down from 3 minutes (or resumed time) to 0.
  /// When it reaches 0, it triggers the final confirmation check.
  void startConfirmationTimer(Function(VoidCallback) setStateCallback) {
    // Clear cooldown info when entering confirmation period
    setStateCallback(() {
      state.cooldownInfo = null;
    });
    
    // Only set remainingSeconds if it's not already set (for resume scenarios)
    if (state.remainingSeconds <= 0) {
      // New check-in: use full duration from constants
      setStateCallback(() {
        state.remainingSeconds = AppConstants.secondCheckDelay.inSeconds;
        state.isAwaitingConfirmation = true;
      });
    } else {
      // Resume from backend: keep existing remainingSeconds, just set flag
      setStateCallback(() {
        state.isAwaitingConfirmation = true;
      });
    }
    
    print('🔍 TIMER DEBUG: Started - remaining=${state.remainingSeconds} seconds, awaiting=${state.isAwaitingConfirmation}');
    
    state.confirmationTimer?.cancel();
    state.confirmationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (state.remainingSeconds > 0) {
          setStateCallback(() {
            state.remainingSeconds--;
            print('⏱️ Timer tick: ${state.remainingSeconds} seconds remaining (awaiting: ${state.isAwaitingConfirmation})');
          });
        } else {
          // Timer expired - time to confirm attendance!
          timer.cancel();
          print('🔔 Timer expired! Checking final RSSI for confirmation...');
          sync.performFinalConfirmationCheck(setStateCallback);
        }
      },
    );
  }
  
  /// Start the cooldown refresh timer
  /// 
  /// This timer refreshes cooldown info every minute to keep
  /// the countdown display up-to-date.
  void startCooldownRefreshTimer() {
    state.cooldownRefreshTimer?.cancel();
    state.cooldownRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) {
        // This will be handled by helpers.loadCooldownInfo
        // through the sync module
        print('🔄 Cooldown refresh timer tick');
      },
    );
  }
  
  /// Cancel confirmation timer
  void cancelConfirmationTimer() {
    state.confirmationTimer?.cancel();
    state.confirmationTimer = null;
    print('❌ Confirmation timer cancelled');
  }
  
  /// Cancel cooldown refresh timer
  void cancelCooldownRefreshTimer() {
    state.cooldownRefreshTimer?.cancel();
    state.cooldownRefreshTimer = null;
    print('❌ Cooldown refresh timer cancelled');
  }
  
  /// Cancel all timers
  void cancelAllTimers() {
    cancelConfirmationTimer();
    cancelCooldownRefreshTimer();
    print('❌ All timers cancelled');
  }
  
  /// Check if confirmation timer is active
  bool isConfirmationTimerActive() {
    return state.confirmationTimer != null && state.confirmationTimer!.isActive;
  }
  
  /// Check if cooldown refresh timer is active
  bool isCooldownRefreshTimerActive() {
    return state.cooldownRefreshTimer != null && state.cooldownRefreshTimer!.isActive;
  }
  
  /// Get formatted time remaining
  String getFormattedTimeRemaining() {
    final minutes = state.remainingSeconds ~/ 60;
    final seconds = state.remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
