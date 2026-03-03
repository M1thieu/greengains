import 'dart:async';
import 'dart:convert';
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
const _kChartH         = 148.0; // height reserved for the bar chart + labels
const _kBarMaxH        = 72.0;  // tallest bar at 100 % of the data range
const _kBarMinH        = 4.0;   // floor so 0-count bars remain visible
const _kBarLabelH      = AppTheme.spaceLg + AppTheme.spaceSm; // 36 px = label area below bars
const _kBarAnimStagger = 40;    // ms added per bar for cascade entrance
const _kBarLabelSize   = 10.0;  // day-of-week label below each bar (below bodySmall)
const _kSkeletonTileH  = 80.0;  // height of each stat-tile skeleton rect
const _kSkeletonTitleW = 160.0; // width of section-title skeleton rect
const _kHeroIconSize   = 80.0;  // empty-state centre icon size
const _kProgressH      = 6.0;   // milestone progress bar height

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
  int? _backendCurrentStreak;
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
      final response = await BackendClient.get('/api/user/profile');
      if (response.statusCode == 200 && mounted) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final stats = body['stats'] as Map<String, dynamic>?;
        final raw = stats?['weekly'] as List<dynamic>?;
        final daysActive = stats?['daysActive'] as int?;
        final totalUploads = stats?['totalUploads'] as int?;
        final currentStreak = stats?['currentStreak'] as int?;
        if (raw != null) {
          setState(() {
            _weeklyData = raw.map((e) => e is num ? e.toInt() : 0).toList();
            _daysActive = daysActive;
            _backendTotalUploads = totalUploads;
            _backendCurrentStreak = currentStreak;
          });
        }
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsScreenTitle)),
      body: _isLoading
          ? _buildLoadingSkeleton(isDark)
          : _stats == null || _stats!.totalUploads == 0
              ? _buildEmptyState(context, theme, isDark)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: ListView(
                    padding: AppTheme.pagePadding,
                    children: [
                      _buildQuickStatsGrid(theme, isDark),
                      const SizedBox(height: AppTheme.spaceMd),
                      _buildMilestoneProgress(theme, isDark),
                      const SizedBox(height: AppTheme.spaceLg),
                      _buildSectionHeader(l10n.statsContributionTimeline, theme, isDark),
                      const SizedBox(height: AppTheme.spaceMd),
                      _buildActivityChart(theme, isDark, l10n),
                    ],
                  ),
                ),
    );
  }

  // ─── Quick stats ────────────────────────────────────────────────────────────

  Widget _buildQuickStatsGrid(ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    // Use local SQLite values when available; fall back to backend on fresh reinstall
    final localTotal = _stats!.totalUploads;
    final displayTotal = localTotal > 0 ? localTotal : (_backendTotalUploads ?? 0);
    final localStreak = _stats!.currentStreak;
    final displayStreak = localStreak > 0 ? localStreak : (_backendCurrentStreak ?? 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildQuickStatTile(l10n.statsTotal, '$displayTotal', Icons.eco, AppColors.primary, theme, isDark)),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(child: _buildQuickStatTile(l10n.statsToday, '${_stats!.uploadsToday}', Icons.today, AppColors.pressure, theme, isDark)),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(child: _buildQuickStatTile(l10n.statsDaysActive, _daysActive != null ? '$_daysActive' : '—', Icons.calendar_month_outlined, AppColors.movement, theme, isDark)),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(child: _buildQuickStatTile(l10n.statsStreak, '${displayStreak}d', Icons.local_fire_department, AppColors.warning, theme, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStatTile(String label, String value, IconData icon, Color iconColor, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceXs),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppIconSizes.sm, color: iconColor),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: AppFontWeights.bold)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark))),
        ],
      ),
    );
  }

  // ─── Milestone progress ─────────────────────────────────────────────────────

  Widget _buildMilestoneProgress(ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    final total = (_stats?.totalUploads ?? 0) > 0
        ? _stats!.totalUploads
        : (_backendTotalUploads ?? 0);

    // Find the next milestone above the current total
    final next = _kMilestones.cast<int?>().firstWhere(
      (m) => m! > total,
      orElse: () => null,
    );

    // All milestones reached — elite badge
    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: AppTheme.surfaceContainer(isDark: isDark),
        child: Row(
          children: [
            Icon(Icons.stars_rounded, color: AppColors.warning, size: AppIconSizes.md),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                l10n.statsMilestoneElite,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: AppFontWeights.semibold),
              ),
            ),
          ],
        ),
      );
    }

    final progress = (total / next).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.statsMilestoneLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              Text(
                '$total / $next',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: AppDurations.medium,
            curve: AppMotion.decelerated,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.spaceXxxs),
              child: LinearProgressIndicator(
                value: value,
                minHeight: _kProgressH,
                backgroundColor: AppColors.primaryAlpha(0.12),
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            l10n.statsMilestoneHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(isDark),
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
    final data = _weeklyData!;
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
                          color: isToday
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMin),
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
    return Row(
      children: [
        Container(
          width: AppTheme.spaceXxs,
          height: AppIconSizes.sm,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppTheme.spaceXxxs)),
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: AppFontWeights.bold)),
      ],
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    final color = AppColors.textSecondary(isDark).withValues(alpha: 0.1);
    final decoration = BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTheme.radiusMd));
    return ListView(
      padding: AppTheme.pagePadding,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(children: List.generate(2, (_) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs), child: Container(height: _kSkeletonTileH, decoration: decoration))))),
        const SizedBox(height: AppTheme.spaceMd),
        Row(children: List.generate(2, (_) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs), child: Container(height: _kSkeletonTileH, decoration: decoration))))),
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
            const SizedBox(height: AppTheme.spaceLg),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startTracking),
            ),
          ],
        ),
      ),
    );
  }
}

