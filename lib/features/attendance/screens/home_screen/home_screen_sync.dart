import 'package:flutter/foundation.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/services/local_database_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/schedule_utils.dart';
import '../../../../core/services/notification_service.dart';
import './home_screen_state.dart';

/// 🔄 HomeScreen Sync Module
///
/// Handles all backend synchronization and API calls.
/// Manages attendance confirmation, cancellation, and state restoration.
///
/// Features:
/// - Sync state from backend on startup
/// - Confirm provisional attendance
/// - Cancel provisional attendance
/// - Handle backend responses
/// - Error recovery and timeouts
class HomeScreenSync {
  final HomeScreenState state;
  final String studentId;

  HomeScreenSync({
    required this.state,
    required this.studentId,
  });

  /// Sync attendance state from backend on app startup
  ///
  /// Restores provisional/confirmed/cancelled state after app restart
  Future<void> syncStateOnStartup({
    required VoidCallback loadCooldownInfo,
    required VoidCallback startConfirmationTimer,
    required void Function(String message) showSnackBar,
  }) async {
    try {
      // Show loading state - use immediate for initial load
      state.update((state) {
        state.beaconStatusType = BeaconStatusType.confirming;
        state.beaconStatus = '🔄 Loading attendance state...';
        state.isCheckingIn = true;
      }, immediate: true);

      state.logger.info('🔄 Syncing attendance state from backend...');

      // Fetch student summary for enhanced HomeScreen (fire and forget)
      _fetchStudentSummary();

      // Add 5-second timeout to prevent infinite waiting
      final syncResult =
          await state.beaconService.syncStateFromBackend(studentId).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          state.logger
              .warning('⏱️ Sync timeout (5s) - falling back to scanning mode');
          return {'success': false, 'error': 'timeout'};
        },
      );

