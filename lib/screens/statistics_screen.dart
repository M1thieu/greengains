import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../data/models/contribution_stats.dart';
import '../data/repositories/contribution_repository.dart';
import '../core/events/app_events.dart';
import '../services/network/backend_client.dart';
import '../core/constants.dart';

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
const _kLineHeightTight       = 1.0;   // tight line-height for numeric displays

// Zone milestones — territory achievements visible on the map.
// Achievable cadence: 5 → 10 → 25 → 50 → 100 → 250 → 500 areas.
const _kMilestones = [5, 10, 25, 50, 100, 250, 500];


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

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  final _contributionRepo = ContributionRepository();

  // Local stats (always available, even offline)
  ContributionStats? _stats;
  bool _isLoading = true;

  // Backend weekly data (7 ints: index 0 = 6 days ago, index 6 = today)
  List<int>? _weeklyData;
  // Backend lifetime stats — fallback when local SQLite is empty (fresh reinstall)
  int? _backendTotalUploads;
  int? _coverageCells; // distinct H3 res-9 cells ever contributed
  int? _longestStreak;
  bool _isLoadingWeekly = true;

  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  StreamSubscription<StatsUpdatedEvent>? _statsUpdatedSub;

  // ── Entrance animations ───────────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final List<Animation<double>> _cardAnims;
  // ── Bar chart selection ───────────────────────────────────────────────────────
  int? _selectedBarIndex;

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

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _cardAnims = List.generate(4, (i) => CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(i * 0.12, (i * 0.12 + 0.55).clamp(0.0, 1.0), curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _uploadSuccessSub?.cancel();
    _statsUpdatedSub?.cancel();
    _entranceCtrl.dispose();
    super.dispose();
  }

  /// Wraps a card widget with a staggered fade+slide entrance.
  Widget _withEntrance(Widget child, int index) {
    final anim = _cardAnims[index];
    return FadeTransition(
      opacity: anim,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, c) => Transform.translate(
          offset: Offset(0, (1 - anim.value) * 18),
          child: c,
        ),
        child: child,
      ),
    );
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
      final data = await BackendClient.get(kApiUserProfile);
      final profile = UserProfileResponse.fromJson(data);
      if (mounted) {
        setState(() {
          _weeklyData = profile.weekly;
          _backendTotalUploads = profile.totalUploads;
          _coverageCells = profile.coverageCells;
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
      appBar: AppBar(
        title: Text(l10n.statsScreenTitle),
        actions: [
          if (!stillLoading && effectiveTotal > 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
              tooltip: l10n.tooltipRefresh,
            ),
        ],
      ),
      body: stillLoading
          ? _buildLoadingSkeleton(isDark)
          : effectiveTotal == 0
              ? _buildEmptyState(context, theme, isDark)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: ListView(
                    padding: AppTheme.pagePadding.copyWith(
                      bottom: MediaQuery.paddingOf(context).bottom + AppTheme.floatingNavHeight + AppTheme.spaceMd,
                    ),
                    children: [
                      _withEntrance(_buildHeroCard(theme, isDark, l10n), 0),
                      const SizedBox(height: AppTheme.spaceSm),
                      _withEntrance(_buildSupportingTrio(theme, isDark), 1),
                      const SizedBox(height: AppTheme.spaceSm),
                      _withEntrance(_buildMilestoneRow(theme, isDark, l10n), 2),
                      const SizedBox(height: AppTheme.spaceSm),
                      _withEntrance(_buildActivityChart(theme, isDark, l10n), 3),
                    ],
                  ),
                ),
    );
  }

  // ─── Hero card ───────────────────────────────────────────────────────────────

  Widget _buildHeroCard(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final localTotal = _stats?.totalUploads ?? 0;
    final totalUploads = localTotal > 0 ? localTotal : (_backendTotalUploads ?? 0);
    // H3 res-9 hex = 0.1053 km² — tangible territory the user can picture.
    final zones = _coverageCells ?? 0;
    final km2 = zones * 0.1053;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        color: AppColors.surface(isDark),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(_coverageCells),
                tween: Tween(begin: 0.0, end: km2),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (_, value, __) => Text(
                  value < 1.0 ? value.toStringAsFixed(2) : value.toStringAsFixed(1),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: AppFontWeights.bold,
                    letterSpacing: _kLetterSpacingDisplay,
                    height: _kLineHeightTight,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceXxs),
              Row(
                children: [
                  Text(
                    l10n.statsKmMapped.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: _kLetterSpacingCaps,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  _InfoIcon(title: l10n.infoKmTitle, body: l10n.infoKmBody),
                  if (totalUploads > 0) ...[
                    const SizedBox(width: AppTheme.spaceSm),
                    Text(
                      '$totalUploads ${l10n.statsDataPtsLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary(isDark),
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Supporting trio ─────────────────────────────────────────────────────────

  Widget _buildSupportingTrio(ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    final streak = _stats?.currentStreak ?? 0;
    final record = _longestStreak ?? 0;
    final tiles = [
      (value: '${_stats?.uploadsToday ?? 0}', label: l10n.statsToday, color: AppColors.pressure),
      (value: streak > 0 ? '${streak}d' : '—', label: l10n.statsStreakLabel, color: AppColors.light),
      (value: record > 0 ? '${record}d' : '—', label: l10n.statsRecordStreak, color: AppColors.quality),
    ];

    return Row(
      children: tiles.indexed.map((entry) {
        final (i, tile) = entry;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < tiles.length - 1 ? AppTheme.spaceSm : 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceSm + AppTheme.spaceXxs,
                AppTheme.spaceSm,
                AppTheme.spaceSm,
                AppTheme.spaceSm,
              ),
              decoration: AppTheme.kpiCard(isDark: isDark, accentColor: tile.color),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

  // ─── Milestone row ───────────────────────────────────────────────────────────

  Widget _buildMilestoneRow(ThemeData theme, bool isDark, AppLocalizations l10n) {
    // Milestones are zone-based — if zones not loaded yet, skip the row.
    final total = _coverageCells;
    if (total == null) return const SizedBox.shrink();
    final next = _kMilestones.cast<int?>().firstWhere((m) => m! > total, orElse: () => null);

    // All milestones reached
    if (next == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        decoration: AppTheme.kpiCard(isDark: isDark, accentColor: AppColors.primary),
        child: Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.primary, size: AppIconSizes.sm),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                l10n.statsMilestoneElite,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final progress = (total / next).clamp(0.0, 1.0);
    final remaining = next - total;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceSm + AppTheme.spaceXxs,
        AppTheme.spaceSm,
        AppTheme.spaceMd,
        AppTheme.spaceSm,
      ),
      decoration: AppTheme.kpiCard(isDark: isDark, accentColor: AppColors.warning),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: AppColors.warning, size: AppIconSizes.sm),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.statsMilestoneLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary(isDark),
                            fontWeight: AppFontWeights.medium,
                          ),
                        ),
                        _InfoIcon(title: l10n.infoMilestoneTitle, body: l10n.infoMilestoneBody),
                      ],
                    ),
                    Text(
                      '$total / $next ${l10n.statsAreasLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXxxs),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: AppDurations.medium,
                  curve: AppMotion.decelerated,
                  builder: (_, value, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: _kProgressH,
                      backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(AppColors.warning),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXxxs),
                Text(
                  l10n.statsMilestoneRemaining(remaining),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary(isDark),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
          // Selected bar callout — replaces the spacer when a bar is tapped
          AnimatedSize(
            duration: AppDurations.fast,
            curve: AppMotion.standard,
            child: _selectedBarIndex != null
                ? _buildBarCallout(data, maxVal.toInt(), chartLocale, isDark, theme, l10n)
                : const SizedBox(height: AppTheme.spaceMd),
          ),
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

                final isSelected = _selectedBarIndex == i;
                final barColor = (isToday || isSelected)
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.25);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBarIndex = isSelected ? null : i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedScale(
                      scale: isSelected ? 1.06 : 1.0,
                      duration: AppDurations.fast,
                      curve: AppMotion.standard,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Value label above bar — only when non-zero
                          if (count > 0)
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: _kBarLabelSize,
                                color: (isToday || isSelected)
                                    ? AppColors.primary
                                    : AppColors.textSecondary(isDark),
                                fontWeight: (isToday || isSelected)
                                    ? AppFontWeights.bold
                                    : AppFontWeights.regular,
                              ),
                            )
                          else
                            const SizedBox(height: _kBarLabelSize + 2),
                          const SizedBox(height: AppTheme.spaceXxxs),
                          AnimatedContainer(
                            duration: Duration(milliseconds: AppDurations.fast.inMilliseconds + i * _kBarAnimStagger),
                            curve: AppMotion.decelerated,
                            height: barH,
                            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxxs),
                            decoration: BoxDecoration(
                              gradient: (isToday || isSelected)
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.65)],
                                    )
                                  : null,
                              color: (isToday || isSelected) ? null : barColor,
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
                              color: (isToday || isSelected)
                                  ? AppColors.primary
                                  : AppColors.textTertiary(isDark),
                              fontWeight: (isToday || isSelected)
                                  ? AppFontWeights.semibold
                                  : AppFontWeights.regular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarCallout(List<int> data, int maxVal, String locale, bool isDark, ThemeData theme, AppLocalizations l10n) {
    final i = _selectedBarIndex!;
    final count = data[i];
    final isToday = i == 6;
    final isBest = maxVal > 0 && count == maxVal;
    final date = DateTime.now().subtract(Duration(days: 6 - i));
    final fullDate = DateFormat('EEE, MMM d', locale).format(date);

    String? badge;
    if (isToday) { badge = l10n.statsBarCalloutToday; }
    else if (isBest) { badge = l10n.statsBarCalloutBest; }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryAlpha(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            fullDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(isDark),
              fontWeight: AppFontWeights.medium,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            l10n.statsBarCalloutUploads(count),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: AppFontWeights.bold,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: AppTheme.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs + 2, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMin),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedBarIndex = null),
            child: Icon(Icons.close, size: 14, color: AppColors.textTertiary(isDark)),
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

// ─── Info sheet ───────────────────────────────────────────────────────────────

/// Tappable ⓘ icon that opens a contextual bottom sheet explaining a metric.
class _InfoIcon extends StatelessWidget {
  const _InfoIcon({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showInfoSheet(context, title, body, isDark);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: AppTheme.spaceXxs),
        child: Icon(
          Icons.info_outline,
          size: 13,
          color: AppColors.textTertiary(isDark),
        ),
      ),
    );
  }
}

void _showInfoSheet(BuildContext context, String title, String body, bool isDark) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd,
      ),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
      ),
    ),
  );
}

