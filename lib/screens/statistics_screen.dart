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
import '../core/constants.dart';
import '../core/events/app_events.dart';
import '../core/app_preferences.dart';
import '../services/stats/stats_service.dart';
import '../widgets/press_scale_detector.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_cell.dart';

// ── Chart / skeleton layout constants ────────────────────────────────────────
// Named so that any future change touches ONE place, not scattered literals.
const _kChartH            = 148.0; // height reserved for the bar chart + labels
const _kBarMaxH           = 72.0;  // tallest bar at 100 % of the data range
const _kBarMinH           = 4.0;   // floor so 0-count bars remain visible
const _kBarLabelH         = AppTheme.spaceLg + AppTheme.spaceSm; // 36 px = label area below bars
const _kBarAnimStagger    = 40;    // ms added per bar for cascade entrance
const _kBarLabelSize      = AppTheme.fontSizeXs;  // day-of-week label below each bar
const _kSkeletonTitleW    = 160.0;                // width of section-title skeleton rect
const _kSkeletonHeroH     = 96.0;                 // height of hero card skeleton placeholder
// ── Typography constants ──────────────────────────────────────────────────────
const _kLetterSpacingCaps     = 2.0;   // wide tracking for uppercase LABEL badges
const _kBarSelectScale        = 1.12;  // selected bar lift — kept subtle, one place to tune

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
  late final TabController _tabCtrl;
  final _contributionRepo = ContributionRepository();

  // Local stats (always available, even offline)
  ContributionStats? _stats;
  bool _isLoading = true;

  // Backend weekly data (7 ints: index 0 = 6 days ago, index 6 = today)
  List<int>? _weeklyData;
  // Backend lifetime stats — fallback when local SQLite is empty (fresh reinstall)
  int? _backendTotalUploads;
  int? _backendUploadsToday; // backend-authoritative today count, survives reinstall
  int? _coverageCells; // distinct H3 res-9 cells ever contributed
  int? _daysActive;
  bool _isLoadingWeekly = true;
  // Previous km² value — used as animation start on reload so it never resets to 0
  double _prevKm2 = 0;
  // Community stats — active mapper count from /api/stats/global (1h server cache)
  // Streak data from backend profile
  int? _longestStreak;
  // All-time best single day upload count
  int? _bestDayCount;
  // Average uploads per active day
  double? _avgPerDay;
  // Weekly new-territory target
  WeeklyTargetResponse? _weeklyTarget;
  // Local Legend status — rank among mappers active in the same area this week
  LocalRankResponse? _localRank;
  // "Only you" impact — cells nobody else has ever mapped
  ImpactResponse? _impact;
  // Weekly civic insight — roughest street, new zones, solo territory
  WeeklyInsightResponse? _insight;
  // Data quality 0–100 from user_stats valid_samples/samples_count
  int? _qualityPct;

  // 30-day heatmap: key = 'yyyy-MM-dd', value = upload count
  Map<String, int>? _dailyCounts;

  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  StreamSubscription<StatsUpdatedEvent>? _statsUpdatedSub;
  /// True while the weekly-goal celebration overlay is visible.
  bool _showWeeklyCelebration = false;

  // ── Entrance animations ───────────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final List<Animation<double>> _cardAnims;
  // ── Bar chart selection + range ──────────────────────────────────────────────
  int? _selectedBarIndex;
  bool _chartMonthView = false; // false = 7-day, true = 30-day (needs backend)
  // ── Backend call throttle — avoid repeated fetches on quick tab switches ──────
  DateTime? _lastWeeklyFetch;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    // Seed weekly data from prefs immediately — chart shows stale data while network loads
    final cached = AppPreferences.instance.cachedWeeklyData;
    if (cached != null) {
      _weeklyData = cached;
      _isLoadingWeekly = false;
    }
    _loadStats();
    _loadWeeklyStats();
    _loadDailyCounts();

    _uploadSuccessSub =
        AppEventBus.instance.on<UploadSuccessEvent>().listen((_) {
      if (mounted) {
        _loadStats();
        _loadWeeklyStats(force: true);
        _loadDailyCounts();
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
    _cardAnims = List.generate(7, (i) => CurvedAnimation(
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
    _tabCtrl.dispose();
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
          offset: Offset(0, (1 - anim.value) * AppOffsets.slideMd),
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

  Future<void> _loadWeeklyStats({bool force = false}) async {
    // Throttle: skip if fresh data was fetched less than 5 minutes ago.
    final now = DateTime.now();
    if (!force && _lastWeeklyFetch != null &&
        now.difference(_lastWeeklyFetch!) < const Duration(minutes: 5)) { return; }
    _lastWeeklyFetch = now;
    // Only show chart skeleton on first load.
    if (_weeklyData == null) setState(() => _isLoadingWeekly = true);
    try {
      // Run independently so weekly target failure can't block profile data.
      final profileFuture = StatsService.instance.fetchProfileAndGlobal();
      final targetFuture = StatsService.instance.fetchWeeklyTarget();
      final localRankFuture = StatsService.instance.fetchLocalRank();
      final impactFuture = StatsService.instance.fetchImpact();
      final insightFuture = StatsService.instance.fetchWeeklyInsight();
      final (:profile, :global) = await profileFuture;
      final weeklyTarget = await targetFuture;
      final localRank = await localRankFuture;
      final impact = await impactFuture;
      final insight = await insightFuture;
      if (mounted) {
        setState(() {
          _weeklyData = profile.weekly;
          unawaited(AppPreferences.instance.setCachedWeeklyData(profile.weekly));
          _backendTotalUploads = profile.totalUploads;
          _backendUploadsToday = profile.uploadsToday;
          _coverageCells = profile.coverageCells;
          _daysActive = profile.daysActive;
          _longestStreak = profile.longestStreak;
          if (profile.bestDayCount != null) _bestDayCount = profile.bestDayCount;
          // Fallback: compute locally if backend field missing (pre-deploy).
          final days = profile.daysActive > 0 ? profile.daysActive : null;
          _avgPerDay = profile.avgPerDay ??
              (days != null && profile.totalUploads > 0
                  ? (profile.totalUploads / days * 10).round() / 10.0
                  : 0.0);
          if (profile.qualityPct != null) _qualityPct = profile.qualityPct;
          if (weeklyTarget != null) {
            _weeklyTarget = weeklyTarget;
            _maybeFireWeeklyCelebration(weeklyTarget);
          }
          if (localRank != null) _localRank = localRank;
          if (impact != null) _impact = impact;
          if (insight != null) _insight = insight;
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

  Future<void> _loadDailyCounts() async {
    try {
      final counts = await _contributionRepo.getDailyCountsForRange(days: 30);
      if (mounted) setState(() => _dailyCounts = counts);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await Future.wait([_loadStats(), _loadWeeklyStats(), _loadDailyCounts()]);
  }

  void _maybeFireWeeklyCelebration(WeeklyTargetResponse target) {
    if (target.newCellsThisWeek < target.target) return;
    // ISO week: "2026-W20"
    final now = DateTime.now();
    final weekNum = ((now.difference(DateTime(now.year, 1, 1)).inDays + DateTime(now.year, 1, 1).weekday) / 7).ceil();
    final weekKey = '${now.year}-W$weekNum';
    final prefs = AppPreferences.instance;
    if (prefs.weeklyGoalCelebratedWeek == weekKey) return;
    unawaited(prefs.setWeeklyGoalCelebratedWeek(weekKey));
    HapticFeedback.mediumImpact();
    setState(() => _showWeeklyCelebration = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showWeeklyCelebration = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final effectiveTotal = (_stats?.totalUploads ?? 0) > 0
        ? _stats!.totalUploads
        : (_backendTotalUploads ?? 0);
    final stillLoading = _isLoading || (_isLoadingWeekly && _backendTotalUploads == null && effectiveTotal == 0);

    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppTheme.floatingNavHeight + AppTheme.spaceMd;

    if (stillLoading) return Scaffold(body: SafeArea(child: _buildLoadingSkeleton(isDark)));
    if (effectiveTotal == 0) return Scaffold(body: SafeArea(child: _buildEmptyState(context, theme, isDark, l10n)));

    return Stack(
      children: [
      Scaffold(
      body: Column(
        children: [
          // Tab bar pinned below status bar
          SizedBox(
            height: topPad,
            child: ColoredBox(color: theme.scaffoldBackgroundColor),
          ),
          _StatsTabBar(controller: _tabCtrl, isDark: isDark, l10n: l10n),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── Tab 1: Core ──────────────────────────────────────────────
                RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: ListView(
                    padding: AppTheme.pagePadding.copyWith(top: AppTheme.spaceSm, bottom: bottomPad),
                    children: [
                      // Hero — bare number, verdict chip inline
                      _withEntrance(_buildHeroCard(theme, isDark, l10n), 0),
                      // Weekly target — the hook: new zones this week
                      if (_weeklyTarget != null) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        _withEntrance(_buildWeeklyTargetCard(theme, isDark, l10n, _weeklyTarget!), 1),
                      ],
                      // Local Legend — rank among mappers active in the same area this week
                      if (_localRank != null && _localRank!.hasActivity && _localRank!.totalMappers > 1) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        _withEntrance(_buildLocalRankCard(theme, isDark, l10n, _localRank!), 1),
                      ],
                      // Impact — cells nobody else has ever mapped ("only you" signal)
                      if (_impact != null && _impact!.soloCells > 0) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        _withEntrance(_buildImpactCard(theme, isDark, l10n, _impact!), 1),
                      ],
                      // Weekly civic insight — roughest street, new zones, solo territory
                      if (_insight != null && _insight!.hasActivity) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        _withEntrance(_buildInsightCard(theme, isDark, l10n, _insight!), 1),
                      ],
                      const SizedBox(height: AppTheme.spaceMd),
                      // Activity snapshot — verdict chip grouped here (weekly scope)
                      Row(
                        children: [
                          Expanded(child: SectionHeader(l10n.statsActivitySection, bottom: 0)),
                          if (_weeklyData != null && _weeklyData!.fold(0, (a, b) => a + b) > 0)
                            _buildVerdictChip(isDark, l10n),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceXxs),
                      _withEntrance(_buildSupportingTrio(theme, isDark), 2),
                      const SizedBox(height: AppTheme.spaceXs),
                      _withEntrance(_buildStreakCard(theme, isDark, l10n), 3),
                      // Territory — milestone ring
                      const SizedBox(height: AppTheme.spaceMd),
                      SectionHeader(l10n.statsTerritorySection),
                      const SizedBox(height: AppTheme.spaceXxs),
                      _withEntrance(_buildMilestoneRow(theme, isDark, l10n), 4),
                      const SizedBox(height: AppTheme.spaceXxs),
                      _withEntrance(_buildTerritoryDetailsLink(theme, isDark, l10n), 5),
                    ],
                  ),
                ),
                // ── Tab 2: In-depth ──────────────────────────────────────────
                RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: _buildInDepthTab(theme, isDark, l10n, bottomPad),
                ),
              ],
            ),
          ),
        ],
      ),   // Column
      ),   // Scaffold
      // ── Weekly goal celebration overlay ────────────────────────────────────
      if (_showWeeklyCelebration)
        _WeeklyGoalCelebration(onDismiss: () => setState(() => _showWeeklyCelebration = false)),
    ],
    );
  }

  // ─── Verdict chip (compact inline badge shown next to hero eyebrow) ──────────

  Widget _buildVerdictChip(bool isDark, AppLocalizations l10n) {
    final weekly = _weeklyData ?? [];
    final daysActive = weekly.where((v) => v > 0).length;

    final String label;
    final Color color;

    if (daysActive >= 5) {
      label = l10n.statsVerdictStrong;
      color = AppColors.primary;
    } else if (daysActive >= 3) {
      label = l10n.statsVerdictGood;
      color = AppColors.movement;
    } else {
      label = l10n.statsVerdictSlow;
      color = AppColors.warning;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs, vertical: AppTheme.spaceXxxs + 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: AppFontWeights.semibold,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ─── Hero card ───────────────────────────────────────────────────────────────

  void _showStatsDetailSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final localTotal = _stats?.totalUploads ?? 0;
    final totalUploads = localTotal > 0 ? localTotal : (_backendTotalUploads ?? 0);
    final zones = _coverageCells ?? 0;
    final km2 = zones * kKm2PerCell;
    final cityBlocks = (km2 / kKm2PerCityBlock).round();
    final bestDay = _weeklyData != null ? _weeklyData!.fold(0, max) : 0;
    final streak = _stats?.currentStreak ?? 0;
    final longest = _longestStreak ?? streak;
    final firstDate = _stats?.firstContributionAt;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) {
        final bottomPad = MediaQuery.paddingOf(context).bottom + AppTheme.spaceMd;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceSm, AppTheme.spaceMd, bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTheme.dragHandle(isDark),
              const SizedBox(height: AppTheme.spaceMd),
              Text(l10n.statsDetailTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.semibold)),
              const SizedBox(height: AppTheme.spaceXxxs),
              if (zones > 0)
                Text(
                  l10n.statsCityBlocks(cityBlocks),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark)),
                ),
              const SizedBox(height: AppTheme.spaceSm),
              // Explainers
              _ExplainerRow(icon: Icons.grid_view_rounded, color: AppColors.primary, text: l10n.statsZoneExplainer, isDark: isDark),
              const SizedBox(height: AppTheme.spaceXxs),
              _ExplainerRow(icon: Icons.upload_rounded, color: AppColors.pressure, text: l10n.statsUploadExplainer, isDark: isDark),
              const SizedBox(height: AppTheme.spaceMd),
              // Personal records grid
              SectionHeader(l10n.statsPersonalRecords),
              Row(
                children: [
                  Expanded(child: StatCell(label: l10n.statsRecordBestDay, value: '$bestDay', color: AppColors.light)),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(child: StatCell(label: l10n.statsRecordLongestStreak, value: '${longest}d', color: AppColors.warning)),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  Expanded(child: StatCell(label: l10n.statsRecordTotalUploads, value: '$totalUploads', color: AppColors.quality)),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(child: StatCell(
                    label: l10n.statsRecordFirstDay,
                    value: firstDate != null
                        ? DateFormat('MMM d, yyyy', Localizations.localeOf(context).toString()).format(firstDate)
                        : '—',
                    color: AppColors.movement,
                  )),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _SensorTypesRow(isDark: isDark, l10n: l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final localTotal = _stats?.totalUploads ?? 0;
    final totalUploads = localTotal > 0 ? localTotal : (_backendTotalUploads ?? 0);
    final zones = _coverageCells ?? 0;
    final km2 = zones * kKm2PerCell;
    final showKm2 = zones > 0;

    return PressScaleDetector(
      onTap: _showStatsDetailSheet,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow — lifetime scope only, no weekly verdict here
          Text(
            showKm2 ? l10n.statsKmMapped : l10n.statsDataPtsLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.eyebrowLabel(isDark),
          ),
          const SizedBox(height: AppTheme.spaceXxxs),
          // Hero number
          if (showKm2)
            TweenAnimationBuilder<double>(
              key: ValueKey(_coverageCells),
              tween: Tween(begin: _prevKm2, end: km2),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              onEnd: () => _prevKm2 = km2,
              builder: (_, value, __) => RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: value < 1.0 ? value.toStringAsFixed(2) : value.toStringAsFixed(1),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: AppFontWeights.bold,
                      letterSpacing: AppTheme.letterSpacingDisplay,
                      height: AppLineHeights.numeric,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  TextSpan(
                    text: ' ${l10n.statsKm2Unit}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                ]),
              ),
            )
          else
            Text(
              '$totalUploads',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: AppFontWeights.bold,
                letterSpacing: AppTheme.letterSpacingDisplay,
                height: AppLineHeights.numeric,
              ),
            ),
          // City blocks context — makes km² tangible for non-technical users
          if (showKm2 && zones > 0) ...[
            const SizedBox(height: AppTheme.spaceXxxs),
            Text(
              l10n.statsCityBlocks((km2 / kKm2PerCityBlock).round()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: AppFontWeights.regular,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceXxxs + 2),
          // Subtitle: upload count + map link
          Row(
            children: [
              Expanded(
                child: showKm2 && totalUploads > 0
                    ? Text(
                        '$totalUploads ${l10n.statsUploadsUnit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: AppFontWeights.medium,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (widget.onGoToHome != null)
                PressScaleDetector(
                  onTap: widget.onGoToHome,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.statsViewOnMap, style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary, fontWeight: AppFontWeights.semibold)),
                      const SizedBox(width: AppTheme.spaceXxxs),
                      Icon(Icons.arrow_forward, size: AppIconSizes.xxs, color: AppColors.primary),
                    ]),
                  ),
                )
              else
                Icon(Icons.info_outline_rounded, size: AppIconSizes.xxs, color: AppColors.textTertiary(isDark).withValues(alpha: 0.5)),
            ],
          ),
        ],
      ),
      ),
    );
  }

  // ─── Stat grid (2×2) ─────────────────────────────────────────────────────────

  Widget _buildSupportingTrio(ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    final localToday = _stats?.uploadsToday ?? 0;
    final uploadsToday = localToday > 0 ? localToday : (_backendUploadsToday ?? _weeklyData?.lastOrNull ?? 0);
    final localWeek = _stats?.uploadsThisWeek ?? 0;
    final uploadsThisWeek = localWeek > 0 ? localWeek : (_weeklyData?.fold(0, (a, b) => a + b) ?? 0);
    final int? bestDay = _bestDayCount ?? _weeklyData?.fold<int>(0, max);
    final avgPerDay = _avgPerDay;
    // Show dash for zero (no history yet) — not a loading spinner.
    final avgLabel = avgPerDay == null ? null
        : avgPerDay == 0.0 ? '—'
        : avgPerDay.toStringAsFixed(1);
    final hairline = AppColors.textTertiary(isDark).withValues(alpha: 0.12);

    return Container(
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(children: [
        IntrinsicHeight(child: Row(children: [
          Expanded(child: _KpiCell(label: l10n.statsToday, value: '$uploadsToday', isDark: isDark, theme: theme)),
          Container(width: 1, color: hairline),
          Expanded(child: _KpiCell(label: l10n.statsThisWeek, value: '$uploadsThisWeek', isDark: isDark, theme: theme)),
        ])),
        Container(height: 1, color: hairline),
        IntrinsicHeight(child: Row(children: [
          Expanded(child: _KpiCell(label: l10n.statsBestDayLabel, value: bestDay != null ? '$bestDay' : null, isDark: isDark, theme: theme)),
          Container(width: 1, color: hairline),
          Expanded(child: _KpiCell(label: l10n.statsAvgPerDay, value: avgLabel, isDark: isDark, theme: theme)),
        ])),
      ]),
    );
  }

  // ─── Streak card ─────────────────────────────────────────────────────────────

  Widget _buildStreakCard(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final streak = _stats?.currentStreak ?? 0;
    final longest = _longestStreak ?? 0;
    if (streak == 0 && longest == 0) return const SizedBox.shrink();

    final isRecord = streak > 0 && streak >= longest && longest > 0;
    final hairline = AppColors.textTertiary(isDark).withValues(alpha: 0.12);

    return Container(
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: streak),
                      duration: AppDurations.medium,
                      curve: AppMotion.decelerated,
                      builder: (_, value, __) => Text('$value', style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: AppFontWeights.bold,
                        color: AppColors.primary,
                        height: AppLineHeights.numeric,
                        letterSpacing: AppTheme.letterSpacingNumeric,
                      )),
                    ),
                    const SizedBox(width: AppTheme.spaceXxs),
                    Text(l10n.statsDaysUnit, style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary.withValues(alpha: 0.7),
                    )),
                    if (isRecord) ...[
                      const SizedBox(width: AppTheme.spaceXs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs + 1, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                        ),
                        child: Text(l10n.statsStreakNewRecord, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: AppFontWeights.semibold,
                        )),
                      ),
                    ],
                  ]),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  Text(l10n.statsCurrentStreakLabel, style: AppTheme.statLabel(isDark)),
                ],
              ),
            ),
          ),
          Container(width: 1, color: hairline),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: longest),
                      duration: AppDurations.medium,
                      curve: AppMotion.decelerated,
                      builder: (_, value, __) => Text('$value', style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: AppFontWeights.bold,
                        height: AppLineHeights.numeric,
                        letterSpacing: AppTheme.letterSpacingNumeric,
                      )),
                    ),
                    const SizedBox(width: AppTheme.spaceXxs),
                    Text(l10n.statsDaysUnit, style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    )),
                  ]),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  Text(l10n.statsLongestLabel, style: AppTheme.statLabel(isDark)),
                ],
              ),
            ),
          ),
        ]),
      ),
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
    final achieved = _kMilestones.where((m) => m <= total).toList();

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm + 2),
        decoration: AppTheme.kpiCard(isDark: isDark, accentColor: AppColors.warning, radius: AppTheme.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: AppDurations.medium,
              curve: AppMotion.decelerated,
              builder: (_, value, __) => _MilestoneRing(
                progress: value,
                total: total,
                next: next,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.statsMilestoneRemaining(remaining),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary(isDark),
                      fontWeight: AppFontWeights.semibold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  Text(
                    '$total / $next ${l10n.statsAreasLabel}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ],
              ),
            ),
          ],
            ),
            if (achieved.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Wrap(
                spacing: AppTheme.spaceXs,
                runSpacing: AppTheme.spaceXxs,
                children: achieved.map((m) => _MilestoneBadge(value: m, isDark: isDark)).toList(),
              ),
            ],
          ],
        ),
    );
  }

  // ─── Weekly target card ──────────────────────────────────────────────────────

  Widget _buildWeeklyTargetCard(ThemeData theme, bool isDark, AppLocalizations l10n, WeeklyTargetResponse target) {
    final done = target.newCellsThisWeek;
    final total = target.target;
    final pct = target.pctComplete.clamp(0.0, 1.0);
    final complete = done >= total;
    final hairline = AppColors.textTertiary(isDark).withValues(alpha: 0.12);
    final accent = complete ? AppColors.primary : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs + 2),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Row(children: [
        Icon(complete ? Icons.check_circle : Icons.flag_outlined, size: AppIconSizes.xs, color: accent),
        const SizedBox(width: AppTheme.spaceXs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  l10n.statsWeeklyTargetLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    letterSpacing: _kLetterSpacingCaps,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                complete ? l10n.statsWeeklyTargetComplete : '$done / $total',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ]),
            const SizedBox(height: AppTheme.spaceXxxs + 1),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMin),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: AppDurations.medium,
                curve: AppMotion.decelerated,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: hairline,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─── Local Legend card ─────────────────────────────────────────────────────────

  Widget _buildLocalRankCard(ThemeData theme, bool isDark, AppLocalizations l10n, LocalRankResponse rank) {
    final accent = rank.isLeader ? AppColors.primary : AppColors.textSecondary(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs + 2),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Row(children: [
        Icon(rank.isLeader ? Icons.emoji_events_rounded : Icons.emoji_events_outlined,
            size: AppIconSizes.xs, color: accent),
        const SizedBox(width: AppTheme.spaceXs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  l10n.statsLocalLegendLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    letterSpacing: _kLetterSpacingCaps,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                l10n.statsLocalLegendRank(rank.rank, rank.totalMappers),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ]),
            const SizedBox(height: AppTheme.spaceXxxs + 1),
            Text(
              rank.isLeader ? l10n.statsLocalLegendLeader : l10n.statsLocalLegendGap(rank.cellsToLead),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary(isDark)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─── Impact card ("only you've ever mapped this") ──────────────────────────────

  Widget _buildImpactCard(ThemeData theme, bool isDark, AppLocalizations l10n, ImpactResponse impact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs + 2),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Row(children: [
        Icon(Icons.fingerprint_rounded, size: AppIconSizes.xs, color: AppColors.primary),
        const SizedBox(width: AppTheme.spaceXs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              l10n.statsImpactLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary(isDark),
                letterSpacing: _kLetterSpacingCaps,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXxxs + 1),
            Text(
              l10n.statsImpactSolo(impact.soloCells),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary(isDark)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─── Weekly civic insight card ───────────────────────────────────────────────

  Widget _buildInsightCard(ThemeData theme, bool isDark, AppLocalizations l10n, WeeklyInsightResponse insight) {
    final rows = <Widget>[];

    if (insight.roughestStreet != null && insight.roughestPercentile != null) {
      rows.add(Text(
        l10n.statsInsightRoughest(insight.roughestStreet!, insight.roughestPercentile!),
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary(isDark)),
      ));
    }

    if (insight.newZonesThisWeek > 0) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppTheme.spaceXxxs + 1));
      rows.add(Text(
        l10n.statsInsightNewZones(insight.newZonesThisWeek),
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary(isDark)),
      ));
    }

    if (insight.soloZones > 0) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppTheme.spaceXxxs + 1));
      rows.add(Text(
        l10n.statsInsightSolo(insight.soloZones),
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary(isDark)),
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs + 2),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.place_rounded, size: AppIconSizes.xs, color: AppColors.primary),
        const SizedBox(width: AppTheme.spaceXs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              l10n.statsInsightLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary(isDark),
                letterSpacing: _kLetterSpacingCaps,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXxxs + 1),
            ...rows,
          ]),
        ),
      ]),
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
            child: CircularProgressIndicator(strokeWidth: AppBorderWidths.spinner, color: AppColors.primary),
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
              _ChartRangeToggle(
                monthView: _chartMonthView,
                isDark: isDark,
                weekLabel: l10n.statsChartWeekTab,
                monthLabel: l10n.statsChartMonthTab,
                onChanged: (v) => setState(() {
                  _chartMonthView = v;
                  _selectedBarIndex = null;
                }),
              ),
            ],
          ),
          // Month empty state
          if (_chartMonthView) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLg),
              alignment: Alignment.center,
              child: Text(
                l10n.statsChartMonthEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
          ] else ...[
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
            height: _kBarMaxH + _kBarLabelH + 4,
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
                    : AppColors.primary.withValues(alpha: 0.45);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBarIndex = isSelected ? null : i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedScale(
                      scale: isSelected ? _kBarSelectScale : 1.0,
                      duration: AppDurations.fast,
                      curve: AppMotion.standard,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Value label above bar — only when non-zero
                          if (count > 0)
                            Text(
                              '$count',
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                            const SizedBox(height: AppTheme.fontSizeXs + AppTheme.spaceXxxs),
                          const SizedBox(height: AppTheme.spaceXxxs),
                          AnimatedContainer(
                            duration: AppDurations.fast + Duration(milliseconds: i * _kBarAnimStagger),
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
                              border: isSelected
                                  ? Border.all(color: AppColors.primary, width: AppBorderWidths.medium)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceXxs),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
          ], // end else (week view)
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
    // Each upload = a batch of light + motion + pressure readings from one location
    final zonesApprox = (count * 0.3).round().clamp(1, 9999);

    String? badge;
    if (isToday) { badge = l10n.statsBarCalloutToday; }
    else if (isBest) { badge = l10n.statsBarCalloutBest; }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
      decoration: BoxDecoration(
        color: AppColors.primaryAlpha(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fullDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontWeight: AppFontWeights.medium,
                        ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: AppFontWeights.semibold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXxxs),
                Text(
                  l10n.statsBarCalloutUploads(count),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n.statsBarCalloutDetail(zonesApprox),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedBarIndex = null),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceXs + 2),
              child: Icon(Icons.close, size: AppIconSizes.xxs, color: AppColors.textTertiary(isDark)),
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


  Widget _buildLoadingSkeleton(bool isDark) {
    final baseColor  = AppColors.shimmerBase(isDark);
    final hlColor    = AppColors.shimmerHighlight(isDark);
    final decoration = BoxDecoration(color: AppColors.surface(isDark), borderRadius: BorderRadius.circular(AppTheme.radiusMd));
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

  // ─── Territory details link ──────────────────────────────────────────────────

  Widget _buildTerritoryDetailsLink(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final zones = _coverageCells ?? 0;
    if (zones == 0) return const SizedBox.shrink();
    return PressScaleDetector(
      onTap: () => _showTerritorySheet(l10n),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.statsTerritoryDetails,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(width: AppTheme.spaceXxxs),
            Icon(Icons.arrow_forward, size: AppIconSizes.xxs, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showTerritorySheet(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final zones = _coverageCells ?? 0;
    final km2 = zones * kKm2PerCell;
    final km2Str = km2 < 1.0 ? km2.toStringAsFixed(2) : km2.toStringAsFixed(1);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.paddingOf(ctx).bottom + AppTheme.spaceLg;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceSm, AppTheme.spaceMd, bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            AppTheme.dragHandle(isDark),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              l10n.statsTerritorySheetTitle,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.semibold),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            // Key metrics row
            Row(
              children: [
                Expanded(child: StatCell(label: l10n.statsKmMapped, value: '$km2Str km²', color: AppColors.primary)),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(child: StatCell(label: l10n.statsTerritoryZones(zones), value: '$zones', color: AppColors.quality)),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            // What was recorded in each zone
            _SensorTypesRow(isDark: isDark, l10n: l10n),
            const SizedBox(height: AppTheme.spaceMd),
            // Map CTA
            Text(
              l10n.statsTerritoryMapCta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
            if (_stats?.firstContributionAt != null) ...[
              const SizedBox(height: AppTheme.spaceXxs),
              Text(
                l10n.statsSinceDate(
                  DateFormat('MMM yyyy', Localizations.localeOf(context).toString())
                    .format(_stats!.firstContributionAt!),
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ],
        ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.statsStartContributing,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: AppFontWeights.semibold),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              l10n.statsEmptyDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            // Locked sensor rows — Duolingo-style preview of what gets unlocked
            _LockedSensorRow(icon: Icons.wb_sunny_outlined, color: AppColors.light, label: l10n.statsEmptyLockLight, isDark: isDark),
            const SizedBox(height: AppTheme.spaceXs),
            _LockedSensorRow(icon: Icons.directions_walk_rounded, color: AppColors.movement, label: l10n.statsEmptyLockMovement, isDark: isDark),
            const SizedBox(height: AppTheme.spaceXs),
            _LockedSensorRow(icon: Icons.compress_rounded, color: AppColors.pressure, label: l10n.statsEmptyLockPressure, isDark: isDark),
            if (widget.onGoToHome != null) ...[
              const SizedBox(height: AppTheme.spaceXl),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onGoToHome!();
                },
                icon: const Icon(Icons.play_arrow_rounded, size: AppIconSizes.sm),
                label: Text(l10n.statsEmptyGoMap),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Quality bar ─────────────────────────────────────────────────────────────

  Widget _buildQualityBar(ThemeData theme, bool isDark, int pct) {
    final l10n = context.l10n;
    final Color barColor;
    final String label;
    if (pct >= 80) {
      barColor = AppColors.quality;
      label = l10n.statsQualityExcellent;
    } else if (pct >= 60) {
      barColor = AppColors.primary;
      label = l10n.statsQualityGood;
    } else if (pct >= 40) {
      barColor = AppColors.warning;
      label = l10n.statsQualityFair;
    } else {
      barColor = AppColors.error;
      label = l10n.statsQualityLow;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l10n.statsQualitySection),
        const SizedBox(height: AppTheme.spaceXs),
        Row(children: [
          Text('$pct%', style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: AppFontWeights.bold,
            color: barColor,
            height: AppLineHeights.numeric,
            letterSpacing: AppTheme.letterSpacingDisplay,
          )),
          const SizedBox(width: AppTheme.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs, vertical: 3),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMin),
            ),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: AppFontWeights.semibold,
              color: barColor,
            )),
          ),
        ]),
        const SizedBox(height: AppTheme.spaceXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMin),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100.0),
            duration: AppDurations.medium,
            curve: AppMotion.decelerated,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: barColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceXxs),
        Text(
          l10n.statsQualitySubtitle,
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary(isDark)),
        ),
      ],
    );
  }

  // ─── In-depth tab ────────────────────────────────────────────────────────────

  Widget _buildInDepthTab(ThemeData theme, bool isDark, AppLocalizations l10n, double bottomPad) {
    final localTotal = _stats?.totalUploads ?? 0;
    final totalUploads = localTotal > 0 ? localTotal : (_backendTotalUploads ?? 0);
    final zones = _coverageCells ?? 0;
    final km2 = zones * kKm2PerCell;
    final km2Str = km2 < 1.0 ? km2.toStringAsFixed(2) : km2.toStringAsFixed(1);
    final daysActive = _daysActive ?? 0;
    final bestDay = _weeklyData != null ? _weeklyData!.fold(0, max) : 0;
    final bestWeek = _weeklyData?.fold(0, (a, b) => a + b) ?? 0;
    final longest = _longestStreak ?? (_stats?.currentStreak ?? 0);
    final locale = Localizations.localeOf(context).toString();
    final hairline = AppColors.textTertiary(isDark).withValues(alpha: 0.12);

    final counts30 = _dailyCounts;
    final activeDays30 = counts30?.values.where((v) => v > 0).length ?? 0;
    final total30 = counts30?.values.fold(0, (a, b) => a + b) ?? 0;
    final avgPerActiveDay = activeDays30 > 0 ? (total30 / activeDays30).round() : 0;

    // Best weekday computation
    String? bestWeekday;
    int bestWeekdayAvg = 0;
    if (counts30 != null && counts30.isNotEmpty) {
      final wd = List<int>.filled(7, 0);
      final wdCount = List<int>.filled(7, 0);
      for (final e in counts30.entries) {
        if (e.value > 0) {
          final idx = DateTime.parse(e.key).weekday - 1;
          wd[idx] += e.value;
          wdCount[idx]++;
        }
      }
      final maxWd = wd.fold(0, max);
      if (maxWd > 0) {
        final bestIdx = wd.indexOf(maxWd);
        bestWeekday = DateFormat('EEE', locale).format(DateTime(2024, 1, 1 + bestIdx));
        bestWeekdayAvg = wdCount[bestIdx] > 0 ? (wd[bestIdx] / wdCount[bestIdx]).round() : 0;
      }
    }

    // Best day contextual: date + multiplier
    DateTime? bestDayDate;
    double bestDayMultiplier = 0;
    if (_weeklyData != null && bestDay > 0) {
      final maxV = _weeklyData!.fold(0, max);
      final idx = _weeklyData!.lastIndexOf(maxV);
      bestDayDate = DateTime.now().subtract(Duration(days: 6 - idx));
      final avg7 = _weeklyData!.fold(0, (a, b) => a + b) / 7.0;
      if (avg7 > 0) bestDayMultiplier = bestDay / avg7;
    }

    return ListView(
      padding: AppTheme.pagePadding.copyWith(top: AppTheme.spaceSm, bottom: bottomPad),
      children: [
        // ── 30-day activity heatmap ───────────────────────────────────────
        if (_dailyCounts != null) ...[
          SectionHeader(l10n.statsInDepth30Days),
          const SizedBox(height: AppTheme.spaceXs),
          _CalendarHeatmap(dailyCounts: _dailyCounts!, isDark: isDark),
          const SizedBox(height: AppTheme.spaceLg),
        ],
        // ── All-time: side-by-side bare numbers with hairline ─────────────
        SectionHeader(l10n.statsAllTimeSection),
        const SizedBox(height: AppTheme.spaceXs),
        IntrinsicHeight(child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$totalUploads', style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: AppFontWeights.bold,
              height: AppLineHeights.numeric,
              letterSpacing: AppTheme.letterSpacingDisplay,
            )),
            const SizedBox(height: AppTheme.spaceXxxs),
            Text(l10n.statsUploadsUnit, style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary(isDark),
            )),
          ])),
          if (zones > 0) ...[
            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd), color: hairline),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(km2Str, style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: AppFontWeights.bold,
                height: AppLineHeights.numeric,
                letterSpacing: AppTheme.letterSpacingDisplay,
              )),
              const SizedBox(height: AppTheme.spaceXxxs),
              Text(l10n.statsKm2Unit, style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary(isDark),
              )),
            ])),
          ],
        ])),
        const SizedBox(height: AppTheme.spaceLg),

        // ── Data quality bar ──────────────────────────────────────────────
        if (_qualityPct != null) ...[
          _buildQualityBar(theme, isDark, _qualityPct!),
          const SizedBox(height: AppTheme.spaceLg),
        ],

        // ── Habits: 3-column hairline grid ───────────────────────────────
        if (counts30 != null) ...[
          SectionHeader(l10n.statsInDepthHabits),
          const SizedBox(height: AppTheme.spaceXs),
          IntrinsicHeight(child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$activeDays30', style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: AppFontWeights.bold,
                height: AppLineHeights.numeric,
                letterSpacing: AppTheme.letterSpacingDisplay,
              )),
              Text(l10n.statsLast30DaysUnit, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary(isDark))),
              const SizedBox(height: AppTheme.spaceXxxs + 1),
              Text(l10n.statsInDepthActiveDays, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.statLabel(isDark)),
            ])),
            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm), color: hairline),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$avgPerActiveDay', style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: AppFontWeights.bold,
                height: AppLineHeights.numeric,
                letterSpacing: AppTheme.letterSpacingDisplay,
              )),
              Text(l10n.statsUploadsUnit, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary(isDark))),
              const SizedBox(height: AppTheme.spaceXxxs + 1),
              Text(l10n.statsInDepthAvgPerDay, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.statLabel(isDark)),
            ])),
            if (bestWeekday != null) ...[
              Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm), color: hairline),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bestWeekday, style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  height: AppLineHeights.numeric,
                )),
                Text('${l10n.statsAvgPrefix} $bestWeekdayAvg', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary(isDark))),
                const SizedBox(height: AppTheme.spaceXxxs + 1),
                Text(l10n.statsInDepthBestWeekday, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.statLabel(isDark)),
              ])),
            ],
          ])),
          const SizedBox(height: AppTheme.spaceLg),
        ],

        // ── Weekly chart ─────────────────────────────────────────────────
        SectionHeader(l10n.statsActivityTrend),
        const SizedBox(height: AppTheme.spaceXs),
        _buildActivityChart(theme, isDark, l10n),
        const SizedBox(height: AppTheme.spaceLg),

        // ── Best day callout (green card) ─────────────────────────────────
        if (bestDay > 0) ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$bestDay', style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: AppFontWeights.bold,
                      color: AppColors.primary,
                      height: AppLineHeights.numeric,
                      letterSpacing: AppTheme.letterSpacingDisplay,
                    )),
                    Text(l10n.statsUploadsUnit, style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    )),
                    if (bestDayDate != null) ...[
                      const SizedBox(height: AppTheme.spaceXxxs),
                      Text(DateFormat('EEE, MMM d', locale).format(bestDayDate), style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      )),
                    ],
                  ],
                ),
                const Spacer(),
                if (bestDayMultiplier > 1.1)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${bestDayMultiplier.toStringAsFixed(1)}×', style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: AppFontWeights.bold,
                        color: AppColors.primary,
                      )),
                      Text(l10n.statsInDepthAvgPerDay, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      )),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
        ],

        // ── Personal records: bare list with colored dots ─────────────────
        SectionHeader(l10n.statsPersonalRecords),
        const SizedBox(height: AppTheme.spaceXs),
        Column(children: [
          _RecordRow(dot: AppColors.primary, label: l10n.statsRecordLongestStreak, value: '$longest', unit: l10n.statsDaysUnit, isDark: isDark),
          _Divider(isDark: isDark),
          _RecordRow(dot: AppColors.warning, label: l10n.statsBestWeekLabel, value: '$bestWeek', unit: l10n.statsUploadsUnit, isDark: isDark),
          _Divider(isDark: isDark),
          if (daysActive > 0) ...[
            _RecordRow(dot: AppColors.movement, label: l10n.statsDaysActive, value: '$daysActive', unit: l10n.statsDaysUnit, isDark: isDark),
            _Divider(isDark: isDark),
          ],
          _RecordRow(dot: AppColors.light, label: l10n.statsRecordBestDay, value: '$bestDay', unit: l10n.statsUploadsUnit, isDark: isDark),
        ]),
        const SizedBox(height: AppTheme.spaceLg),

        // ── Sensors: chips ────────────────────────────────────────────────
        SectionHeader(l10n.statsTerritoryWhatRecorded),
        const SizedBox(height: AppTheme.spaceXs),
        Wrap(spacing: AppTheme.spaceXs, runSpacing: AppTheme.spaceXxs, children: [
          _SensorChip(icon: Icons.wb_sunny_outlined, label: l10n.statsTerritoryLightLabel, color: AppColors.light),
          _SensorChip(icon: Icons.directions_walk, label: l10n.statsTerritoryMotionLabel, color: AppColors.movement),
          _SensorChip(icon: Icons.compress_rounded, label: l10n.statsTerritoryPressureLabel, color: AppColors.pressure),
        ]),
        const SizedBox(height: AppTheme.spaceLg),

        // ── Map CTA ───────────────────────────────────────────────────────
        if (widget.onGoToHome != null)
          PressScaleDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onGoToHome!();
            },
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: AppTheme.surfaceContainer(isDark: isDark),
              child: Row(children: [
                Icon(Icons.map_outlined, size: AppIconSizes.xs, color: AppColors.primary),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(child: Text(l10n.statsTerritoryMapCta, style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ))),
                Icon(Icons.arrow_forward, size: AppIconSizes.xxs, color: AppColors.primary),
              ]),
            ),
          ),
      ],
    );
  }
}

