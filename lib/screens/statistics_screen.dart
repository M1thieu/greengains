import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../data/models/contribution_stats.dart';
import '../data/repositories/contribution_repository.dart';
import '../core/events/app_events.dart';
import '../services/network/backend_client.dart';

// ── Chart / skeleton layout constants ────────────────────────────────────────
// Named so that any future change touches ONE place, not scattered literals.
const _kChartH            = 148.0; // height reserved for the bar chart + labels
const _kBarMaxH           = 72.0;  // tallest bar at 100 % of the data range
const _kBarMinH           = 4.0;   // floor so 0-count bars remain visible
const _kBarLabelH         = AppTheme.spaceLg + AppTheme.spaceSm; // 36 px = label area below bars
const _kBarAnimStagger    = 40;    // ms added per bar for cascade entrance
const _kBarLabelSize      = 10.0;  // day-of-week label below each bar (below bodySmall)
const _kSkeletonTitleW    = 160.0; // width of section-title skeleton rect
const _kSkeletonHeroH     = 96.0;  // height of hero card skeleton placeholder
const _kHeroIconSize      = 80.0;  // empty-state centre icon size
const _kProgressH         = 6.0;   // milestone progress bar height
const _kTrioLabelSize     = 10.0;  // small label inside supporting trio tiles
// ── Typography constants ──────────────────────────────────────────────────────
const _kLetterSpacingDisplay  = -2.0;  // tight tracking for displayLarge hero number
const _kLetterSpacingHero     = -0.5;  // tight tracking for titleLarge in tiles
const _kLetterSpacingCaps     = 2.0;   // wide tracking for uppercase LABEL badges
const _kLetterSpacingSection  = 1.2;   // small-caps section header tracking
const _kLineHeightTight       = 1.0;   // tight line-height for numeric displays

// Reward milestones — thresholds at which rewards unlock.
// Designed to feel achievable at each step (not a wall).
const _kMilestones = [10, 50, 100, 250, 500, 1000, 5000];


