import 'dart:async';
import 'package:flutter_beacon/flutter_beacon.dart';
import '../constants/app_constants.dart';
import 'permission_service.dart';

class BeaconService {
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal();

  final PermissionService _permissionService = PermissionService();
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

  // 3. TWO-STAGE ATTENDANCE SYSTEM
  void _startTwoStageAttendance(String studentId, String classId) {
    if (_currentAttendanceState != 'scanning') return;
    
    // Stage 1: Provisional attendance
    _currentAttendanceState = 'provisional';
    _onAttendanceStateChanged?.call('provisional', studentId, classId);
    print("Stage 1: Provisional attendance started for student $studentId in class $classId");
    
    _provisionalTimer = Timer(AppConstants.provisionalAttendanceDelay, () {
      if (_currentAttendanceState == 'provisional') {
        _checkForConfirmation(studentId, classId);
      }
    });
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
  }

  // Enhanced beacon detection with all advanced features
  bool analyzeBeacon(Beacon beacon, String studentId, String classId) {
    final rssi = beacon.rssi;
    
    // Basic range check
    if (rssi <= AppConstants.rssiThreshold) {
      _resetAttendanceState();
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

  void dispose() {
    _resetAttendanceState();
    stopRanging();
  }
}