// ── Stats tab bar ─────────────────────────────────────────────────────────────

class _StatsTabBar extends StatelessWidget {
  const _StatsTabBar({required this.controller, required this.isDark, required this.l10n});
  final TabController controller;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXxs),
      child: TabBar(
        controller: controller,
        labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: AppFontWeights.semibold),
        unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: AppFontWeights.medium),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary(isDark),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
          insets: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
        ),
        tabs: [
          Tab(text: l10n.statsTabCore),
          Tab(text: l10n.statsTabInDepth),
        ],
      ),
    );
  }
}

// ── Chart range toggle (W / M segmented control) ─────────────────────────────

class _ChartRangeToggle extends StatelessWidget {
  const _ChartRangeToggle({
    required this.monthView,
    required this.isDark,
    required this.weekLabel,
    required this.monthLabel,
    required this.onChanged,
  });
  final bool monthView;
  final bool isDark;
  final String weekLabel;
  final String monthLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryAlpha(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(label: weekLabel, selected: !monthView, onTap: () => onChanged(false), isDark: isDark),
          _Tab(label: monthLabel, selected: monthView, onTap: () => onChanged(true), isDark: isDark),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap, required this.isDark});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs + 2, vertical: AppTheme.spaceXxxs + 1),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: selected ? AppFontWeights.semibold : AppFontWeights.medium,
            color: selected ? AppColors.darkTextPrimary : AppColors.textSecondary(isDark),
          ),
        ),
      ),
    );
  }
}


