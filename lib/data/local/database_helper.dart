import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/contribution_stats.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants.dart';

/// Enhanced SQLite database for comprehensive app state persistence
///
/// Schema:
/// - contributions: Upload history with geohash for tile coverage
/// - tracking_sessions: Start/stop history for analytics
/// - upload_queue: Pending uploads (for future retry logic)
/// - app_state: Key-value store for misc state
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'greengains.db');

    return await openDatabase(
      path,
      version: 2, // Incremented for new tables
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Contributions table (existing + enhanced)
    await db.execute('''
      CREATE TABLE contributions (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        samples_count INTEGER NOT NULL,
        geohash TEXT,
        success INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_timestamp ON contributions(timestamp)',
    );

    // Tracking sessions - when did user start/stop tracking?
    await db.execute('''
      CREATE TABLE tracking_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at INTEGER NOT NULL,
        stopped_at INTEGER,
        duration_ms INTEGER,
        samples_collected INTEGER DEFAULT 0,
        uploads_completed INTEGER DEFAULT 0,
        ended_reason TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_session_started ON tracking_sessions(started_at)',
    );

    // Daily pot cache - offline-first design
    await db.execute('''
      CREATE TABLE daily_pot_cache (
        user_id TEXT PRIMARY KEY,
        total_credits INTEGER NOT NULL,
        uploads_today INTEGER NOT NULL,
        uploads_required INTEGER NOT NULL,
        is_unlocked INTEGER NOT NULL,
        has_claimed_today INTEGER NOT NULL,
        last_claim_date TEXT,
        last_synced_at INTEGER NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Upload queue (for future retry mechanism)
    await db.execute('''
      CREATE TABLE upload_queue (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        next_retry_at INTEGER
      )
    ''');

    // Generic key-value state store
    await db.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // Add new tables for v2
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tracking_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            stopped_at INTEGER,
            duration_ms INTEGER,
            samples_collected INTEGER DEFAULT 0,
            uploads_completed INTEGER DEFAULT 0,
            ended_reason TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_session_started ON tracking_sessions(started_at)',
        );

        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_pot_cache (
            user_id TEXT PRIMARY KEY,
            total_credits INTEGER NOT NULL,
            uploads_today INTEGER NOT NULL,
            uploads_required INTEGER NOT NULL,
            is_unlocked INTEGER NOT NULL,
            has_claimed_today INTEGER NOT NULL,
            last_claim_date TEXT,
            last_synced_at INTEGER NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS upload_queue (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0,
            last_error TEXT,
            next_retry_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        debugPrint('Database upgraded successfully to v2');
      } catch (e) {
        debugPrint('Error upgrading database: $e');
      }
    }
  }

  // ========== CONTRIBUTIONS ==========

  /// Insert a contribution record
  Future<void> insertContribution({
    required String id,
    required DateTime timestamp,
    required int samplesCount,
    String? geohash,
    required bool success,
  }) async {
    final db = await database;
    await db.insert(
      'contributions',
      {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'samples_count': samplesCount,
        'geohash': geohash,
        'success': success ? 1 : 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get total successful uploads count
  Future<int> getTotalCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM contributions WHERE success = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get today's uploads count
  Future<int> getTodayCount() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM contributions WHERE timestamp >= ? AND success = 1',
      [todayStart.millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get today's tile coverage split by day/night (distinct geohash per period)
  Future<TileCoverageStats> getTodayTileCoverage() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final results = await db.rawQuery(
      '''
        SELECT part, COUNT(*) as count
        FROM (
          SELECT DISTINCT
            geohash,
            CASE
              WHEN CAST(STRFTIME('%H', datetime(timestamp / 1000, 'unixepoch', 'localtime')) AS INTEGER)
                BETWEEN $kDayStartHour AND ${kDayEndHour - 1} THEN 'day'
              ELSE 'night'
            END as part
          FROM contributions
          WHERE success = 1
            AND geohash IS NOT NULL
            AND geohash != ''
            AND timestamp >= ?
        ) t
        GROUP BY part
      ''',
      [todayStart.millisecondsSinceEpoch],
    );

    var day = 0;
    var night = 0;
    for (final row in results) {
      final part = row['part']?.toString();
      final count = row['count'] is int
          ? row['count'] as int
          : int.tryParse(row['count']?.toString() ?? '') ?? 0;
      if (part == 'day') {
        day = count;
      } else if (part == 'night') {
        night = count;
      }
    }

    return TileCoverageStats(dayTiles: day, nightTiles: night);
  }

  /// Get current streak (consecutive days with uploads)
  Future<int> getStreak() async {
    final db = await database;

    // Get distinct dates with successful uploads, ordered desc
    final results = await db.rawQuery('''
      SELECT DISTINCT DATE(timestamp / 1000, 'unixepoch') as date
      FROM contributions
      WHERE success = 1
      ORDER BY date DESC
    ''');

    if (results.isEmpty) return 0;

    int streak = 0;
    DateTime? expectedDate = DateTime.now();

    for (final row in results) {
      final dateStr = row['date'] as String;
      final date = DateTime.parse(dateStr);

      // Normalize to start of day
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final normalizedExpected =
          DateTime(expectedDate!.year, expectedDate.month, expectedDate.day);

      if (normalizedDate == normalizedExpected) {
        streak++;
        expectedDate = normalizedDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // ========== TRACKING SESSIONS ==========

  /// Start a new tracking session
  Future<int> startTrackingSession() async {
    final db = await database;
    final id = await db.insert('tracking_sessions', {
      'started_at': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('Started tracking session: $id');
    return id;
  }

  /// Stop the active tracking session
  Future<void> stopTrackingSession({
    String? endedReason,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Use transaction for atomicity
    await db.transaction((txn) async {
      // Find the most recent session without a stopped_at time
      final results = await txn.query(
        'tracking_sessions',
        where: 'stopped_at IS NULL',
        orderBy: 'started_at DESC',
        limit: 1,
      );

      if (results.isEmpty) {
        debugPrint('No active tracking session to stop');
        return;
      }

      final session = results.first;
      final sessionId = session['id'] as int;
      final startedAt = session['started_at'] as int;
      final duration = now - startedAt;

      await txn.update(
        'tracking_sessions',
        {
          'stopped_at': now,
          'duration_ms': duration,
          'ended_reason': endedReason,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      debugPrint('Stopped tracking session $sessionId (duration: ${duration ~/ 1000}s, reason: $endedReason)');
    });
  }

  /// Update stats for the current tracking session
  Future<void> updateTrackingSessionStats({
    int? samplesCollected,
    int? uploadsCompleted,
  }) async {
    final db = await database;

    // Use transaction for atomicity
    await db.transaction((txn) async {
      // Find active session
      final results = await txn.query(
        'tracking_sessions',
        where: 'stopped_at IS NULL',
        orderBy: 'started_at DESC',
        limit: 1,
      );

      if (results.isEmpty) return;

      final sessionId = results.first['id'] as int;
      final updates = <String, dynamic>{};

      if (samplesCollected != null) {
        updates['samples_collected'] = samplesCollected;
      }
      if (uploadsCompleted != null) {
        updates['uploads_completed'] = uploadsCompleted;
      }

      if (updates.isNotEmpty) {
        await txn.update(
          'tracking_sessions',
          updates,
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      }
    });
  }

  /// Get the active tracking session (if any)
  Future<Map<String, dynamic>?> getActiveTrackingSession() async {
    final db = await database;
    final results = await db.query(
      'tracking_sessions',
      where: 'stopped_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );

    return results.isEmpty ? null : results.first;
  }

  /// Get tracking session history
  Future<List<Map<String, dynamic>>> getTrackingHistory({
    int limit = 10,
  }) async {
    final db = await database;
    return await db.query(
      'tracking_sessions',
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }

  // ========== UPLOAD QUEUE ==========

  /// Add an upload to the retry queue
  Future<void> queueUpload({
    required String id,
    required String payload,
  }) async {
    final db = await database;
    await db.insert(
      'upload_queue',
      {
        'id': id,
        'payload': payload,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get pending uploads from queue
  Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final db = await database;
    return await db.query(
      'upload_queue',
      orderBy: 'created_at ASC',
    );
  }

  /// Remove upload from queue
  Future<void> removeFromQueue(String id) async {
    final db = await database;
    await db.delete(
      'upload_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update retry info for failed upload
  Future<void> updateUploadRetry({
    required String id,
    required String error,
    required int nextRetryAt,
  }) async {
    final db = await database;
    final current = await db.query(
      'upload_queue',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (current.isEmpty) return;

    final retryCount = (current.first['retry_count'] as int? ?? 0) + 1;

    await db.update(
      'upload_queue',
      {
        'retry_count': retryCount,
        'last_error': error,
        'next_retry_at': nextRetryAt,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== APP STATE (Key-Value) ==========

  /// Set a state value
  Future<void> setState(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_state',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a state value
  Future<String?> getState(String key) async {
    final db = await database;
    final results = await db.query(
      'app_state',
      where: 'key = ?',
      whereArgs: [key],
    );

    return results.isEmpty ? null : results.first['value'] as String;
  }

  /// Delete a state value
  Future<void> deleteState(String key) async {
    final db = await database;
    await db.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Get all state values
  Future<Map<String, String>> getAllState() async {
    final db = await database;
    final results = await db.query('app_state');

    return Map.fromEntries(
      results.map((row) => MapEntry(
        row['key'] as String,
        row['value'] as String,
      )),
    );
  }

  // ========== MAINTENANCE ==========

  /// Clean old data (contributions older than 90 days)
  Future<void> cleanOldData({int daysToKeep = 90}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: daysToKeep))
        .millisecondsSinceEpoch;

    final deleted = await db.delete(
      'contributions',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );

    if (deleted > 0) {
      debugPrint('Cleaned $deleted old contributions (older than $daysToKeep days)');
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final contributions = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM contributions'),
    ) ?? 0;

    final sessions = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tracking_sessions'),
    ) ?? 0;

    final queuedUploads = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM upload_queue'),
    ) ?? 0;

    return {
      'contributions': contributions,
      'tracking_sessions': sessions,
      'queued_uploads': queuedUploads,
    };
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
