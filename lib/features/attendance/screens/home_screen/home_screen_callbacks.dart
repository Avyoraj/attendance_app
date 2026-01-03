import '../../../../core/constants/app_constants.dart';
import './home_screen_state.dart';
import './home_screen_timers.dart';
import './home_screen_helpers.dart';
import './home_screen_sync.dart';

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
/// - State guards to prevent conflicting updates
/// - Auto-refresh of summary data on state changes
class HomeScreenCallbacks {
  final HomeScreenState state;
  final HomeScreenTimers timers;
  final HomeScreenHelpers helpers;
  HomeScreenSync? sync; // Optional - set after construction to avoid circular deps
  
  /// Track last state change time to prevent rapid conflicting updates
  DateTime? _lastStateChangeTime;
  String? _lastStateType;

  HomeScreenCallbacks({
    required this.state,
    required this.timers,
    required this.helpers,
  });

  /// Check if we should accept this state change (debounce rapid changes)
  bool _shouldAcceptStateChange(String newState) {
    final now = DateTime.now();
    
    // Always accept if no previous state
    if (_lastStateChangeTime == null || _lastStateType == null) {
      _lastStateChangeTime = now;
      _lastStateType = newState;
      return true;
    }
    
    final timeSinceLastChange = now.difference(_lastStateChangeTime!).inMilliseconds;
    
    // If same state, always accept (refresh)
    if (newState == _lastStateType) {
      _lastStateChangeTime = now;
      return true;
    }
    
    // Define state priority (higher = more important, can override lower)
    final statePriority = {
      'scanning': 0,
      'no_session': 1,
      'provisional': 5,
      'confirming': 6,
      'confirmed': 10,
      'success': 10,
      'cooldown': 9,
      'cancelled': 8,
      'failed': 8,
      'device_mismatch': 8,
      'queued': 7,
    };
    
    final oldPriority = statePriority[_lastStateType] ?? 0;
    final newPriority = statePriority[newState] ?? 0;
    
    // Only accept if new state has higher/equal priority OR enough time has passed
    if (newPriority >= oldPriority || timeSinceLastChange > 500) {
      _lastStateChangeTime = now;
      _lastStateType = newState;
      return true;
    }
    
    state.logger.debug('🛡️ State change blocked: $newState (current: $_lastStateType, priority: $newPriority < $oldPriority)');
    return false;
  }

  /// Setup the main callback that gets invoked on beacon state changes
  void setupBeaconStateCallback() {
    state.beaconService.setOnAttendanceStateChanged(
      (beaconState, studentId, classId) {
        // Check if we should accept this state change
        if (!_shouldAcceptStateChange(beaconState)) {
          return;
        }
        
        // Always update current class ID when state changes
        state.update((state) {
          state.currentClassId = classId;
        }, immediate: true);  // Use immediate for class ID updates

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
    
    final currentTime = _formatCurrentTime();
    final todayDate = _formatTodayDate();
    final formattedClassName = _formatClassName(classId);

    // Use immediate update for critical state transition
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.provisional;
      state.beaconStatus =
          '⏳ Check-in recorded for Class $formattedClassName!\nStay in class for 3 minutes to confirm attendance.';
      state.isCheckingIn = false; // Stop loading
      state.isAwaitingConfirmation = true; // Mark that we're waiting
      
      // IMMEDIATELY update today's attendance status for widgets
      // Don't wait for backend fetch - show it right away
      state.todayStatus = 'provisional';
      state.todayClassName = formattedClassName;
      state.todayCheckInTime = currentTime;
      
      // Also update recent history immediately with today's provisional entry
      // Check if today's entry already exists, if so update it, else add it
      final existingIndex = state.recentHistory.indexWhere((entry) {
        final entryDate = entry['date'] ?? entry['check_in_time']?.toString().split('T')[0];
        return entryDate == todayDate;
      });
      
      final newEntry = {
        'class_id': classId,
        'className': formattedClassName,
        'status': 'provisional',
        'check_in_time': currentTime,
        'date': todayDate,
      };
      
      if (existingIndex >= 0) {
        // Update existing entry
        state.recentHistory[existingIndex] = newEntry;
      } else {
        // Add new entry at the beginning
        state.recentHistory = [newEntry, ...state.recentHistory];
      }
    }, immediate: true);

    timers.startConfirmationTimer();
    timers.startCooldownRefreshTimer();
    helpers.showSnackBar('✅ Provisional check-in successful! Stay for 3 min.');

    // NOTE: Do NOT call _refreshSummaryData() here!
    // The local state is already set correctly above.
    // Backend fetch would overwrite our local state with stale/empty data.

    state.logger.debug('✅ Provisional attendance recorded for Class $classId');
    state.logger.debug('🔒 Status locked during confirmation period');
    state.logger.debug('📍 Current status: ${state.beaconStatus}');
  }

