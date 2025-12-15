import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/beacon_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/http_service.dart';
import '../../../../core/services/attendance_service.dart';
import '../../../auth/services/auth_service.dart';

/// Represents the high-level status the UI should display.
enum BeaconStatusType {
  scanning,
  provisional,
  confirming,
  confirmed,
  success,
  cancelled,
  failed,
  cooldown,
  deviceLocked,
  info,
}

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
class HomeScreenState extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;
  // Service instances
  final BeaconService beaconService = BeaconService();
  final AttendanceService attendanceService = AttendanceService();
  final AuthService authService = AuthService();
  final LoggerService logger = LoggerService();
  final HttpService httpService = HttpService();

  // Platform channel for notification updates
  static const platform =
      MethodChannel('com.example.attendance_app/beacon_service');

  // Static flags for battery optimization check
  static bool hasCheckedBatteryOnce = false;
  static bool? cachedBatteryCardState;

  // Beacon scanning state (centralized in BeaconService; UI no longer owns streams)
  String beaconStatus = 'Initializing...';
  BeaconStatusType beaconStatusType = BeaconStatusType.info;
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
  int? lastRssi;
  double? lastDistance;

  // Cooldown and class tracking
  String? currentClassId;
  Map<String, dynamic>? cooldownInfo;

  // Cooldown refresh timer
  Timer? cooldownRefreshTimer;

  // Manual sync state
  bool isSyncing = false;

  /// Set syncing state and notify listeners
  void setIsSyncing(bool value) {
    update((state) {
      state.isSyncing = value;
    });
  }

  /// Apply updates and notify listeners
  void update(void Function(HomeScreenState state) updates) {
    if (_isDisposed) return;
    updates(this);
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Dispose of all timers and subscriptions
  @override
  void dispose() {
    confirmationTimer?.cancel();
    cooldownRefreshTimer?.cancel();
    // Important: Do NOT dispose the global BeaconService here.
    // Disposing it cancels confirmation timers and background logic.
    // Instead, just clear the UI callback to avoid updates to a disposed screen.
    beaconService.clearOnAttendanceStateChanged();
    _isDisposed = true;
    super.dispose();
  }

  /// Reset to initial scanning state
  void resetToScanning() {
    update((state) {
      state.beaconStatusType = BeaconStatusType.scanning;
      state.beaconStatus = '📡 Scanning for classroom beacon...';
      state.isCheckingIn = false;
      state.isAwaitingConfirmation = false;
      state.remainingSeconds = 0;
      state.confirmationTimer?.cancel();
    });
  }

  /// Update beacon status
  void updateBeaconStatus(String status,
      {BeaconStatusType type = BeaconStatusType.info}) {
    update((state) {
      state.beaconStatusType = type;
      state.beaconStatus = status;
    });
  }

  /// Update proximity metrics (RSSI / distance) for UI hero card
  void updateProximity({int? rssi, double? distance}) {
    update((state) {
      state.lastRssi = rssi ?? state.lastRssi;
      state.lastDistance = distance ?? state.lastDistance;
    });
  }

  /// Check if status is locked (shouldn't be updated)
  bool isStatusLocked() {
    return {
      BeaconStatusType.provisional,
      BeaconStatusType.confirming,
      BeaconStatusType.confirmed,
      BeaconStatusType.success,
      BeaconStatusType.cancelled,
      BeaconStatusType.cooldown,
    }.contains(beaconStatusType);
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
