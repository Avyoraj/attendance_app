import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'permission_service.dart';
import 'device_id_service.dart';
import 'http_service.dart';
import 'attendance_confirmation_service.dart';
import 'rssi_stream_service.dart';

class BeaconService {
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal() {
    // Setup confirmation callbacks
    _confirmationService.onConfirmationSuccess = _handleConfirmationSuccess;
    _confirmationService.onConfirmationFailure = _handleConfirmationFailure;
  }

  final _logger = Logger();
  final PermissionService _permissionService = PermissionService();
  final DeviceIdService _deviceIdService = DeviceIdService();
  final HttpService _httpService = HttpService();
  final AttendanceConfirmationService _confirmationService = AttendanceConfirmationService();
  final RSSIStreamService _rssiStreamService = RSSIStreamService();
  
  StreamSubscription<RangingResult>? _streamRanging;
  
  // Advanced signal tracking
  final List<int> _rssiHistory = [];
  final List<DateTime> _rssiTimestamps = [];
  Timer? _movementDetectionTimer;
  Timer? _provisionalTimer;
  Timer? _confirmationTimer;
  
  // Attendance state tracking
  String _currentAttendanceState = 'scanning'; // scanning, provisional, confirmed, failed
  Function(String, String, String)? _onAttendanceStateChanged;
  
  // Track current RSSI for streaming
  int? _currentRssi;
  String? _currentStudentId;
  String? _currentClassId;
  
  // NEW: Cooldown tracking to prevent duplicate check-ins
  DateTime? _lastCheckInTime;
  String? _lastCheckedStudentId;
  String? _lastCheckedClassId;

  Future<void> initializeBeaconScanning() async {
    // Request permissions first
    await _permissionService.requestBeaconPermissions();

    try {
      // Configure faster scanning for better responsiveness
      await flutterBeacon.initializeScanning;
    } catch (e) {
      print("FATAL ERROR initializing beacon scanner: $e");
      rethrow;
    }
  }

  Stream<RangingResult> startRanging() {
    final regions = <Region>[
      Region(
        identifier: AppConstants.schoolIdentifier,
        proximityUUID: AppConstants.proximityUUID,
      ),
    ];

    return flutterBeacon.ranging(regions);
  }

  void stopRanging() {
    _streamRanging?.cancel();
    _streamRanging = null;
  }

