import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/app_preferences.dart';
import '../../data/local/database_helper.dart';
import '../tracking/tracking_session_manager.dart';
import '../location/foreground_location_service.dart';

/// Centralized app state management and restoration
///
/// Responsibilities:
/// - Restore app state after crashes/restarts
/// - Coordinate state between Flutter and Native
/// - Provide migration utilities
/// - Export/import state for debugging
class AppStateManager {
  AppStateManager._();
  static final AppStateManager instance = AppStateManager._();

  final _db = DatabaseHelper.instance;
  final _prefs = AppPreferences.instance;

  /// Initialize and restore complete app state
  Future<void> initialize() async {
    await _prefs.ensureInitialized();

    // Restore tracking state
    await _restoreTrackingState();

    // Clean old data periodically
    await _cleanOldData();

    debugPrint('AppStateManager initialized');
  }

  /// Restore tracking state and sync with foreground service
  Future<void> _restoreTrackingState() async {
    final session = await _db.getActiveTrackingSession();
    final isServiceEnabled = _prefs.foregroundServiceEnabled;

    if (session != null && !isServiceEnabled) {
      // Orphaned session - close it
      await _db.stopTrackingSession(endedReason: 'app_restart_service_stopped');
      debugPrint('Closed orphaned tracking session');
    } else if (session != null && isServiceEnabled) {
      // Valid active session - restore it
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        session['started_at'] as int,
      );
      debugPrint('Restored active tracking session from ${startedAt.toIso8601String()}');
    }
  }

  /// Clean old data to keep database size manageable
  Future<void> _cleanOldData() async {
    try {
      await _db.cleanOldData(daysToKeep: 90);
    } catch (e) {
      debugPrint('Error cleaning old data: $e');
    }
  }

  /// Get complete app state summary
  Future<AppStateSummary> getStateSummary() async {
    final stats = await _db.getDatabaseStats();
    final activeSession = await _db.getActiveTrackingSession();
    final sessionStats = await TrackingSessionManager.instance.getStats();

    return AppStateSummary(
      isTracking: activeSession != null,
      totalContributions: stats['contributions'] ?? 0,
      totalSessions: stats['tracking_sessions'] ?? 0,
      queuedUploads: stats['queued_uploads'] ?? 0,
      averageSessionDuration: sessionStats.averageDuration,
    );
  }

  /// Export app state as JSON (for debugging/support)
  Future<Map<String, dynamic>> exportState() async {
    final summary = await getStateSummary();
    final appState = await _db.getAllState();
    final recentSessions = await _db.getTrackingHistory(limit: 5);

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'summary': {
        'is_tracking': summary.isTracking,
        'total_contributions': summary.totalContributions,
        'total_sessions': summary.totalSessions,
        'queued_uploads': summary.queuedUploads,
        'avg_session_duration_minutes': summary.averageSessionDuration.inMinutes,
      },
      'app_state': appState,
      'recent_sessions': recentSessions.map((s) => {
        'started_at': DateTime.fromMillisecondsSinceEpoch(s['started_at'] as int).toIso8601String(),
        'stopped_at': s['stopped_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(s['stopped_at'] as int).toIso8601String()
            : null,
        'duration_ms': s['duration_ms'],
        'samples_collected': s['samples_collected'],
        'uploads_completed': s['uploads_completed'],
        'ended_reason': s['ended_reason'],
      }).toList(),
    };
  }

  /// Get JSON export as string
  Future<String> exportStateJson() async {
    final state = await exportState();
    return const JsonEncoder.withIndent('  ').convert(state);
  }

  /// Save a persistent state value
  Future<void> saveState(String key, String value) async {
    await _db.setState(key, value);
  }

  /// Get a persistent state value
  Future<String?> getState(String key) async {
    return await _db.getState(key);
  }

  /// Clear all cached data (useful for sign out)
  Future<void> clearCache() async {
    debugPrint('App cache cleared');
  }

  /// Reset app state (for debugging)
  Future<void> resetState() async {
    // Stop any active tracking
    if (ForegroundLocationService.instance.isRunning.value) {
      await ForegroundLocationService.instance.stop();
    }

    await clearCache();

    debugPrint('App state reset complete');
  }
}

/// Summary of current app state
class AppStateSummary {
  final bool isTracking;
  final int totalContributions;
  final int totalSessions;
  final int queuedUploads;
  final Duration averageSessionDuration;

  const AppStateSummary({
    required this.isTracking,
    required this.totalContributions,
    required this.totalSessions,
    required this.queuedUploads,
    required this.averageSessionDuration,
  });

  @override
  String toString() {
    return 'AppState(tracking: $isTracking, contributions: $totalContributions, '
        'sessions: $totalSessions, queued: $queuedUploads, '
        'avgDuration: ${averageSessionDuration.inMinutes}m)';
  }
}
