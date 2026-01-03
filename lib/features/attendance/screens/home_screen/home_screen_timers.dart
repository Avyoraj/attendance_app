import 'dart:async';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/log_config.dart';
import '../../../../core/services/confirmation_timer_service.dart';
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
  void startConfirmationTimer() {
    // Clear cooldown info when entering confirmation period
    state.update((state) {
      state.cooldownInfo = null;
    });
    final persistent = ConfirmationTimerService();

    // Establish or resume persistent timer with override-aware behavior
    final persistedRemaining =
        persistent.hasActiveTimer() ? persistent.getRemainingSeconds() : 0;
    final isResumeRequest = state.remainingSeconds > 0; // from backend sync

    if (!persistent.hasActiveTimer()) {
      // No persisted timer yet: start with resume value if provided, else full duration
      final startSeconds =
          isResumeRequest ? state.remainingSeconds : AppConstants.secondCheckDelay.inSeconds;
      // Fire-and-forget persistence (non-blocking)
      persistent.start(Duration(seconds: startSeconds));
      state.update((s) {
        s.remainingSeconds = startSeconds;
        s.isAwaitingConfirmation = true;
      });
    } else {
      // A persisted timer exists. If this call is a resume request with a tighter
      // remaining value (e.g., 126s vs 180s), override the persisted timer.
      if (isResumeRequest && persistedRemaining > state.remainingSeconds) {
        // Override to honor backend remaining time
        persistent.start(Duration(seconds: state.remainingSeconds));
        state.update((s) {
          s.remainingSeconds = state.remainingSeconds;
          s.isAwaitingConfirmation = true;
        });
        state.logger.debug(
            '🔧 TIMER OVERRIDE: persisted=${persistedRemaining}s ➜ using resumed ${state.remainingSeconds}s');
      } else {
        // Keep persisted timer and reflect remaining in UI
        state.update((s) {
          s.remainingSeconds = persistedRemaining;
          s.isAwaitingConfirmation = true;
        });
        if (isResumeRequest) {
          state.logger.debug(
              '⏸️ TIMER KEEP: persisted=${persistedRemaining}s (resume requested ${state.remainingSeconds}s not tighter)');
        }
      }
    }

  state.logger.debug(
    '🔍 TIMER DEBUG (persistent): started/resumed with ${state.remainingSeconds}s remaining');

    // UI tick timer pulls remaining time from persistent storage each second
    state.confirmationTimer?.cancel();
    state.confirmationTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = persistent.getRemainingSeconds();
      if (remaining > 0) {
        state.update((s) {
          s.remainingSeconds = remaining;
          s.logger.debugThrottled(
            'confirmation-timer',
            '⏱️ Persistent tick: ${s.remainingSeconds}s remaining',
            interval: LogConfig.timerInterval(),
          );
        }, immediate: true);  // Use immediate for smooth countdown display
      } else {
        timer.cancel();
        
        // IMPORTANT: When timer reaches zero, show "Confirming..." state
        // DO NOT show cancelled - wait for AttendanceConfirmationService callback
        state.update((s) {
          s.remainingSeconds = 0;
          // Keep isAwaitingConfirmation true briefly while service confirms
          // This prevents showing "cancelled" prematurely
          s.beaconStatusType = BeaconStatusType.confirming;
          s.beaconStatus = '🔄 Verifying attendance...\nPlease wait.';
        }, immediate: true);
        
        state.logger.info(
            '🔔 Timer reached zero - showing "Confirming..." while awaiting service result');
        
        // Clear persistent store
        persistent.clear();
        
        // Set a safety timeout: if no callback received within 10 seconds,
        // sync with backend to get actual state
        Future.delayed(const Duration(seconds: 10), () {
          // Only re-sync if still in "confirming" state (no callback received)
          if (state.beaconStatusType == BeaconStatusType.confirming) {
            state.logger.warning('⚠️ No confirmation callback after 10s - re-syncing with backend');
            // Trigger a manual refresh to get actual state from backend
            state.update((s) {
              s.beaconStatus = '🔄 Syncing with server...';
            });
            // The sync will be triggered by the user's next refresh or we can trigger it here
            // For now, just reset to scanning if still stuck
            Future.delayed(const Duration(seconds: 5), () {
              if (state.beaconStatusType == BeaconStatusType.confirming) {
                state.logger.warning('⚠️ Still stuck in confirming state - resetting');
                state.update((s) {
                  s.beaconStatusType = BeaconStatusType.scanning;
                  s.beaconStatus = '📡 Scanning for classroom beacon...';
                  s.isAwaitingConfirmation = false;
                  s.isCheckingIn = false;
                }, immediate: true);
              }
            });
          }
        });
      }
    });
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
        state.logger.debugThrottled(
          'cooldown-refresh',
          '🔄 Cooldown refresh timer tick',
          interval: const Duration(minutes: 1),
        );
      },
    );
  }

  /// Cancel confirmation timer
  void cancelConfirmationTimer() {
    // Cancel immediately to stop any countdown
    state.confirmationTimer?.cancel();
    state.update((state) {
      state.confirmationTimer = null;
    }, immediate: true);  // Use immediate to ensure UI updates right away
    // Also clear persistent timer state
    ConfirmationTimerService().clear();
    state.logger.debug('❌ Confirmation timer cancelled');
  }

  /// Cancel cooldown refresh timer
  void cancelCooldownRefreshTimer() {
    state.update((state) {
      state.cooldownRefreshTimer?.cancel();
      state.cooldownRefreshTimer = null;
    });
    state.logger.debug('❌ Cooldown refresh timer cancelled');
  }

  /// Cancel all timers
  void cancelAllTimers() {
    cancelConfirmationTimer();
    cancelCooldownRefreshTimer();
    state.logger.debug('❌ All timers cancelled');
  }

  /// Check if confirmation timer is active
  bool isConfirmationTimerActive() {
    return state.confirmationTimer != null && state.confirmationTimer!.isActive;
  }

  /// Check if cooldown refresh timer is active
  bool isCooldownRefreshTimerActive() {
    return state.cooldownRefreshTimer != null &&
        state.cooldownRefreshTimer!.isActive;
  }

  /// Get formatted time remaining
  String getFormattedTimeRemaining() {
    final minutes = state.remainingSeconds ~/ 60;
    final seconds = state.remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
