import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import '../models/attendance_state.dart';
import 'permission_service.dart';
import 'device_id_service.dart';
import 'http_service.dart';
import 'attendance_confirmation_service.dart';
import 'rssi_stream_service.dart';
import 'simple_notification_service.dart';
import 'settings_service.dart';

// Import modular components
import 'beacon_service/beacon_rssi_analyzer.dart';
import 'beacon_service/beacon_cooldown_manager.dart';
import 'beacon_service/beacon_state_manager.dart';
import 'beacon_service/beacon_sync_handler.dart';
import 'beacon_service/beacon_confirmation_handler.dart';

/// 📡 Beacon Service (Refactored)
///
/// Main orchestrator for beacon-based attendance tracking.
/// Uses modular components for better organization:
/// - BeaconRssiAnalyzer: RSSI processing & smoothing
/// - BeaconCooldownManager: Duplicate check-in prevention
/// - BeaconStateManager: State machine management
/// - BeaconSyncHandler: Backend synchronization
/// - BeaconConfirmationHandler: Confirmation logic
///
/// This file is now ~250 lines (was 759 lines)
class BeaconService {
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;

  BeaconService._internal() {
    // Initialize modular components
    _initializeModules();

    // Setup confirmation callbacks
    _confirmationService.onConfirmationSuccess = _handleConfirmationSuccess;
    _confirmationService.onConfirmationFailure = _handleConfirmationFailure;
    _confirmationService.onConfirmationQueued = _handleConfirmationQueued;
  }

  final _logger = Logger();

  // External services
  final PermissionService _permissionService = PermissionService();
  final DeviceIdService _deviceIdService = DeviceIdService();
  final HttpService _httpService = HttpService();
  final AttendanceConfirmationService _confirmationService =
      AttendanceConfirmationService();
  final RSSIStreamService _rssiStreamService = RSSIStreamService();

  // Modular components
  late final BeaconRssiAnalyzer _rssiAnalyzer;
  late final BeaconCooldownManager _cooldownManager;
  late final BeaconStateManager _stateManager;
  late final BeaconSyncHandler _syncHandler;
  late final BeaconConfirmationHandler _confirmationHandler;

  // Beacon ranging
  StreamSubscription<RangingResult>? _streamRanging;
  bool _isScanning = false;
  String? _activeStudentId;
  void Function(RangingResult result)? _onRangingCallback;
  DateTime? _lastNotifUpdate;
  DateTime? _lastNotScanningLog;

  // Instrumentation: RSSI feed counter and throttled logs
  int _rssiFeedCount = 0;
  DateTime? _lastRssiLogTime;

  // Guard against duplicate attendance state callback registrations
  bool _attendanceCallbackRegistered = false;

  // Background assist for screen-off scenarios
  Timer? _provisionalWatchdogTimer;
  String? _lastClassId;
  DateTime? _lastBeaconEventTime;

  // Legacy signal tracking (for backward compatibility)
  final List<int> _rssiHistory = [];
  final List<DateTime> _rssiTimestamps = [];
  int? _lastRssi; // latest raw RSSI sample
  double? _lastDistance; // latest estimated distance (meters)

  /// Initialize all modular components
  void _initializeModules() {
    _rssiAnalyzer = BeaconRssiAnalyzer();
    _cooldownManager = BeaconCooldownManager();
    _stateManager = BeaconStateManager();
    _syncHandler = BeaconSyncHandler();
    _confirmationHandler = BeaconConfirmationHandler();

    // Initialize handlers with dependencies
    _syncHandler.init(_cooldownManager, _stateManager);
    _confirmationHandler.init(_stateManager);

    _logger.i('✅ Beacon service modules initialized');
  }

  /// Initialize beacon scanning
  Future<void> initializeBeaconScanning() async {
    await _permissionService.requestBeaconPermissions();

    try {
      await flutterBeacon.initializeScanning;
      _logger.i('✅ Beacon scanning initialized');
    } catch (e) {
      _logger.e("❌ FATAL ERROR initializing beacon scanner: $e");
      rethrow;
    }
  }