/// Statistics screen — local stats (fast/offline) + server 7-day chart.
///
/// Two data sources run in parallel:
///   1. Local SQLite via ContributionRepository → total, today, streak (instant)
///   2. Backend /api/user/profile → weekly[7] upload counts per day
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _contributionRepo = ContributionRepository();

  // Local stats (always available, even offline)
  ContributionStats? _stats;
  bool _isLoading = true;

  // Backend weekly data (7 ints: index 0 = 6 days ago, index 6 = today)
  List<int>? _weeklyData;
  // Backend lifetime stats — fallback when local SQLite is empty (fresh reinstall)
  int? _daysActive;
  int? _backendTotalUploads;
  int? _coverageCells; // distinct H3 res-9 cells ever contributed
  int? _currentStreak;
  int? _longestStreak;
  bool _isLoadingWeekly = true;

  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  StreamSubscription<StatsUpdatedEvent>? _statsUpdatedSub;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadWeeklyStats();

    _uploadSuccessSub =
        AppEventBus.instance.on<UploadSuccessEvent>().listen((_) {
      if (mounted) {
        _loadStats();
        _loadWeeklyStats();
      }
    });
    _statsUpdatedSub =
        AppEventBus.instance.on<StatsUpdatedEvent>().listen((event) {
      if (mounted) setState(() { _stats = event.stats; _isLoading = false; });
    });
  }

  @override
  void dispose() {
    _uploadSuccessSub?.cancel();
    _statsUpdatedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _contributionRepo.getStats();
      if (mounted) setState(() { _stats = stats; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeeklyStats() async {
    setState(() => _isLoadingWeekly = true);
    try {
      final data = await BackendClient.get('/api/user/profile');
      final profile = UserProfileResponse.fromJson(data);
      if (mounted) {
        setState(() {
          _weeklyData = profile.weekly;
          _daysActive = profile.daysActive;
          _backendTotalUploads = profile.totalUploads;
          _coverageCells = profile.coverageCells;
          _currentStreak = profile.currentStreak;
          _longestStreak = profile.longestStreak;
        });
      }
    } catch (_) {
      // Silently fail — local stats still visible
    } finally {
      if (mounted) setState(() => _isLoadingWeekly = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadStats(), _loadWeeklyStats()]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    // Use backend total as fallback when local SQLite is empty (e.g. after reinstall)
    final effectiveTotal = (_stats?.totalUploads ?? 0) > 0
        ? _stats!.totalUploads
        : (_backendTotalUploads ?? 0);
    // Show skeleton while either local OR backend is still loading (first render)
    final stillLoading = _isLoading || (_isLoadingWeekly && _backendTotalUploads == null && effectiveTotal == 0);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsScreenTitle)),
      body: stillLoading
          ? _buildLoadingSkeleton(isDark)
          : effectiveTotal == 0
              ? _buildEmptyState(context, theme, isDark)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: ListView(
                    padding: AppTheme.pagePadding,
                    children: [
                      _buildHeroCard(theme, isDark, l10n),
                      const SizedBox(height: AppTheme.spaceSm),
                      _buildSupportingTrio(theme, isDark),
                      const SizedBox(height: AppTheme.spaceLg),
                      _buildSectionHeader(l10n.statsContributionTimeline, theme, isDark),
                      const SizedBox(height: AppTheme.spaceMd),
                      _buildActivityChart(theme, isDark, l10n),
                    ],
                  ),
                ),
    );
  }

  // ─── Hero card ───────────────────────────────────────────────────────────────

  Widget _buildHeroCard(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final localTotal = _stats?.totalUploads ?? 0;
    final total = localTotal > 0 ? localTotal : (_backendTotalUploads ?? 0);

    // Find the next milestone above the current total
    final next = _kMilestones.cast<int?>().firstWhere(
      (m) => m! > total,
      orElse: () => null,
    );
    final progress = next != null ? (total / next).clamp(0.0, 1.0) : 1.0;

    final surfaceColor = AppColors.surface(isDark);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        color: surfaceColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                AppTheme.spaceMd,
                AppTheme.spaceMd,
                AppTheme.spaceMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$total',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: AppFontWeights.bold,
                            letterSpacing: _kLetterSpacingDisplay,
                            height: _kLineHeightTight,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceXxs),
                        Text(
                          l10n.statsTotal.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            letterSpacing: _kLetterSpacingCaps,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (next != null)
                        Text(
                          '$total / $next',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: AppFontWeights.medium,
                          ),
                        ),
                      if (_longestStreak != null && _longestStreak! > 0)
                        Text(
                          l10n.statsStreakBest(_longestStreak!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary(isDark),
                            letterSpacing: _kLetterSpacingSection,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: AppDurations.medium,
              curve: AppMotion.decelerated,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: _kProgressH,
                backgroundColor: AppColors.primaryAlpha(0.10),
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                borderRadius: BorderRadius.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Supporting trio ─────────────────────────────────────────────────────────

  Widget _buildSupportingTrio(ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    final streak = _currentStreak ?? _stats?.currentStreak ?? 0;
    final tiles = [
      (
        value: '${_stats?.uploadsToday ?? 0}',
        label: l10n.statsToday,
        color: AppColors.pressure,
      ),
      (
        value: streak > 0 ? '$streak' : (_daysActive != null ? '$_daysActive' : '—'),
        label: streak > 0 ? l10n.statsStreak : l10n.statsDaysActive,
        color: AppColors.movement,
      ),
      (
        value: _coverageCells != null ? '$_coverageCells' : '—',
        label: l10n.statsCoverage,
        color: AppColors.quality,
      ),
    ];

    return Row(
      children: tiles.map((tile) {
        final isLast = tile == tiles.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : AppTheme.spaceSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: AppTheme.spaceSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppTheme.spaceXs,
                    height: AppTheme.spaceXs,
                    decoration: BoxDecoration(
                      color: tile.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXxs),
                  Text(
                    tile.value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: AppFontWeights.bold,
                      letterSpacing: _kLetterSpacingHero,
                      height: _kLineHeightTight,
                    ),
                  ),
                  Text(
                    tile.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: _kTrioLabelSize,
                      color: AppColors.textSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Activity chart ──────────────────────────────────────────────────────────

  /// Shows the real 7-day bar chart when backend data is available,
  /// a loading skeleton while fetching, or the today-only KPI as fallback.
  Widget _buildActivityChart(ThemeData theme, bool isDark, AppLocalizations l10n) {
    if (_isLoadingWeekly && _weeklyData == null) {
      // Backend still loading — show skeleton placeholder
      return Container(
        height: _kChartH,
        decoration: AppTheme.surfaceContainer(isDark: isDark),
        child: Center(
          child: SizedBox(
            width: AppIconSizes.sm,
            height: AppIconSizes.sm,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (_weeklyData != null) {
      return _buildWeeklyBarChart(theme, isDark, l10n);
    }

    // Backend unavailable (offline or error) — honest today-only fallback
    return _buildTodayOnlyKpi(theme, isDark, l10n);
  }

  Widget _buildWeeklyBarChart(ThemeData theme, bool isDark, AppLocalizations l10n) {
    // Ensure exactly 7 elements — pad/trim defensively
    final raw7 = _weeklyData!;
    final data = List<int>.generate(7, (i) => i < raw7.length ? raw7[i] : 0);
    final maxVal = data.fold(0, max).toDouble();
    final weeklyTotal = data.fold(0, (a, b) => a + b);
    final chartLocale = Localizations.localeOf(context).toString();
    final trendDelta = (data[4] + data[5] + data[6]) - (data[0] + data[1] + data[2]);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.statsActivityTrend,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.semibold),
                  ),
                  Row(
                    children: [
                      Text(
                        l10n.statsWeeklyTotal(weeklyTotal),
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark)),
                      ),
                      const SizedBox(width: AppTheme.spaceXxs),
                      Icon(
                        trendDelta > 0 ? Icons.trending_up : trendDelta < 0 ? Icons.trending_down : Icons.trending_flat,
                        size: AppIconSizes.xs,
                        color: trendDelta > 0 ? AppColors.primary : trendDelta < 0 ? AppColors.error : AppColors.textTertiary(isDark),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs, vertical: AppTheme.spaceXxs),
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                ),
                child: Text(
                  l10n.statsWeeklyLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            height: _kBarMaxH + _kBarLabelH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = data[i];
                final isToday = i == 6;
                final barH = maxVal > 0
                    ? (count / maxVal * _kBarMaxH).clamp(_kBarMinH, _kBarMaxH)
                    : _kBarMinH;
                final date = DateTime.now().subtract(Duration(days: 6 - i));
                final label = DateFormat('EEE', chartLocale).format(date);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: AppDurations.fast.inMilliseconds + i * _kBarAnimStagger),
                        curve: AppMotion.decelerated,
                        height: barH,
                        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxxs),
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.65)],
                                )
                              : null,
                          color: isToday ? null : AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusSm),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXxs),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: _kBarLabelSize,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textTertiary(isDark),
                          fontWeight: isToday
                              ? AppFontWeights.semibold
                              : AppFontWeights.regular,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOnlyKpi(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final todayCount = _stats!.uploadsToday;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.statsActivityTrend, style: theme.textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.semibold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs, vertical: AppTheme.spaceXxs),
                decoration: BoxDecoration(color: AppColors.primaryAlpha(0.1), borderRadius: BorderRadius.circular(AppTheme.radiusMin)),
                child: Text(l10n.statsTodayLabel, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: AppFontWeights.semibold)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$todayCount',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  color: AppColors.primary,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceXxs),
                child: Text(
                  l10n.statsToday.toLowerCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared section widgets ──────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, ThemeData theme, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: AppColors.textTertiary(isDark),
        letterSpacing: _kLetterSpacingSection,
        fontWeight: AppFontWeights.semibold,
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    final color = AppColors.textSecondary(isDark).withValues(alpha: 0.1);
    final decoration = BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTheme.radiusMd));
    return ListView(
      padding: AppTheme.pagePadding,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(height: _kSkeletonHeroH, decoration: decoration),
        const SizedBox(height: AppTheme.spaceSm),
        Row(children: List.generate(3, (_) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs), child: Container(height: 72, decoration: decoration))))),
        const SizedBox(height: AppTheme.spaceLg),
        Container(height: AppIconSizes.sm, width: _kSkeletonTitleW, decoration: decoration),
        const SizedBox(height: AppTheme.spaceMd),
        Container(height: _kChartH, decoration: decoration),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              decoration: BoxDecoration(color: AppColors.primaryAlpha(0.08), shape: BoxShape.circle),
              child: Icon(Icons.bar_chart_outlined, size: _kHeroIconSize, color: AppColors.primary),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(l10n.statsStartContributing, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: AppFontWeights.semibold)),
            const SizedBox(height: AppTheme.spaceXs),
            Text(l10n.statsEmptyDescription, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary(isDark))),
          ],
        ),
      ),
    );
  }
}

