import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'core/extensions/context_extensions.dart';
import 'core/services/time_ago_service.dart';
import 'core/themes.dart';
import 'services/location/foreground_location_service.dart';

/// Main navigation shell with bottom navigation bar.
/// Uses PageView + _KeepAlive so each tab keeps its state AND supports swipe.
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

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: AppDurations.fast,
      curve: AppMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTracking =
        _locationService.isRunning.value && !_locationService.isPaused.value;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: const [
          _KeepAlive(child: HomeScreen()),
          _KeepAlive(child: ProfileScreen()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            // Show a live dot on the Home icon when tracking is active
            icon: Badge(
              isLabelVisible: isTracking && _currentIndex != 0,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.home_outlined),
            ),
            selectedIcon: const Icon(Icons.home),
            label: context.l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.l10n.navProfile,
          ),
        ],
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