  /// Start beacon ranging
  Future<void> startScanning({
    required String studentId,
    void Function(RangingResult result)? onRanging,
  }) async {
    if (_isScanning && _streamRanging != null) {
      _logger.d('🔁 Beacon scanning already active');
      // Update callback if provided
      if (onRanging != null) _onRangingCallback = onRanging;
      return;
    }

    await initializeBeaconScanning();
    _activeStudentId = studentId;
    _onRangingCallback = onRanging;

    final regions = <Region>[
      Region(
        identifier: AppConstants.schoolIdentifier,
        proximityUUID: AppConstants.proximityUUID,
      ),
    ];

    _logger.i('📡 Starting beacon ranging (centralized) ...');
    // Start persistent foreground notification (external control mode)
    try {
      await SimpleNotificationService.startForegroundNotification();
    } catch (e) {
      _logger.w('⚠️ Failed to start foreground notification: $e');
    }
    _isScanning = true;
    _streamRanging = flutterBeacon.ranging(regions).listen(
      (RangingResult result) => _handleRangingResult(result),
      onError: (e) {
        _logger.e('❌ Ranging stream error: $e');
      },
      cancelOnError: false,
    );

    // Start background watchdog to mitigate OEM throttling when screen off
    _startProvisionalWatchdogIfNeeded();
  }

  void _handleRangingResult(RangingResult result) {
    // Fan-out to any UI listener for auxiliary UX (e.g., live status text)
    try {
      _onRangingCallback?.call(result);
    } catch (e) {
      _logger.w('⚠️ onRanging callback error: $e');
    }

    if (_activeStudentId == null) return; // Need student context

    if (result.beacons.isEmpty) {
      // No-op here; UI may render scanning; core logic only triggers on beacons
      return;
    }

    final beacon = result.beacons.first;
    // Keep analyzer warm
    _rssiAnalyzer.feedRssiSample(beacon.rssi);

    // Derive class
    final classId = getClassIdFromBeacon(beacon);
    _lastClassId = classId; // remember last seen class for watchdog
    _lastBeaconEventTime = DateTime.now();

    // Debounced foreground notification update (approx every 1.5s)
    _updateForegroundStatusDebounced(
        classId, beacon.rssi, beacon.txPower ?? -59);

    // Respect scanning state from state manager
    if (!_stateManager.isScanning) {
      _logNotScanningThrottled();
      return;
    }

    // Run main analysis; will set state and schedule timers as needed
    analyzeBeacon(beacon, _activeStudentId!, classId);
  }

  void _updateForegroundStatusDebounced(String classId, int rssi, int txPower) {
    final now = DateTime.now();
    if (_lastNotifUpdate == null ||
        now.difference(_lastNotifUpdate!).inMilliseconds >= 1500) {
      _lastNotifUpdate = now;
      final distance = _estimateDistance(rssi, txPower);
      _lastRssi = rssi;
      _lastDistance = distance;
      final title =
          distance <= 2.0 ? '✅ In Range - $classId' : '📍 $classId Detected';
      final content = 'RSSI: $rssi • ${distance.toStringAsFixed(1)}m away';
      SimpleNotificationService.updateStatusText(title, content)
          .catchError((_) {});
    }
  }

