import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../data/models/contribution_stats.dart';
import '../data/repositories/contribution_repository.dart';
import '../core/events/app_events.dart';
import '../widgets/time_ago_text.dart';

/// Comprehensive statistics screen showing detailed contribution metrics,
/// environmental insights, achievements, and future earnings
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _contributionRepo = ContributionRepository();
  ContributionStats? _stats;
  bool _isLoading = true;
  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  StreamSubscription<StatsUpdatedEvent>? _statsUpdatedSub;

  @override
  void initState() {
    super.initState();
    _loadStats();

    // Listen to upload success events for automatic refresh
    _uploadSuccessSub = AppEventBus.instance
        .on<UploadSuccessEvent>()
        .listen(_onUploadSuccess);

    // Listen to stats updated events (in case stats are refreshed elsewhere)
    _statsUpdatedSub = AppEventBus.instance
        .on<StatsUpdatedEvent>()
        .listen(_onStatsUpdated);
  }

  @override
  void dispose() {
    _uploadSuccessSub?.cancel();
    _statsUpdatedSub?.cancel();
    super.dispose();
  }

  void _onUploadSuccess(UploadSuccessEvent event) {
    if (mounted) {
      // Reload stats when a new upload completes
      _loadStats();
    }
  }

  void _onStatsUpdated(StatsUpdatedEvent event) {
    if (mounted) {
      setState(() {
        _stats = event.stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _contributionRepo.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsScreenTitle),
        // Share feature commented out - will be implemented later
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.share_outlined),
        //     onPressed: () {
        //       // TODO: Implement share stats functionality
        //     },
        //     tooltip: 'Share statistics',
        //   ),
        // ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null || _stats!.totalUploads == 0
              ? _buildEmptyState(context, theme, isDark)
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  color: AppColors.primary,
                  child: ListView(
                    padding: AppTheme.pagePadding,
                    children: [
                      // Quick stats grid
                      _buildQuickStatsGrid(theme, isDark),
                      const SizedBox(height: AppTheme.spaceLg),

                      // Section: Contribution Timeline - Simple trend chart
                      _buildSectionHeader(l10n.statsContributionTimeline, theme, isDark),
                      const SizedBox(height: AppTheme.spaceMd),
                      _buildSimpleTrendChart(theme, isDark, l10n),
                      const SizedBox(height: AppTheme.spaceLg),

                      // Section: Achievements (Coming soon placeholder)
                      _buildSectionHeader(l10n.statsAchievements, theme, isDark),
                      const SizedBox(height: AppTheme.spaceMd),
                      _buildAchievementsPlaceholder(theme, isDark, l10n),
                      const SizedBox(height: AppTheme.spaceLg),

                      // Section: Future Earnings
                      _buildSectionHeader(l10n.statsEarnings, theme, isDark),
                      const SizedBox(height: AppTheme.spaceMd),
                      _buildEarningsPlaceholder(theme, isDark, l10n),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroMetricCard(ThemeData theme, bool isDark) {
    final totalContributions = _stats!.totalUploads;
    // Weekly change calculation will be added when we track historical data
    final weeklyChange = 0; // Placeholder - needs historical data tracking

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.eco,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            totalContributions.toString(),
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: AppFontWeights.bold,
              color: AppColors.primary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            context.l10n.statsTotalContributions,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          if (_stats!.loadedAt != null) ...[
            const SizedBox(height: 4),
            TimeAgoText(
              timestamp: _stats!.loadedAt!,
              prefix: context.l10n.statsUpdatedPrefix,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark).withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          if (weeklyChange > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  '+$weeklyChange% this week',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeights.semibold,
                    color: AppColors.success,
                  ),
                ),
              ],
            )
          else
            Text(
              context.l10n.statsKeepContributing,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid(ThemeData theme, bool isDark) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatTile(
            l10n.statsToday,
            '${_stats!.uploadsToday}',
            Icons.today,
            theme,
            isDark,
          ),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: _buildQuickStatTile(
            l10n.statsStreak,
            '${_stats!.currentStreak}d',
            Icons.local_fire_department,
            theme,
            isDark,
          ),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: _buildQuickStatTile(
            l10n.statsTotal,
            '${_stats!.totalUploads}',
            Icons.eco,
            theme,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatTile(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppFontWeights.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate appropriate grid interval for whole numbers
  double _calculateGridInterval(List<FlSpot> spots) {
    final maxValue = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxValue <= 5) return 1.0;
    if (maxValue <= 10) return 2.0;
    if (maxValue <= 20) return 5.0;
    return (maxValue / 4).ceilToDouble();
  }

  /// Calculate max Y value ensuring it's a whole number with some padding
  double _calculateMaxY(List<FlSpot> spots) {
    final maxValue = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return 5.0; // Show 0-5 range when all values are 0
    // Add 20% padding and round up to nearest whole number
    return (maxValue * 1.2).ceilToDouble();
  }

  /// Simple trend chart showing basic contribution pattern
  Widget _buildSimpleTrendChart(ThemeData theme, bool isDark, AppLocalizations l10n) {
    // Create a simple 7-day visualization
    // Use today's count as the latest point, then taper back for demo purposes
    final todayCount = _stats!.uploadsToday.toDouble();

    // Until we fetch historical daily counts, show zeros for previous days
    final spots = List.generate(7, (index) {
      if (index == 6) {
        return FlSpot(index.toDouble(), todayCount);
      }
      return FlSpot(index.toDouble(), 0.0);
    });

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
                l10n.statsActivityTrend,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXs,
                  vertical: AppTheme.spaceXxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                ),
                child: Text(
                  l10n.statsLast7Days,
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
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateGridInterval(spots),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        // Only show whole numbers on Y-axis
                        if (value % 1 != 0) return const SizedBox();
                        return Text(
                          value.toInt().toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary(isDark),
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = [l10n.statsDayMon, l10n.statsDayTue, l10n.statsDayWed, l10n.statsDayThu, l10n.statsDayFri, l10n.statsDaySat, l10n.statsDayToday];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: value.toInt() == 6
                                    ? AppColors.primary
                                    : AppColors.textTertiary(isDark),
                                fontSize: 11,
                                fontWeight: value.toInt() == 6
                                    ? AppFontWeights.semibold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: _calculateMaxY(spots),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: index == 6 ? 5 : 3, // Highlight today
                          color: index == 6 ? AppColors.primary : Colors.white,
                          strokeWidth: index == 6 ? 2 : 1,
                          strokeColor: AppColors.primary,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            l10n.statsVisualizationNote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary(isDark),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Generic coming soon card for features not yet implemented
  Widget _buildComingSoonCard(
    String title,
    String description,
    IconData icon,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: AppTheme.surfaceContainer(
        isDark: isDark,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsPlaceholder(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return _buildComingSoonCard(
      l10n.statsAchievements,
      l10n.statsAchievementsDescription,
      Icons.emoji_events_outlined,
      theme,
      isDark,
    );
  }

  Widget _buildEarningsPlaceholder(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return _buildComingSoonCard(
      l10n.statsEarningsTracking,
      l10n.statsEarningsDescription,
      Icons.attach_money,
      theme,
      isDark,
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: AppFontWeights.bold,
          ),
        ),
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bar_chart_outlined,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              l10n.statsStartContributing,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              l10n.statsEmptyDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
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
