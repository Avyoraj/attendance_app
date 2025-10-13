import 'dart:async';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'http_service.dart';
import 'logger_service.dart';
import 'alert_service.dart';
import '../constants/api_constants.dart';

/// Service to sync local attendance records with backend
/// Automatically syncs when internet becomes available
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LoggerService _logger = LoggerService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final HttpService _httpService = HttpService();
  final AlertService _alertService = AlertService();

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;

  /// Initialize sync service
  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivityService.connectionStream.listen(
      _handleConnectivityChange,
    );

    // Setup periodic sync (every 5 minutes)
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncPendingRecords(),
    );

    _logger.info('Sync service initialized');

    // Try initial sync if online
    if (_connectivityService.isOnline) {
      await syncPendingRecords();
    }
  }

  void _handleConnectivityChange(bool isOnline) {
    if (isOnline) {
      _logger.info('Internet restored - starting sync');
      syncPendingRecords();
    }
  }

  /// Sync all pending attendance records to backend
  Future<int> syncPendingRecords() async {
    if (_isSyncing) {
      _logger.debug('Sync already in progress, skipping');
      return 0;
    }

    if (!_connectivityService.isOnline) {
      _logger.debug('Cannot sync - no internet connection');
      return 0;
    }

    _isSyncing = true;
    int syncedCount = 0;

    try {
      final pendingRecords = await _localDb.getUnsyncedRecords();
      
      if (pendingRecords.isEmpty) {
        _logger.debug('No pending records to sync');
        return 0;
      }

      _logger.info('🔄 Starting sync of ${pendingRecords.length} records');

      for (final record in pendingRecords) {
        try {
          final success = await _syncSingleRecord(record);
          
          if (success) {
            await _localDb.markAsSynced(record['id'] as int);
            syncedCount++;
            _logger.debug('✓ Synced record ${record['id']}');
          } else {
            _logger.warning('✗ Failed to sync record ${record['id']}');
            // Stop syncing if we get errors (might be server issue)
            break;
          }
          
          // Small delay between requests to avoid overwhelming server
          await Future.delayed(const Duration(milliseconds: 500));
          
        } catch (e, stackTrace) {
          _logger.error('Error syncing record ${record['id']}', e, stackTrace);
          break; // Stop on error
        }
      }

      if (syncedCount > 0) {
        _logger.info('✅ Successfully synced $syncedCount records');
        await _alertService.showAttendanceSyncedNotification(syncedCount);
        
        // Cleanup old synced records
        await _localDb.cleanupOldRecords();
      }

    } catch (e, stackTrace) {
      _logger.error('Error during sync process', e, stackTrace);
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  Future<bool> _syncSingleRecord(Map<String, dynamic> record) async {
    try {
      final response = await _httpService.post(
        url: ApiConstants.checkInUrl,
        body: {
          'studentId': record['student_id'],
          'classId': record['class_id'],
          'timestamp': record['timestamp'],
          'rssi': record['rssi'],
          'distance': record['distance'],
          'offline_sync': true, // Flag to indicate this is a synced record
        },
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e, stackTrace) {
      _logger.error('Failed to sync record to server', e, stackTrace);
      return false;
    }
  }

  /// Get count of pending records waiting to sync
  Future<int> getPendingCount() async {
    return await _localDb.getPendingCount();
  }

  /// Force immediate sync
  Future<int> forceSyncNow() async {
    _logger.info('Force sync requested');
    return await syncPendingRecords();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _logger.info('Sync service disposed');
  }
}
