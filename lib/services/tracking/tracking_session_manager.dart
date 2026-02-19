import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/app_preferences.dart';
import '../../data/local/database_helper.dart';
import '../../core/events/app_events.dart';

/// Manages tracking session state and persistence
///
/// Responsibilities:
/// - Track when user starts/stops data collection
/// - Persist session state to survive app restarts
/// - Restore active sessions after crashes
/// - Emit events for UI updates
class TrackingSessionManager {
  TrackingSessionManager._();
  static final TrackingSessionManager instance = TrackingSessionManager._();

  final _db = DatabaseHelper.instance;
  final _prefs = AppPreferences.instance;

  final _isTrackingNotifier = ValueNotifier<bool>(false);
  ValueListenable<bool> get isTracking => _isTrackingNotifier;

  int? _currentSessionId;
  DateTime? _sessionStartTime;

  /// Initialize and restore state from database
  Future<void> initialize() async {
    await _prefs.ensureInitialized();

    // Check if there's an active session in the database
    final activeSession = await _db.getActiveTrackingSession();

    if (activeSession != null) {
      // We have an incomplete session - likely from a crash or force-stop
      _currentSessionId = activeSession['id'] as int;
      _sessionStartTime = DateTime.fromMillisecondsSinceEpoch(
        activeSession['started_at'] as int,
      );

      // Check if foreground service is actually running
      final isServiceEnabled = _prefs.foregroundServiceEnabled;
      final wasPaused = _prefs.trackingPaused;

      if (isServiceEnabled && !wasPaused) {
        // Service was actively running - restore state and let it auto-restart
        _isTrackingNotifier.value = true;
        debugPrint('Restored active tracking session: $_currentSessionId (started at $_sessionStartTime)');
      } else {
        // Service was stopped OR paused when app was killed - close the session
        final reason = wasPaused ? 'session_paused_app_killed' : 'service_stopped_externally';
        debugPrint('Closing orphaned session (reason: $reason)');
        await _db.stopTrackingSession(endedReason: reason);
        _currentSessionId = null;
        _sessionStartTime = null;
        // If the service was paused, reset prefs so it doesn't auto-restart on relaunch
        if (wasPaused) {
          await _prefs.setForegroundServiceEnabled(false);
          await _prefs.setTrackingPaused(false);
        }
      }
    }

    debugPrint('TrackingSessionManager initialized: isTracking=${_isTrackingNotifier.value}');
  }

  /// Start a new tracking session
  Future<void> startSession() async {
    if (_isTrackingNotifier.value) {
      debugPrint('Session already active, ignoring start request');
      return;
    }

    // Create new session in database
    _currentSessionId = await _db.startTrackingSession();
    _sessionStartTime = DateTime.now();
    _isTrackingNotifier.value = true;

    // Emit event for UI
    AppEventBus.instance.emit(TrackingStateChangedEvent(
      isTracking: true,
      timestamp: _sessionStartTime!,
    ));

    debugPrint('Started tracking session: $_currentSessionId');
  }

  /// Stop the current tracking session
  Future<void> stopSession({String? reason}) async {
    if (!_isTrackingNotifier.value) {
      debugPrint('No active session to stop');
      return;
    }

    await _db.stopTrackingSession(endedReason: reason);

    final duration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : null;

    _isTrackingNotifier.value = false;
    _currentSessionId = null;
    _sessionStartTime = null;

    // Emit event for UI
    AppEventBus.instance.emit(TrackingStateChangedEvent(
      isTracking: false,
      timestamp: DateTime.now(),
    ));

    if (duration != null) {
      debugPrint('Stopped tracking session (duration: ${duration.inMinutes}m, reason: $reason)');
    } else {
      debugPrint('Stopped tracking session (reason: $reason)');
    }
  }

  /// Record samples collected in current session
  Future<void> recordSamplesCollected(int count) async {
    if (_currentSessionId == null) return;

    await _db.updateTrackingSessionStats(samplesCollected: count);
  }

  /// Record upload completed in current session
  Future<void> recordUploadCompleted() async {
    if (_currentSessionId == null) return;

    final currentSession = await _db.getActiveTrackingSession();
    if (currentSession == null) return;

    final currentUploads = currentSession['uploads_completed'] as int? ?? 0;
    await _db.updateTrackingSessionStats(uploadsCompleted: currentUploads + 1);
  }

  /// Get current session info
  Future<Map<String, dynamic>?> getCurrentSession() async {
    if (_currentSessionId == null) return null;
    return await _db.getActiveTrackingSession();
  }

  /// Get session history
  Future<List<Map<String, dynamic>>> getHistory({int limit = 10}) async {
    return await _db.getTrackingHistory(limit: limit);
  }

  /// Get session statistics
  Future<SessionStats> getStats() async {
    final history = await _db.getTrackingHistory(limit: 100);

    if (history.isEmpty) {
      return SessionStats.empty;
    }

    final completedSessions = history.where((s) => s['stopped_at'] != null).toList();

    if (completedSessions.isEmpty) {
      return SessionStats.empty;
    }

    final totalDuration = completedSessions.fold<int>(
      0,
      (sum, session) => sum + (session['duration_ms'] as int? ?? 0),
    );

    final totalSamples = completedSessions.fold<int>(
      0,
      (sum, session) => sum + (session['samples_collected'] as int? ?? 0),
    );

    final totalUploads = completedSessions.fold<int>(
      0,
      (sum, session) => sum + (session['uploads_completed'] as int? ?? 0),
    );

    final avgDuration = totalDuration ~/ completedSessions.length;

    return SessionStats(
      totalSessions: completedSessions.length,
      totalDurationMs: totalDuration,
      averageDurationMs: avgDuration,
      totalSamplesCollected: totalSamples,
      totalUploads: totalUploads,
    );
  }

  void dispose() {
    _isTrackingNotifier.dispose();
  }
}

/// Session statistics model
class SessionStats {
  final int totalSessions;
  final int totalDurationMs;
  final int averageDurationMs;
  final int totalSamplesCollected;
  final int totalUploads;

  const SessionStats({
    required this.totalSessions,
    required this.totalDurationMs,
    required this.averageDurationMs,
    required this.totalSamplesCollected,
    required this.totalUploads,
  });

  static const SessionStats empty = SessionStats(
    totalSessions: 0,
    totalDurationMs: 0,
    averageDurationMs: 0,
    totalSamplesCollected: 0,
    totalUploads: 0,
  );

  Duration get totalDuration => Duration(milliseconds: totalDurationMs);
  Duration get averageDuration => Duration(milliseconds: averageDurationMs);

  @override
  String toString() {
    return 'SessionStats(sessions: $totalSessions, totalDuration: ${totalDuration.inHours}h, avgDuration: ${averageDuration.inMinutes}m)';
  }
}
