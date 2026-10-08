import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../widgets/press_scale_detector.dart';

/// Value + label pair, placed inside its module's single surface. No card of
/// its own: spacing groups cells as well as borders do (Han, Humphreys & Chen
/// 1999), and each extra container lowers apparent usability (Tractinsky 1997).
class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final theme = Theme.of(context);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppFontWeights.bold,
              color: AppColors.textPrimary(isDark),
              letterSpacing: AppTheme.letterSpacingSubtle,
              height: AppLineHeights.tight,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXxs),
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
