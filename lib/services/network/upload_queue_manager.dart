import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/local/database_helper.dart';
import '../../core/events/app_events.dart';
import 'backend_client.dart';

/// Manages the upload retry queue for failed sensor batch uploads.
///
/// When an upload fails (network error, server error), the payload is
/// saved to SQLite and retried with exponential backoff. On network
/// reconnect, the queue is automatically processed.
///
/// Max retries: 5 (then marked as permanently failed and removed).
class UploadQueueManager {
  UploadQueueManager._();
  static final UploadQueueManager instance = UploadQueueManager._();

  static const int _maxRetries = 5;
  Timer? _retryTimer;
  StreamSubscription? _connectivitySub;
  bool _processing = false;

  final DatabaseHelper _db = DatabaseHelper.instance;
  final AppEventBus _eventBus = AppEventBus.instance;

  /// Initialize: listen for connectivity changes to auto-retry.
  void initialize() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        processQueue();
      }
    });
    // Process any leftover items on startup
    processQueue();
  }

  /// Enqueue a failed upload for retry.
  Future<void> enqueue(String id, Map<String, dynamic> payload) async {
    await _db.queueUpload(
      id: id,
      payload: jsonEncode(payload),
    );
    debugPrint('[UploadQueue] Enqueued upload $id for retry');
    _scheduleRetry(const Duration(seconds: 30));
  }

  /// Process all pending uploads in the queue.
  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;

    try {
      final pending = await _db.getPendingUploads();
      if (pending.isEmpty) return;

      debugPrint('[UploadQueue] Processing ${pending.length} pending uploads');

      BackendClient? client;
      try {
        client = BackendClient();
      } catch (e) {
        debugPrint('[UploadQueue] Cannot create BackendClient: $e');
        return;
      }

      for (final item in pending) {
        final id = item['id'] as String;
        final retryCount = item['retry_count'] as int? ?? 0;

        // Skip items not yet ready for retry
        final nextRetryAt = item['next_retry_at'] as int?;
        if (nextRetryAt != null && DateTime.now().millisecondsSinceEpoch < nextRetryAt) {
          continue;
        }

        if (retryCount >= _maxRetries) {
          debugPrint('[UploadQueue] Upload $id exceeded max retries, removing');
          await _db.removeFromQueue(id);
          continue;
        }

        try {
          final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
          await client.uploadBatch(payload);

          // Success - remove from queue
          await _db.removeFromQueue(id);
          debugPrint('[UploadQueue] Upload $id succeeded on retry #$retryCount');

          _eventBus.emit(UploadSuccessEvent(
            samplesCount: (payload['readings'] as List?)?.length ?? 0,
            timestamp: DateTime.now(),
          ));
        } catch (e) {
          // Exponential backoff: 30s, 60s, 120s, 240s, 480s
          final backoffMs = 30000 * (1 << retryCount);
          final nextRetry = DateTime.now().millisecondsSinceEpoch + backoffMs;

          await _db.updateUploadRetry(
            id: id,
            error: e.toString(),
            nextRetryAt: nextRetry,
          );
          debugPrint('[UploadQueue] Upload $id failed (retry #$retryCount): $e');
        }
      }

      // Check if there are still items to retry
      final remaining = await _db.getPendingUploads();
      if (remaining.isNotEmpty) {
        _scheduleRetry(const Duration(minutes: 1));
      }
    } finally {
      _processing = false;
    }
  }

  /// Get count of pending uploads.
  Future<int> getPendingCount() async {
    final pending = await _db.getPendingUploads();
    return pending.length;
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => processQueue());
  }

  /// Clean up resources.
  void dispose() {
    _retryTimer?.cancel();
    _connectivitySub?.cancel();
  }
}
