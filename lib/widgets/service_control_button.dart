import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_preferences.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../services/location/location_service.dart';
import '../utils/app_snackbars.dart';

/// Active status indicator that shows tracking is working
/// Pulses and animates when recording to give clear visual feedback
class ServiceControlButton extends StatefulWidget {
  const ServiceControlButton({super.key});

  @override
  State<ServiceControlButton> createState() => _ServiceControlButtonState();
}

class _ServiceControlButtonState extends State<ServiceControlButton>
    with TickerProviderStateMixin {
  final _locationService = ForegroundLocationService.instance;
  final _locationPermissionHelper = LocationService.instance;
  final _prefs = AppPreferences.instance;
  bool _isTogglingService = false;
  late AnimationController _buttonAnimController;
  late Animation<double> _buttonScale;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Button press scale animation
    _buttonAnimController = AnimationController(
      duration: AppDurations.fast,
      vsync: this,
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: AppMotion.standard),
    );

    // Continuous pulse animation for active state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation for active state
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.45).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start animations if already tracking
    _onServiceStateChanged();

    // Listen to service state changes
    _locationService.isRunning.addListener(_onServiceStateChanged);
    _locationService.isPaused.addListener(_onServiceStateChanged);
  }

  void _onServiceStateChanged() {
    final isActive = _locationService.isRunning.value &&
        !_locationService.isPaused.value;
    if (isActive) {
      _startActiveAnimations();
    } else {
      _stopActiveAnimations();
    }
  }

  void _startActiveAnimations() {
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  void _stopActiveAnimations() {
    _pulseController.stop();
    _glowController.stop();
    _pulseController.reset();
    _glowController.reset();
  }

  @override
  void dispose() {
    _locationService.isRunning.removeListener(_onServiceStateChanged);
    _locationService.isPaused.removeListener(_onServiceStateChanged);
    _buttonAnimController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _toggleService() async {
    if (_isTogglingService) return; // Prevent double-tap

    // TODO: replace ad-hoc permission prompts with a dedicated UX flow (one-time modal + status banner).
    var isRunning = _locationService.isRunning.value;
    final isPaused = _locationService.isPaused.value;
    if (!isRunning) {
      final hasAccess = await _ensureLocationAccess();
      if (!hasAccess) {
        return;
      }
      // Service state could change while user deals with OS dialog
      isRunning = _locationService.isRunning.value;
    }

    setState(() {
      _isTogglingService = true;
    });

    // Trigger button scale animation
    _buttonAnimController.forward().then((_) => _buttonAnimController.reverse());

    final actionLabel = !isRunning
        ? 'start'
        : (isPaused ? 'resume' : 'pause');
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
      final msg = actionLabel == 'start'
          ? 'Couldn\'t start tracking — please try again.'
          : actionLabel == 'resume'
              ? 'Couldn\'t resume — please try again.'
              : 'Couldn\'t pause — please try again.';
      AppSnackbars.showError(context, msg);
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingService = false;
        });
      }
    }
  }

  Future<bool> _ensureLocationAccess() async {
    await _prefs.ensureInitialized();

    final granted = await _locationPermissionHelper.requestLocation();
    if (!granted) {
      if (mounted) {
        AppSnackbars.showInfo(
          context,
          'Location access is needed to track your contributions.',
        );
      }
      return false;
    }

    await _prefs.setShareLocation(true);
    await _locationService.requestLocationPermission();

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        _locationService.isRunning,
        _locationService.isPaused,
      ]),
      builder: (context, _) {
        final isRunning = _locationService.isRunning.value;
        final isPaused = _locationService.isPaused.value;
        final isActive = isRunning && !isPaused;
        final isDark = theme.brightness == Brightness.dark;
        return AnimatedBuilder(
          animation: _buttonScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _buttonScale.value,
              child: child,
            );
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  // Pulsing glow when active
                  boxShadow: isActive && !_isTogglingService
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: _glowAnimation.value),
                            blurRadius: 16 * _pulseAnimation.value,
                            spreadRadius: 1 * _pulseAnimation.value,
                          ),
                        ]
                      : [],
                ),
                child: FilledButton(
                  onPressed: _isTogglingService ? null : _toggleService,
                  style: FilledButton.styleFrom(
                    backgroundColor: isActive ? AppColors.primary : AppColors.surfaceElevated(isDark),
                    foregroundColor: isActive ? Colors.white : AppColors.textPrimary(isDark),
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceMd,
                      horizontal: AppTheme.spaceLg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppFontWeights.semibold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing dot when recording
                      if (isActive && !_isTogglingService)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    blurRadius: 4 * _pulseAnimation.value,
                                    spreadRadius: 2 * _pulseAnimation.value,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (_isTogglingService)
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                              isActive ? Colors.white : theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      if (!isRunning && !_isTogglingService)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.play_circle_fill, size: 24),
                        ),
                      Text(
                        _isTogglingService
                            ? (!isRunning
                                ? 'Starting…'
                                : isPaused
                                    ? 'Resuming…'
                                    : 'Pausing…')
                            : isRunning
                                ? (isPaused ? 'Resume' : 'Pause')
                                : 'Start Contributing',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
