import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Centralized service for managing "time ago" updates
/// Uses a single timer instead of creating one per widget
/// Notifies all listeners once per minute for efficient updates
class TimeAgoService {
  TimeAgoService._();
  static final instance = TimeAgoService._();

  Timer? _timer;
  final _tickNotifier = ValueNotifier<int>(0);

  /// Subscribe to minute ticks to update "time ago" displays
  ValueListenable<int> get tick => _tickNotifier;

  /// Start the centralized timer (call once at app startup)
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _tickNotifier.value++;
    });
  }

  /// Stop the timer
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Format a timestamp as "time ago" using the timeago package
  static String format(DateTime timestamp) {
    return timeago.format(timestamp, locale: 'en_short');
  }

  void dispose() {
    stop();
    _tickNotifier.dispose();
  }
}
