import 'package:flutter/material.dart';
import '../core/themes.dart';
import '../data/models/contribution_stats.dart';

/// Impact summary card — hero number + secondary metrics.
/// Flat, neutral dark surface. Accent (Emerald) only on numbers/icons.
/// No gradients, no glow. Linear/GitHub-style card aesthetic.
class ImpactSummaryCard extends StatelessWidget {
  final ContributionStats? stats;
  final TileCoverageStats? tileCoverage;

  const ImpactSummaryCard({
    super.key,
    this.stats,
    this.tileCoverage,
  });

  String _formatCoverageArea() {
    if (tileCoverage == null || tileCoverage!.totalTiles == 0) return '—';
    final area = (tileCoverage!.totalTiles * 0.024).toStringAsFixed(1);
    return '$area km²';
  }

  String _formatDaysActive() {
    if (stats == null || stats!.totalUploads == 0) return '—';
    final days = stats!.currentStreak;
    return days <= 1 ? '1 day' : '$days days';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasData = stats != null && stats!.totalUploads > 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        // Flat neutral surface — no gradient, no green tint
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: hasData
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.border(isDark),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + title + subtitle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.eco_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasData ? 'Your Impact' : 'Ready to Start?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeights.semibold,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasData
                          ? 'Environmental data you\'ve contributed'
                          : 'Start tracking to map your environment',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (hasData) ...[
            const SizedBox(height: AppTheme.spaceLg),

            // Hero number
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stats!.totalUploads}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: AppFontWeights.bold,
                    color: AppColors.primary,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'contributions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMd),
            Divider(color: AppColors.divider(isDark), height: 1),
            const SizedBox(height: AppTheme.spaceMd),

            // Secondary metrics — inline row
            Row(
              children: [
                _ImpactMetric(
                  icon: Icons.map_outlined,
                  value: _formatCoverageArea(),
                  label: 'Area Covered',
                  isDark: isDark,
                ),
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  color: AppColors.divider(isDark),
                ),
                _ImpactMetric(
                  icon: Icons.local_fire_department_outlined,
                  value: _formatDaysActive(),
                  label: 'Active Streak',
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ImpactMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;

  const _ImpactMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary(isDark)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: AppFontWeights.semibold,
                color: AppColors.textPrimary(isDark),
                height: 1,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
