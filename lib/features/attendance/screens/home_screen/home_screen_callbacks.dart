import '../../../../core/constants/app_constants.dart';
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

  HomeScreenCallbacks({
    required this.state,
    required this.timers,
    required this.helpers,
  });

  /// Setup the main callback that gets invoked on beacon state changes
  void setupBeaconStateCallback() {
    state.beaconService.setOnAttendanceStateChanged(
      (beaconState, studentId, classId) {
        // Always update current class ID when state changes
        state.update((state) {
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
          case 'queued':
            _handleQueuedState(classId);
            break;
          case 'no_session':
            _handleNoSessionState(classId);
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

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.provisional;
      state.beaconStatus =
          '⏳ Check-in recorded for Class $classId!\nStay in class for 3 minutes to confirm attendance.';
      state.isCheckingIn = false; // Stop loading
    });

    timers.startConfirmationTimer();
    timers.startCooldownRefreshTimer();
    helpers.showSnackBar('✅ Provisional check-in successful! Stay for 3 min.');

    state.logger.debug('✅ Provisional attendance recorded for Class $classId');
    state.logger.debug('🔒 Status locked during confirmation period');
    state.logger.debug('📍 Current status: ${state.beaconStatus}');
  }

  /// Handle confirmed state (attendance confirmed successfully)
  void _handleConfirmedState(String classId) {
    state.logger.info('✅ Confirmed state: $classId');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.confirmed;
      state.beaconStatus =
          '✅ Attendance CONFIRMED for Class $classId!\nYou may now leave if needed.';
      state.isAwaitingConfirmation = false;
      state.confirmationTimer?.cancel();
      state.isCheckingIn = false;
    });

    helpers.loadCooldownInfo();
    helpers.showSnackBar('🎉 Attendance confirmed! You\'re marked present.');

    state.logger.debug('✅ Attendance confirmed for Class $classId');
    state.logger.debug('✅ Confirmation complete - status remains locked');
  }

  /// Handle success state (5-second delay after confirmation)
  void _handleSuccessState(String classId) {
    state.logger.info('🎉 Success state: $classId');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.success;
      state.beaconStatus =
          '✅ Attendance Recorded for Class $classId\nYou\'re all set! Enjoy your class.';
    });

    helpers.showSnackBar('✅ Attendance confirmed. Enjoy your class!');
    state.logger
        .debug('✅ Success state - attendance recorded for Class $classId');
  }

  /// Handle cooldown state (already checked in, within 15-minute cooldown)
  void _handleCooldownState(String classId) {
    // Don't override cancelled state with cooldown
    if (state.beaconStatusType == BeaconStatusType.cancelled) {
      state.logger.debug('🔒 Cooldown blocked: User has cancelled attendance');
      return;
    }

    state.logger.info('⏳ Cooldown state: $classId');

    helpers.loadCooldownInfo();

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.cooldown;
      final cooldown = state.beaconService.getCooldownInfo();
      final minutesRemaining = cooldown?['minutesRemaining'] ?? 15;
      state.beaconStatus =
          '✅ You\'re Already Checked In for Class $classId\nEnjoy your class! Next check-in available in $minutesRemaining minutes.';
    });

    helpers.showSnackBar('✅ You\'re already checked in. Enjoy your class!');
    state.logger
        .debug('⏳ Cooldown state - already checked in for Class $classId');
  }

  /// Handle cancelled state (user left during waiting period)
  void _handleCancelledState(String classId) {
    state.logger.info('❌ Cancelled state: $classId');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.cancelled;
      state.beaconStatus =
          '❌ Attendance Cancelled!\nYou left the classroom during the confirmation period.\n\nStay in class for the full ${AppConstants.secondCheckDelay.inSeconds} seconds next time.';
      state.isAwaitingConfirmation = false;
      state.confirmationTimer?.cancel();
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    });

    helpers.showSnackBar(
        '❌ Attendance cancelled - you left the classroom too early!');
    state.logger.warning(
        '🚫 Attendance cancelled for Class $classId (left during waiting period)');
  }

  /// Handle queued state (confirmation saved for offline sync)
  void _handleQueuedState(String classId) {
    state.logger.info('📤 Queued state: $classId');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.confirming;
      state.beaconStatus =
          '📤 Attendance queued for Class $classId!\nWill sync automatically when you\'re back online.';
      state.isAwaitingConfirmation = false;
      state.confirmationTimer?.cancel();
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    });

    helpers.showSnackBar(
        '📤 No network - attendance queued. Will sync when online.');
    state.logger.info('📤 Attendance queued for offline sync: $classId');
  }

  /// Handle device mismatch (account linked to another device)
  void _handleDeviceMismatchState() {
    state.logger.warning('🔒 Device mismatch detected');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.deviceLocked;
      state.beaconStatus =
          '🔒 Device Locked: This account is linked to another device.';
      state.isCheckingIn = false;
    });

    helpers.showSnackBar(
        '🔒 This account is linked to another device. Please contact admin.');
    state.logger.warning('🔒 Device mismatch detected');
  }

  /// Handle failed state (check-in failed)
  void _handleFailedState(String classId) {
    // Don't override if already checked in successfully
    if (state.isAwaitingConfirmation ||
        {
          BeaconStatusType.provisional,
          BeaconStatusType.confirmed,
          BeaconStatusType.success,
        }.contains(state.beaconStatusType)) {
      state.logger
          .debug('🔒 Ignoring failed state - already checked in successfully');
      return;
    }

    state.logger.error('❌ Failed state: $classId');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.failed;
      state.beaconStatus =
          '❌ Check-in failed. Please move closer to the beacon.';
      state.isCheckingIn = false;
    });

    helpers
        .showSnackBar('⚠️ Check-in failed. Try moving closer to the beacon.');
    state.logger.error('❌ Check-in failed for Class $classId');
  }

  /// Handle no session state (beacon detected but no active class session)
  void _handleNoSessionState(String classId) {
    state.logger.info('📭 No session state: $classId');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.noSession;
      state.beaconStatus =
          '📭 No Active Class Session\nBeacon detected but no class is currently in session.\nWait for your teacher to start the session.';
      state.isCheckingIn = false;
    });

    helpers.showSnackBar('📭 No active class session. Wait for teacher to start.');
    state.logger.info('📭 No active session for beacon $classId');
  }

  /// Handle default/scanning state
  void _handleDefaultState() {
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.scanning;
      state.beaconStatus = 'Scanning for classroom beacon...';
    });
  }
}
