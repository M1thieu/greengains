import 'package:flutter/material.dart';
import '../core/themes.dart';
import '../data/models/contribution_stats.dart';

/// Impact summary card — hero number + secondary metrics
/// Shows total contributions as the primary number, area + streak below
class ImpactSummaryCard extends StatelessWidget {
  final ContributionStats? stats;
  final TileCoverageStats? tileCoverage;

  const ImpactSummaryCard({
    super.key,
    this.stats,
    this.tileCoverage,
  });

  String _formatCoverageArea() {
    if (tileCoverage == null || tileCoverage!.totalTiles == 0) {
      return '—';
    }
    // Each tile is roughly 156m x 156m = ~24,000 m^2 = 0.024 km^2
    final area = (tileCoverage!.totalTiles * 0.024).toStringAsFixed(1);
    return '$area km²';
  }

  String _formatDaysActive() {
    if (stats == null || stats!.totalUploads == 0) return '—';
    final days = stats!.currentStreak;
    if (days <= 1) return '1 day';
    return '$days days';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasData = stats != null && stats!.totalUploads > 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: hasData ? AppGradients.surfaceGlow(isDark) : null,
        color: hasData ? null : AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: hasData
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.border(isDark),
          width: 1,
        ),
        boxShadow: hasData
            ? [
                ...AppColors.glowEffect(AppColors.primary, opacity: 0.12),
                ...(isDark
                    ? AppColors.elevationDark(active: true)
                    : AppColors.elevationLight(active: true)),
              ]
            : (isDark
                ? AppColors.elevationDark(active: false)
                : AppColors.elevationLight(active: false)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: hasData ? AppGradients.greenGlow : null,
                  color: hasData ? null : AppColors.primaryAlpha(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasData ? Icons.eco : Icons.eco_outlined,
                  color: hasData ? AppColors.primary : AppColors.textSecondary(isDark),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasData ? 'Your Impact' : 'Ready to Start?',
                      style: AppTheme.smallHeader(theme),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasData
                          ? 'Environmental data you\'ve contributed'
                          : 'Track your environmental contributions',
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

            // Hero number — total contributions
            Center(
              child: Column(
                children: [
                  Text(
                    '${stats!.totalUploads}',
                    style: AppTheme.displayNumber(theme).copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXxs),
                  Text(
                    'total contributions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceLg),
            Container(height: 1, color: AppColors.divider(isDark)),
            const SizedBox(height: AppTheme.spaceMd),

            // Secondary metrics
            Row(
              children: [
                Expanded(
                  child: _ImpactMetric(
                    icon: Icons.map_outlined,
                    value: _formatCoverageArea(),
                    label: 'Area Covered',
                    isDark: isDark,
                    isActive: hasData,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: _ImpactMetric(
                    icon: Icons.calendar_today,
                    value: _formatDaysActive(),
                    label: 'Days Active',
                    isDark: isDark,
                    isActive: hasData,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual impact metric display
class _ImpactMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  final bool isActive;

  const _ImpactMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceXs),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryAlpha(0.1)
                : AppColors.surfaceElevated(isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.primary : AppColors.textTertiary(isDark),
          ),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppFontWeights.semibold,
            color: isActive
                ? AppColors.textPrimary(isDark)
                : AppColors.textSecondary(isDark),
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary(isDark),
            fontSize: 12,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