  /// Handle confirmed state (attendance confirmed successfully)
  void _handleConfirmedState(String classId) {
    state.logger.info('✅ Confirmed state: $classId');

    // IMPORTANT: Cancel the UI countdown timer FIRST (before state update)
    timers.cancelConfirmationTimer();
    
    final todayDate = _formatTodayDate();
    final formattedClassName = _formatClassName(classId);

    // Use immediate update for critical state transition
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.confirmed;
      state.beaconStatus =
          '✅ Attendance CONFIRMED for Class $formattedClassName!\nYou may now leave if needed.';
      state.isAwaitingConfirmation = false;
      state.isCheckingIn = false;
      state.remainingSeconds = 0;
      
      // IMMEDIATELY update today's status for widgets
      state.todayStatus = 'confirmed';
      state.todayClassName = formattedClassName;
      
      // Update recent history to show confirmed status
      final existingIndex = state.recentHistory.indexWhere((entry) {
        final entryDate = entry['date'] ?? entry['check_in_time']?.toString().split('T')[0];
        return entryDate == todayDate;
      });
      
      if (existingIndex >= 0) {
        // Update existing entry to confirmed
        state.recentHistory[existingIndex]['status'] = 'confirmed';
      }
    }, immediate: true);

    helpers.loadCooldownInfo();
    helpers.showSnackBar('🎉 Attendance confirmed! You\'re marked present.');

    // Refresh summary data to show confirmed attendance
    _refreshSummaryData();

    state.logger.debug('✅ Attendance confirmed for Class $formattedClassName');
    state.logger.debug('✅ Confirmation complete - status remains locked');
  }

  /// Handle success state (5-second delay after confirmation)
  void _handleSuccessState(String classId) {
    state.logger.info('🎉 Success state: $classId');

    // Ensure timer is cancelled
    timers.cancelConfirmationTimer();

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.success;
      state.beaconStatus =
          '✅ Attendance Recorded for Class $classId\nYou\'re all set! Enjoy your class.';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
    }, immediate: true);

    helpers.showSnackBar('✅ Attendance confirmed. Enjoy your class!');
    
    // Final refresh to ensure widgets show correct data
    _refreshSummaryData();
    
    state.logger
        .debug('✅ Success state - attendance recorded for Class $classId');
  }
  
  /// Format current time as HH:MM AM/PM
  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
  
  /// Format today's date as YYYY-MM-DD
  String _formatTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Format class name (e.g., "101" -> "CS101")
  String _formatClassName(String classId) {
    // If already has letters prefix, return as-is
    if (RegExp(r'^[A-Za-z]').hasMatch(classId)) {
      return classId.toUpperCase();
    }
    // Otherwise, add "CS" prefix
    return 'CS$classId';
  }
  
  /// Refresh summary data from backend (fire and forget)
  void _refreshSummaryData() {
    if (sync != null) {
      // Fire and forget - don't await
      sync!.fetchStudentSummary();
    }
  }

  /// Handle cooldown state (already checked in, within 15-minute cooldown)
  void _handleCooldownState(String classId) {
    // Don't override cancelled or confirmed states with cooldown
    if (state.beaconStatusType == BeaconStatusType.cancelled ||
        state.beaconStatusType == BeaconStatusType.confirmed ||
        state.beaconStatusType == BeaconStatusType.success) {
      state.logger.debug('🔒 Cooldown blocked: User already has terminal state (${state.beaconStatusType})');
      return;
    }

    state.logger.info('⏳ Cooldown state: $classId');

    // Cancel any running timer when entering cooldown
    timers.cancelConfirmationTimer();
    
    helpers.loadCooldownInfo();

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.cooldown;
      final cooldown = state.beaconService.getCooldownInfo();
      final minutesRemaining = cooldown?['minutesRemaining'] ?? 15;
      state.beaconStatus =
          '✅ You\'re Already Checked In for Class $classId\nEnjoy your class! Next check-in available in $minutesRemaining minutes.';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
    }, immediate: true);

    helpers.showSnackBar('✅ You\'re already checked in. Enjoy your class!');
    state.logger
        .debug('⏳ Cooldown state - already checked in for Class $classId');
  }

  /// Handle cancelled state (user left during waiting period)
  void _handleCancelledState(String classId) {
    state.logger.info('❌ Cancelled state: $classId');

    // IMPORTANT: Cancel the UI countdown timer
    timers.cancelConfirmationTimer();

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.cancelled;
      state.beaconStatus =
          '❌ Attendance Cancelled!\nYou left the classroom during the confirmation period.\n\nStay in class for the full ${AppConstants.secondCheckDelay.inSeconds} seconds next time.';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    }, immediate: true);

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
    }, immediate: true);

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
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
    }, immediate: true);

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
          BeaconStatusType.cooldown,
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
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
    }, immediate: true);

    helpers
        .showSnackBar('⚠️ Check-in failed. Try moving closer to the beacon.');
    state.logger.error('❌ Check-in failed for Class $classId');
  }

  /// Handle no session state (beacon detected but no active class session)
  void _handleNoSessionState(String classId) {
    // Don't override if already in a checked-in state
    if ({
      BeaconStatusType.provisional,
      BeaconStatusType.confirmed,
      BeaconStatusType.success,
      BeaconStatusType.cooldown,
    }.contains(state.beaconStatusType)) {
      state.logger.debug('🔒 Ignoring no_session - already checked in');
      return;
    }
    
    state.logger.info('📭 No session state: $classId');

    state.update((state) {
      state.beaconStatusType = BeaconStatusType.noSession;
      state.beaconStatus =
          '📭 No Active Class Session\nBeacon detected but no class is currently in session.\nWait for your teacher to start the session.';
      state.isCheckingIn = false;
    }, immediate: true);

    helpers.showSnackBar('📭 No active class session. Wait for teacher to start.');
    state.logger.info('📭 No active session for beacon $classId');
  }

  /// Handle default/scanning state
  void _handleDefaultState() {
    // Don't override if in a meaningful state
    if ({
      BeaconStatusType.provisional,
      BeaconStatusType.confirmed,
      BeaconStatusType.success,
      BeaconStatusType.cooldown,
      BeaconStatusType.cancelled,
      BeaconStatusType.failed,
    }.contains(state.beaconStatusType)) {
      state.logger.debug('🔒 Ignoring default state - already in meaningful state');
      return;
    }
    
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.scanning;
      state.beaconStatus = 'Scanning for classroom beacon...';
    });
  }
}
