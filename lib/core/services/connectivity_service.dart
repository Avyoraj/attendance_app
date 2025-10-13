import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'logger_service.dart';

/// Service to monitor internet connectivity
/// Provides real-time connection status updates
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final LoggerService _logger = LoggerService();
  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isOnline = false;
  bool get isOnline => _isOnline;
  
  /// Stream of connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity status
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
    
    _logger.info('Connectivity service initialized');
  }

  Future<void> _checkConnectivity() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e, stackTrace) {
      _logger.error('Error checking connectivity', e, stackTrace);
      _updateConnectionStatus(false);
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // Check if any connection type is available (WiFi, Mobile, etc.)
    _isOnline = results.any((result) => 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet
    );
    
    // Only log and notify if status actually changed
    if (wasOnline != _isOnline) {
      _updateConnectionStatus(_isOnline);
    }
  }

  void _updateConnectionStatus(bool isOnline) {
    _isOnline = isOnline;
    _logger.networkStatus(isOnline);
    _connectionController.add(isOnline);
  }

  /// Manually check if internet is available
  Future<bool> checkConnection() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      final isConnected = results.any((result) => 
        result == ConnectivityResult.wifi || 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet
      );
      
      _updateConnectionStatus(isConnected);
      return isConnected;
    } catch (e, stackTrace) {
      _logger.error('Error checking connection', e, stackTrace);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
    _logger.info('Connectivity service disposed');
  }
}