      if (syncResult['success'] == true) {
        final syncedCount = syncResult['synced'] ?? 0;

        if (syncedCount > 0) {
          state.logger
              .info('✅ Synced $syncedCount attendance records on startup');

          final attendance = syncResult['attendance'] as List?;
          if (attendance != null) {
            for (var record in attendance) {
              if (record['status'] == 'provisional') {
                await _handleProvisionalSync(
                  record,
                  startConfirmationTimer: startConfirmationTimer,
                  showSnackBar: showSnackBar,
                );
                break;
              } else if (record['status'] == 'confirmed') {
                await _handleConfirmedSync(record, loadCooldownInfo);
                break;
              } else if (record['status'] == 'cancelled') {
                await _handleCancelledSync(record);
                break;
              } else if (record['status'] == 'flagged') {
                // Handle PROXY FLAGGED status - don't restart timer
                await _handleFlaggedSync(record);
                break;
              }
            }
          }
        } else {
          state.logger.info('📭 No attendance records to sync');
          state.update((state) {
            state.beaconStatusType = BeaconStatusType.scanning;
            state.isCheckingIn = false;
            state.beaconStatus = '📡 Scanning for classroom beacon...';
          }, immediate: true);
        }
      } else {
        state.logger.warning('⚠️ State sync failed: ${syncResult['error']}');
        state.update((state) {
          state.beaconStatusType = BeaconStatusType.scanning;
          state.isCheckingIn = false;
          state.beaconStatus = '📡 Scanning for classroom beacon...';
        }, immediate: true);
      }
      // Surface offline pending actions to the user
      await _refreshPendingActionsBadge(showSnackBar: showSnackBar);
    } catch (e) {
      state.logger.error('❌ State sync error on startup', e);
      state.update((state) {
        state.beaconStatusType = BeaconStatusType.scanning;
        state.isCheckingIn = false;
        state.beaconStatus = '📡 Scanning for classroom beacon...';
      }, immediate: true);
    }
  }

  /// Handle provisional record from sync
  Future<void> _handleProvisionalSync(Map<String, dynamic> record,
      {required VoidCallback startConfirmationTimer,
      required void Function(String message) showSnackBar}) async {
    
    // DON'T restart timer if we're already in a terminal state (confirmed/success)
    // This prevents timer restart after confirmation when sync returns stale data
    if (state.beaconStatusType == BeaconStatusType.confirmed ||
        state.beaconStatusType == BeaconStatusType.success ||
        state.beaconStatusType == BeaconStatusType.cooldown) {
      state.logger.debug('🔒 Skipping provisional sync - already in terminal state (${state.beaconStatusType})');
      return;
    }
    
    final remainingSeconds = record['remainingSeconds'] as int? ?? 0;
    final classId = record['classId'] as String;

    if (remainingSeconds > 0) {
      state.logger.info(
          '⏱️ Resuming provisional countdown: $remainingSeconds seconds for Class $classId');

      // Use immediate for critical state restoration
      state.update((state) {
        state.beaconStatusType = BeaconStatusType.provisional;
        state.isAwaitingConfirmation = true;
        state.remainingSeconds = remainingSeconds;
        state.currentClassId = classId;
        state.beaconStatus =
            '⏳ Check-in recorded for Class $classId!\n(Resumed) Stay in class to confirm attendance.';
        state.isCheckingIn = false;
      }, immediate: true);

      startConfirmationTimer();
      showSnackBar(
          '⏱️ Resumed: ${(remainingSeconds ~/ 60)}:${(remainingSeconds % 60).toString().padLeft(2, '0')} remaining');

      state.logger.info('✅ UI countdown resumed successfully');
    }
  }

  /// Handle confirmed record from sync
  Future<void> _handleConfirmedSync(
    Map<String, dynamic> record,
    VoidCallback loadCooldownInfo,
  ) async {
    final classId = record['classId'] as String;
    state.logger.info('✅ Found confirmed attendance for Class $classId');

    // Use immediate for critical state restoration
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.cooldown;
      state.currentClassId = classId;
      state.beaconStatus =
          '✅ You\'re Already Checked In for Class $classId\nEnjoy your class!';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    }, immediate: true);

    loadCooldownInfo();
  }

  /// Handle cancelled record from sync
  Future<void> _handleCancelledSync(
    Map<String, dynamic> record,
  ) async {
    final classId = record['classId'] as String;
    final cancelledTime = DateTime.parse(record['checkInTime']);
    final reason = record['cancellation_reason'] ?? record['cancellationReason'];
    
    state.logger.info('❌ Found cancelled attendance for Class $classId. Reason: $reason');

    final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
      cancelledTime: cancelledTime,
      now: DateTime.now(),
    );

    // Use immediate for critical state restoration
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.cancelled;
      state.currentClassId = classId;
      state.beaconStatus =
          '❌ Attendance Cancelled for Class $classId\n${reason != null ? "Reason: $reason" : cancelledInfo['message']}';
      state.cooldownInfo = cancelledInfo;
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    }, immediate: true);

    state.logger.info('🎓 Cancelled state loaded with schedule awareness');
  }

  /// Handle FLAGGED record from sync (proxy detection)
  /// This prevents the timer from restarting when a student is flagged
  Future<void> _handleFlaggedSync(
    Map<String, dynamic> record,
  ) async {
    final classId = record['classId'] as String;
    final reason = record['cancellation_reason'] ?? record['cancellationReason'] ?? 'Proxy pattern detected';
    
    state.logger.warning('🚫 Found FLAGGED attendance for Class $classId. Reason: $reason');

    // Use immediate for critical state restoration
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.failed;
      state.currentClassId = classId;
      state.beaconStatus =
          '🚫 ATTENDANCE FLAGGED\n\n$reason\n\nPlease see your teacher for manual review.';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    }, immediate: true);

    // Show notification about flagged status
    await NotificationService.showErrorNotification(
      title: '🚫 Attendance Flagged',
      message: 'Please see your teacher for review.',
    );

    state.logger.info('🚨 Flagged state loaded - needs teacher review');
  }

  /// Perform final RSSI check and confirm/cancel attendance
  ///
  /// This is the critical check that happens when the countdown timer expires.
  /// It uses raw RSSI data to prevent false confirmations.
  Future<void> performFinalConfirmationCheck() async {
    state.logger
        .info('🔍 CONFIRMATION CHECK: Starting final RSSI verification...');

    // Get raw RSSI data (bypasses grace period cache)
    final rssiData = state.beaconService.getRawRssiData();
    final currentRssi = rssiData['rssi'] as int?;
    final rssiAge = rssiData['ageSeconds'] as int?;
    final isInGracePeriod = rssiData['isInGracePeriod'] as bool? ?? false;
    const threshold = AppConstants.confirmationRssiThreshold;

    state.logger.debug('📊 CONFIRMATION CHECK:');
    state.logger.debug(
        '   - Raw RSSI: $currentRssi dBm ${isInGracePeriod ? "(⚠️ IN GRACE PERIOD)" : ""}');
    state.logger.debug('   - RSSI Age: ${rssiAge ?? "N/A"}s');
    state.logger.debug('   - Threshold: $threshold dBm');
    state.logger.debug(
        '   - Required: RSSI >= $threshold AND age <= 3s AND not in grace period');

    // Check if RSSI is available
    if (currentRssi == null) {
      await _cancelAttendance('No beacon detected during confirmation.');
      return;
    }

    // Check if RSSI data is stale
    if (rssiAge != null && rssiAge > 3) {
      await _cancelAttendance('Beacon data is stale.');
      return;
    }

    // Check if in grace period (using cached values)
    if (isInGracePeriod) {
      await _cancelAttendance('Beacon signal too weak.');
      return;
    }

    // Perform strict RSSI threshold check
    if (currentRssi >= threshold) {
      // User is still in range - CONFIRM attendance
      await _confirmAttendance();
    } else {
      // User left the classroom - CANCEL attendance
      await _cancelAttendance(
          'You left the classroom during the confirmation period.');
    }
  }

  /// Confirm attendance on backend
  Future<void> _confirmAttendance() async {
    state.logger.info('✅ CONFIRMED: User is in range');

    // Use immediate for critical state change
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.confirmed;
      state.beaconStatus =
          '✅ Attendance CONFIRMED!\nYou stayed in the classroom.';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
    }, immediate: true);

    if (state.currentClassId != null) {
      try {
        // Include deviceId for backend enforcement
        final deviceId = await DeviceIdService().getDeviceId();
        final result = await state.httpService.confirmAttendance(
          studentId: studentId,
          classId: state.currentClassId!,
          deviceId: deviceId,
        );

        if (result['success'] == true) {
          state.logger.info('✅ Backend confirmed attendance');

          // Show success notification
          await NotificationService.showSuccessNotification(
            classId: state.currentClassId!,
            message:
                'Logged at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          );

          // Show cooldown notification
          await NotificationService.showCooldownNotification(
            classId: state.currentClassId!,
            classStartTime: DateTime.now(),
          );
        } else {
          // Check for specific error types
          final errorCode = result['error'] as String?;
          
          if (errorCode == 'PROXY_DETECTED') {
            // 🚨 PROXY DETECTED - Attendance blocked!
            final otherStudent = result['otherStudent'] ?? 'another student';
            state.logger.error('🚫 PROXY DETECTED: Blocked with $otherStudent');
            
            // Use immediate for critical error state
            state.update((state) {
              state.beaconStatusType = BeaconStatusType.failed;
              state.beaconStatus = 
                  '🚫 ATTENDANCE BLOCKED!\n\nSuspicious pattern detected with $otherStudent.\n\nPlease see your teacher.';
              state.isAwaitingConfirmation = false;
              state.remainingSeconds = 0;
              state.isCheckingIn = false;
            }, immediate: true);
            
            // Show blocking notification
            await NotificationService.showErrorNotification(
              title: '🚫 Attendance Blocked',
              message: 'Proxy pattern detected. Please see your teacher.',
            );
            
            return; // Don't queue for retry - this is intentional blocking
          } else if (errorCode == 'DEVICE_MISMATCH') {
            // Device binding violation
            state.logger.error('🔒 DEVICE MISMATCH: Wrong device');
            
            // Use immediate for critical error state
            state.update((state) {
              state.beaconStatusType = BeaconStatusType.failed;
              state.beaconStatus = 
                  '🔒 DEVICE MISMATCH!\n\nThis account is linked to another device.\n\nPlease use your registered device.';
              state.isAwaitingConfirmation = false;
              state.remainingSeconds = 0;
              state.isCheckingIn = false;
            }, immediate: true);
            
            return; // Don't queue for retry
          }
          
          // Other errors - queue for offline processing
          await LocalDatabaseService().savePendingAction(
            actionType: 'confirm',
            studentId: studentId,
            classId: state.currentClassId!,
          );
          state.logger.warning('Queued offline confirm action for later sync');
        }
      } catch (e, stackTrace) {
        state.logger.error('❌ Error confirming attendance', e, stackTrace);
        // Network/server failure: queue confirm for retry
        if (state.currentClassId != null) {
          await LocalDatabaseService().savePendingAction(
            actionType: 'confirm',
            studentId: studentId,
            classId: state.currentClassId!,
          );
          state.logger.info('📥 Confirm action queued for retry');
        }
      }
    }
  }

  /// Cancel attendance on backend
  Future<void> _cancelAttendance(
    String reason,
  ) async {
    state.logger.warning('❌ CANCELLED: $reason');

    final cancelledTime = DateTime.now();
    final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
      cancelledTime: cancelledTime,
      now: cancelledTime,
    );

    // Use immediate for critical state change
    state.update((state) {
      state.beaconStatusType = BeaconStatusType.cancelled;
      state.beaconStatus = '❌ Attendance Cancelled!\n$reason';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
      state.cooldownInfo = cancelledInfo;
    }, immediate: true);

    if (state.currentClassId != null) {
      await NotificationService.showCancelledNotification(
        classId: state.currentClassId!,
        cancelledTime: cancelledTime,
      );

      try {
        // Include deviceId for backend enforcement
        final deviceId = await DeviceIdService().getDeviceId();

        final result = await state.httpService.cancelProvisionalAttendance(
          studentId: studentId,
          classId: state.currentClassId!,
          deviceId: deviceId,
        );
        if (result['success'] != true) {
          await LocalDatabaseService().savePendingAction(
            actionType: 'cancel',
            studentId: studentId,
            classId: state.currentClassId!,
          );
          state.logger.warning('Queued offline cancel action for later sync');
        }
      } catch (e, stackTrace) {
        state.logger.warning('⚠️ Error cancelling on backend', e, stackTrace);
        // Queue cancel for retry
        await LocalDatabaseService().savePendingAction(
          actionType: 'cancel',
          studentId: studentId,
          classId: state.currentClassId!,
        );
        state.logger.info('📥 Cancel action queued for retry');
      }
    }
  }

  /// Fetch student summary data for enhanced HomeScreen
  /// 
  /// Fetches today's status, weekly stats, and recent history
  /// Updates state asynchronously without blocking main sync
  /// 
  /// Public method - can be called to refresh data after state changes
  Future<void> fetchStudentSummary() async {
    try {
      state.logger.info('📊 Fetching student summary for $studentId...');
      
      final result = await state.httpService.getStudentSummary(
        studentId: studentId,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          state.logger.warning('⏱️ Student summary fetch timeout');
          return {'success': false, 'error': 'timeout'};
        },
      );

      if (result['success'] == true) {
        state.updateSummary(result);
        state.logger.info('✅ Student summary loaded successfully');
      } else {
        state.logger.warning('⚠️ Failed to fetch student summary: ${result['error']}');
        state.markSummaryLoaded(); // Mark as loaded even on failure to stop skeleton
      }
    } catch (e) {
      state.logger.error('❌ Error fetching student summary', e);
      state.markSummaryLoaded(); // Mark as loaded even on error to stop skeleton
    }
  }
  
  // Keep private alias for internal use
  Future<void> _fetchStudentSummary() => fetchStudentSummary();

  /// Refresh pending action count and notify user if any are queued
  Future<void> _refreshPendingActionsBadge({
    required void Function(String message) showSnackBar,
  }) async {
    try {
      final previousCount = state.pendingActionCount;
      final pending = await LocalDatabaseService().getPendingActions();
      state.updatePendingActionsCount(pending.length);

      if (pending.isNotEmpty) {
        showSnackBar(
            '📤 ${pending.length} offline actions queued. Will auto-sync when online.');
      } else if (previousCount > 0) {
        // Transitioned from having pending actions to none
        showSnackBar('✅ Offline actions replayed successfully.');
      }
    } catch (e) {
      state.logger.warning('⚠️ Unable to refresh pending actions badge', e);
    }
  }
}