  double _estimateDistance(int rssi, int txPower) {
    if (rssi == 0) return -1.0;
    final ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return math.pow(ratio, 10).toDouble();
    } else {
      return (0.89976) * math.pow(ratio, 7.7095) + 0.111;
    }
  }

  /// Stop beacon ranging
  void stopRanging() {
    _streamRanging?.cancel();
    _streamRanging = null;
    _isScanning = false;
    _logger.i('⏹️ Beacon ranging stopped');
    // Stop watchdog
    _provisionalWatchdogTimer?.cancel();
    _provisionalWatchdogTimer = null;
    // Stop persistent foreground notification
    SimpleNotificationService.stopForegroundNotification().catchError((e) {
      _logger.w('⚠️ Failed to stop foreground notification: $e');
    });
  }

  /// Analyze beacon for attendance (main entry point)
  bool analyzeBeacon(Beacon beacon, String studentId, String classId) {
    final rssi = beacon.rssi;

    // Prevent re-entry shortly after confirmation
    if (_stateManager.isInLockout) {
      _logger.d('🔒 Post-confirmation lockout active - ignoring beacon');
      return false;
    }

    // Feature flag gate: if new pipeline disabled, fallback to legacy simple proximity logic
    final settings = SettingsService().getSettings();
    if (!settings.newAttendancePipelineEnabled) {
      // Minimal legacy path: immediate check-in if RSSI strong enough and not in cooldown
      if (_cooldownManager.isInCooldown(studentId, classId)) return false;
      if (rssi < AppConstants.rssiThreshold) return false;
      _logger.i('🚦 Legacy pipeline: direct provisional for $classId');
      _startTwoStageAttendance(studentId, classId);
      return true;
    }

    // Feed RSSI to analyzer
    _rssiAnalyzer.feedRssiSample(rssi);

    // Update legacy tracking (for backward compatibility)
    _updateLegacyTracking(rssi);

    // Check if scanning state
    if (!_stateManager.isScanning) {
      _logNotScanningThrottled();
      return false;
    }

    // Check cooldown
    if (_cooldownManager.isInCooldown(studentId, classId)) {
      _logger.d('⏳ Cooldown active - check-in blocked');

      // Notify UI once
      if (_stateManager.currentState == 'scanning') {
        _stateManager.setStateAndNotify('cooldown', studentId, classId);
      }
      return false;
    }

    // Check signal stability
    if (!_isSignalStable(rssi)) {
      _logger.d('📊 Signal not stable yet');
      return false;
    }

    // Check if student in classroom
    if (!_rssiAnalyzer.isStudentInClassroom()) {
      _logger.d('📍 Student not in classroom range');
      return false;
    }

    // All checks passed - start attendance
    _startTwoStageAttendance(studentId, classId);
    return true;
  }

  /// Latest proximity metrics for UI hero card
  int? get lastRssi => _lastRssi;
  double? get lastDistance => _lastDistance;

  /// Start a lightweight watchdog to help trigger provisional in background
  /// Useful on devices that throttle ranging callbacks when screen is fully off.
  void _startProvisionalWatchdogIfNeeded() {
    // Already running
    if (_provisionalWatchdogTimer != null) return;

    _provisionalWatchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      try {
        // Only act while in scanning state
        if (!_stateManager.isScanning) return;
        if (_activeStudentId == null) return;

        // Need a recently seen classId to attribute check-in
        final classId = _lastClassId;
        if (classId == null) return;

        // Refresh scan if no beacon events for a while (possible throttling)
        _refreshScanIfStale();

        // Respect cooldown
        if (_cooldownManager.isInCooldown(_activeStudentId!, classId)) return;

        // Require a current RSSI reading and classroom proximity
        final rssi = _rssiAnalyzer.currentRssi;
        if (rssi == null) return;
        if (!_rssiAnalyzer.isStudentInClassroom()) return;

        // Basic stability gate (reuse legacy window)
        if (!_isSignalStable(rssi)) return;

        _logger.i(
            '🕑 Watchdog: triggering provisional (screen-off assist) for $classId');
        _startTwoStageAttendance(_activeStudentId!, classId);
      } catch (e) {
        _logger.w('⚠️ Watchdog tick error: $e');
      }
    });

    _logger.d('👀 Provisional watchdog started');
  }

  /// Attempt to refresh scanning if beacon callbacks appear stale.
  void _refreshScanIfStale() {
    if (_lastBeaconEventTime == null) return;
    final since = DateTime.now().difference(_lastBeaconEventTime!);
    if (since.inSeconds >= 5) {
      _logger.w(
          '🛠️ Watchdog: refreshing beacon ranging after ${since.inSeconds}s inactivity');
      try {
        _streamRanging?.cancel();
        _streamRanging = null;
        _isScanning = false;
        // Restart with same student context (UI callback preserved)
        startScanning(
            studentId: _activeStudentId!, onRanging: _onRangingCallback);
      } catch (e) {
        _logger.e('❌ Error refreshing scan: $e');
      }
    }
  }

  void _logNotScanningThrottled() {
    final now = DateTime.now();
    if (_lastNotScanningLog == null ||
        now.difference(_lastNotScanningLog!).inSeconds >= 5) {
      _lastNotScanningLog = now;
      _logger.d('⏸️ Not in scanning state - ignoring beacon');
    }
  }

  /// Check if signal is stable (legacy method)
  bool _isSignalStable(int newRssi) {
    _rssiHistory.add(newRssi);
    _rssiTimestamps.add(DateTime.now());

    // Keep only recent readings (last 5 seconds)
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 5));
    while (_rssiTimestamps.isNotEmpty &&
        _rssiTimestamps.first.isBefore(cutoffTime)) {
      _rssiHistory.removeAt(0);
      _rssiTimestamps.removeAt(0);
    }

    // Need at least minimum readings
    if (_rssiHistory.length < AppConstants.minimumReadingsForStability) {
      return _rssiHistory.isNotEmpty;
    }

    // Calculate variance
    final average = _rssiHistory.reduce((a, b) => a + b) / _rssiHistory.length;
    final variance = _rssiHistory
            .map((rssi) => (rssi - average).abs())
            .reduce((a, b) => a + b) /
        _rssiHistory.length;

    return variance <= AppConstants.rssiVarianceThreshold;
  }

  /// Update legacy tracking (for backward compatibility)
  void _updateLegacyTracking(int rssi) {
    // Keep legacy variables updated for any code that still uses them
    // This can be removed after full migration
  }

  /// Start two-stage attendance process
  void _startTwoStageAttendance(String studentId, String classId) {
    _logger.i('🎯 Starting attendance for $studentId in $classId');

    // Set cooldown
    _cooldownManager.setCooldown(studentId, classId, DateTime.now());

    // Change to provisional state
    _stateManager.setStateAndNotify('provisional', studentId, classId);

    // Submit to backend
    _submitProvisionalCheckIn(studentId, classId);
  }

  /// Submit provisional check-in to backend
  Future<void> _submitProvisionalCheckIn(
      String studentId, String classId) async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final rssi = _rssiAnalyzer.currentRssi ?? -70;

      _logger.i(
          '📱 Submitting check-in: Student=$studentId, Class=$classId, Device=$deviceId, RSSI=$rssi');

      final result = await _httpService.checkIn(
        studentId: studentId,
        classId: classId,
        deviceId: deviceId,
        rssi: rssi,
      );

      if (result['success'] == true) {
        final attendanceId = result['attendanceId'];

        _logger.i('✅ Check-in successful! ID: $attendanceId');

        if (attendanceId != null && attendanceId != 'unknown') {
          // Schedule confirmation
          _confirmationService.scheduleConfirmation(
            attendanceId: attendanceId,
            studentId: studentId,
            classId: classId,
            // New check-in: full delay, so no override
          );

          // Start RSSI streaming
          _rssiStreamService.startStreaming(
            studentId: studentId,
            classId: classId,
            sessionDate: DateTime.now(),
          );

          _logger.i('📡 RSSI streaming started');
        }
      } else if (result['error'] == 'DEVICE_MISMATCH') {
        _logger.e('🔒 DEVICE MISMATCH: ${result['message']}');
        _stateManager.setStateAndNotify('device_mismatch', studentId, classId);
      } else {
        _logger.e('❌ Check-in failed: ${result['message']}');
        _stateManager.setStateAndNotify('failed', studentId, classId);
      }
    } catch (e) {
      _logger.e('❌ Error submitting check-in: $e');
      _stateManager.setStateAndNotify('failed', studentId, classId);
    }
  }

  /// Handle confirmation success (callback from confirmation service)
  void _handleConfirmationSuccess(String studentId, String classId) {
    _confirmationHandler.handleConfirmationSuccess(studentId, classId);
  }

  /// Handle confirmation failure (callback from confirmation service)
  void _handleConfirmationFailure(String studentId, String classId) {
    _confirmationHandler.handleConfirmationFailure(studentId, classId);
    // Clear cooldown on cancellation
    _cooldownManager.clearCooldown();
  }

  /// Handle confirmation queued (offline - will retry when network returns)
  void _handleConfirmationQueued(String studentId, String classId) {
    _logger.i('📥 Confirmation queued for offline sync: $studentId / $classId');
    // Notify UI via the existing callback mechanism
    _stateManager.notifyStateChange('queued', studentId, classId);
    // Note: We don't start cooldown here - that happens after successful sync
  }

  // ========== PUBLIC API ==========

  /// Get current RSSI (with smoothing and grace period)
  int? getCurrentRssi() => _rssiAnalyzer.getCurrentRssi();

  /// Get raw RSSI data (without grace period - for final checks)
  Map<String, dynamic> getRawRssiData() => _rssiAnalyzer.getRawRssiData();

  /// Last time a REAL beacon packet was observed via ranging
  DateTime? get lastBeaconEventTime => _lastBeaconEventTime;

  /// Whether a real beacon packet was seen within the last [maxAge]
  bool wasBeaconSeenRecently({Duration? maxAge}) {
    final threshold = maxAge ?? AppConstants.confirmationBeaconVisibilityMaxAge;
    if (_lastBeaconEventTime == null) return false;
    final since = DateTime.now().difference(_lastBeaconEventTime!);
    return since <= threshold;
  }

  /// Feed RSSI sample (for external services)
  void feedRssiSample(int rssi) {
    _rssiAnalyzer.feedRssiSample(rssi);
    // Instrumentation: count and occasionally log to verify scanner activity
    _rssiFeedCount++;
    final now = DateTime.now();
    final shouldLogByCount = _rssiFeedCount % 50 == 0; // every 50 samples
    final shouldLogByTime = _lastRssiLogTime == null ||
        now.difference(_lastRssiLogTime!).inSeconds >= 30;
    if (shouldLogByCount || shouldLogByTime) {
      _lastRssiLogTime = now;
      _logger.d('📶 RSSI feed activity: total=$_rssiFeedCount last=$rssi');
    }
  }

  /// Get cooldown info
  Map<String, dynamic>? getCooldownInfo() => _cooldownManager.getCooldownInfo();

  /// Clear cooldown
  void clearCooldown() => _cooldownManager.clearCooldown();

  /// Sync state from backend
  Future<Map<String, dynamic>> syncStateFromBackend(String studentId) {
    return _syncHandler.syncStateFromBackend(studentId);
  }

  /// 🆕 Stream of attendance state changes
  /// Use with StreamBuilder for reactive UI updates that handle lifecycle automatically.
  /// This prevents glitches when UI rebuilds (keyboard opens, screen rotates, etc.)
  Stream<AttendanceState> get attendanceStateStream => _stateManager.stateStream;

  /// 🆕 Get current attendance state synchronously (snapshot)
  AttendanceState get currentAttendanceState => _stateManager.currentStateSnapshot;

  /// Set state change callback
  void setOnAttendanceStateChanged(
      Function(String state, String studentId, String classId) callback) {
    // Guard against multiple registrations causing duplicate state transitions
    if (_attendanceCallbackRegistered) {
      _logger.d('🔁 Replacing existing attendance state callback');
    }
    _stateManager.setOnStateChanged(callback);
    _attendanceCallbackRegistered = true;
    _logger.d('✅ Attendance state callback registered');
  }

  /// Clear state change callback (use when a screen with callback is disposed)
  void clearOnAttendanceStateChanged() {
    _stateManager.clearOnStateChanged();
    _attendanceCallbackRegistered = false;
    _logger.d('🧹 Attendance state callback cleared');
  }

  /// Get class ID from beacon
  String getClassIdFromBeacon(Beacon beacon) {
    return beacon.minor.toString();
  }

  /// Dispose service
  void dispose() {
    _stateManager.dispose();
    stopRanging();
    _confirmationService.dispose();
    _rssiStreamService.dispose();
    _logger.i('🧹 Beacon service disposed');
  }
}
