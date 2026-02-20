import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/contribution_stats.dart';
import '../../data/models/daily_pot.dart';

/// Central event bus for app-wide reactive updates
/// Replaces polling and manual refresh with event-driven architecture
class AppEventBus {
  AppEventBus._();
  static final instance = AppEventBus._();

  final _controller = StreamController<AppEvent>.broadcast();

  /// Listen to specific event types
  Stream<T> on<T extends AppEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  /// Emit an event to all listeners
  void emit(AppEvent event) {
    _controller.add(event);
    debugPrint('[EventBus] ${event.runtimeType}: ${event.debugInfo}');
  }

  void dispose() {
    _controller.close();
  }
}

/// Base class for all app events
sealed class AppEvent {
  String get debugInfo;
}

/// Upload completed successfully - triggers stats refresh
class UploadSuccessEvent extends AppEvent {
  final int samplesCount;
  final DateTime timestamp;
  final String? geohash;

  UploadSuccessEvent({
    required this.samplesCount,
    required this.timestamp,
    this.geohash,
  });

  @override
  String get debugInfo => 'samples=$samplesCount, geohash=$geohash';
}

/// Upload failed - can retry or show error
class UploadFailedEvent extends AppEvent {
  final String reason;
  final DateTime timestamp;

  UploadFailedEvent({
    required this.reason,
    required this.timestamp,
  });

  @override
  String get debugInfo => 'reason=$reason';
}

/// Stats updated from database - refresh UI
class StatsUpdatedEvent extends AppEvent {
  final ContributionStats stats;

  StatsUpdatedEvent(this.stats);

  @override
  String get debugInfo =>
      'uploads=${stats.totalUploads}, today=${stats.uploadsToday}, streak=${stats.currentStreak}';
}

/// Tracking state changed - update UI consistently
class TrackingStateChangedEvent extends AppEvent {
  final bool isTracking;
  final DateTime timestamp;

  TrackingStateChangedEvent({
    required this.isTracking,
    required this.timestamp,
  });

  @override
  String get debugInfo => 'isTracking=$isTracking';
}

/// Daily pot updated - refresh daily pot UI
class DailyPotUpdatedEvent extends AppEvent {
  final DailyPot pot;

  DailyPotUpdatedEvent(this.pot);

  @override
  String get debugInfo => 'canClaim=${pot.canClaim}, progress=${pot.progress}';
}

/// Daily pot claimed successfully
class DailyPotClaimedEvent extends AppEvent {
  final int amount;
  final DateTime timestamp;

  DailyPotClaimedEvent({
    required this.amount,
    required this.timestamp,
  });

  @override
  String get debugInfo => 'amount=$amount';
}

/// Location permission granted/denied
class LocationPermissionChangedEvent extends AppEvent {
  final bool granted;

  LocationPermissionChangedEvent(this.granted);

  @override
  String get debugInfo => 'granted=$granted';
}
