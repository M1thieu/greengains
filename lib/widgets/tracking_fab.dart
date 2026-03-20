import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../services/location/location_service.dart';
import '../utils/app_snackbars.dart';

// ── FAB sizing / animation constants ─────────────────────────────────────────
const _kFabSize              = 72.0;   // prominent center-bottom FAB (Silencio-style)
const _kFabIconSize          = 32.0;
const _kFabJellyDuration     = Duration(milliseconds: 420); // total squish→pop→settle
const _kFabToggleDuration    = Duration(milliseconds: 220); // color/size transition
const _kFabSwitchDuration    = Duration(milliseconds: 180); // icon crossfade
const _kFabActiveShadowBlur   = 18.0;
const _kFabIdleShadowBlur     = AppTheme.spaceXs;    // 8
const _kFabActiveShadowSpread = AppTheme.spaceXxxs;  // 2

/// Compact 56×56 FAB with jelly press feedback.
///
/// On tap: squish (0.88×) → pop (1.18×) → elastic settle (1.0×).
/// Icon transitions via AnimatedSwitcher (scale+fade).
/// Color transitions via AnimatedContainer.
/// Fades out when bottom sheet expands — caller wraps in AnimatedOpacity.
class TrackingFab extends StatefulWidget {
  const TrackingFab({super.key});

  @override
  State<TrackingFab> createState() => _TrackingFabState();
}

class _TrackingFabState extends State<TrackingFab>
    with SingleTickerProviderStateMixin {
  final _locationService = ForegroundLocationService.instance;
  final _locationPermissionHelper = LocationService.instance;
  final _prefs = AppPreferences.instance;
  bool _isToggling = false;

  late final AnimationController _jellyController;
  late final Animation<double> _jellyScale;

  @override
  void initState() {
    super.initState();
    _locationService.isRunning.addListener(_rebuild);
    _locationService.isPaused.addListener(_rebuild);

    _jellyController = AnimationController(
      vsync: this,
      duration: _kFabJellyDuration,
    );

    // Squish → pop → elastic settle
    _jellyScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_jellyController);
  }

  @override
  void dispose() {
    _jellyController.dispose();
    _locationService.isRunning.removeListener(_rebuild);
    _locationService.isPaused.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_isToggling) return;

    // Fire jelly immediately — doesn't wait for service ops
    _jellyController.forward(from: 0.0);

    var isRunning = _locationService.isRunning.value;
    final isPaused = _locationService.isPaused.value;

    if (!isRunning) {
      final granted = await _locationPermissionHelper.requestLocation();
      if (!granted) {
        if (mounted) {
          AppSnackbars.showInfo(context, context.l10n.permissionLocationMessage);
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
        HapticFeedback.lightImpact();
        await _locationService.pauseTracking();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbars.showError(context, context.l10n.trackingErrorUpdateFailed);
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _locationService.isRunning.value;
    final isPaused = _locationService.isPaused.value;
    final isActive = isRunning && !isPaused;

    final l10n = context.l10n;
    final (icon, bgColor, fgColor, tooltip) = switch (true) {
      _ when _isToggling => (Icons.hourglass_empty, AppColors.surfaceElevated(true), Colors.white54, l10n.trackingFabStarting),
      _ when isActive    => (Icons.pause,            AppColors.primary,              Colors.white,   l10n.trackingFabPause),
      _ when isPaused    => (Icons.play_arrow,        AppColors.warning,              Colors.white,   l10n.trackingFabResume),
      _                  => (Icons.play_arrow,        AppColors.primary,              Colors.white,   l10n.trackingFabStart),
    };

    // Pre-compute gradient colors — only recalculated when bgColor changes (state toggle),
    // not on every animation frame inside AnimatedContainer.
    final gradient = AppGradients.darkBottomGradient(bgColor);

    return Semantics(
      button: true,
      label: tooltip,
      child: ScaleTransition(
        scale: _jellyScale,
        child: GestureDetector(
          onTap: _isToggling ? null : _toggle,
          child: Tooltip(
            message: tooltip,
            child: AnimatedContainer(
              duration: _kFabToggleDuration,
              curve: Curves.easeInOut,
              width: _kFabSize,
              height: _kFabSize,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: isActive ? 0.50 : 0.30),
                    blurRadius: isActive ? _kFabActiveShadowBlur : _kFabIdleShadowBlur,
                    spreadRadius: isActive ? _kFabActiveShadowSpread : 0,
                    offset: const Offset(0, AppTheme.spaceXxs),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: _kFabSwitchDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: fgColor,
                  size: _kFabIconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
