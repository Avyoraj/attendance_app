import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'permission_service.dart';
import 'device_id_service.dart';
import 'http_service.dart';
import 'attendance_confirmation_service.dart';
import 'rssi_stream_service.dart';

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
  }

  final _logger = Logger();
  
  // External services
  final PermissionService _permissionService = PermissionService();
  final DeviceIdService _deviceIdService = DeviceIdService();
  final HttpService _httpService = HttpService();
  final AttendanceConfirmationService _confirmationService = AttendanceConfirmationService();
  final RSSIStreamService _rssiStreamService = RSSIStreamService();
  
  // Modular components
  late final BeaconRssiAnalyzer _rssiAnalyzer;
  late final BeaconCooldownManager _cooldownManager;
  late final BeaconStateManager _stateManager;
  late final BeaconSyncHandler _syncHandler;
  late final BeaconConfirmationHandler _confirmationHandler;
  
  // Beacon ranging
  StreamSubscription<RangingResult>? _streamRanging;
  
  // Legacy signal tracking (for backward compatibility)
  final List<int> _rssiHistory = [];
  final List<DateTime> _rssiTimestamps = [];
  
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
  Stream<RangingResult> startRanging() {
    final regions = <Region>[
      Region(
        identifier: AppConstants.schoolIdentifier,
        proximityUUID: AppConstants.proximityUUID,
      ),
    ];

    _logger.i('📡 Starting beacon ranging...');
    return flutterBeacon.ranging(regions);
  }

  /// Stop beacon ranging
  void stopRanging() {
    _streamRanging?.cancel();
    _streamRanging = null;
    _logger.i('⏹️ Beacon ranging stopped');
  }

  /// Analyze beacon for attendance (main entry point)
  bool analyzeBeacon(Beacon beacon, String studentId, String classId) {
    final rssi = beacon.rssi;
    
    // Feed RSSI to analyzer
    _rssiAnalyzer.feedRssiSample(rssi);
    
    // Update legacy tracking (for backward compatibility)
    _updateLegacyTracking(rssi);
    
    // Check if scanning state
    if (!_stateManager.isScanning) {
      _logger.d('⏸️ Not in scanning state - ignoring beacon');
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
  
  /// Check if signal is stable (legacy method)
  bool _isSignalStable(int newRssi) {
    _rssiHistory.add(newRssi);
    _rssiTimestamps.add(DateTime.now());
    
    // Keep only recent readings (last 5 seconds)
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 5));
    while (_rssiTimestamps.isNotEmpty && _rssiTimestamps.first.isBefore(cutoffTime)) {
      _rssiHistory.removeAt(0);
      _rssiTimestamps.removeAt(0);
    }
    
    // Need at least minimum readings
    if (_rssiHistory.length < AppConstants.minimumReadingsForStability) {
      return _rssiHistory.isNotEmpty;
    }
    
    // Calculate variance
    final average = _rssiHistory.reduce((a, b) => a + b) / _rssiHistory.length;
    final variance = _rssiHistory.map((rssi) => (rssi - average).abs()).reduce((a, b) => a + b) / _rssiHistory.length;
    
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
  Future<void> _submitProvisionalCheckIn(String studentId, String classId) async {
    try {
      final deviceId = await _deviceIdService.getDeviceId();
      final rssi = _rssiAnalyzer.currentRssi ?? -70;
      
      _logger.i('📱 Submitting check-in: Student=$studentId, Class=$classId, Device=$deviceId, RSSI=$rssi');
      
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
  
  // ========== PUBLIC API ==========
  
  /// Get current RSSI (with smoothing and grace period)
  int? getCurrentRssi() => _rssiAnalyzer.getCurrentRssi();
  
  /// Get raw RSSI data (without grace period - for final checks)
  Map<String, dynamic> getRawRssiData() => _rssiAnalyzer.getRawRssiData();
  
  /// Feed RSSI sample (for external services)
  void feedRssiSample(int rssi) => _rssiAnalyzer.feedRssiSample(rssi);
  
  /// Get cooldown info
  Map<String, dynamic>? getCooldownInfo() => _cooldownManager.getCooldownInfo();
  
  /// Clear cooldown
  void clearCooldown() => _cooldownManager.clearCooldown();
  
  /// Sync state from backend
  Future<Map<String, dynamic>> syncStateFromBackend(String studentId) {
    return _syncHandler.syncStateFromBackend(studentId);
  }
  
  /// Set state change callback
  void setOnAttendanceStateChanged(Function(String state, String studentId, String classId) callback) {
    _stateManager.setOnStateChanged(callback);
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
