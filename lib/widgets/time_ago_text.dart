import 'package:flutter/material.dart';
import '../core/services/time_ago_service.dart';

/// A widget that displays "time ago" text and automatically updates every minute.
/// Uses centralized TimeAgoService for efficient timer management.
/// Only rebuilds itself, not parent widgets - optimized for performance.
class TimeAgoText extends StatelessWidget {
  const TimeAgoText({
    super.key,
    required this.timestamp,
    this.style,
    this.prefix = '',
  });

  final DateTime timestamp;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    // Listen to centralized timer for updates
    return ValueListenableBuilder<int>(
      valueListenable: TimeAgoService.instance.tick,
      builder: (context, _, __) {
        return Text(
          '$prefix${TimeAgoService.format(timestamp, locale: locale)}',
          style: style,
        );
      },
    );
  }
}
