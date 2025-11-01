import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Centralized state management for the attendance app
/// Uses Provider pattern for reactive state updates
class AttendanceState extends ChangeNotifier {
  // Core attendance state
  String _beaconStatus = 'scanning';
  bool _isCheckingIn = false;
  bool _isAwaitingConfirmation = false;
  int? _remainingSeconds;
  Map<String, dynamic>? _cooldownInfo;
  String? _currentClassId;
  String? _studentId;

  // UI state
  bool _showBatteryCard = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String get beaconStatus => _beaconStatus;
  bool get isCheckingIn => _isCheckingIn;
  bool get isAwaitingConfirmation => _isAwaitingConfirmation;
  int? get remainingSeconds => _remainingSeconds;
  Map<String, dynamic>? get cooldownInfo => _cooldownInfo;
  String? get currentClassId => _currentClassId;
  String? get studentId => _studentId;
  bool get showBatteryCard => _showBatteryCard;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // State update methods
  void updateBeaconStatus(String status) {
    if (_beaconStatus != status) {
      _beaconStatus = status;
      notifyListeners();
    }
  }

  void setCheckingIn(bool checkingIn) {
    if (_isCheckingIn != checkingIn) {
      _isCheckingIn = checkingIn;
      notifyListeners();
    }
  }

  void setAwaitingConfirmation(bool awaiting) {
    if (_isAwaitingConfirmation != awaiting) {
      _isAwaitingConfirmation = awaiting;
      notifyListeners();
    }
  }

  void updateRemainingSeconds(int? seconds) {
    if (_remainingSeconds != seconds) {
      _remainingSeconds = seconds;
      notifyListeners();
    }
  }

  void updateCooldownInfo(Map<String, dynamic>? info) {
    _cooldownInfo = info;
    notifyListeners();
  }

  void setCurrentClassId(String? classId) {
    if (_currentClassId != classId) {
      _currentClassId = classId;
      notifyListeners();
    }
  }

  void setStudentId(String? studentId) {
    if (_studentId != studentId) {
      _studentId = studentId;
      notifyListeners();
    }
  }

  void setShowBatteryCard(bool show) {
    if (_showBatteryCard != show) {
      _showBatteryCard = show;
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void setError(String? error) {
    if (_errorMessage != error) {
      _errorMessage = error;
      notifyListeners();
    }
  }

  // Reset methods
  void resetToScanning() {
    _beaconStatus = 'scanning';
    _isCheckingIn = false;
    _isAwaitingConfirmation = false;
    _remainingSeconds = null;
    _currentClassId = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Utility methods
  bool get isStatusLocked {
    return ['cooldown', 'device_locked', 'cancelled'].contains(_beaconStatus.toLowerCase());
  }

  bool get isInProvisionalState {
    return ['provisional_check_in', 'confirming'].contains(_beaconStatus.toLowerCase());
  }

  String getFormattedRemainingTime() {
    if (_remainingSeconds == null) return '';
    
    final minutes = _remainingSeconds! ~/ 60;
    final seconds = _remainingSeconds! % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // State validation
  bool get isValidState {
    return _studentId != null && _studentId!.isNotEmpty;
  }

}

/// Provider wrapper for easy access
class AttendanceProvider extends StatelessWidget {
  final Widget child;
  final AttendanceState? attendanceState;

  const AttendanceProvider({
    super.key,
    required this.child,
    this.attendanceState,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AttendanceState>(
      create: (_) => attendanceState ?? AttendanceState(),
      child: child,
    );
  }
}

/// Extension for easy access to AttendanceState
extension AttendanceStateExtension on BuildContext {
  AttendanceState get attendanceState => Provider.of<AttendanceState>(this, listen: false);
  AttendanceState get attendanceStateWatch => Provider.of<AttendanceState>(this);
}