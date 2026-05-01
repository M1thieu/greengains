import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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

  /// Shows the permission priming sheet. Returns true if user tapped CTA,
  /// false if they dismissed. Never throws.
  Future<bool> _showPermissionPriming(BuildContext ctx) async {
    final result = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PermissionPrimingSheet(),
    );
    return result == true;
  }

  Future<void> _stop() async {
    if (_isToggling) return;
    HapticFeedback.heavyImpact();
    setState(() => _isToggling = true);
    try {
      await _locationService.stop();
      await _prefs.setShareLocation(false);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _toggle() async {
    if (_isToggling) return;

    // Fire jelly immediately — doesn't wait for service ops
    _jellyController.forward(from: 0.0);

    var isRunning = _locationService.isRunning.value;
    final isPaused = _locationService.isPaused.value;

    if (!isRunning) {
      // Show permission priming screen before the OS dialog — only when not yet granted.
      final currentPermission = await Geolocator.checkPermission();
      if (currentPermission == LocationPermission.denied) {
        if (!mounted) return;
        final confirmed = await _showPermissionPriming(context);
        if (!confirmed) return;
      }

      final granted = await _locationPermissionHelper.requestLocation();
      if (!granted) {
        if (mounted) {
          AppSnackbars.showInfo(context, context.l10n.permissionLocationMessage);
        }
        return;
      }
      await _prefs.setShareLocation(true);
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

    // FAB floats over the dark map — colours intentionally use isDark: true.
    final l10n = context.l10n;
    final (icon, bgColor, fgColor, tooltip) = switch (true) {
      _ when _isToggling => (Icons.hourglass_empty, AppColors.surfaceElevated(true), AppColors.textSecondary(true), l10n.trackingFabStarting),
      _ when isActive    => (Icons.pause,            AppColors.darkBackground,        Colors.white,   l10n.trackingFabPause),
      _ when isPaused    => (Icons.play_arrow,        AppColors.primary,              Colors.white,   l10n.trackingFabResume),
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
          onLongPress: (_locationService.isRunning.value && !_isToggling) ? _stop : null,
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
                border: isActive
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
                boxShadow: [
                  // Outer ring — active tracking (green ring on dark FAB) or idle (green ring on green FAB)
                  if (isActive || (!isRunning && !isPaused && !_isToggling))
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 0,
                      spreadRadius: 6,
                    ),
                  // Drop shadow
                  BoxShadow(
                    color: bgColor.withValues(alpha: isActive ? 0.50 : 0.35),
                    blurRadius: isActive ? _kFabActiveShadowBlur : 24,
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

// ── Permission priming sheet ──────────────────────────────────────────────────

/// Shown before the OS location dialog on first ever Start press.
/// Explains battery impact and what we collect — lifts permission grant rate.
class _PermissionPrimingSheet extends StatelessWidget {
  const _PermissionPrimingSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary(isDark).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Icon(Icons.location_on_outlined, color: AppColors.primary, size: AppIconSizes.xl),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                l10n.permissionPrimingTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _PrimingRow(
                icon: Icons.battery_saver_outlined,
                text: l10n.permissionPrimingBattery,
                isDark: isDark,
                theme: theme,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              _PrimingRow(
                icon: Icons.shield_outlined,
                text: l10n.permissionPrimingCollects,
                isDark: isDark,
                theme: theme,
              ),
              const SizedBox(height: AppTheme.spaceXl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.permissionPrimingCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimingRow extends StatelessWidget {
  const _PrimingRow({
    required this.icon,
    required this.text,
    required this.isDark,
    required this.theme,
  });
  final IconData icon;
  final String text;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSizes.sm, color: AppColors.primary),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
