import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_preferences.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../services/location/location_service.dart';
import '../utils/app_snackbars.dart';

/// Compact 56×56 FAB that replaces the full-width ServiceControlButton
/// for the map-as-background layout.
///
/// Icon-only (no label): play / pause / hourglass (loading).
/// Fades out when the bottom sheet is expanded — caller wraps in AnimatedOpacity.
class TrackingFab extends StatefulWidget {
  const TrackingFab({super.key});

  @override
  State<TrackingFab> createState() => _TrackingFabState();
}

class _TrackingFabState extends State<TrackingFab> {
  final _locationService = ForegroundLocationService.instance;
  final _locationPermissionHelper = LocationService.instance;
  final _prefs = AppPreferences.instance;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _locationService.isRunning.addListener(_rebuild);
    _locationService.isPaused.addListener(_rebuild);
  }

  @override
  void dispose() {
    _locationService.isRunning.removeListener(_rebuild);
    _locationService.isPaused.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_isToggling) return;

    var isRunning = _locationService.isRunning.value;
    final isPaused = _locationService.isPaused.value;

    if (!isRunning) {
      final granted = await _locationPermissionHelper.requestLocation();
      if (!granted) {
        if (mounted) {
          AppSnackbars.showInfo(
            context,
            'Location access is needed to track your contributions.',
          );
        }
        return;
      }
      await _prefs.setShareLocation(true);
      await _locationService.requestLocationPermission();
      isRunning = _locationService.isRunning.value;
    }

    setState(() => _isToggling = true);

    try {
      if (!isRunning) {
        HapticFeedback.mediumImpact();
        await _locationService.start();
      } else if (isPaused) {
        HapticFeedback.lightImpact();
        await _locationService.resumeTracking();
      } else {
        await _locationService.pauseTracking();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbars.showError(context, 'Couldn\'t update tracking — please try again.');
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _locationService.isRunning.value;
    final isPaused = _locationService.isPaused.value;
    final isActive = isRunning && !isPaused;

    final (icon, bgColor, fgColor) = switch (true) {
      _ when _isToggling => (Icons.hourglass_empty, AppColors.surfaceElevated(true), Colors.white54),
      _ when isActive    => (Icons.pause, AppColors.primary, Colors.white),
      _ when isPaused    => (Icons.play_arrow, AppColors.warning, Colors.white),
      _                  => (Icons.play_arrow, AppColors.primary, Colors.white),
    };

    return FloatingActionButton(
      heroTag: 'tracking_fab',
      onPressed: _isToggling ? null : _toggle,
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: 4,
      child: Icon(icon, size: 28),
    );
  }
}
