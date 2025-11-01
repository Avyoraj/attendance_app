import 'package:flutter/material.dart';
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
  Future<void> syncStateOnStartup(
    String studentId,
    Function(VoidCallback) setStateCallback,
    Function loadCooldownInfo,
    Function startConfirmationTimer,
    Function showSnackBar,
  ) async {
    try {
      // Show loading state
      setStateCallback(() {
        state.beaconStatus = '🔄 Loading attendance state...';
        state.isCheckingIn = true;
      });
      
      state.logger.info('🔄 Syncing attendance state from backend...');
      
      // Add 5-second timeout to prevent infinite waiting
      final syncResult = await state.beaconService
          .syncStateFromBackend(studentId)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              state.logger.warning('⏱️ Sync timeout (5s) - falling back to scanning mode');
              return {'success': false, 'error': 'timeout'};
            },
          );
      
      if (syncResult['success'] == true) {
        final syncedCount = syncResult['synced'] ?? 0;
        
        if (syncedCount > 0) {
          state.logger.info('✅ Synced $syncedCount attendance records on startup');
          
          final attendance = syncResult['attendance'] as List?;
          if (attendance != null) {
            for (var record in attendance) {
              if (record['status'] == 'provisional') {
                await _handleProvisionalSync(record, setStateCallback, startConfirmationTimer, showSnackBar);
                break;
              } else if (record['status'] == 'confirmed') {
                await _handleConfirmedSync(record, setStateCallback, loadCooldownInfo);
                break;
              } else if (record['status'] == 'cancelled') {
                await _handleCancelledSync(record, setStateCallback);
                break;
              }
            }
          }
        } else {
          state.logger.info('📭 No attendance records to sync');
          setStateCallback(() {
            state.isCheckingIn = false;
            state.beaconStatus = '📡 Scanning for classroom beacon...';
          });
        }
      } else {
        state.logger.warning('⚠️ State sync failed: ${syncResult['error']}');
        setStateCallback(() {
          state.isCheckingIn = false;
          state.beaconStatus = '📡 Scanning for classroom beacon...';
        });
      }
    } catch (e) {
      state.logger.error('❌ State sync error on startup', e);
      setStateCallback(() {
        state.isCheckingIn = false;
        state.beaconStatus = '📡 Scanning for classroom beacon...';
      });
    }
  }
  
  /// Handle provisional record from sync
  Future<void> _handleProvisionalSync(
    Map<String, dynamic> record,
    Function(VoidCallback) setStateCallback,
    Function startConfirmationTimer,
    Function showSnackBar,
  ) async {
    final remainingSeconds = record['remainingSeconds'] as int? ?? 0;
    final classId = record['classId'] as String;
    
    if (remainingSeconds > 0) {
      state.logger.info('⏱️ Resuming provisional countdown: $remainingSeconds seconds for Class $classId');
      
      setStateCallback(() {
        state.isAwaitingConfirmation = true;
        state.remainingSeconds = remainingSeconds;
        state.currentClassId = classId;
        state.beaconStatus = '⏳ Check-in recorded for Class $classId!\n(Resumed) Stay in class to confirm attendance.';
      });
      
      startConfirmationTimer();
      showSnackBar('⏱️ Resumed: ${(remainingSeconds ~/ 60)}:${(remainingSeconds % 60).toString().padLeft(2, '0')} remaining');
      
      state.logger.info('✅ UI countdown resumed successfully');
    }
  }
  
  /// Handle confirmed record from sync
  Future<void> _handleConfirmedSync(
    Map<String, dynamic> record,
    Function(VoidCallback) setStateCallback,
    Function loadCooldownInfo,
  ) async {
    final classId = record['classId'] as String;
    state.logger.info('✅ Found confirmed attendance for Class $classId');
    
    setStateCallback(() {
      state.currentClassId = classId;
      state.beaconStatus = '✅ You\'re Already Checked In for Class $classId\nEnjoy your class!';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    });
    
    loadCooldownInfo();
  }
  
  /// Handle cancelled record from sync
  Future<void> _handleCancelledSync(
    Map<String, dynamic> record,
    Function(VoidCallback) setStateCallback,
  ) async {
    final classId = record['classId'] as String;
    final cancelledTime = DateTime.parse(record['checkInTime']);
    state.logger.info('❌ Found cancelled attendance for Class $classId');
    
    final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
      cancelledTime: cancelledTime,
      now: DateTime.now(),
    );
    
    setStateCallback(() {
      state.currentClassId = classId;
      state.beaconStatus = '❌ Attendance Cancelled for Class $classId\n${cancelledInfo['message']}';
      state.cooldownInfo = cancelledInfo;
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
    });
    
    state.logger.info('🎓 Cancelled state loaded with schedule awareness');
  }
  
  /// Perform final RSSI check and confirm/cancel attendance
  /// 
  /// This is the critical check that happens when the countdown timer expires.
  /// It uses raw RSSI data to prevent false confirmations.
  Future<void> performFinalConfirmationCheck(
    Function(VoidCallback) setStateCallback,
  ) async {
    print('🔍 CONFIRMATION CHECK: Starting final RSSI verification...');
    
    // Get raw RSSI data (bypasses grace period cache)
    final rssiData = state.beaconService.getRawRssiData();
    final currentRssi = rssiData['rssi'] as int?;
    final rssiAge = rssiData['ageSeconds'] as int?;
    final isInGracePeriod = rssiData['isInGracePeriod'] as bool? ?? false;
    const threshold = AppConstants.confirmationRssiThreshold;
    
    print('📊 CONFIRMATION CHECK:');
    print('   - Raw RSSI: $currentRssi dBm ${isInGracePeriod ? "(⚠️ IN GRACE PERIOD)" : ""}');
    print('   - RSSI Age: ${rssiAge ?? "N/A"}s');
    print('   - Threshold: $threshold dBm');
    print('   - Required: RSSI >= $threshold AND age <= 3s AND not in grace period');
    
    // Check if RSSI is available
    if (currentRssi == null) {
      await _cancelAttendance(setStateCallback, 'No beacon detected during confirmation.');
      return;
    }
    
    // Check if RSSI data is stale
    if (rssiAge != null && rssiAge > 3) {
      await _cancelAttendance(setStateCallback, 'Beacon data is stale.');
      return;
    }
    
    // Check if in grace period (using cached values)
    if (isInGracePeriod) {
      await _cancelAttendance(setStateCallback, 'Beacon signal too weak.');
      return;
    }
    
    // Perform strict RSSI threshold check
    if (currentRssi >= threshold) {
      // User is still in range - CONFIRM attendance
      await _confirmAttendance(setStateCallback);
    } else {
      // User left the classroom - CANCEL attendance
      await _cancelAttendance(setStateCallback, 'You left the classroom during the confirmation period.');
    }
  }
  
  /// Confirm attendance on backend
  Future<void> _confirmAttendance(Function(VoidCallback) setStateCallback) async {
    print('✅ CONFIRMED: User is in range');
    
    setStateCallback(() {
      state.beaconStatus = '✅ Attendance CONFIRMED!\nYou stayed in the classroom.';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
    });
    
    if (state.currentClassId != null) {
      try {
        final result = await state.httpService.confirmAttendance(
          studentId: studentId,
          classId: state.currentClassId!,
        );
        
        if (result['success'] == true) {
          print('✅ Backend confirmed attendance');
          
          // Show success notification
          await NotificationService.showSuccessNotification(
            classId: state.currentClassId!,
            message: 'Logged at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          );
          
          // Show cooldown notification
          await NotificationService.showCooldownNotification(
            classId: state.currentClassId!,
            classStartTime: DateTime.now(),
          );
        }
      } catch (e) {
        print('❌ Error confirming attendance: $e');
      }
    }
  }
  
  /// Cancel attendance on backend
  Future<void> _cancelAttendance(
    Function(VoidCallback) setStateCallback,
    String reason,
  ) async {
    print('❌ CANCELLED: $reason');
    
    final cancelledTime = DateTime.now();
    final cancelledInfo = ScheduleUtils.getScheduleAwareCancelledInfo(
      cancelledTime: cancelledTime,
      now: cancelledTime,
    );
    
    setStateCallback(() {
      state.beaconStatus = '❌ Attendance Cancelled!\n$reason';
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.isCheckingIn = false;
      state.cooldownInfo = cancelledInfo;
    });
    
    if (state.currentClassId != null) {
      await NotificationService.showCancelledNotification(
        classId: state.currentClassId!,
        cancelledTime: cancelledTime,
      );
      
      try {
        await state.httpService.cancelProvisionalAttendance(
          studentId: studentId,
          classId: state.currentClassId!,
        );
      } catch (e) {
        print('⚠️ Error cancelling on backend: $e');
      }
    }
  }
}
