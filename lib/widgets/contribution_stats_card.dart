import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/events/app_events.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../data/models/contribution_stats.dart';
import '../data/repositories/contribution_repository.dart';
import 'time_ago_text.dart';

// ── ContributionStatsCard layout constants ────────────────────────────────────
const _kStatIconPad          = AppTheme.spaceSm;                      // 12 — icon container padding
const _kStatIconBgRadius     = AppTheme.radiusMd;                     // 12 — icon container radius
const _kStatIconSize         = 22.0;                                  // main icon (between sm/lg)
const _kStatStreakIconSize    = AppIconSizes.xs;                       // 16 — streak fire icon
const _kStatDividerH         = AppTheme.spaceLg;                      // 24 — column divider height
const _kStatNumberTracking   = -0.2;                                  // letterSpacing for numbers
const _kStatSkeletonIconSize = AppTheme.spaceXl + AppTheme.spaceXxs;  // 36 — skeleton icon box
const _kStatSkeletonValW     = AppTheme.spaceXl;                      // 32 — skeleton value width
const _kStatSkeletonValH     = 18.0;                                  // skeleton value height
const _kStatSkeletonLblW     = AppTheme.spaceXl - AppTheme.spaceXxs;  // 28 — skeleton label width
const _kStatSkeletonLblH     = AppTheme.spaceSm;                      // 12 — skeleton label height
const _kStatSkeletonRefreshW = AppIconSizes.sm;                       // 20 — skeleton refresh box

/// Compact horizontal contribution stats bar
/// Optimized for fast rendering and clean code
class ContributionStatsCard extends StatefulWidget {
  const ContributionStatsCard({super.key});

  @override
  State<ContributionStatsCard> createState() => ContributionStatsCardState();
}

