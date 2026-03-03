import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../data/models/contribution_stats.dart';

// Badge / divider sizing — named constants so changes are in one place.
const _kBadgePaddingH = AppTheme.spaceXs;  // horizontal badge padding (8)
const _kBadgePaddingV = AppTheme.spaceXxxs; // vertical badge padding   (2)
const _kMetricDividerH = AppTheme.spaceLg;  // divider line height       (24)
const _kMetricIconSize = AppIconSizes.xs;   // secondary metric icon     (16)

/// Impact summary card — Vercel/Linear-style KPI card.
///
/// Design principles:
/// - surfaceElevated background → floats above the surface-level bottom sheet
/// - Solid visible border — never conditional/alpha
/// - Label → hero number → secondary metrics (clean 3-row hierarchy)
/// - No decorative icon header, no gradients, no glow
/// - isLoading: shows skeleton instead of content while stats API is in-flight
/// - MergeSemantics: screen reader reads entire card as one meaningful unit
class ImpactSummaryCard extends StatelessWidget {
  final ContributionStats? stats;
  final TileCoverageStats? tileCoverage;
  final bool isLoading;
  /// Number of community-mapped tiles fetched from the global endpoint.
  /// Shows a "X areas mapped by community" context row when > 0.
  final int communityTileCount;

  const ImpactSummaryCard({
    super.key,
    this.stats,
    this.tileCoverage,
    this.isLoading = false,
    this.communityTileCount = 0,
  });

  String _formatCoverageArea() {
    if (tileCoverage == null || tileCoverage!.totalTiles == 0) return '—';
    final area = (tileCoverage!.totalTiles * 0.024).toStringAsFixed(1);
    return '$area km²';
  }

  String _formatDaysActive(BuildContext context) {
    if (stats == null || stats!.totalUploads == 0) return '—';
    return context.l10n.daysActive(stats!.currentStreak);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final hasData = stats != null && stats!.totalUploads > 0;

    final semanticLabel = isLoading
        ? l10n.loadingStatsLabel
        : hasData
            ? l10n.contributionStatsSemanticsLabel(
                '${stats!.totalUploads}',
                _formatCoverageArea(),
                _formatDaysActive(context),
              )
            : l10n.noContributionsYet;

    return Semantics(
      label: semanticLabel,
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
          child: isLoading
              ? _buildSkeleton(isDark)
              : hasData
                  ? _buildData(context, theme, isDark)
                  : _buildEmpty(context, theme, isDark),
        ),
      ),
    );
  }

  /// Skeleton — shown while stats API is in-flight.
  /// Matches the data layout so there's no layout shift on load.
  Widget _buildSkeleton(bool isDark) {
    final base = AppColors.shimmerBase(isDark);
    final hi = AppColors.shimmerHighlight(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SkeletonBox(w: 120, h: 11, color: base),
        const SizedBox(height: 8),
        _SkeletonBox(w: 80, h: 36, color: hi),
        const SizedBox(height: AppTheme.spaceMd),
        Divider(color: AppColors.divider(isDark), height: 1),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            _SkeletonBox(w: 72, h: 32, color: base),
            const SizedBox(width: AppTheme.spaceMd),
            _SkeletonBox(w: 72, h: 32, color: base),
          ],
        ),
      ],
    );
  }

  Widget _buildData(BuildContext context, ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small caps label
        Text(
          l10n.yourContributions,
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFontWeights.semibold,
            letterSpacing: 1.0,
            color: AppColors.textSecondary(isDark),
          ),
        ),
        const SizedBox(height: 6),

        // Hero number + today badge
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
            if (stats!.uploadsToday > 0) ...[
              const SizedBox(width: AppTheme.spaceXs),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceXxs),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: _kBadgePaddingH, vertical: _kBadgePaddingV),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAlpha(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    '+${stats!.uploadsToday} ${l10n.statsToday.toLowerCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          l10n.impactCardContext,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(isDark),
            height: 1.2,
          ),
        ),

        const SizedBox(height: AppTheme.spaceMd),
        Divider(color: AppColors.divider(isDark), height: 1),
        const SizedBox(height: AppTheme.spaceMd),

        // Secondary metrics
        Row(
          children: [
            _ImpactMetric(
              icon: Icons.map_outlined,
              value: _formatCoverageArea(),
              label: l10n.areaCovered,
              isDark: isDark,
              iconColor: AppColors.pressure,
            ),
            Container(
              width: 1,
              height: _kMetricDividerH,
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
              color: AppColors.divider(isDark),
            ),
            _ImpactMetric(
              icon: Icons.local_fire_department_outlined,
              value: _formatDaysActive(context),
              label: l10n.activeStreak,
              isDark: isDark,
              iconColor: AppColors.warning,
            ),
          ],
        ),

        // Community context — shown once global tiles have loaded
        if (communityTileCount > 0) ...[
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Icon(Icons.public, size: _kMetricIconSize, color: AppColors.textTertiary(isDark)),
              const SizedBox(width: AppTheme.spaceXxs),
              Text(
                l10n.statsCommunityAreas(communityTileCount),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(isDark),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    return Row(
      children: [
        Icon(
          Icons.sensors_outlined,
          size: 28,
          color: AppColors.primary,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.startContributingTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeights.semibold,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.startContributingHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImpactMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  final Color? iconColor;

  const _ImpactMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _kMetricIconSize, color: iconColor ?? AppColors.textSecondary(isDark)),
        const SizedBox(width: AppTheme.spaceXxs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeights.semibold,
                color: AppColors.textPrimary(isDark),
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(isDark),
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double w;
  final double h;
  final Color color;

  const _SkeletonBox({required this.w, required this.h, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
