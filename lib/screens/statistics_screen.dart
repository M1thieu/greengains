import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../data/models/contribution_stats.dart';
import '../data/repositories/contribution_repository.dart';
import '../core/events/app_events.dart';
import '../core/app_preferences.dart';
import '../services/network/backend_client.dart';
import '../core/constants.dart';

// ── Chart / skeleton layout constants ────────────────────────────────────────
// Named so that any future change touches ONE place, not scattered literals.
const _kChartH            = 148.0; // height reserved for the bar chart + labels
const _kBarMaxH           = 72.0;  // tallest bar at 100 % of the data range
const _kBarMinH           = 4.0;   // floor so 0-count bars remain visible
const _kBarLabelH         = AppTheme.spaceLg + AppTheme.spaceSm; // 36 px = label area below bars
const _kBarAnimStagger    = 40;    // ms added per bar for cascade entrance
const _kBarLabelSize      = 11.0;  // day-of-week label below each bar
const _kSkeletonTitleW    = 160.0; // width of section-title skeleton rect
const _kSkeletonHeroH     = 96.0;  // height of hero card skeleton placeholder
const _kHeroIconSize      = 80.0;  // empty-state centre icon size
const _kProgressH         = 6.0;   // milestone progress bar height
const _kTrioLabelSize     = 11.0;  // small label inside supporting trio tiles
// ── Typography constants ──────────────────────────────────────────────────────
const _kLetterSpacingDisplay  = -2.0;  // tight tracking for displayLarge hero number
const _kLetterSpacingHero     = -0.5;  // tight tracking for titleLarge in tiles
const _kLetterSpacingCaps     = 2.0;   // wide tracking for uppercase LABEL badges
const _kLineHeightTight       = 1.0;   // tight line-height for numeric displays

// Zone milestones — territory achievements visible on the map.
// Achievable cadence: 5 → 10 → 25 → 50 → 100 → 250 → 500 areas.
const _kMilestones = [5, 10, 25, 50, 100, 250, 500, 1000];


