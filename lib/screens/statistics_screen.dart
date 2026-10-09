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
import '../core/utils/area_format.dart';
import '../core/events/app_events.dart';
import '../core/app_preferences.dart';
import '../core/utils/composite_subscription.dart';
import '../services/location/foreground_location_service.dart';
import '../services/sensors/sensor_capabilities.dart';
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
  final _locationService = ForegroundLocationService.instance;

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
  // Community stats — active mapper count + total zones from /api/stats/global
  // (1h server cache). Fetched alongside profile but was previously discarded
  // after destructuring — never actually shown anywhere.
  GlobalStatsResponse? _global;
  // Streak data from backend profile
  int? _longestStreak;
  // Weekly new-territory target
  WeeklyTargetResponse? _weeklyTarget;
  // "Only you" impact — cells nobody else has ever mapped
  ImpactResponse? _impact;
  // Data quality 0–100 from user_stats valid_samples/samples_count
  int? _qualityPct;
  // Week-over-week comparison: total uploads in the previous 7-day window
  int? _prevWeekTotal;

  // 30-day heatmap: key = 'yyyy-MM-dd', value = upload count
  Map<String, int>? _dailyCounts;

  final _subs = <StreamSubscription>[];
  // ── Entrance animations ───────────────────────────────────────────────────────
  /// Delay added per card so they cascade in instead of arriving together.
  static const _kEntranceStagger = 0.10;
  /// Portion of the controller's run each card animates over.
  static const _kEntranceSpan = 0.55;

  late final AnimationController _entranceCtrl;
  /// Built on demand and cached — no fixed length, so adding a card never
  /// requires bumping a count (and can never overrun it).
  final Map<int, CurvedAnimation> _cardAnims = {};

  CurvedAnimation _cardAnim(int index) => _cardAnims.putIfAbsent(index, () {
        final start = (index * _kEntranceStagger).clamp(0.0, 1.0);
        return CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(
            start,
            (start + _kEntranceSpan).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        );
      });
  // ── Bar chart selection + range ──────────────────────────────────────────────
  bool _chartMonthView = false; // false = 7-day, true = 30-day (needs backend)
  // ── Backend call throttle — avoid repeated fetches on quick tab switches ──────
  DateTime? _lastWeeklyFetch;

  @override
  void initState() {
    super.initState();
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

    _subs.add(AppEventBus.instance.on<UploadSuccessEvent>().listen((_) {
      if (mounted) {
        _loadStats();
        _loadWeeklyStats(force: true);
        _loadDailyCounts();
      }
    }));
    _subs.add(AppEventBus.instance.on<StatsUpdatedEvent>().listen((event) {
      if (mounted) setState(() { _stats = event.stats; _isLoading = false; });
    }));

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
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
    _subs.cancelAll();
    for (final anim in _cardAnims.values) { anim.dispose(); }
    _entranceCtrl.dispose();
    super.dispose();
  }

  /// Spacing + entrance for a card that only renders when its data is present.
  /// [builder] receives the non-null value, so call sites need no `!`. Returns
  /// an empty list when absent, so the caller spreads it straight into the
  /// ListView — no extra wrapper widget, identical layout to an inline `if`.
  List<Widget> _optionalCard<T>(
    T? value,
    int animIndex,
    Widget Function(T) builder, {
    bool Function(T)? when,
  }) {
    if (value == null || (when != null && !when(value))) return const [];
    return [
      const SizedBox(height: AppTheme.spaceSm),
      _withEntrance(builder(value), animIndex),
    ];
  }

  /// Wraps a card widget with a staggered fade+slide entrance.
  Widget _withEntrance(Widget child, int index) {
    final anim = _cardAnim(index);
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
      final impactFuture = StatsService.instance.fetchImpact();
      final (:profile, :global) = await profileFuture;
      final weeklyTarget = await targetFuture;
      final impact = await impactFuture;
      if (mounted) {
        setState(() {
          if (global.activeMappers > 0) _global = global;
          _weeklyData = profile.weekly;
          unawaited(AppPreferences.instance.setCachedWeeklyData(profile.weekly));
          _backendTotalUploads = profile.totalUploads;
          _coverageCells = profile.coverageCells;
          _daysActive = profile.daysActive;
          _longestStreak = profile.longestStreak;
          if (profile.qualityPct != null) _qualityPct = profile.qualityPct;
          if (profile.prevWeekTotal != null) _prevWeekTotal = profile.prevWeekTotal;
          if (weeklyTarget != null) _weeklyTarget = weeklyTarget;
          if (impact != null) _impact = impact;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final effectiveTotal = (_stats?.totalUploads ?? 0) > 0
        ? _stats!.totalUploads
        : (_backendTotalUploads ?? 0);
    final stillLoading = _isLoading || (_isLoadingWeekly && _backendTotalUploads == null && effectiveTotal == 0);

    final bottomPad = MediaQuery.paddingOf(context).bottom + AppTheme.floatingNavHeight + AppTheme.spaceMd;

    if (stillLoading) return Scaffold(body: SafeArea(child: _buildLoadingSkeleton(isDark)));
    if (effectiveTotal == 0) return Scaffold(body: SafeArea(child: _buildEmptyState(context, theme, isDark, l10n)));

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 40,
            actions: [
              IconButton(
                icon: Icon(Icons.query_stats_rounded, size: AppIconSizes.sm),
                color: AppColors.textTertiary(isDark),
                tooltip: l10n.statsOpenDetails,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _openDetailsScreen();
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: ListView(
              padding: AppTheme.pagePadding.copyWith(top: AppTheme.spaceXxs, bottom: bottomPad),
              children: [
                _withEntrance(_buildHeroCard(theme, isDark, l10n), 0),
                ..._optionalCard(_weeklyTarget, 1,
                    (t) => _buildWeeklyTargetCard(theme, isDark, l10n, t)),
                ..._optionalCard(_impact, 1,
                    (i) => _buildImpactCard(theme, isDark, l10n, i),
                    when: (i) => i.soloCells > 0),
                // No insight card (it repeated the weekly target and the
                // impact card) and no today/week/best-day numbers (the chart
                // below shows them): one representation per fact.
                const SizedBox(height: AppTheme.spaceLg),
                SectionHeader(l10n.statsActivityTrend),
                const SizedBox(height: AppTheme.spaceXs),
                _withEntrance(_buildActivityChart(theme, isDark, l10n), 3),
                const SizedBox(height: AppTheme.spaceMd),
                SectionHeader(l10n.statsTerritorySection),
                const SizedBox(height: AppTheme.spaceXxs),
                _withEntrance(_buildTerritoryAndStreak(theme, isDark, l10n), 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Details screen ──────────────────────────────────────────────────────────

  void _openDetailsScreen() {
    final localTotal = _stats?.totalUploads ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatisticsDetailScreen(
          args: StatsDetailArgs(
            dailyCounts: _dailyCounts,
            totalUploads: localTotal > 0 ? localTotal : (_backendTotalUploads ?? 0),
            zones: _coverageCells ?? 0,
            qualityPct: _qualityPct,
            daysActive: _daysActive,
            weeklyData: _weeklyData,
            longestStreak: _longestStreak ?? (_stats?.currentStreak ?? 0),
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
              // Scale of one place, as a concrete unit (Kim et al. 2016).
              _ExplainerRow(icon: Icons.hexagon_outlined, color: AppColors.primary, text: l10n.statsZoneExplainer(formatCellArea(context, 1)), isDark: isDark),
              const SizedBox(height: AppTheme.spaceMd),
              // Personal records: one surface, cells grouped by spacing.
              SectionHeader(l10n.statsPersonalRecords),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
                decoration: AppTheme.surfaceContainer(isDark: isDark),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: StatCell(label: l10n.statsRecordBestDay, value: '$bestDay')),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(child: StatCell(label: l10n.statsRecordLongestStreak, value: l10n.daysActive(longest))),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: StatCell(label: l10n.statsRecordTotalUploads, value: '$totalUploads')),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(child: StatCell(
                          label: l10n.statsRecordFirstDay,
                          value: firstDate != null
                              ? DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(firstDate)
                              : '—',
                        )),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: StatCell(
                          label: l10n.statsRecordBestSession,
                          value: '${AppPreferences.instance.bestSessionZonesGained}',
                        )),
                        const SizedBox(width: AppTheme.spaceMd),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ),
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

    // Quality-based left accent — green (≥70), amber (40-69), red (<40).
    // Omit accent when quality unknown so the card doesn't look broken on first load.
    final qualityAccent = _qualityPct == null
        ? null
        : _qualityPct! >= 70
            ? AppColors.primary
            : _qualityPct! >= 40
                ? AppColors.warning
                : AppColors.error;

    return PressScaleDetector(
      onTap: _showStatsDetailSheet,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: AppTheme.surfaceContainer(
          isDark: isDark,
          border: qualityAccent != null
              ? Border(left: BorderSide(color: qualityAccent, width: 3))
              : null,
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow
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
              builder: (_, value, __) {
                final area = formatArea(context, value);
                return RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: area.value,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: AppFontWeights.bold,
                      letterSpacing: AppTheme.letterSpacingDisplay,
                      height: AppLineHeights.numeric,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  TextSpan(
                    text: ' ${area.unit}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                ]),
              );
              },
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
                Icon(Icons.info_outline_rounded, size: AppIconSizes.xxs, color: AppColors.textTertiary(isDark).withValues(alpha: 0.65)),
            ],
          ),
        ],
      ),
      ),
    );
  }

  // ─── Territory + streak ──────────────────────────────────────────────────────
  // One factual block: zone progress, then current/longest streak. No ring, no
  // role-name link — plain numbers and labels, consistent with the rest of Stats.

  Widget _buildTerritoryAndStreak(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final total = _coverageCells;
    final streak = _stats?.currentStreak ?? 0;
    final longest = _longestStreak ?? 0;
    final hasZone = total != null;
    final hasStreak = streak > 0 || longest > 0;
    if (!hasZone && !hasStreak) return const SizedBox.shrink();

    final hairline = AppColors.textTertiary(isDark).withValues(alpha: 0.12);
    final isRecord = streak > 0 && streak >= longest && longest > 0;

    Widget? zone;
    if (hasZone) {
      final next = _kMilestones.cast<int?>().firstWhere((m) => m! > total, orElse: () => null);
      final achieved = _kMilestones.where((m) => m <= total).toList();
      if (next == null) {
        zone = Row(children: [
          Icon(Icons.workspace_premium, color: AppColors.primary, size: AppIconSizes.sm),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(l10n.statsMilestoneElite,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: AppFontWeights.semibold)),
          ),
        ]);
      } else {
        final remaining = next - total;
        zone = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.statsMilestoneRemaining(remaining),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary(isDark), fontWeight: AppFontWeights.semibold)),
          const SizedBox(height: AppTheme.spaceXxxs),
          Text('$total / $next ${l10n.statsAreasLabel}',
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.warning, fontWeight: AppFontWeights.semibold)),
          if (achieved.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: AppTheme.spaceXs,
              runSpacing: AppTheme.spaceXxs,
              children: achieved.map((m) => _MilestoneBadge(value: m, isDark: isDark)).toList(),
            ),
          ],
        ]);
      }
    }

    Widget? streakRow;
    if (hasStreak) {
      streakRow = IntrinsicHeight(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                Text(l10n.statsDaysUnit, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary.withValues(alpha: 0.7))),
                if (isRecord) ...[
                  const SizedBox(width: AppTheme.spaceXs),
                  // Flexible + ellipsis: a longer translation (French runs ~15-20%
                  // longer than English) shrinks instead of overflowing the Row.
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs + 1, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                      ),
                      child: Text(l10n.statsStreakNewRecord,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: AppFontWeights.semibold),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: AppTheme.spaceXxxs),
              Text(l10n.statsCurrentStreakLabel, style: AppTheme.statLabel(isDark).copyWith(color: AppColors.primary.withValues(alpha: 0.75))),
            ]),
          ),
          Container(width: 1, color: hairline),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppTheme.spaceMd),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  Text(l10n.statsDaysUnit, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark))),
                ]),
                const SizedBox(height: AppTheme.spaceXxxs),
                Text(l10n.statsLongestLabel, style: AppTheme.statLabel(isDark).copyWith(
                  color: isRecord ? AppColors.primary.withValues(alpha: 0.75) : null,
                )),
              ]),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (zone != null) zone,
        if (zone != null && (_coverageCells ?? 0) > 0) ...[
          const SizedBox(height: AppTheme.spaceXs),
          _buildTerritoryDetailsLink(theme, isDark, l10n),
        ],
        if (zone != null && streakRow != null) ...[
          const SizedBox(height: AppTheme.spaceSm),
          Container(height: 1, color: hairline),
          const SizedBox(height: AppTheme.spaceSm),
        ],
        if (streakRow != null) streakRow,
        if (_global != null) ...[
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            l10n.statsCommunityLine(_global!.activeMappers, _global!.totalZones),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary(isDark)),
          ),
        ],
      ]),
    );
  }

  // ─── Weekly target card ──────────────────────────────────────────────────────

  Widget _buildWeeklyTargetCard(ThemeData theme, bool isDark, AppLocalizations l10n, WeeklyTargetResponse target) {
    final done = target.newCellsThisWeek;
    final total = target.target;
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
            // The flag icon + fraction + bar already read as "progress toward
            // a goal" — no label needed, and "this week" was a duplicate of
            // the chart section's own title further down (statsActivityTrend).
            Text(
              complete ? l10n.statsWeeklyTargetComplete : '$done / $total',
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXxs),
            // One segment per place to find: a small icon array makes the
            // proportion readable at a glance and reduces denominator
            // neglect (Garcia-Retamero et al. 2012 review).
            Row(children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: AppTheme.spaceXxxs),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppDurations.medium,
                    height: AppTheme.spaceXxs,
                    decoration: BoxDecoration(
                      color: i < done ? accent : hairline,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                    ),
                  ),
                ),
              ],
            ]),
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
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark)),
            ),
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
                  if (_prevWeekTotal != null && _prevWeekTotal! > 0) ...[
                    const SizedBox(height: 1),
                    Builder(builder: (context) {
                      final prev = _prevWeekTotal!;
                      final pct = ((weeklyTotal - prev) / prev * 100).round();
                      final sign = pct >= 0 ? '+' : '';
                      final color = pct > 0
                          ? AppColors.primary
                          : pct < 0
                              ? AppColors.error
                              : AppColors.textTertiary(isDark);
                      return Text(
                        l10n.statsVsPrevWeek('$sign$pct'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: color,
                          fontWeight: AppFontWeights.medium,
                        ),
                      );
                    }),
                  ],
                ],
              ),
              _ChartRangeToggle(
                monthView: _chartMonthView,
                isDark: isDark,
                weekLabel: l10n.statsChartWeekTab,
                monthLabel: l10n.statsChartMonthTab,
                onChanged: (v) => setState(() => _chartMonthView = v),
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
          const SizedBox(height: AppTheme.spaceMd),
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
                final barColor = isToday ? AppColors.primary : AppColors.primary.withValues(alpha: 0.45);

                return Expanded(
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
                            color: isToday ? AppColors.primary : AppColors.textSecondary(isDark),
                            fontWeight: isToday ? AppFontWeights.bold : AppFontWeights.regular,
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
                          gradient: isToday
                              ? LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.65)],
                                )
                              : null,
                          color: isToday ? null : barColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusSm),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXxs),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: _kBarLabelSize,
                          color: isToday ? AppColors.primary : AppColors.textSecondary(isDark),
                          fontWeight: isToday ? AppFontWeights.semibold : AppFontWeights.regular,
                        ),
                      ),
                    ],
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
    );
  }

  void _showTerritorySheet(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final zones = _coverageCells ?? 0;
    final km2 = zones * kKm2PerCell;
    final km2Str = formatAreaText(context, km2);

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
              decoration: AppTheme.surfaceContainer(isDark: isDark),
              child: Row(
                children: [
                  Expanded(child: StatCell(label: l10n.statsKmMapped, value: km2Str)),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(child: StatCell(label: l10n.sessionSummaryZonesClaimed(zones), value: '$zones')),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            // What was recorded in each zone
            _SensorTypesRow(isDark: isDark, l10n: l10n),
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
            // "Enable tracking" only makes sense while tracking is off: with it
            // on, data simply hasn't been uploaded yet.
            if (widget.onGoToHome != null)
              ListenableBuilder(
                listenable: Listenable.merge([_locationService.isRunning, _locationService.isPaused]),
                builder: (context, _) {
                  final tracking = _locationService.isRunning.value || _locationService.isPaused.value;
                  if (tracking) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spaceXl),
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onGoToHome!();
                      },
                      child: Text(l10n.statsEmptyGoMap),
                    ),
                  );
                },
              ),
          ],
        ),
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
    return PressScaleDetector(
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
    // Every sensor the phone uploads, icon + one word: no explanatory
    // sentences. Sensors without a map layer yet stay neutral grey so hue
    // keeps meaning "this layer" (Brewer 1994).
    final neutral = AppColors.textSecondary(isDark);
    final sensors = [
      (key: 'light',       icon: Icons.wb_sunny_outlined,   color: AppColors.light,    label: l10n.statsTerritoryLightLabel),
      (key: 'motion',      icon: Icons.directions_walk,     color: AppColors.movement, label: l10n.statsTerritoryMotionLabel),
      (key: 'pressure',    icon: Icons.compress_rounded,    color: AppColors.pressure, label: l10n.statsTerritoryPressureLabel),
      (key: 'magnetic',    icon: Icons.explore_outlined,    color: neutral,            label: l10n.sensorMagneticField),
      (key: 'wifi',        icon: Icons.wifi_rounded,        color: neutral,            label: l10n.sensorWifi),
      (key: 'temperature', icon: Icons.thermostat_rounded,  color: neutral,            label: l10n.sensorTemperature),
      (key: 'humidity',    icon: Icons.water_drop_outlined, color: neutral,            label: l10n.sensorHumidity),
    ];
    return FutureBuilder<Set<String>>(
      future: SensorCapabilities.load(),
      builder: (context, snap) {
        final present = snap.data;
        // Only this phone's sensors; until known (or if the platform cannot
        // say), list the ones nearly every phone has.
        final shown = [
          for (final s in sensors)
            if (present != null && present.isNotEmpty
                ? present.contains(s.key)
                : const {'light', 'motion', 'wifi'}.contains(s.key))
              s,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(l10n.statsTerritoryWhatRecorded),
            Wrap(
              spacing: AppTheme.spaceMd,
              runSpacing: AppTheme.spaceSm,
              children: [
                for (final s in shown)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, size: AppIconSizes.xs, color: s.color),
                      const SizedBox(width: AppTheme.spaceXxs),
                      Text(s.label, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textPrimary(isDark))),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}


// ── Day-of-week personality chart ────────────────────────────────────────────

/// 7-bar mini chart (Mon–Sun) showing relative activity distribution.
/// Inspired by Dawarich's weekly_pattern_chart_data helper.
class _WeekdayChart extends StatelessWidget {
  const _WeekdayChart({
    required this.dayTotals,
    required this.isDark,
    required this.locale,
  });
  final List<int> dayTotals; // length 7, index 0 = Monday
  final bool isDark;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxV = dayTotals.fold(0, max);
    if (maxV == 0) return const SizedBox.shrink();
    final bestIdx = dayTotals.indexOf(maxV);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceSm),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final value = dayTotals[i];
          final fraction = maxV > 0 ? value / maxV : 0.0;
          final isMax = i == bestIdx && value > 0;
          final label = DateFormat('E', locale)
              .format(DateTime(2024, 1, 1 + i))[0]
              .toUpperCase();

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction),
                    duration: Duration(milliseconds: 400 + i * 60),
                    curve: Curves.easeOut,
                    builder: (_, frac, __) => SizedBox(
                      height: _kBarMaxH,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: max(_kBarMinH, _kBarMaxH * frac),
                          decoration: BoxDecoration(
                            color: isMax
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.28),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isMax
                          ? AppColors.primary
                          : AppColors.textTertiary(isDark),
                      fontWeight: isMax
                          ? AppFontWeights.bold
                          : AppFontWeights.medium,
                      fontSize: _kBarLabelSize,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
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

// ── KPI hairline grid cell ────────────────────────────────────────────────────


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

// ── Locked sensor row for empty state ────────────────────────────────────────
// ── In-depth statistics screen ────────────────────────────────────────────────

class StatsDetailArgs {
  const StatsDetailArgs({
    required this.totalUploads,
    required this.zones,
    this.dailyCounts,
    this.qualityPct,
    this.daysActive,
    this.weeklyData,
    this.longestStreak,
  });
  final int totalUploads;
  final int zones;
  final Map<String, int>? dailyCounts;
  final int? qualityPct;
  final int? daysActive;
  final List<int>? weeklyData;
  final int? longestStreak;
}

class StatisticsDetailScreen extends StatelessWidget {
  const StatisticsDetailScreen({super.key, required this.args});
  final StatsDetailArgs args;

  Widget _qualityBar(ThemeData theme, bool isDark, AppLocalizations l10n, int pct) {
    final Color barColor;
    final String label;
    if (pct >= 80) {
      barColor = AppColors.quality; label = l10n.statsQualityExcellent;
    } else if (pct >= 60) {
      barColor = AppColors.primary; label = l10n.statsQualityGood;
    } else if (pct >= 40) {
      barColor = AppColors.warning; label = l10n.statsQualityFair;
    } else {
      barColor = AppColors.error; label = l10n.statsQualityLow;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(l10n.statsQualitySection),
      const SizedBox(height: AppTheme.spaceXs),
      Row(children: [
        Text('$pct%', style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: AppFontWeights.bold, color: barColor,
          height: AppLineHeights.numeric, letterSpacing: AppTheme.letterSpacingDisplay,
        )),
        const SizedBox(width: AppTheme.spaceSm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs, vertical: 3),
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMin),
          ),
          child: Text(label, style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: AppFontWeights.semibold, color: barColor,
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
            value: value, minHeight: 6,
            backgroundColor: barColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ),
      const SizedBox(height: AppTheme.spaceXxs),
      Text(l10n.statsQualitySubtitle,
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary(isDark))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppTheme.spaceMd;
    final locale = Localizations.localeOf(context).toString();
    final hairline = AppColors.textTertiary(isDark).withValues(alpha: 0.12);

    final counts30 = args.dailyCounts;
    final activeDays30 = counts30?.values.where((v) => v > 0).length ?? 0;
    final total30 = counts30?.values.fold(0, (a, b) => a + b) ?? 0;
    final avgPerActiveDay = activeDays30 > 0 ? (total30 / activeDays30).round() : 0;

    String? bestWeekday;
    int bestWeekdayAvg = 0;
    List<int>? weekdayTotals;
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
        weekdayTotals = wd;
      }
    }

    final km2 = args.zones * kKm2PerCell;
    final area = formatArea(context, km2);
    final bestDay = args.weeklyData != null ? args.weeklyData!.fold(0, max) : 0;
    final bestWeek = args.weeklyData?.fold(0, (a, b) => a + b) ?? 0;
    final longest = args.longestStreak ?? 0;
    final daysActive = args.daysActive ?? 0;

    DateTime? bestDayDate;
    double bestDayMultiplier = 0;
    if (args.weeklyData != null && bestDay > 0) {
      final maxV = args.weeklyData!.fold(0, max);
      final idx = args.weeklyData!.lastIndexOf(maxV);
      bestDayDate = DateTime.now().subtract(Duration(days: 6 - idx));
      final avg7 = args.weeklyData!.fold(0, (a, b) => a + b) / 7.0;
      if (avg7 > 0) bestDayMultiplier = bestDay / avg7;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTabInDepth,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.semibold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: AppIconSizes.xs),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding.copyWith(top: AppTheme.spaceSm, bottom: bottomPad),
        children: [
          if (counts30 != null) ...[
            SectionHeader(l10n.statsInDepth30Days),
            const SizedBox(height: AppTheme.spaceXs),
            _CalendarHeatmap(dailyCounts: counts30, isDark: isDark),
            const SizedBox(height: AppTheme.spaceLg),
          ],
          SectionHeader(l10n.statsAllTimeSection),
          const SizedBox(height: AppTheme.spaceXs),
          Container(
            decoration: AppTheme.surfaceContainer(isDark: isDark),
            child: IntrinsicHeight(child: Row(children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${args.totalUploads}', style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: AppFontWeights.bold,
                    height: AppLineHeights.numeric,
                    letterSpacing: AppTheme.letterSpacingDisplay,
                  )),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  Text(l10n.statsUploadsUnit, style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  )),
                ]),
              )),
              if (args.zones > 0) ...[
                Container(width: 1, color: hairline),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(area.value, style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: AppFontWeights.bold,
                      height: AppLineHeights.numeric,
                      letterSpacing: AppTheme.letterSpacingDisplay,
                    )),
                    const SizedBox(height: AppTheme.spaceXxxs),
                    Text(area.unit, style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    )),
                  ]),
                )),
              ],
            ])),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          if (args.qualityPct != null) ...[
            _qualityBar(theme, isDark, l10n, args.qualityPct!),
            const SizedBox(height: AppTheme.spaceLg),
          ],
          if (counts30 != null) ...[
            SectionHeader(l10n.statsInDepthHabits),
            const SizedBox(height: AppTheme.spaceXs),
            Container(
              decoration: AppTheme.surfaceContainer(isDark: isDark),
              child: IntrinsicHeight(child: Row(children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$activeDays30', style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: AppFontWeights.bold, height: AppLineHeights.numeric,
                      letterSpacing: AppTheme.letterSpacingDisplay,
                    )),
                    Text(l10n.statsLast30DaysUnit, style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary(isDark))),
                    const SizedBox(height: AppTheme.spaceXxxs + 1),
                    Text(l10n.statsInDepthActiveDays, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTheme.statLabel(isDark)),
                  ]),
                )),
                Container(width: 1, color: hairline),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$avgPerActiveDay', style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: AppFontWeights.bold, height: AppLineHeights.numeric,
                      letterSpacing: AppTheme.letterSpacingDisplay,
                    )),
                    Text(l10n.statsUploadsUnit, style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary(isDark))),
                    const SizedBox(height: AppTheme.spaceXxxs + 1),
                    Text(l10n.statsInDepthAvgPerDay, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTheme.statLabel(isDark)),
                  ]),
                )),
                if (bestWeekday != null) ...[
                  Container(width: 1, color: hairline),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(bestWeekday, style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: AppFontWeights.bold, height: AppLineHeights.numeric,
                      )),
                      Text('${l10n.statsAvgPrefix} $bestWeekdayAvg', style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary(isDark))),
                      const SizedBox(height: AppTheme.spaceXxxs + 1),
                      Text(l10n.statsInDepthBestWeekday, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppTheme.statLabel(isDark)),
                    ]),
                  )),
                ],
              ])),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],
          if (weekdayTotals != null) ...[
            SectionHeader(l10n.statsInDepthWhenYouMap),
            const SizedBox(height: AppTheme.spaceXs),
            _WeekdayChart(dayTotals: weekdayTotals, isDark: isDark, locale: locale),
            const SizedBox(height: AppTheme.spaceLg),
          ],
          if (bestDay > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$bestDay', style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: AppFontWeights.bold, color: AppColors.primary,
                    height: AppLineHeights.numeric, letterSpacing: AppTheme.letterSpacingDisplay,
                  )),
                  Text(l10n.statsUploadsUnit, style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary(isDark))),
                  if (bestDayDate != null) ...[
                    const SizedBox(height: AppTheme.spaceXxxs),
                    Text(DateFormat('EEE, MMM d', locale).format(bestDayDate),
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary(isDark))),
                  ],
                ]),
                const Spacer(),
                if (bestDayMultiplier > 1.1)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${bestDayMultiplier.toStringAsFixed(1)}×', style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppFontWeights.bold, color: AppColors.primary,
                    )),
                    Text(l10n.statsInDepthAvgPerDay, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary(isDark))),
                  ]),
              ]),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],
          SectionHeader(l10n.statsPersonalRecords),
          const SizedBox(height: AppTheme.spaceXs),
          Container(
            decoration: AppTheme.surfaceContainer(isDark: isDark),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
            child: Column(children: [
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
          ),
          const SizedBox(height: AppTheme.spaceLg),
          SectionHeader(l10n.statsTerritoryWhatRecorded),
          const SizedBox(height: AppTheme.spaceXs),
          Wrap(spacing: AppTheme.spaceXs, runSpacing: AppTheme.spaceXxs, children: [
            _SensorChip(icon: Icons.wb_sunny_outlined, label: l10n.statsTerritoryLightLabel, color: AppColors.light),
            _SensorChip(icon: Icons.directions_walk, label: l10n.statsTerritoryMotionLabel, color: AppColors.movement),
            _SensorChip(icon: Icons.compress_rounded, label: l10n.statsTerritoryPressureLabel, color: AppColors.pressure),
          ]),
        ],
      ),
    );
  }
}
