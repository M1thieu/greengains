import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../widgets/press_scale_detector.dart';

/// Reusable stat cell: big value + small label, optional tap.
/// Replaces duplicated number+label patterns across profile, stats, and sheet widgets.
class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final theme = Theme.of(context);

    final content = Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.contentCard(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppFontWeights.bold,
              color: color ?? AppColors.textPrimary(isDark),
              letterSpacing: -0.5,
              height: AppLineHeights.tight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.statLabel(isDark),
            maxLines: 2,
            softWrap: true,
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return PressScaleDetector(onTap: onTap, child: content);
  }
}