  // 1. SIGNAL PATTERN BEHAVIOR - Fast and elastic analysis
  bool _isSignalStable(int newRssi) {
    _rssiHistory.add(newRssi);
    _rssiTimestamps.add(DateTime.now());
    
    // Keep only recent readings (last 5 seconds for speed)
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 5));
    while (_rssiTimestamps.isNotEmpty && _rssiTimestamps.first.isBefore(cutoffTime)) {
      _rssiHistory.removeAt(0);
      _rssiTimestamps.removeAt(0);
    }
    
    // Very permissive - need only 2 readings (faster response)
    if (_rssiHistory.length < AppConstants.minimumReadingsForStability) {
      return _rssiHistory.isNotEmpty; // Even 1 reading is acceptable
    }
    
    // Calculate variance in signal strength - much more tolerant
    final average = _rssiHistory.reduce((a, b) => a + b) / _rssiHistory.length;
    final variance = _rssiHistory.map((rssi) => (rssi - average).abs()).reduce((a, b) => a + b) / _rssiHistory.length;
    
    print("Signal analysis - RSSI: $newRssi, Average: ${average.toStringAsFixed(1)}, Variance: ${variance.toStringAsFixed(1)}");
    
    return variance <= AppConstants.rssiVarianceThreshold; // Now 25 instead of 15
  }

  // 2. MOVEMENT DETECTION - Allow natural classroom movement (elastic)
  bool _isStudentInClassroom() {
    if (_rssiHistory.length < 2) return true; // Be permissive initially
    
    // Much more elastic - allow significant movement within classroom
    final recentReadings = _rssiHistory.take(3).toList();
    final maxDiff = recentReadings.reduce((a, b) => a > b ? a : b) - recentReadings.reduce((a, b) => a < b ? a : b);
    
    final inClassroom = maxDiff <= 20; // Allow 20 dBm variation (walking around)
    print("Movement detection - Max RSSI diff: $maxDiff, In classroom: $inClassroom");
    return inClassroom;
  }

  // 3. TWO-STAGE ATTENDANCE SYSTEM - Now with backend integration
  void _startTwoStageAttendance(String studentId, String classId) {
    if (_currentAttendanceState != 'scanning') {
      print('⏸️ Check-in blocked: Already processing attendance (state: $_currentAttendanceState)');
      return;
    }
    
    // NEW: Check cooldown to prevent duplicate check-ins
    if (_lastCheckInTime != null && 
        _lastCheckedStudentId == studentId && 
        _lastCheckedClassId == classId) {
      final timeSinceLastCheckIn = DateTime.now().difference(_lastCheckInTime!);
      // Use 15 minutes cooldown (900 seconds)
      if (timeSinceLastCheckIn < const Duration(minutes: 15)) {
        final minutesRemaining = 15 - timeSinceLastCheckIn.inMinutes;
        print('⏳ Cooldown active: $minutesRemaining minutes remaining for $studentId in $classId');
        print('⏳ Last check-in was at: $_lastCheckInTime');
        
        // Notify UI with a positive cooldown message - FIX: Pass state first
        if (_onAttendanceStateChanged != null && _currentAttendanceState == 'scanning') {
          _onAttendanceStateChanged!(
            'cooldown',  // ← FIXED: state comes first
            studentId,
            classId
          );
          // Set state to prevent repeated messages
          _currentAttendanceState = 'cooldown';
        }
        return;
      }
    }
    
    // Record this check-in time
    _lastCheckInTime = DateTime.now();
    _lastCheckedStudentId = studentId;
    _lastCheckedClassId = classId;
    print('✅ Cooldown check passed - proceeding with check-in at $_lastCheckInTime');
    
    // Store current state
    _currentStudentId = studentId;
    _currentClassId = classId;
    
    // Stage 1: Provisional attendance
    _currentAttendanceState = 'provisional';
    _onAttendanceStateChanged?.call('provisional', studentId, classId);
    _logger.i("Stage 1: Provisional attendance started for student $studentId in class $classId");
    
    // Submit provisional check-in to backend
    _submitProvisionalCheckIn(studentId, classId);
    
    // OLD TWO-STAGE SYSTEM - DISABLED
    // We now use backend confirmation via AttendanceConfirmationService
    // The old _checkForConfirmation is causing "failed" status after successful check-in
    // _provisionalTimer = Timer(AppConstants.provisionalAttendanceDelay, () {
    //   if (_currentAttendanceState == 'provisional') {
    //     _checkForConfirmation(studentId, classId);
    //   }
    // });
    
    print('🎯 Provisional check-in submitted - backend will confirm after 30 seconds');
  }
  
  /// NEW: Submit provisional check-in with device ID
  Future<void> _submitProvisionalCheckIn(String studentId, String classId) async {
    try {
      // Get device ID
      final deviceId = await _deviceIdService.getDeviceId();
      final rssi = _rssiHistory.isNotEmpty ? _rssiHistory.last : -70;
      
      _logger.i('📱 Submitting check-in: Student=$studentId, Class=$classId, Device=$deviceId, RSSI=$rssi');
      
      // Call backend API
      final result = await _httpService.checkIn(
        studentId: studentId,
        classId: classId,
        deviceId: deviceId,
        rssi: rssi,
      );
      
      if (result['success'] == true) {
        final attendanceId = result['attendanceId'];
        final status = result['status'];
        
        _logger.i('✅ Check-in successful! ID: $attendanceId, Status: $status');
        
        // Only schedule confirmation if we have a valid attendance ID
        if (attendanceId != null && attendanceId != 'unknown') {
          // Schedule confirmation (30 seconds for testing, 10 minutes in production)
          _confirmationService.scheduleConfirmation(
            attendanceId: attendanceId,
            studentId: studentId,
            classId: classId,  // NEW: Pass classId
          );
          
          // Start RSSI streaming (2 minutes for testing, 15 minutes in production)
          _rssiStreamService.startStreaming(
            studentId: studentId,
            classId: classId,
            sessionDate: DateTime.now(),
          );
          
          _logger.i('📡 RSSI streaming started for co-location detection');
        } else {
          _logger.w('⚠️ Attendance ID is null/unknown, skipping confirmation scheduling');
        }
      } else if (result['error'] == 'DEVICE_MISMATCH') {
        // CRITICAL: Device mismatch detected
        _logger.e('🔒 DEVICE MISMATCH: ${result['message']}');
        _currentAttendanceState = 'failed';
        _onAttendanceStateChanged?.call('device_mismatch', studentId, classId);
        // TODO: Show alert dialog to user
      } else {
        _logger.e('❌ Check-in failed: ${result['message']}');
        _currentAttendanceState = 'failed';
        _onAttendanceStateChanged?.call('failed', studentId, classId);
      }
    } catch (e) {
      _logger.e('❌ Error submitting check-in: $e');
      _currentAttendanceState = 'failed';
      _onAttendanceStateChanged?.call('failed', studentId, classId);
    }
  }

  void _checkForConfirmation(String studentId, String classId) {
    // Stage 2: Check if student is still present in classroom
    if (_isStudentInClassroom() && _rssiHistory.isNotEmpty && _rssiHistory.last > AppConstants.rssiThreshold) {
      _currentAttendanceState = 'confirmed';
      _onAttendanceStateChanged?.call('confirmed', studentId, classId);
      print("Stage 2: Attendance confirmed for student $studentId in class $classId");
      
      // Stop scanning after confirmation
      _confirmationTimer = Timer(AppConstants.confirmationWindow, () {
        _resetAttendanceState();
      });
    } else {
      _currentAttendanceState = 'failed';
      _onAttendanceStateChanged?.call('failed', studentId, classId);
      print("Stage 2: Attendance failed - student moved or signal weak");
      _resetAttendanceState();
    }
  }

  void _resetAttendanceState() {
    _currentAttendanceState = 'scanning';
    _provisionalTimer?.cancel();
    _confirmationTimer?.cancel();
    _movementDetectionTimer?.cancel();
    _rssiHistory.clear();
    _rssiTimestamps.clear();
    _currentStudentId = null;
    _currentClassId = null;
    _currentRssi = null;
    // DON'T clear cooldown tracking - preserve it:
    // _lastCheckInTime, _lastCheckedStudentId, _lastCheckedClassId
    print('🔄 State reset to scanning (cooldown preserved)');
  }
  
  /// Handle confirmation success from AttendanceConfirmationService
  void _handleConfirmationSuccess(String studentId, String classId) {
    _logger.i('🎉 Attendance confirmed for $studentId in $classId');
    
    // Change state to confirmed (don't reset to scanning)
    _currentAttendanceState = 'confirmed';
    _currentStudentId = studentId;
    _currentClassId = classId;
    
    // Notify UI - FIX: Pass state first, then studentId, then classId
    if (_onAttendanceStateChanged != null) {
      _onAttendanceStateChanged!(
        'confirmed',  // ← FIXED: state comes first
        studentId,
        classId
      );
    }
    
    // After 5 seconds, reset to scanning but show a success cooldown message
    Future.delayed(const Duration(seconds: 5), () {
      if (_currentAttendanceState == 'confirmed') {
        _resetAttendanceState();
        
        // Notify UI with a persistent success message
        // Note: We use 'success' state to show custom message without triggering checkIn again
        if (_onAttendanceStateChanged != null) {
          _onAttendanceStateChanged!(
            'success',  // ← FIXED: state comes first
            studentId,
            classId
          );
        }
      }
    });
  }
  
  /// Handle confirmation failure from AttendanceConfirmationService  
  void _handleConfirmationFailure(String studentId, String classId) {
    _logger.e('❌ Attendance confirmation failed for $studentId in $classId');
    
    // Change state to failed
    _currentAttendanceState = 'failed';
    
    // Notify UI
    if (_onAttendanceStateChanged != null) {
      _onAttendanceStateChanged!(
        studentId,
        classId,
        '❌ Check-in failed. Please try again.'
      );
    }
    
    // Reset after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _resetAttendanceState();
    });
  }
  
  /// Get current RSSI value (for RSSI streaming service)
  int? getCurrentRssi() {
    return _currentRssi;
  }

  // Enhanced beacon detection with all advanced features
  bool analyzeBeacon(Beacon beacon, String studentId, String classId) {
    final rssi = beacon.rssi;
    
    // Store current RSSI for streaming
    _currentRssi = rssi;
    
    // DON'T RESET if we're in confirmed state (let the 5-second delay handle it)
    if (_currentAttendanceState == 'confirmed') {
      _logger.i('✅ Attendance confirmed for $studentId in $classId');
      _logger.i('✅ Confirmation complete - status remains locked');
      return true; // Already confirmed, don't process further
    }
    
    // DON'T RESET if we're in cooldown state (show persistent success message)
    if (_currentAttendanceState == 'cooldown') {
      // Cooldown message already shown, just return
      return true; // Already processed, cooldown active
    }
    
    // Basic range check (only reset if NOT confirmed)
    if (rssi <= AppConstants.rssiThreshold) {
      // Only reset if we're not awaiting confirmation
      if (_currentAttendanceState != 'provisional') {
        _resetAttendanceState();
      }
      return false;
    }
    
    // FAST TRACK: If signal is very strong and stable (stationary scenario)
    _rssiHistory.add(rssi);
    _rssiTimestamps.add(DateTime.now());
    
    // Clean old readings
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 5));
    while (_rssiTimestamps.isNotEmpty && _rssiTimestamps.first.isBefore(cutoffTime)) {
      _rssiHistory.removeAt(0);
      _rssiTimestamps.removeAt(0);
    }
    
    // INSTANT ATTENDANCE for strong, stable signals (stationary users)
    if (rssi > -60 && _rssiHistory.length >= 2) { // Very close and stable
      final recentReadings = _rssiHistory.take(2).toList();
      final variance = (recentReadings[0] - recentReadings[1]).abs();
      
      if (variance <= 5) { // Very stable = stationary
        print("FAST TRACK: Strong stable signal detected (RSSI: $rssi, variance: $variance)");
        if (_currentAttendanceState == 'scanning') {
          _currentAttendanceState = 'confirmed';
          _onAttendanceStateChanged?.call('confirmed', studentId, classId);
          return true;
        }
      }
    }
    
    // REGULAR FLOW: For moving users or weaker signals
    if (!_isSignalStable(rssi)) {
      print("Signal not stable yet, continuing analysis...");
      return false;
    }
    
    // Movement detection - ensure student is in classroom (elastic)
    if (!_isStudentInClassroom()) {
      print("Student appears to be outside classroom range...");
      return false;
    }
    
    // Start two-stage attendance if all checks pass
    if (_currentAttendanceState == 'scanning') {
      _startTwoStageAttendance(studentId, classId);
    }
    
    return _currentAttendanceState == 'confirmed';
  }

  // Legacy method for backward compatibility
  bool isBeaconInRange(Beacon beacon) {
    return beacon.rssi > AppConstants.rssiThreshold;
  }

  String getClassIdFromBeacon(Beacon beacon) {
    return beacon.minor.toString();
  }

  // Set callback for attendance state changes
  void setOnAttendanceStateChanged(Function(String state, String studentId, String classId) callback) {
    _onAttendanceStateChanged = callback;
  }
  
  // NEW: Clear cooldown (useful for testing or manual reset)
  void clearCooldown() {
    _lastCheckInTime = null;
    _lastCheckedStudentId = null;
    _lastCheckedClassId = null;
    print('🔄 Cooldown cleared - check-ins allowed immediately');
  }
  
  // NEW: Get cooldown info
  Map<String, dynamic>? getCooldownInfo() {
    if (_lastCheckInTime == null) return null;
    
    final timeSinceLastCheckIn = DateTime.now().difference(_lastCheckInTime!);
    final minutesRemaining = 15 - timeSinceLastCheckIn.inMinutes;
    
    return {
      'lastCheckInTime': _lastCheckInTime!.toIso8601String(),
      'studentId': _lastCheckedStudentId,
      'classId': _lastCheckedClassId,
      'minutesRemaining': minutesRemaining > 0 ? minutesRemaining : 0,
      'isActive': minutesRemaining > 0,
    };
  }

  void dispose() {
    _resetAttendanceState();
    stopRanging();
    _confirmationService.dispose();
    _rssiStreamService.dispose();
  }
}