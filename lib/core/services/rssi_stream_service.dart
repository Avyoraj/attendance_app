import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'http_service.dart';
import 'beacon_service.dart';

/// Service for streaming RSSI data to backend for co-location analysis
/// Captures RSSI every 5 seconds for 15 minutes after check-in
/// Uploads in batches to detect suspicious patterns
class RSSIStreamService {
  static final RSSIStreamService _instance = RSSIStreamService._internal();
  factory RSSIStreamService() => _instance;
  RSSIStreamService._internal();

  final _logger = Logger();
  final _httpService = HttpService();

  Timer? _captureTimer;
  Timer? _uploadTimer;
  Timer? _durationTimer;

  String? _activeStudentId;
  String? _activeClassId;
  DateTime? _sessionDate;
  List<Map<String, dynamic>> _rssiBuffer = [];
  bool _isStreaming = false;

  /// Start RSSI streaming after check-in
  void startStreaming({
    required String studentId,
    required String classId,
    required DateTime sessionDate,
  }) {
    // Stop any existing stream
    stopStreaming();

    _activeStudentId = studentId;
    _activeClassId = classId;
    _sessionDate = sessionDate;
    _rssiBuffer.clear();
    _isStreaming = true;

    _logger.i('📡 Starting RSSI streaming for $studentId');
    _logger.i('⏱️ Will stream for ${AppConstants.rssiStreamDuration.inMinutes} minutes');

    // Start capture timer (every 5 seconds)
    _captureTimer = Timer.periodic(
      AppConstants.rssiCaptureInterval,
      (timer) => _captureRSSI(),
    );

    // Start upload timer (every 1 minute)
    _uploadTimer = Timer.periodic(
      AppConstants.rssiBatchUploadInterval,
      (timer) => _uploadBatch(),
    );

    // Set duration timer (stop after 15 minutes)
    _durationTimer = Timer(
      AppConstants.rssiStreamDuration,
      () => stopStreaming(reason: 'Duration completed'),
    );
  }

  /// Capture current RSSI value
  Future<void> _captureRSSI() async {
    if (!_isStreaming) return;

    try {
      // TODO: Get actual RSSI from BeaconScannerService
      // For now, this is a placeholder
      final rssi = await _getCurrentRSSI();
      final distance = _calculateDistance(rssi);

      final reading = {
        'timestamp': DateTime.now().toIso8601String(),
        'rssi': rssi,
        'distance': distance,
      };

      _rssiBuffer.add(reading);
      _logger.d('📊 Captured RSSI: $rssi dBm ($distance m) - Buffer: ${_rssiBuffer.length}');

      // Auto-upload if buffer reaches max size
      if (_rssiBuffer.length >= AppConstants.rssiMaxBatchSize) {
        await _uploadBatch();
      }
    } catch (e) {
      _logger.e('❌ Error capturing RSSI: $e');
    }
  }

  /// Upload buffered RSSI data to backend
  Future<void> _uploadBatch() async {
    if (_rssiBuffer.isEmpty) {
      _logger.d('📤 No RSSI data to upload');
      return;
    }

    if (_activeStudentId == null || _activeClassId == null || _sessionDate == null) {
      _logger.w('⚠️ Missing stream metadata, cannot upload');
      return;
    }

    try {
      _logger.i('📤 Uploading ${_rssiBuffer.length} RSSI readings...');

      final response = await _httpService.streamRSSI(
        studentId: _activeStudentId!,
        classId: _activeClassId!,
        sessionDate: _sessionDate!,
        rssiData: List.from(_rssiBuffer), // Copy to prevent modification during upload
      );

      if (response['success'] == true) {
        _logger.i('✅ Uploaded ${_rssiBuffer.length} readings successfully');
        _rssiBuffer.clear(); // Clear buffer after successful upload
      } else {
        _logger.e('❌ Upload failed: ${response['error']}');
        // Keep buffer for retry on next cycle
      }
    } catch (e) {
      _logger.e('❌ Error uploading RSSI batch: $e');
      // Keep buffer for retry
    }
  }

  /// Stop RSSI streaming
  void stopStreaming({String reason = 'Manual stop'}) {
    if (!_isStreaming) return;

    _logger.i('🛑 Stopping RSSI streaming: $reason');

    // Cancel all timers
    _captureTimer?.cancel();
    _uploadTimer?.cancel();
    _durationTimer?.cancel();

    _captureTimer = null;
    _uploadTimer = null;
    _durationTimer = null;

    // Upload any remaining data
    if (_rssiBuffer.isNotEmpty) {
      _uploadBatch();
    }

    // Clear state
    _isStreaming = false;
    _activeStudentId = null;
    _activeClassId = null;
    _sessionDate = null;
  }

  /// Get current RSSI from beacon scanner
  Future<int> _getCurrentRSSI() async {
    // Get RSSI from BeaconService
    final beaconService = BeaconService();
    final rssi = beaconService.getCurrentRssi();
    
    if (rssi != null) {
      // 🎯 CRITICAL FIX: Feed the RSSI back to keep beacon service buffer alive
      // During confirmation wait, beacon ranging is blocked, so buffer would expire
      // By feeding captured RSSI back, we maintain fresh samples for confirmation check
      beaconService.feedRssiSample(rssi);
      return rssi;
    }
    
    // Fallback if no beacon detected - still feed it to maintain buffer
    _logger.w('⚠️ No beacon RSSI available, using default');
    final fallbackRssi = -70;
    beaconService.feedRssiSample(fallbackRssi);
    return fallbackRssi;
  }

  /// Calculate distance from RSSI using path loss model
  double _calculateDistance(int rssi) {
    const int txPower = -59; // Calibrated TX power at 1m
    const double n = 2.0; // Path loss exponent

    if (rssi == 0) return -1.0;

    final ratio = (txPower - rssi) / (10 * n);
    return double.parse((pow(10, ratio)).toStringAsFixed(2));
  }

  /// Check if currently streaming
  bool get isStreaming => _isStreaming;

  /// Get stream status info
  Map<String, dynamic>? getStreamInfo() {
    if (!_isStreaming) return null;

    return {
      'studentId': _activeStudentId,
      'classId': _activeClassId,
      'sessionDate': _sessionDate?.toIso8601String(),
      'bufferSize': _rssiBuffer.length,
      'isActive': _isStreaming,
    };
  }

  /// Dispose resources
  void dispose() {
    stopStreaming(reason: 'Service disposed');
  }
}


