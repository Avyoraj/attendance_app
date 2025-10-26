import 'package:logger/logger.dart';
import '../../constants/app_constants.dart';

/// 📊 RSSI Analyzer Module
/// 
/// Handles all RSSI (signal strength) processing including:
/// - RSSI smoothing (moving average to reduce noise)
/// - Exit hysteresis (grace period to prevent false cancellations)
/// - Signal quality analysis
/// - Raw RSSI data access (for final confirmation checks)
class BeaconRssiAnalyzer {
  final _logger = Logger();
  
  // RSSI Smoothing buffer (reduces noise from body movement)
  final List<int> _rssiSmoothingBuffer = [];
  final List<DateTime> _rssiSmoothingTimestamps = [];
  
  // Exit Hysteresis tracking (prevents false cancellations)
  DateTime? _weakSignalStartTime;
  bool _isInGracePeriod = false;
  int? _lastKnownGoodRssi; // Cache last valid smoothed RSSI for grace period
  
  // Current RSSI tracking
  int? _currentRssi;
  
  /// Feed a new RSSI sample into the analyzer
  void feedRssiSample(int rssi) {
    _currentRssi = rssi;
    _addRssiSample(rssi);
    _logger.d('📥 RSSI sample fed: $rssi dBm (Buffer: ${_rssiSmoothingBuffer.length})');
  }
  
  /// Add RSSI sample to smoothing buffer
  void _addRssiSample(int rssi) {
    _rssiSmoothingBuffer.add(rssi);
    _rssiSmoothingTimestamps.add(DateTime.now());
    
    // Keep buffer size manageable (2x window size)
    const maxBufferSize = AppConstants.rssiSmoothingWindow * 2;
    if (_rssiSmoothingBuffer.length > maxBufferSize) {
      _rssiSmoothingBuffer.removeAt(0);
      _rssiSmoothingTimestamps.removeAt(0);
    }
  }
  
  /// Get current RSSI with exit hysteresis (grace period protection)
  /// 
  /// This method prevents false attendance cancellations caused by:
  /// - Body movement blocking signal temporarily
  /// - Phone rotation
  /// - Brief signal interruptions
  /// 
  /// Returns smoothed RSSI or cached "good" RSSI during grace period
  int? getCurrentRssi() {
    final now = DateTime.now();
    
    // 1. Check if we have any RSSI data
    if (_rssiSmoothingBuffer.isEmpty) {
      _logger.w('⚠️ No beacon data available');
      return null;
    }
    
    // 2. Calculate time since last RSSI sample
    final mostRecentSampleTime = _rssiSmoothingTimestamps.isNotEmpty 
        ? _rssiSmoothingTimestamps.last 
        : null;
    
    if (mostRecentSampleTime == null) {
      _logger.w('⚠️ No recent RSSI samples available');
      return null;
    }
    
    final timeSinceLastBeacon = now.difference(mostRecentSampleTime);
    
    // 3. EXIT HYSTERESIS LOGIC (prevents false cancellations)
    if (timeSinceLastBeacon > AppConstants.beaconLostTimeout) {
      // Beacon not seen for 45+ seconds - might be temporary
      
      if (_weakSignalStartTime == null) {
        // First time detecting weak signal - START grace period
        _weakSignalStartTime = now;
        _isInGracePeriod = true;
        _logger.w('⚠️ Beacon weak for ${timeSinceLastBeacon.inSeconds}s - Starting ${AppConstants.exitGracePeriod.inSeconds}s grace period');
        _logger.w('   Reason: Could be body movement/phone rotation - not cancelling yet');
        
        // Return last known good RSSI (cached value)
        return _lastKnownGoodRssi ?? _currentRssi;
      }
      
      // Calculate how long we've been in weak signal state
      final weakDuration = now.difference(_weakSignalStartTime!);
      
      if (weakDuration <= AppConstants.exitGracePeriod) {
        // Still within grace period - DON'T cancel attendance
        final remainingSeconds = AppConstants.exitGracePeriod.inSeconds - weakDuration.inSeconds;
        _logger.w('⏳ Grace period active: ${remainingSeconds}s remaining (weak for ${weakDuration.inSeconds}s)');
        
        // Return last known good RSSI (cached before grace period)
        return _lastKnownGoodRssi ?? _currentRssi;
      } else {
        // Grace period expired - student ACTUALLY left
        _logger.e('❌ Beacon lost for ${weakDuration.inSeconds}s (grace period: ${AppConstants.exitGracePeriod.inSeconds}s)');
        _logger.e('   Student has left the classroom - clearing RSSI');
        
        // Clear stale data
        clearAllData();
        
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
  
  /// Get smoothed RSSI using moving average (reduces noise)
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
    
    _logger.d('📊 RSSI Smoothing: Raw=$_currentRssi, Smoothed=$smoothedRssi (avg of $windowSize samples)');
    
    return smoothedRssi;
  }
  
  /// Get raw RSSI data WITHOUT grace period fallback
  /// 
  /// CRITICAL: Used for final confirmation checks to prevent false confirmations
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
  
  /// Check if student is in classroom based on RSSI
  bool isStudentInClassroom() {
    final rssi = getCurrentRssi();
    if (rssi == null) return false;
    return rssi >= AppConstants.rssiThreshold;
  }
  
  /// Clear all RSSI data
  void clearAllData() {
    _currentRssi = null;
    _rssiSmoothingBuffer.clear();
    _rssiSmoothingTimestamps.clear();
    _weakSignalStartTime = null;
    _isInGracePeriod = false;
    _lastKnownGoodRssi = null;
    _logger.d('🧹 RSSI analyzer data cleared');
  }
  
  /// Check if currently in grace period
  bool get isInGracePeriod => _isInGracePeriod;
  
  /// Get current raw RSSI value
  int? get currentRssi => _currentRssi;
  
  /// Get buffer size (for debugging)
  int get bufferSize => _rssiSmoothingBuffer.length;
}