class ContributionStatsCardState extends State<ContributionStatsCard>
    with SingleTickerProviderStateMixin {
  final _repository = ContributionRepository();
  ContributionStats _stats = ContributionStats.empty;
  bool _loading = true;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: AppDurations.slow,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: AppMotion.emphasized), // Slight bounce!
    );
    _loadStats();

    // Listen to upload success events for automatic refresh
    _uploadSuccessSub = AppEventBus.instance
        .on<UploadSuccessEvent>()
        .listen(_onUploadSuccess);
  }

  @override
  void dispose() {
    _uploadSuccessSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onUploadSuccess(UploadSuccessEvent event) {
    if (mounted) {
      _loadStats();
      // Subtle pulse animation to indicate update
      _pulseController.forward().then((_) => _pulseController.reverse());
    }
  }

  /// Public method to refresh stats from parent widget
  Future<void> refresh() => _loadStats();

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _repository.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });

        // Emit stats updated event so other parts of the app can react
        AppEventBus.instance.emit(StatsUpdatedEvent(stats));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Skeleton loading state
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: AppTheme.surfaceContainer(isDark: isDark),
        child: Row(
          children: [
            // Icon skeleton
            Container(
              width: _kStatSkeletonIconSize,
              height: _kStatSkeletonIconSize,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(isDark),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),

            // Stats skeleton
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSkeletonStat(isDark),
                  _buildDivider(isDark),
                  _buildSkeletonStat(isDark),
                  _buildDivider(isDark),
                  _buildSkeletonStat(isDark),
                ],
              ),
            ),

            const SizedBox(width: AppTheme.spaceXs),
            // Refresh button skeleton
            Container(
              width: _kStatSkeletonRefreshW,
              height: _kStatSkeletonRefreshW,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(isDark),
                borderRadius: BorderRadius.circular(AppTheme.radiusMin),
              ),
            ),
          ],
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
            width: AppBorderWidths.thin,
          ),
          boxShadow: isDark
              ? AppColors.elevationDark(active: false)
              : AppColors.elevationLight(active: false),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: AppIconSizes.sm,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                context.l10n.statsFailedToLoad,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
            TextButton(
              onPressed: _loadStats,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
              ),
              child: Text(context.l10n.buttonRetry),
            ),
          ],
        ),
      );
    }

    // Empty state for first-time users
    if (_stats.totalUploads == 0) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: isDark
              ? AppColors.elevationDark(active: false)
              : AppColors.elevationLight(active: false),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(
                Icons.terrain,
                color: AppColors.primary,
                size: AppIconSizes.md,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.statsReadyToContribute,
                    style: AppTheme.smallHeader(theme),
                  ),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  Text(
                    context.l10n.statsFirstContributionHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_downward,
              color: AppColors.primary,
              size: AppIconSizes.sm,
            ),
          ],
        ),
      );
    }

    // Milestone detection
    final bool isFirstUpload = _stats.totalUploads == 1;
    final bool isMilestone = _stats.totalUploads > 0 && (_stats.totalUploads % 10 == 0 || _stats.totalUploads % 50 == 0 || _stats.totalUploads % 100 == 0);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          gradient: (isMilestone || isFirstUpload)
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primaryLight.withValues(alpha: 0.12),
                  ],
                )
              : AppGradients.surfaceGlow(isDark),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: (isMilestone || isFirstUpload)
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.border(isDark),
            width: AppBorderWidths.thin,
          ),
          boxShadow: (isMilestone || isFirstUpload)
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
        child: Row(
        children: [
          // Icon with better visual treatment
          Container(
            padding: const EdgeInsets.all(_kStatIconPad),
            decoration: BoxDecoration(
              gradient: (isMilestone || isFirstUpload)
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primary],
                    )
                  : null,
              color: (isMilestone || isFirstUpload)
                  ? null
                  : AppColors.primaryAlpha(0.12),
              borderRadius: BorderRadius.circular(_kStatIconBgRadius),
              boxShadow: (isMilestone || isFirstUpload)
                  ? AppColors.glowEffect(AppColors.primary, opacity: 0.3)
                  : null,
            ),
            child: Icon(
              (isMilestone || isFirstUpload) ? Icons.celebration : Icons.terrain,
              color: (isMilestone || isFirstUpload)
                  ? Colors.white
                  : AppColors.primary,
              size: _kStatIconSize,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),

          // Stats in horizontal row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCompactStat(
                      theme,
                      isDark,
                      label: context.l10n.statsTotal,
                      value: '${_stats.totalUploads}',
                    ),
                    _buildDivider(isDark),
                    _buildCompactStat(
                      theme,
                      isDark,
                      label: context.l10n.statsThisWeek,
                      value: '${_stats.uploadsThisWeek}',
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXxs),
                if (_stats.firstContributionAt != null)
                  Text(
                    context.l10n.statsSinceDate(DateFormat('MMM yyyy', Localizations.localeOf(context).toString()).format(_stats.firstContributionAt!)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(isDark).withValues(alpha: 0.6),
                      fontSize: AppTheme.fontSizeXxs,
                    ),
                  )
                else if (_stats.loadedAt != null)
                  TimeAgoText(
                    timestamp: _stats.loadedAt!,
                    prefix: context.l10n.statsUpdatedPrefix,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(isDark).withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: _kStatDividerH,
      color: AppColors.divider(isDark),
    );
  }

  Widget _buildCompactStat(
    ThemeData theme,
    bool isDark, {
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _kStatStreakIconSize, color: iconColor ?? AppColors.primary),
          const SizedBox(height: AppTheme.spaceXxxs),
        ],
        Text(
          value,
          style: AppTheme.displayNumber(theme).copyWith(
            fontSize: theme.textTheme.headlineMedium?.fontSize,
            color: AppColors.textPrimary(isDark),
            letterSpacing: _kStatNumberTracking,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXxxs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary(isDark),
            fontWeight: AppFontWeights.medium,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonStat(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _kStatSkeletonValW,
          height: _kStatSkeletonValH,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated(isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusMin),
          ),
        ),
        const SizedBox(height: AppTheme.spaceXxxs),
        Container(
          width: _kStatSkeletonLblW,
          height: _kStatSkeletonLblH,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated(isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusMin),
          ),
        ),
      ],
    );
  }
}
