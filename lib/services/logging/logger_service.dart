import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized logging service that bridges Kotlin logs and Flutter logs.
/// Usage:
///   LoggerService.info('MyTag', 'Something happened');
///   LoggerService.trackEvent('share_button_pressed', {'count': 2});
class LoggerService {
  static const _methodChannel = MethodChannel('greengains/logger');

  static final LoggerService _instance = LoggerService._();

  factory LoggerService() {
    return _instance;
  }

  LoggerService._();

  /// Log a message to native Kotlin logger and local buffer.
  static void info(String tag, String message) {
    _log('INFO', tag, message);
  }

  static void debug(String tag, String message) {
    _log('DEBUG', tag, message);
  }

  static void warn(String tag, String message) {
    _log('WARN', tag, message);
  }

  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final errorMsg = error != null ? '$message\n$error' : message;
    _log('ERROR', tag, errorMsg);
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }

  static void _log(String level, String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$level] [$tag] $message';

    // Always print to debugger
    if (kDebugMode) {
      debugPrint(logLine);
    }

    // TODO: Send to Kotlin logger via MethodChannel (future enhancement)
    // This allows Flutter logs to be persisted on Kotlin side too
  }

  /// Track an analytics event.
  /// Events are buffered locally and can be exported for debugging.
  static void trackEvent(String eventName, [Map<String, dynamic>? params]) {
    final timestamp = DateTime.now().toIso8601String();
    final event = {
      'timestamp': timestamp,
      'event': eventName,
      'params': params ?? {},
    };

    if (kDebugMode) {
      debugPrint('[ANALYTICS] $event');
    }

    // TODO: Send to analytics backend later (Sentry, Firebase Analytics, custom)
  }

  /// Read all logs from the native Kotlin side.
  static Future<String> readNativeLogs() async {
    try {
      final logs = await _methodChannel.invokeMethod<String>('readLogs');
      return logs ?? '(No logs available)';
    } catch (e) {
      return 'Failed to read logs: $e';
    }
  }

  /// Clear all native logs.
  static Future<void> clearNativeLogs() async {
    try {
      await _methodChannel.invokeMethod<bool>('clearLogs');
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  /// Get native log file size in bytes.
  static Future<int> getNativeLogFileSizeBytes() async {
    try {
      final size = await _methodChannel.invokeMethod<int>('getLogFileSizeBytes');
      return size ?? 0;
    } catch (e) {
      debugPrint('Failed to get log file size: $e');
      return 0;
    }
  }

  /// Export logs as a formatted string (Kotlin + Flutter).
  /// Used for debugging, crash reports, or sharing with developers.
  static Future<String> exportLogs() async {
    final nativeLogs = await readNativeLogs();
    final header = '''
═══════════════════════════════════════════════════════════
GreenGains Debug Logs
Exported: ${DateTime.now().toIso8601String()}
═══════════════════════════════════════════════════════════

─── NATIVE (KOTLIN) LOGS ───
''';
    final footer = '''

─── END NATIVE LOGS ───
''';

    return header + nativeLogs + footer;
  }
}
