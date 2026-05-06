import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/statistics_screen.dart';
import 'core/extensions/context_extensions.dart';
import 'core/services/time_ago_service.dart';
import 'core/themes.dart';
import 'services/location/foreground_location_service.dart';

// ── Floating nav bar constants ─────────────────────────────────────────────────
const _kNavBackgroundAlpha = 0.60;
const _kNavBorderAlpha     = 0.08;
const _kNavShadowAlpha     = 0.40;
const _kNavShadowBlur      = 32.0;
const _kNavShadowOffsetY   = 12.0;

/// Main navigation shell with floating bottom nav bar (Silencio-style).
/// extendBody: true — map/content bleeds to full screen height behind the nav.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final PageController _pageController;
  final _locationService = ForegroundLocationService.instance;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    TimeAgoService.instance.start();
    _locationService.isRunning.addListener(_rebuild);
    _locationService.isPaused.addListener(_rebuild);
    _syncForegroundState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _locationService.isRunning.removeListener(_rebuild);
    _locationService.isPaused.removeListener(_rebuild);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncForegroundState();
    }
  }

  Future<void> _syncForegroundState() async {
    await _locationService.isServiceRunning();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: AppDurations.fast,
      curve: AppMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTracking =
        _locationService.isRunning.value && !_locationService.isPaused.value;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      // Map extends to full screen height — nav floats on top.
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: [
          _KeepAlive(child: HomeScreen(onGoToStats: () => _onTabSelected(1), onOpenProfile: () => _onTabSelected(2))),
          _KeepAlive(child: StatisticsScreen(onGoToHome: () => _onTabSelected(0))),
          _KeepAlive(child: ProfileScreen()),
        ],
      ),
      // Floating pill nav bar — RepaintBoundary isolates it from page rebuilds.
      bottomNavigationBar: RepaintBoundary(
        child: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spaceLg,
          right: AppTheme.spaceLg,
          bottom: bottomPadding + AppTheme.spaceSm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTheme.glassBlurSigma,
              sigmaY: AppTheme.glassBlurSigma,
            ),
            child: Container(
          height: AppTheme.floatingNavHeight,
          // No borderRadius here — ClipRRect already clips the shape.
          decoration: AppColors.glassDecoration(
            isDark: isDark,
            backgroundAlpha: _kNavBackgroundAlpha,
            borderAlpha: _kNavBorderAlpha,
          ).copyWith(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _kNavShadowAlpha),
                blurRadius: _kNavShadowBlur,
                offset: const Offset(0, _kNavShadowOffsetY),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: context.l10n.navHome,
                selected: _currentIndex == 0,
                badge: isTracking && _currentIndex != 0,
                onTap: () => _onTabSelected(0),
              ),
              _NavItem(
                icon: Icons.bar_chart_outlined,
                selectedIcon: Icons.bar_chart,
                label: context.l10n.navStats,
                selected: _currentIndex == 1,
                onTap: () => _onTabSelected(1),
              ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: context.l10n.navProfile,
                selected: _currentIndex == 2,
                onTap: () => _onTabSelected(2),
              ),
            ],
          ),
        ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Single icon tab inside the floating nav bar.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected ? AppColors.primary : AppColors.textSecondary(isDark);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge,
              backgroundColor: AppColors.primary,
              child: Icon(
                selected ? selectedIcon : icon,
                color: color,
                size: AppIconSizes.md,
              ),
            ),
            // Label only visible on selected tab — cleaner than always-visible labels
            AnimatedSize(
              duration: AppDurations.fast,
              curve: AppMotion.standard,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppTheme.spaceXxxs),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppTheme.fontSizeNavLabel,
                          fontWeight: AppFontWeights.semibold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab's widget tree alive when swiping away from it.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
