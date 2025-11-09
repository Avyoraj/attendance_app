import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'logger_service.dart';
import 'dart:convert';

/// Local database service for offline attendance storage
/// Stores attendance records when internet is unavailable
/// Syncs to backend when connection is restored
class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  final LoggerService _logger = LoggerService();
  Database? _database;

  static const String _tableName = 'pending_attendance';
  static const String _dbName = 'attendance_local.db';
  static const int _dbVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _logger.info('Initializing local database at: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        rssi INTEGER,
        distance REAL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    _logger.info('Local database table created');

    // Also create pending actions table on fresh installs
    await _createPendingActionsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPendingActionsTable(db);
    }
  }

  Future<void> _createPendingActionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL, -- 'confirm' | 'cancel'
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        payload TEXT, -- reserved for future use
        processed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    _logger.info('Pending actions table ensured');
  }

  /// Save attendance record locally (for offline mode)
  Future<int> saveAttendanceLocally({
    required String studentId,
    required String classId,
    required DateTime timestamp,
    int? rssi,
    double? distance,
  }) async {
    try {
      final db = await database;
      final id = await db.insert(_tableName, {
        'student_id': studentId,
        'class_id': classId,
        'timestamp': timestamp.toIso8601String(),
        'rssi': rssi,
        'distance': distance,
        'synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.info(
          '📝 Attendance saved locally: Student $studentId, Class $classId (ID: $id)');
      return id;
    } catch (e, stackTrace) {
      _logger.error('Failed to save attendance locally', e, stackTrace);
      rethrow;
    }
  }

  /// Save a pending confirmation/cancellation action when offline or server error
  Future<int> savePendingAction({
    required String actionType, // 'confirm' | 'cancel'
    required String studentId,
    required String classId,
    Map<String, dynamic>? payload,
  }) async {
    assert(actionType == 'confirm' || actionType == 'cancel');
    try {
      final db = await database;
      final id = await db.insert('pending_actions', {
        'action_type': actionType,
        'student_id': studentId,
        'class_id': classId,
  'payload': payload == null ? null : jsonEncode(payload),
        'processed': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.info('🧾 Queued pending action [$actionType] for $classId (ID: $id)');
      return id;
    } catch (e, stackTrace) {
      _logger.error('Failed to save pending action', e, stackTrace);
      rethrow;
    }
  }

  /// Get all unprocessed pending actions
  Future<List<Map<String, dynamic>>> getPendingActions() async {
    try {
      final db = await database;
      final rows = await db.query(
        'pending_actions',
        where: 'processed = 0',
        orderBy: 'created_at ASC',
      );
      _logger.debug('Found ${rows.length} pending actions');
      return rows;
    } catch (e, stackTrace) {
      _logger.error('Failed to get pending actions', e, stackTrace);
      return [];
    }
  }

  /// Mark a pending action as processed
  Future<void> markActionProcessed(int id) async {
    try {
      final db = await database;
      await db.update(
        'pending_actions',
        {'processed': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.debug('Pending action $id marked as processed');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark action processed', e, stackTrace);
    }
  }

  /// Cleanup processed actions older than N days
  Future<void> cleanupOldActions({int daysOld = 7}) async {
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final deleted = await db.delete(
        'pending_actions',
        where: 'processed = 1 AND created_at < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      _logger.info('🧹 Cleaned up $deleted old processed actions');
    } catch (e, stackTrace) {
      _logger.error('Failed to cleanup old actions', e, stackTrace);
    }
  }

  /// Get all unsynced attendance records
  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    try {
      final db = await database;
      final records = await db.query(
        _tableName,
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
      );

      _logger.debug('Found ${records.length} unsynced records');
      return records;
    } catch (e, stackTrace) {
      _logger.error('Failed to get unsynced records', e, stackTrace);
      return [];
    }
  }

  /// Mark a record as synced
  Future<void> markAsSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        _tableName,
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      _logger.debug('Record $id marked as synced');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark record as synced', e, stackTrace);
    }
  }

  /// Delete synced records older than specified days
  Future<void> cleanupOldRecords({int daysOld = 7}) async {
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final deleted = await db.delete(
        _tableName,
        where: 'synced = ? AND created_at < ?',
        whereArgs: [1, cutoffDate.toIso8601String()],
      );

      _logger.info('🗑️ Cleaned up $deleted old synced records');
    } catch (e, stackTrace) {
      _logger.error('Failed to cleanup old records', e, stackTrace);
    }
  }

  /// Get count of pending records
  Future<int> getPendingCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName WHERE synced = 0');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      _logger.error('Failed to get pending count', e, stackTrace);
      return 0;
    }
  }

  /// Get all attendance records for history
  Future<List<Map<String, dynamic>>> getAllRecords({int limit = 100}) async {
    try {
      final db = await database;
      return await db.query(
        _tableName,
        orderBy: 'created_at DESC',
        limit: limit,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to get all records', e, stackTrace);
      return [];
    }
  }

  /// Delete a specific record
  Future<void> deleteRecord(int id) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.debug('Record $id deleted');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete record', e, stackTrace);
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.info('Database closed');
    }
  }
}
