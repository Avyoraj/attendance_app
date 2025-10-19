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
  
  // 🎯 NEW: RSSI Smoothing buffer (for noise reduction)
  final List<int> _rssiSmoothingBuffer = [];
  final List<DateTime> _rssiSmoothingTimestamps = [];
  
  // 🎯 NEW: Exit Hysteresis tracking (prevents false cancellations)
  DateTime? _weakSignalStartTime;
  bool _isInGracePeriod = false;
  int? _lastKnownGoodRssi; // Cache last valid smoothed RSSI for grace period
  
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
    _logger.e('   Reason: Student left classroom during waiting period (out of beacon range)');
    
    // Change state to 'cancelled' (different from 'failed')
    _currentAttendanceState = 'cancelled';
    
    // Notify UI with 'cancelled' state
    if (_onAttendanceStateChanged != null) {
      _onAttendanceStateChanged!('cancelled', studentId, classId);
    }
    
    // Reset after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _resetAttendanceState();
    });
  }
  
  /// Get current RSSI value (for RSSI streaming service)
  /// ✅ ENHANCED: Returns smoothed RSSI with exit hysteresis (prevents false cancellations)
  int? getCurrentRssi() {
    final now = DateTime.now();
    
    // 1. Check if we have any RSSI data
    if (_rssiSmoothingBuffer.isEmpty) {
      _logger.w('⚠️ No beacon data available');
      return null;
    }
    
    // 2. Calculate time since last RSSI sample (use most recent sample timestamp)
    // This is MORE reliable than _lastBeaconTimestamp because samples are added
    // even when analyzeBeacon() isn't called (beacon detection is intermittent)
    final mostRecentSampleTime = _rssiSmoothingTimestamps.isNotEmpty 
        ? _rssiSmoothingTimestamps.last 
        : null;
    
    if (mostRecentSampleTime == null) {
      _logger.w('⚠️ No recent RSSI samples available');
      return null;
    }
    
    final timeSinceLastBeacon = now.difference(mostRecentSampleTime);
    
    // 3. EXIT HYSTERESIS LOGIC (prevents false cancellations from body movement)
    if (timeSinceLastBeacon > AppConstants.beaconLostTimeout) {
      // Beacon not seen for 45+ seconds - might be temporary (body blocking signal)
      
      if (_weakSignalStartTime == null) {
        // First time detecting weak signal - START grace period
        _weakSignalStartTime = now;
        _isInGracePeriod = true;
        _logger.w('⚠️ Beacon weak for ${timeSinceLastBeacon.inSeconds}s - Starting ${AppConstants.exitGracePeriod.inSeconds}s grace period');
        _logger.w('   Reason: Could be body movement/phone rotation - not cancelling yet');
        
        // Return last known good RSSI (don't call _getSmoothedRssi as it clears old samples)
        return _lastKnownGoodRssi ?? _currentRssi;
      }
      
      // Calculate how long we've been in weak signal state
      final weakDuration = now.difference(_weakSignalStartTime!);
      
      if (weakDuration <= AppConstants.exitGracePeriod) {
        // Still within grace period - DON'T cancel attendance
        final remainingSeconds = AppConstants.exitGracePeriod.inSeconds - weakDuration.inSeconds;
        _logger.w('⏳ Grace period active: ${remainingSeconds}s remaining (weak for ${weakDuration.inSeconds}s)');
        
        // Return last known good RSSI (cached before grace period started)
        return _lastKnownGoodRssi ?? _currentRssi;
      } else {
        // Grace period expired - student ACTUALLY left
        _logger.e('❌ Beacon lost for ${weakDuration.inSeconds}s (grace period: ${AppConstants.exitGracePeriod.inSeconds}s)');
        _logger.e('   Student has left the classroom - clearing RSSI');
        
        // Clear stale data
        _currentRssi = null;
        _rssiSmoothingBuffer.clear();
        _rssiSmoothingTimestamps.clear();
        _weakSignalStartTime = null;
        _isInGracePeriod = false;
        _lastKnownGoodRssi = null;
        
        return null; // Truly lost - cancel attendance
      }
    }
    
    // 4. Signal is GOOD - reset grace period tracking
    if (_weakSignalStartTime != null) {
      _logger.i('✅ Beacon signal restored (was weak for ${now.difference(_weakSignalStartTime!).inSeconds}s)');
      _weakSignalStartTime = null;
      _isInGracePeriod = false;
    }
    
    // 5. Return smoothed RSSI (reduces noise)
    final smoothedRssi = _getSmoothedRssi();
    if (smoothedRssi != null) {
      _lastKnownGoodRssi = smoothedRssi; // Cache for grace period use
    }
    return smoothedRssi;
  }
  
  /// 🎯 NEW: Get smoothed RSSI using moving average (reduces noise from body movement)
  int? _getSmoothedRssi() {
    if (_rssiSmoothingBuffer.isEmpty) return _currentRssi;
    
    // Clean old samples (older than 10 seconds)
    final now = DateTime.now();
    final cutoff = now.subtract(AppConstants.rssiSampleMaxAge);
    
    while (_rssiSmoothingTimestamps.isNotEmpty && 
           _rssiSmoothingTimestamps.first.isBefore(cutoff)) {
      _rssiSmoothingBuffer.removeAt(0);
      _rssiSmoothingTimestamps.removeAt(0);
    }
    
    if (_rssiSmoothingBuffer.isEmpty) return _currentRssi;
    
    // Calculate moving average of recent samples
    final windowSize = _rssiSmoothingBuffer.length < AppConstants.rssiSmoothingWindow
        ? _rssiSmoothingBuffer.length
        : AppConstants.rssiSmoothingWindow;
    
    final recentSamples = _rssiSmoothingBuffer.sublist(
      _rssiSmoothingBuffer.length - windowSize
    );
    
    final smoothedRssi = recentSamples.reduce((a, b) => a + b) ~/ windowSize;
    
    _logger.d('📊 RSSI Smoothing: Raw=${_currentRssi}, Smoothed=$smoothedRssi (avg of $windowSize samples)');
    
    return smoothedRssi;
  }
  
  /// 🎯 NEW: Add RSSI sample to smoothing buffer
  void _addRssiSample(int rssi) {
    _rssiSmoothingBuffer.add(rssi);
    _rssiSmoothingTimestamps.add(DateTime.now());
    
    // Keep buffer size manageable (2x window size)
    final maxBufferSize = AppConstants.rssiSmoothingWindow * 2;
    if (_rssiSmoothingBuffer.length > maxBufferSize) {
      _rssiSmoothingBuffer.removeAt(0);
      _rssiSmoothingTimestamps.removeAt(0);
    }
  }
  
  /// 🎯 PUBLIC: Allow external services to feed RSSI samples (like RSSIStreamService)
  /// This prevents buffer expiry during confirmation wait when ranging is blocked
  void feedRssiSample(int rssi) {
    _currentRssi = rssi;
    _addRssiSample(rssi);
    _logger.d('📥 External RSSI sample fed: $rssi dBm (Buffer: ${_rssiSmoothingBuffer.length})');
  }
  
  /// 🔴 CRITICAL: Get raw RSSI data WITHOUT grace period fallback
  /// Used for final confirmation check to prevent false confirmations
  /// This bypasses the exit hysteresis logic that caches old "good" values
  Map<String, dynamic> getRawRssiData() {
    final now = DateTime.now();
    
    // Get most recent RSSI timestamp
    final mostRecentTime = _rssiSmoothingTimestamps.isNotEmpty 
        ? _rssiSmoothingTimestamps.last 
        : null;
    
    // Calculate RSSI age
    final rssiAge = mostRecentTime != null 
        ? now.difference(mostRecentTime) 
        : null;
    
    return {
      'rssi': _currentRssi, // Real current RSSI (NOT cached _lastKnownGoodRssi)
      'timestamp': mostRecentTime,
      'ageSeconds': rssiAge?.inSeconds,
      'bufferSize': _rssiSmoothingBuffer.length,
      'isInGracePeriod': _isInGracePeriod, // Flag if we're using cached values
    };
  }

  // Enhanced beacon detection with all advanced features
  bool analyzeBeacon(Beacon beacon, String studentId, String classId) {
    final rssi = beacon.rssi;
    
    // Store current RSSI for streaming
    _currentRssi = rssi;
    
    // 🎯 NEW: Add RSSI sample to smoothing buffer (reduces noise)
    // This also updates _rssiSmoothingTimestamps which getCurrentRssi() uses
    _addRssiSample(rssi);
    
    // Get smoothed RSSI for more stable decision-making
    final smoothedRssi = _getSmoothedRssi() ?? rssi;
    
    _logger.d('🔍 Beacon Analysis: Raw=$rssi, Smoothed=$smoothedRssi, State=$_currentAttendanceState');
    
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
    
    // 🎯 ENHANCED: Use dual-threshold system
    // - Stricter threshold for CHECK-IN (must be close)
    // - Lenient threshold for CONFIRMATION (can move around slightly)
    final thresholdToUse = _currentAttendanceState == 'scanning'
        ? AppConstants.checkInRssiThreshold  // -75 dBm (strict entry)
        : AppConstants.confirmationRssiThreshold; // -82 dBm (lenient staying)
    
    _logger.d('📏 Using threshold: $thresholdToUse (state: $_currentAttendanceState)');
    
    // Basic range check using SMOOTHED RSSI
    if (smoothedRssi <= thresholdToUse) {
      _logger.d('⚠️ Smoothed RSSI ($smoothedRssi) below threshold ($thresholdToUse)');
      // Only reset if we're not awaiting confirmation
      if (_currentAttendanceState != 'provisional') {
        _resetAttendanceState();
      }
      return false;
    }
    
    // FAST TRACK: If signal is very strong and stable (stationary scenario)
    // Use raw RSSI for fast track (already added to smoothing buffer above)
    _rssiHistory.add(rssi);
    _rssiTimestamps.add(DateTime.now());
    
    // Clean old readings
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 5));
    while (_rssiTimestamps.isNotEmpty && _rssiTimestamps.first.isBefore(cutoffTime)) {
      _rssiHistory.removeAt(0);
      _rssiTimestamps.removeAt(0);
    }
    
    // INSTANT ATTENDANCE for strong, stable signals (stationary users)
    // 🎯 Use smoothed RSSI for stability check
    if (smoothedRssi > -60 && _rssiHistory.length >= 2) { // Very close and stable
      final recentReadings = _rssiHistory.take(2).toList();
      final variance = (recentReadings[0] - recentReadings[1]).abs();
      
      if (variance <= 5) { // Very stable = stationary
        _logger.i("⚡ FAST TRACK: Strong stable signal detected (Smoothed RSSI: $smoothedRssi, variance: $variance)");
        if (_currentAttendanceState == 'scanning') {
          _currentAttendanceState = 'confirmed';
          _onAttendanceStateChanged?.call('confirmed', studentId, classId);
          return true;
        }
      }
    }
    
    // REGULAR FLOW: For moving users or weaker signals
    // 🎯 Use smoothed RSSI for stability check
    if (!_isSignalStable(smoothedRssi)) {
      _logger.d("Signal not stable yet, continuing analysis...");
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

  /// 🎯 NEW: Sync attendance state from backend (called on app startup/login)
  /// This prevents "already checked in" confusion by restoring state from backend
  Future<Map<String, dynamic>> syncStateFromBackend(String studentId) async {
    try {
      _logger.i('🔄 Syncing attendance state from backend for student: $studentId');
      
      // Fetch today's attendance from backend
      final result = await _httpService.getTodayAttendance(studentId: studentId);
      
      if (result['success'] != true) {
        _logger.e('❌ Failed to sync state: ${result['error']}');
        return {
          'success': false,
          'error': result['error'],
          'synced': 0,
        };
      }
      
      final attendance = result['attendance'] as List;
      _logger.i('📥 Received ${attendance.length} attendance records from backend');
      
      int syncedCount = 0;
      
      for (var record in attendance) {
        final classId = record['classId'] as String;
        final status = record['status'] as String;
        
        _logger.i('   Class $classId: $status');
        
        if (status == 'confirmed') {
          // Restore cooldown for confirmed attendance
          final confirmedAt = record['confirmedAt'] != null 
              ? DateTime.parse(record['confirmedAt'] as String)
              : null;
          
          if (confirmedAt != null) {
            // Set cooldown tracking
            _lastCheckInTime = confirmedAt;
            _lastCheckedStudentId = studentId;
            _lastCheckedClassId = classId;
            
            final timeSinceConfirmation = DateTime.now().difference(confirmedAt);
            final minutesRemaining = 15 - timeSinceConfirmation.inMinutes;
            
            if (minutesRemaining > 0) {
              _logger.i('   ✅ Restored cooldown: $minutesRemaining minutes remaining');
              syncedCount++;
            } else {
              _logger.i('   ⏰ Cooldown expired (${timeSinceConfirmation.inMinutes} minutes ago)');
            }
          }
        } else if (status == 'provisional') {
          // Resume provisional countdown if still valid
          final remainingSeconds = record['remainingSeconds'] as int? ?? 0;
          final attendanceId = record['attendanceId'] as String?;
          
          if (remainingSeconds > 0 && attendanceId != null) {
            _logger.i('   ⏱️ Resuming provisional countdown: ${remainingSeconds}s remaining');
            
            // Set state to provisional
            _currentAttendanceState = 'provisional';
            _currentStudentId = studentId;
            _currentClassId = classId;
            
            // Schedule confirmation with remaining time
            _confirmationService.scheduleConfirmation(
              attendanceId: attendanceId,
              studentId: studentId,
              classId: classId,
            );
            
            // Restart RSSI streaming for co-location detection
            _rssiStreamService.startStreaming(
              studentId: studentId,
              classId: classId,
              sessionDate: DateTime.now(),
            );
            
            _logger.i('   📡 RSSI streaming restarted for provisional attendance');
            syncedCount++;
            
            // Notify UI about provisional state
            _onAttendanceStateChanged?.call('provisional', studentId, classId);
          } else if (record['shouldConfirm'] == true) {
            // Provisional time expired - should have been confirmed
            _logger.w('   ⚠️ Provisional expired - backend should confirm/cancel');
          }
        } else if (status == 'cancelled') {
          // 🔴 FIX: Clear cooldown for cancelled attendance
          // Cancelled attendance should NOT trigger cooldown - user can try again!
          _logger.i('   ❌ Found cancelled attendance - clearing cooldown');
          
          // Clear cooldown tracking so user can check in again
          _lastCheckInTime = null;
          _lastCheckedStudentId = null;
          _lastCheckedClassId = null;
          
          syncedCount++;
        }
      }
      
      _logger.i('✅ State sync complete: $syncedCount records synced');
      
      return {
        'success': true,
        'synced': syncedCount,
        'total': attendance.length,
        'attendance': attendance,
      };
    } catch (e) {
      _logger.e('❌ State sync error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'synced': 0,
      };
    }
  }

  void dispose() {
    _resetAttendanceState();
    stopRanging();
    _confirmationService.dispose();
    _rssiStreamService.dispose();
  }
}