class _SensorTypesRow extends StatelessWidget {
  const _SensorTypesRow({required this.isDark, required this.l10n});
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sensors = [
      (icon: Icons.wb_sunny_outlined,    color: AppColors.light,     label: l10n.statsTerritoryLightLabel,    desc: l10n.statsTerritoryLightDesc),
      (icon: Icons.directions_walk,      color: AppColors.movement,  label: l10n.statsTerritoryMotionLabel,   desc: l10n.statsTerritoryMotionDesc),
      (icon: Icons.compress_rounded,     color: AppColors.pressure,  label: l10n.statsTerritoryPressureLabel, desc: l10n.statsTerritoryPressureDesc),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l10n.statsTerritoryWhatRecorded),
        ...sensors.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(s.icon, size: AppIconSizes.xxs, color: s.color),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: AppFontWeights.semibold)),
                    Text(s.desc,  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary(isDark))),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}


// ── 30-day calendar heatmap ───────────────────────────────────────────────────

class _CalendarHeatmap extends StatefulWidget {
  const _CalendarHeatmap({required this.dailyCounts, required this.isDark});
  final Map<String, int> dailyCounts;
  final bool isDark;

  @override
  State<_CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<_CalendarHeatmap> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;
    final l10n = context.l10n;
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final days = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
    final maxCount = widget.dailyCounts.values.fold(0, max);
    final locale = Localizations.localeOf(context).toString();

