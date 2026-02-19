import 'package:flutter/material.dart';
import '../core/themes.dart';

/// Dismissible tip card that appears contextually to guide users
/// Tips are shown once and can be dismissed permanently
class ContextualTipCard extends StatelessWidget {
  const ContextualTipCard({
    super.key,
    required this.tipId,
    required this.icon,
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  final String tipId;
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(
        isDark: isDark,
        elevated: true,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceXs),
            decoration: BoxDecoration(
              color: AppColors.primaryAlpha(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: AppFontWeights.semibold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onDismiss,
                      tooltip: 'Dismiss',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      color: AppColors.textSecondary(isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
