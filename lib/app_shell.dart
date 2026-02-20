import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'core/extensions/context_extensions.dart';
import 'core/services/time_ago_service.dart';
import 'core/themes.dart';
import 'services/location/foreground_location_service.dart';

/// Main navigation shell with bottom navigation bar.
///
/// PageView handles swipe gestures between Home and Profile automatically.
/// The NavigationBar syncs with page position via [_onPageChanged].
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final PageController _pageController;
  final _locationService = ForegroundLocationService.instance;

  static const _screens = [
    HomeScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    TimeAgoService.instance.start();
    _locationService.isRunning.addListener(_rebuild);
    _locationService.isPaused.addListener(_rebuild);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _locationService.isRunning.removeListener(_rebuild);
    _locationService.isPaused.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onPageChanged(int index) => setState(() => _currentIndex = index);

  void _onDestinationSelected(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = _locationService.isRunning.value &&
        !_locationService.isPaused.value;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // no swipe — map pan conflicts
        onPageChanged: _onPageChanged,
        children: _screens,
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