    // Localized Mon-Sun single-char headers
    final dayHeaders = List.generate(7, (i) {
      final d = DateTime(2024, 1, 1 + i); // Jan 1 2024 = Monday
      return DateFormat('E', locale).format(d)[0].toUpperCase();
    });

    // Group into rows of 7
    final rows = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      rows.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }

    // Selected day detail
    final selCount = _selectedKey != null ? (widget.dailyCounts[_selectedKey!] ?? 0) : null;
    final selDate = _selectedKey != null ? DateTime.parse(_selectedKey!) : null;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMM', locale).format(days.first) == DateFormat('MMM', locale).format(today)
                      ? DateFormat('MMMM yyyy', locale).format(today)
                      : '${DateFormat('MMM', locale).format(days.first)} – ${DateFormat('MMM yyyy', locale).format(today)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: AppFontWeights.semibold),
                ),
              ),
              // Selected day chip
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: selCount != null && selDate != null
                    ? Container(
                        key: ValueKey(_selectedKey),
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs, vertical: 2),
                        decoration: BoxDecoration(
                          color: selCount > 0
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.primaryAlpha(0.06),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                        ),
                        child: Text(
                          selCount > 0
                              ? l10n.statsHeatmapDayDetail(
                                  DateFormat('EEE d', locale).format(selDate), selCount)
                              : l10n.statsHeatmapNoUploads(DateFormat('EEE d', locale).format(selDate)),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: selCount > 0 ? AppColors.primary : AppColors.textTertiary(isDark),
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          // Localized day-of-week header
          Row(
            children: dayHeaders.map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary(isDark),
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: AppTheme.spaceXxxs + 2),
          ...rows.map((week) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (week == rows.first)
                  ...List.generate(
                    (week.first.weekday - 1) % 7,
                    (_) => const Expanded(child: SizedBox()),
                  ),
                ...week.map((day) {
                  final key = DateFormat('yyyy-MM-dd').format(day);
                  final count = widget.dailyCounts[key] ?? 0;
                  final isToday = key == todayKey;
                  final isSelected = key == _selectedKey;
                  final intensity = maxCount > 0 ? count / maxCount : 0.0;

                  Color dotColor;
                  if (count == 0) {
                    dotColor = AppColors.primaryAlpha(0.08);
                  } else if (intensity < 0.33) {
                    dotColor = AppColors.primary.withValues(alpha: 0.35);
                  } else if (intensity < 0.66) {
                    dotColor = AppColors.primary.withValues(alpha: 0.60);
                  } else {
                    dotColor = AppColors.primary;
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedKey = isSelected ? null : key);
                      },
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: dotColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                            border: isSelected
                                ? Border.all(color: AppColors.primary, width: 2)
                                : isToday
                                    ? Border.all(color: AppColors.primary, width: 1.5)
                                    : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (week == rows.last)
                  ...List.generate(
                    (7 - week.length) % 7,
                    (_) => const Expanded(child: SizedBox()),
                  ),
              ],
            ),
          )),
          const SizedBox(height: AppTheme.spaceXxs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                l10n.statsHeatmapLess,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary(isDark)),
              ),
              const SizedBox(width: AppTheme.spaceXxs),
              ...[0.08, 0.35, 0.60, 1.0].map((a) => Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: a),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxs),
                ),
              )),
              Text(
                l10n.statsHeatmapMore,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary(isDark)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sensor chip (icon + label, no description) ───────────────────────────────

class _SensorChip extends StatelessWidget {
  const _SensorChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXxs + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.xxs, color: color),
          const SizedBox(width: AppTheme.spaceXxxs + 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: AppFontWeights.semibold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Explainer row (icon + one-line text) ─────────────────────────────────────

class _ExplainerRow extends StatelessWidget {
  const _ExplainerRow({required this.icon, required this.color, required this.text, required this.isDark});
  final IconData icon;
  final Color color;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: AppIconSizes.xxs, color: color),
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark)),
          ),
        ),
      ],
    );
  }
}

