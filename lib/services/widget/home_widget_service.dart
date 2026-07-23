import 'package:flutter/services.dart';

/// Pushes zone count, streak, and active state to the Android home screen widget.
///
/// Uses the existing greengains/foreground MethodChannel — no extra package needed.
/// Silently ignores failures (widget not installed is non-critical).
class HomeWidgetService {
  HomeWidgetService._();

  static const _channel = MethodChannel('greengains/foreground');

  static Future<void> update({
    required int zoneCount,
    required int streak,
    required bool isActive,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateHomeWidget', {
        'zoneCount': zoneCount,
        'streak': streak,
        'isActive': isActive,
      });
    } catch (_) {
      // Widget not placed on home screen or update failed — non-critical.
    }
  }
}
