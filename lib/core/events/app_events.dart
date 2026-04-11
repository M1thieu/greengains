import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/contribution_stats.dart';

/// Central event bus for app-wide reactive updates
class AppEventBus {
  AppEventBus._();
  static final instance = AppEventBus._();

  final _controller = StreamController<AppEvent>.broadcast();

  Stream<T> on<T extends AppEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  void emit(AppEvent event) {
    _controller.add(event);
    debugPrint('[EventBus] ${event.runtimeType}: ${event.debugInfo}');
  }

  void dispose() {
    _controller.close();
  }
}

sealed class AppEvent {
  String get debugInfo;
}

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

class StatsUpdatedEvent extends AppEvent {
  final ContributionStats stats;

  StatsUpdatedEvent(this.stats);

  @override
  String get debugInfo =>
      'uploads=${stats.totalUploads}, today=${stats.uploadsToday}, streak=${stats.currentStreak}';
}

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

class LocationPermissionChangedEvent extends AppEvent {
  final bool granted;

  LocationPermissionChangedEvent(this.granted);

  @override
  String get debugInfo => 'granted=$granted';
}

/// Broadcast by StatisticsScreen after it fetches /api/user/profile.
/// ProfileScreen subscribes to this instead of making its own API call.
class ProfileUpdatedEvent extends AppEvent {
  final int totalUploads;
  final int daysActive;
  final int coverageCells;
  final int longestStreak;

  ProfileUpdatedEvent({
    required this.totalUploads,
    required this.daysActive,
    required this.coverageCells,
    required this.longestStreak,
  });

  @override
  String get debugInfo =>
      'uploads=$totalUploads, days=$daysActive, cells=$coverageCells, streak=$longestStreak';
}