// ── Milestone progress ring ───────────────────────────────────────────────────

class _MilestoneRing extends StatelessWidget {
  const _MilestoneRing({
    required this.progress,
    required this.total,
    required this.next,
  });
  final double progress;
  final int total;
  final int next;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _RingPainter(progress: progress),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  color: AppColors.warning,
                  height: AppLineHeights.tight,
                ),
              ),
              Text(
                '/$next',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning.withValues(alpha: 0.65),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge({required this.value, required this.isDark});
  final int value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMin),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: AppTheme.fontSizeXxs, color: AppColors.warning),
          const SizedBox(width: AppTheme.spaceTiny),
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 7) / 2;
    const sw = AppBorderWidths.ringStroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, 2 * pi, false,
      Paint()
        ..color = AppColors.warning.withValues(alpha: 0.13)
        ..strokeWidth = sw
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = AppColors.warning
          ..strokeWidth = sw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── KPI hairline grid cell ────────────────────────────────────────────────────

class _KpiCell extends StatelessWidget {
  const _KpiCell({required this.label, required this.value, required this.isDark, required this.theme});
  final String label;
  final String? value;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            child: value != null
                ? Text(value!, key: ValueKey(value), style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: AppFontWeights.bold,
                    height: AppLineHeights.numeric,
                    letterSpacing: AppTheme.letterSpacingNumeric,
                  ))
                : SizedBox(key: const ValueKey('loading'), width: 36, height: 22, child: LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxs),
                    backgroundColor: AppColors.textTertiary(isDark).withValues(alpha: 0.12),
                    color: AppColors.primary.withValues(alpha: 0.4),
                  )),
          ),
          const SizedBox(height: AppTheme.spaceXxxs),
          Text(label, style: AppTheme.statLabel(isDark)),
        ],
      ),
    );
  }
}