/// Statistics screen — local stats (fast/offline) + server 7-day chart.
///
/// Two data sources run in parallel:
///   1. Local SQLite via ContributionRepository → total, today, streak (instant)
///   2. Backend /api/user/profile → weekly[7] upload counts per day
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.onGoToHome});

  /// Switches to the Home tab — used by the empty-state CTA.
  final VoidCallback? onGoToHome;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _contributionRepo = ContributionRepository();

  // Local stats (always available, even offline)
  ContributionStats? _stats;
  bool _isLoading = true;

  // Backend weekly data (7 ints: index 0 = 6 days ago, index 6 = today)
  List<int>? _weeklyData;
  // Backend lifetime stats — fallback when local SQLite is empty (fresh reinstall)
  int? _backendTotalUploads;
  int? _coverageCells; // distinct H3 res-9 cells ever contributed
  int? _daysActive;
  bool _isLoadingWeekly = true;
  // Previous km² value — used as animation start on reload so it never resets to 0
  double _prevKm2 = 0;
  // Community stats — active mapper count from /api/stats/global (1h server cache)
  int? _activeMappers;

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
    WidgetsBinding.instance.addObserver(this);
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
      duration: const Duration(milliseconds: 800),
    )..forward();
    _cardAnims = List.generate(6, (i) => CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(i * 0.10, (i * 0.10 + 0.55).clamp(0.0, 1.0), curve: Curves.easeOut),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStats();
      _loadWeeklyStats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    // Only show skeleton on first load — subsequent reloads update in-place.
    if (_stats == null) setState(() => _isLoading = true);
    try {
      final stats = await _contributionRepo.getStats();
      if (mounted) setState(() { _stats = stats; _isLoading = false; });
    } catch (e) {
      debugPrint('Local stats load failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeeklyStats() async {
    // Only show chart skeleton on first load.
    if (_weeklyData == null) setState(() => _isLoadingWeekly = true);
    try {
      // Profile + global community stats run in parallel — same auth, different cache TTLs.
      final results = await Future.wait([
        BackendClient.get(kApiUserProfile),
        BackendClient.get(kApiStatsGlobal).catchError((_) => <String, dynamic>{}),
      ]);
      final profile = UserProfileResponse.fromJson(results[0]);
      final global = GlobalStatsResponse.fromJson(results[1]);
      if (mounted) {
        setState(() {
          _weeklyData = profile.weekly;
          _backendTotalUploads = profile.totalUploads;
          _coverageCells = profile.coverageCells;
          _daysActive = profile.daysActive;
          if (global.activeMappers > 0) _activeMappers = global.activeMappers;
          // Auto-highlight best day on first load
          if (_selectedBarIndex == null && profile.weekly.isNotEmpty) {
            final maxV = profile.weekly.fold(0, max);
            if (maxV > 0) _selectedBarIndex = profile.weekly.lastIndexOf(maxV);
          }
        });
        AppEventBus.instance.emit(ProfileUpdatedEvent(
          totalUploads: profile.totalUploads,
          daysActive: profile.daysActive,
          coverageCells: profile.coverageCells,
          longestStreak: profile.longestStreak,
        ));
        // Persist streak for native StreakAlertWorker — no network call needed at 8pm.
        unawaited(AppPreferences.instance.setCurrentStreak(profile.currentStreak));
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

    final topPad = MediaQuery.paddingOf(context).top + AppTheme.spaceSm;
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppTheme.floatingNavHeight + AppTheme.spaceMd;

    return Scaffold(
      body: stillLoading
          ? SafeArea(child: _buildLoadingSkeleton(isDark))
          : effectiveTotal == 0
              ? SafeArea(child: _buildEmptyState(context, theme, isDark, l10n))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: ListView(
                    padding: AppTheme.pagePadding.copyWith(
                      top: topPad,
                      bottom: bottomPad,
                    ),
                    children: [
                      _withEntrance(_buildHeroCard(theme, isDark, l10n), 0),
                      const SizedBox(height: AppTheme.spaceMd),
                      if ((_stats?.currentStreak ?? 0) >= 3) ...[
                        _withEntrance(_StreakBanner(
                          streak: _stats!.currentStreak,
                          uploadsToday: _stats!.uploadsToday,
                          isDark: isDark,
                        ), 1),
                        const SizedBox(height: AppTheme.spaceMd),
                      ],
                      _StatsSectionLabel(l10n.statsActivitySection, isDark: isDark),
                      const SizedBox(height: AppTheme.spaceXs),
                      _withEntrance(_buildSupportingTrio(theme, isDark), 2),
                      const SizedBox(height: AppTheme.spaceMd),
                      _StatsSectionLabel(l10n.statsTerritorySection, isDark: isDark),
                      const SizedBox(height: AppTheme.spaceXs),
                      _withEntrance(_buildMilestoneRow(theme, isDark, l10n), 3),
                      const SizedBox(height: AppTheme.spaceMd),
                      _withEntrance(_buildActivityChart(theme, isDark, l10n), 4),
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
    // When territory isn't computed yet (H3 pending), fall back to upload count
    // as the hero metric so the card always shows a meaningful number.
    final showKm2 = zones > 0;

    return Container(
      decoration: AppTheme.kpiCard(isDark: isDark, accentColor: AppColors.primary, radius: AppTheme.radiusLg),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showKm2)
                TweenAnimationBuilder<double>(
                  key: ValueKey(_coverageCells),
                  tween: Tween(begin: _prevKm2, end: km2),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  onEnd: () => _prevKm2 = km2,
                  builder: (_, value, __) => Text(
                    value < 1.0 ? value.toStringAsFixed(2) : value.toStringAsFixed(1),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: AppFontWeights.bold,
                      letterSpacing: _kLetterSpacingDisplay,
                      height: _kLineHeightTight,
                    ),
                  ),
                )
              else
                Text(
                  '$totalUploads',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: AppFontWeights.bold,
                    letterSpacing: _kLetterSpacingDisplay,
                    height: _kLineHeightTight,
                  ),
                ),
              const SizedBox(height: AppTheme.spaceXxs),
              Row(
                children: [
                  Text(
                    showKm2
                        ? l10n.statsKmMapped.toUpperCase()
                        : l10n.statsDataPtsLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: _kLetterSpacingCaps,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  if (showKm2 && totalUploads > 0) ...[
                    const SizedBox(width: AppTheme.spaceSm),
                    Flexible(
                      child: Text(
                        '$totalUploads ${l10n.statsDataPtsLabel}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontWeight: AppFontWeights.medium,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (!showKm2) ...[
                    const SizedBox(width: AppTheme.spaceSm),
                    Flexible(
                      child: Text(
                        l10n.statsMapGrowing,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontWeight: AppFontWeights.medium,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              // Archive anchor — "since Apr 2025" — territory feels permanent
              if (_stats?.firstContributionAt != null) ...[
                const SizedBox(height: AppTheme.spaceXxxs),
                Text(
                  l10n.statsSinceDate(DateFormat('MMM yyyy', Localizations.localeOf(context).toString()).format(_stats!.firstContributionAt!)),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ],
              // Community context + View on map — bottom of hero
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_activeMappers != null && _activeMappers! > 0)
                    Flexible(
                      child: Text(
                        l10n.statsCommunityMappers(_activeMappers!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontWeight: AppFontWeights.medium,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (widget.onGoToHome != null)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onGoToHome!();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.statsViewOnMap,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: AppFontWeights.semibold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward, size: 11, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  // ─── Supporting trio ─────────────────────────────────────────────────────────

  Widget _buildSupportingTrio(ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    final daysActive = _daysActive ?? 0;
    final daysLoaded = _daysActive != null;
    final streak = _stats?.currentStreak ?? 0;
    final uploadsToday = _stats?.uploadsToday ?? 0;
    // Streak at risk: has a multi-day streak but hasn't mapped today yet.
    final streakAtRisk = streak >= 3 && uploadsToday == 0;
    final tiles = [
      (value: '$uploadsToday', label: l10n.statsToday, color: streakAtRisk ? AppColors.warning : AppColors.pressure),
      (value: '${_stats?.uploadsThisWeek ?? 0}', label: l10n.statsThisWeek, color: AppColors.light),
      (value: daysLoaded ? '$daysActive' : '—', label: l10n.statsDaysActive, color: AppColors.quality),
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
                    color: AppColors.textSecondary(isDark),
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
          ClipRect(
           child: SizedBox(
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
                                  : AppColors.textSecondary(isDark),
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
           )),
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
          Flexible(
            child: Text(
              fullDate,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: AppFontWeights.medium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Flexible(
            child: Text(
              l10n.statsBarCalloutUploads(count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: AppFontWeights.bold,
              ),
              overflow: TextOverflow.ellipsis,
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedBarIndex = null),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.close, size: 14, color: AppColors.textTertiary(isDark)),
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
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$todayCount',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  color: todayCount > 0 ? AppColors.primary : AppColors.textSecondary(isDark),
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceXxs),
                child: Text(
                  l10n.statsDataPtsLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            l10n.statsWeeklyChartOffline,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }


  // ─── Insight card (Dawarich-style contextual facts) ─────────────────────────

  Widget _buildLoadingSkeleton(bool isDark) {
    final baseColor  = AppColors.shimmerBase(isDark);
    final hlColor    = AppColors.shimmerHighlight(isDark);
    final decoration = BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppTheme.radiusMd));
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: hlColor,
      child: ListView(
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              decoration: BoxDecoration(color: AppColors.primaryAlpha(0.08), shape: BoxShape.circle),
              child: Icon(Icons.terrain, size: _kHeroIconSize, color: AppColors.primary),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(l10n.statsStartContributing, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: AppFontWeights.semibold)),
            const SizedBox(height: AppTheme.spaceXs),
            Text(l10n.statsEmptyDescription, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary(isDark))),
            if (widget.onGoToHome != null) ...[
              const SizedBox(height: AppTheme.spaceXl),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onGoToHome!();
                },
                icon: const Icon(Icons.map_outlined, size: AppIconSizes.sm),
                label: Text(l10n.statsEmptyGoMap),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Info sheet ───────────────────────────────────────────────────────────────


// ── Streak banner ─────────────────────────────────────────────────────────────

/// Compact horizontal card shown when current streak ≥ 3.
/// Intentionally calm — no guilt messaging, just acknowledgement.
/// The animated counter rolls in from 0 on first render for a subtle delight moment.
class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak, required this.uploadsToday, required this.isDark});
  final int streak;
  final int uploadsToday;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final atRisk = uploadsToday == 0;
    final accent = atRisk ? AppColors.warning : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm + 2,
      ),
      decoration: AppTheme.kpiCard(isDark: isDark, accentColor: accent),
      child: Row(
        children: [
          Icon(
            atRisk ? Icons.local_fire_department : Icons.local_fire_department_rounded,
            color: accent, size: 20,
          ),
          const SizedBox(width: AppTheme.spaceXs),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: streak),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, value, __) => Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: AppFontWeights.bold,
                color: accent,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceXxs),
          Text(
            l10n.statsStreakLabel.toLowerCase(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(isDark),
              fontWeight: AppFontWeights.medium,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              atRisk ? l10n.statsStreakAtRisk : l10n.statsStreakDays(streak),
              style: TextStyle(
                fontSize: 12,
                color: atRisk ? AppColors.warning : AppColors.textTertiary(isDark),
                fontWeight: atRisk ? AppFontWeights.semibold : AppFontWeights.regular,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSectionLabel extends StatelessWidget {
  const _StatsSectionLabel(this.text, {required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: AppFontWeights.semibold,
        color: AppColors.textSecondary(isDark),
        letterSpacing: 0.8,
      ),
    );
  }
}
