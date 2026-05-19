import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';

/// Consistent section eyebrow header — ALL CAPS, small, muted.
/// Replaces scattered inline TextStyle definitions across all screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.bottom = AppTheme.spaceXs});
  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(text.toUpperCase(), style: AppTheme.eyebrowLabel(isDark)),
    );
  }
}