// ── Record row (dot + label + right-aligned value) ────────────────────────────

class _RecordRow extends StatelessWidget {
  // ignore: unused_element_parameter
  const _RecordRow({required this.dot, required this.label, this.sub, required this.value, required this.unit, required this.isDark});
  final Color dot;
  final String label;
  final String? sub;
  final String value;
  final String unit;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
      child: Row(children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: dot.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))),
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: AppFontWeights.medium)),
          if (sub != null)
            Text(sub!, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary(isDark))),
        ])),
        RichText(text: TextSpan(children: [
          TextSpan(text: value, style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppFontWeights.bold,
            color: AppColors.textPrimary(isDark),
            letterSpacing: -0.3,
          )),
          TextSpan(text: ' $unit', style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary(isDark),
          )),
        ])),
      ]),
    );
  }
}

// ── Thin divider for list containers ─────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.textTertiary(isDark).withValues(alpha: 0.12),
      indent: AppTheme.spaceMd,
      endIndent: AppTheme.spaceMd,
    );
  }
}

// ── Weekly goal celebration overlay ──────────────────────────────────────────
// Full-screen dimmed overlay with a centered card.
// Auto-dismisses after 4s; tappable anywhere to dismiss early.
class _WeeklyGoalCelebration extends StatefulWidget {
  const _WeeklyGoalCelebration({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  State<_WeeklyGoalCelebration> createState() => _WeeklyGoalCelebrationState();
}

class _WeeklyGoalCelebrationState extends State<_WeeklyGoalCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: _fadeAnim.value,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55 * _fadeAnim.value),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: child,
              ),
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                l10n.weeklyGoalTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  letterSpacing: AppTheme.letterSpacingSubtle,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                l10n.weeklyGoalBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onDismiss,
                  child: Text(l10n.weeklyGoalDismiss),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Locked sensor row for empty state ────────────────────────────────────────
class _LockedSensorRow extends StatelessWidget {
  const _LockedSensorRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.isDark,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceXs,
      ),
      decoration: AppTheme.contentCard(isDark: isDark),
      child: Row(
        children: [
          Icon(icon, size: AppIconSizes.sm, color: color.withValues(alpha: 0.70)),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


