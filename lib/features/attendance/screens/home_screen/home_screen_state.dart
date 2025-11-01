import 'dart:async';
import 'package:flutter/services.dart';
import '../../../../core/services/beacon_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/http_service.dart';
import '../../services/attendance_service.dart';
import '../../../auth/services/auth_service.dart';

/// 📦 HomeScreen State Module
/// 
/// Centralizes all state variables for the HomeScreen.
/// This module holds all the data that the screen uses.
/// 
/// Features:
/// - Service instances
/// - UI state flags
/// - Timer references
/// - Cooldown tracking
/// - Battery optimization state
class HomeScreenState {
  // Service instances
  final BeaconService beaconService = BeaconService();
  final AttendanceService attendanceService = AttendanceService();
  final AuthService authService = AuthService();
  final LoggerService logger = LoggerService();
  final HttpService httpService = HttpService();
  
  // Platform channel for notification updates
  static const platform = MethodChannel('com.example.attendance_app/beacon_service');
  
  // Static flags for battery optimization check
  static bool hasCheckedBatteryOnce = false;
  static bool? cachedBatteryCardState;
  
  // Beacon scanning state
  StreamSubscription? streamRanging;
  String beaconStatus = 'Initializing...';
  bool isCheckingIn = false;
  
  // Battery optimization state
  bool showBatteryCard = false; // Start hidden, show after check
  bool isBatteryOptimizationDisabled = false;
  bool isCheckingBatteryOptimization = false;
  
  // Confirmation timer state
  Timer? confirmationTimer;
  int remainingSeconds = 0;
  bool isAwaitingConfirmation = false;
  String? provisionalAttendanceId;
  
  // Beacon tracking
  DateTime? lastBeaconSeen;
  DateTime? lastNotificationUpdate;
  
  // Cooldown and class tracking
  String? currentClassId;
  Map<String, dynamic>? cooldownInfo;
  
  // Cooldown refresh timer
  Timer? cooldownRefreshTimer;
  
  /// Dispose of all timers and subscriptions
  void dispose() {
    confirmationTimer?.cancel();
    cooldownRefreshTimer?.cancel();
    streamRanging?.cancel();
    beaconService.dispose();
  }
  
  /// Reset to initial scanning state
  void resetToScanning() {
    beaconStatus = '📡 Scanning for classroom beacon...';
    isCheckingIn = false;
    isAwaitingConfirmation = false;
    remainingSeconds = 0;
    confirmationTimer?.cancel();
  }
  
  /// Update beacon status
  void updateBeaconStatus(String status) {
    beaconStatus = status;
  }
  
  /// Check if status is locked (shouldn't be updated)
  bool isStatusLocked() {
    return beaconStatus.contains('Check-in recorded') || 
           beaconStatus.contains('CONFIRMED') ||
           beaconStatus.contains('Attendance Recorded') ||
           beaconStatus.contains('Already Checked In') ||
           beaconStatus.contains('Cancelled') ||
           beaconStatus.contains('Processing') ||
           beaconStatus.contains('Recording your attendance');
  }
  
  /// Check if in provisional state (awaiting confirmation)
  bool isInProvisionalState() {
    return isAwaitingConfirmation && remainingSeconds > 0;
  }
  
  /// Get formatted remaining time for display
  String getFormattedRemainingTime() {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
