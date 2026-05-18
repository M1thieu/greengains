import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../services/auth/auth_service.dart';
import '../services/location/foreground_location_service.dart';
import '../services/network/backend_client.dart';
import '../services/referral/referral_service.dart';
import '../core/constants.dart';
import '../utils/app_snackbars.dart';
import 'webview_screen.dart';

// ── Onboarding layout constants ───────────────────────────────────────────────
// Hero icon sizes that don't map directly to AppIconSizes entries.
const _kWelcomeHeroSize = AppIconSizes.xl + AppTheme.spaceLg; // 48+24 = 72 — eco icon

/// Onboarding — 2 pages: Welcome → Sign In
/// Typography-first premium redesign (Stripe/Linear/Vercel aesthetic).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.initialPage = 0,
  });

  final VoidCallback onComplete;
  /// Page to start on. Pass 1 to skip directly to the sign-in page
  /// (used when onboarding was previously completed but user signed out).
  final int initialPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _signingIn = false;
  bool _startingTracking = false;
  int? _activeMappers; // null = not yet loaded / failed
  bool _showCodeField = false;
  String _inviteCode = '';
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _fetchMapperCount();
  }

  Future<void> _fetchMapperCount() async {
    try {
      final data = await BackendClient.get(kApiStatsGlobal);
      final count = GlobalStatsResponse.fromJson(data).activeMappers;
      if (mounted && count > 0) setState(() => _activeMappers = count);
    } catch (_) {} // non-critical — show nothing if it fails
  }

  @override
  void dispose() {
    _pageController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: AppDurations.fast,
        curve: AppMotion.standard,
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Capture l10n before async gap (Flutter best practice)
    final l10n = context.l10n;
    if (_signingIn) return;
    setState(() => _signingIn = true);

    try {
      await AuthService.signInWithGoogleUniversal();
      if (!mounted) return;

      // Fire-and-forget: record explicit consent to backend + cache locally.
      // PackageInfo fetch is inside the closure so there is only one async gap
      // on the main path (above), keeping context use below lint-safe.
      unawaited(
        PackageInfo.fromPlatform().then((packageInfo) =>
          BackendClient.post(kApiUserConsent, {
            'platform': Platform.isIOS ? 'ios' : 'android',
            'appVersion': packageInfo.version,
          }).then((body) async {
            final rawDate = body['agreedAt'];
            final dt = rawDate != null ? DateTime.tryParse(rawDate.toString()) : DateTime.now();
            await AppPreferences.instance.setConsentDate(dt ?? DateTime.now());
          }),
        ).catchError((_) {
          // Non-critical — consent date will be set on next successful call.
        }),
      );

      // If the user entered an invite code, convert it fire-and-forget.
      final code = _inviteCode.trim().toUpperCase();
      if (code.isNotEmpty) {
        unawaited(
          ReferralService.instance.registerReferralOpen(referralCode: code),
        );
      }

      AppSnackbars.showSuccess(context, l10n.signInSuccess);
      await Future.delayed(AppDurations.medium);
      if (!mounted) return;
      // First-time onboarding → advance to "start mapping" page.
      // Re-sign-in (initialPage > 0) → complete immediately.
      if (widget.initialPage > 0) {
        widget.onComplete();
      } else {
        _pageController.nextPage(
          duration: AppDurations.fast,
          curve: AppMotion.standard,
        );
      }
    } catch (e) {
      debugPrint('Sign-in error: $e');
      if (!mounted) return;
      setState(() => _signingIn = false);
      AppSnackbars.showError(context, l10n.signInError);
    }
  }

  // Removed _skipSignIn() - all users must sign in with Google (no anonymous mode)

  Future<void> _handleStartMapping() async {
    if (_startingTracking) return;
    setState(() => _startingTracking = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        setState(() => _startingTracking = false);
        final l10n = context.l10n;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.onboardingPermissionDeniedForeverTitle),
            content: Text(l10n.onboardingPermissionDeniedForeverBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.buttonPrevious),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Geolocator.openAppSettings();
                },
                child: Text(l10n.onboardingOpenSettings),
              ),
            ],
          ),
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() => _startingTracking = false);
        if (mounted) AppSnackbars.showError(context, context.l10n.onboardingPermissionDenied);
        return;
      }

      // Permission granted — prompt battery optimization before completing.
      await _requestBatteryExemption();
      if (!mounted) return;

      await ForegroundLocationService.instance.start();
      if (mounted) widget.onComplete();
    } catch (e) {
      debugPrint('Start mapping error: $e');
      if (mounted) {
        setState(() => _startingTracking = false);
        AppSnackbars.showError(context, context.l10n.errorGeneric);
      }
    }
  }

  /// Request battery optimization exemption inline — fires once during onboarding
  /// right after location permission is granted, while the user is still engaged.
  Future<void> _requestBatteryExemption() async {
    try {
      const platform = MethodChannel('greengains/foreground');
      final bool isIgnoring =
          await platform.invokeMethod('isIgnoringBatteryOptimizations');
      if (!isIgnoring) {
        await platform.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (_) {
      // Non-critical — tracking works without it, just may be killed by Doze.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    // First-time onboarding has 3 pages; re-signin shows only sign-in (1 page).
    final pageCount = widget.initialPage == 0 ? 3 : 1;

    return Scaffold(
      body: Stack(
        children: [
          // PageView — Welcome → Sign In → Start Mapping (first-time only)
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // navigation is programmatic
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              if (widget.initialPage == 0) _buildWelcomePage(theme, isDark, l10n),
              _buildSignInPage(theme, isDark, l10n),
              if (widget.initialPage == 0) _buildStartPage(theme, isDark, l10n),
            ],
          ),

          // Bottom navigation — dots + conditional full-width CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated pill dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pageCount,
                    (index) => AnimatedContainer(
                      duration: AppDurations.fast,
                      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs),
                      height: AppTheme.spaceXs,
                      width: _currentPage == index ? AppTheme.spaceLg : AppTheme.spaceXs,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.primary
                            : AppColors.textTertiary(isDark),
                        borderRadius: BorderRadius.circular(AppTheme.spaceXxs),
                      ),
                    ),
                  ),
                ),
                if (_currentPage == 0) ...[
                  const SizedBox(height: AppTheme.spaceXl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _nextPage,
                        child: Text(l10n.buttonNext),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceXxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 1: Welcome ─────────────────────────────────────────────────────────
  Widget _buildWelcomePage(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hex hero bleeds edge-to-edge from top (no safe area)
        const SizedBox(
          height: 260,
          width: double.infinity,
          child: _OnboardingHexHero(),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLg, AppTheme.spaceLg,
                  AppTheme.spaceLg, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.onboardingWelcomeTitle,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: AppFontWeights.semibold,
                      letterSpacing: -0.8,
                      height: 1.12,
                      color: Colors.white.withValues(alpha: 0.96),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    l10n.onboardingWelcomeSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                  const Spacer(),
                  _FeatureRow(
                    icon: Icons.battery_saver_outlined,
                    title: l10n.onboardingFeature1Title,
                    description: l10n.onboardingFeature1Description,
                    isDark: isDark,
                    theme: theme,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  _FeatureRow(
                    icon: Icons.shield_outlined,
                    title: l10n.onboardingFeature2Title,
                    description: l10n.onboardingFeature2Description,
                    isDark: isDark,
                    theme: theme,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  _FeatureRow(
                    icon: Icons.map_outlined,
                    title: l10n.onboardingFeature3Title,
                    description: l10n.onboardingFeature3Description,
                    isDark: isDark,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Page 2: Sign In ──────────────────────────────────────────────────────────
  Widget _buildSignInPage(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              l10n.onboardingSignInTitle,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: AppFontWeights.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              l10n.onboardingSignInSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            if (_activeMappers != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: AppTheme.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Text(
                  l10n.onboardingSocialProof(_activeMappers!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
            ],
            const Spacer(),

            // Privacy Policy / TOS — split-placeholder pattern:
            // pass sentinel tokens into the localized template, then split
            // on them to extract surrounding prose segments.
            // This preserves correct word order for every locale.
            Builder(builder: (context) {
              const ppToken = '__PP__';
              const tosToken = '__TOS__';
              final full = l10n.onboardingPrivacyNotice(ppToken, tosToken);
              final beforePP = full.split(ppToken)[0];
              final rest = full.split(ppToken)[1];
              final betweenLinks = rest.split(tosToken)[0];
              final afterTOS = rest.split(tosToken)[1];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                    children: [
                      TextSpan(text: beforePP),
                      TextSpan(
                        text: l10n.privacyPolicy,
                        style: TextStyle(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: AppFontWeights.medium,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => WebViewScreen(
                                url: 'https://greengains.eremat.org/privacy-policy',
                                title: l10n.privacyPolicy,
                              ),
                            ));
                          },
                      ),
                      TextSpan(text: betweenLinks),
                      TextSpan(
                        text: l10n.termsOfService,
                        style: TextStyle(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: AppFontWeights.medium,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => WebViewScreen(
                                url: 'https://greengains.eremat.org/terms-of-service',
                                title: l10n.termsOfService,
                              ),
                            ));
                          },
                      ),
                      TextSpan(text: afterTOS),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: AppTheme.spaceLg),

            // Invite code — optional, collapsed by default
            AnimatedSize(
              duration: AppDurations.fast,
              curve: AppMotion.standard,
              child: _showCodeField
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: l10n.onboardingCodeHint,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceSm,
                            vertical: AppTheme.spaceXs + AppTheme.spaceXxs,
                          ),
                        ),
                        onChanged: (v) => _inviteCode = v,
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : GestureDetector(
                      onTap: () => setState(() => _showCodeField = true),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                        child: Text(
                          l10n.onboardingHaveCode,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),

            // Official Google Sign-In Button — full-width
            SizedBox(
              width: double.infinity,
              child: InkWell(
                onTap: _signingIn ? null : _handleGoogleSignIn,
                borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                child: _signingIn
                    ? Container(
                        height: AppTheme.authButtonHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated(isDark),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowDark(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      )
                    : SvgPicture.asset(
                        AppTheme.googleButtonAsset(theme.brightness),
                        height: AppTheme.authButtonHeight,
                        fit: BoxFit.contain,
                      ),
              ),
            ),

            const SizedBox(height: AppTheme.spaceXxl),
          ],
        ),
      ),
    );
  }

  // ── Page 3: Start Mapping ─────────────────────────────────────────────────────
  Widget _buildStartPage(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: Icon(
                Icons.map_outlined,
                size: _kWelcomeHeroSize,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              l10n.onboardingActivateTitle,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: AppFontWeights.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              l10n.onboardingActivateSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(isDark),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            _FeatureRow(
              icon: Icons.battery_saver_outlined,
              title: l10n.permissionPrimingBattery,
              description: l10n.permissionPrimingBatteryDesc,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            _FeatureRow(
              icon: Icons.security_outlined,
              title: l10n.permissionPrimingCollects,
              description: l10n.permissionPrimingCollectsDesc,
              isDark: isDark,
              theme: theme,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _startingTracking ? null : _handleStartMapping,
                child: _startingTracking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(l10n.onboardingActivateCta),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXxl),
          ],
        ),
      ),
    );
  }
}

// ── Onboarding feature row ────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32, height: 32,
          child: Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.semibold,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Onboarding hex hero animation ────────────────────────────────────────────

class _OnboardingHexHero extends StatefulWidget {
  const _OnboardingHexHero();

  @override
  State<_OnboardingHexHero> createState() => _OnboardingHexHeroState();
}

class _OnboardingHexHeroState extends State<_OnboardingHexHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) { _ctrl.reset(); _ctrl.forward(); }
        });
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _OnboardingHexPainter(_ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _OnboardingHexPainter extends CustomPainter {
  const _OnboardingHexPainter(this.t);
  final double t;

  static const _hexR = 22.0;
  static const _radius = 7;
  static const _fillRatio = 0.22;
  static const _newRatio = 0.10;
  static const _seed = 11;

  (double, double) _hexToPixel(int q, int r) {
    final x = _hexR * (3 / 2 * q);
    final y = _hexR * (math.sqrt(3) / 2 * q + math.sqrt(3) * r);
    return (x, y);
  }

  ui.Path _hexPath(double cx, double cy, double r) {
    final path = ui.Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.58;

    // Street grid
    final streetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.6;
    for (int i = 0; i < size.height / 28 + 2; i++) {
      canvas.drawLine(Offset(0, i * 28.0), Offset(size.width, i * 28.0 + 6), streetPaint);
    }
    for (int i = 0; i < size.width / 28 + 2; i++) {
      canvas.drawLine(Offset(i * 28.0, 0), Offset(i * 28.0 + 8, size.height), streetPaint);
    }

    // Generate cells
    final rng = math.Random(_seed);
    final cells = <(int, int, bool, bool, int)>[];
    for (int q = -_radius; q <= _radius; q++) {
      final rMin = math.max(-_radius, -q - _radius);
      final rMax = math.min(_radius, -q + _radius);
      for (int r = rMin; r <= rMax; r++) {
        final dist = (q.abs() + r.abs() + (q + r).abs()) ~/ 2;
        final isClaimed = rng.nextDouble() < _fillRatio;
        final isNew = isClaimed && rng.nextDouble() < (_newRatio / _fillRatio);
        cells.add((q, r, isClaimed, isNew, dist));
      }
    }

    for (final (q, r, claimed, isNew, dist) in cells) {
      final (px, py) = _hexToPixel(q, r);
      final x = cx + px;
      final y = cy + py;

      if (x < -_hexR * 2 || x > size.width + _hexR * 2) continue;
      if (y < -_hexR * 2 || y > size.height + _hexR * 2) continue;

      final revealAt = dist / (_radius + 1.0);
      final opacity = ((t - revealAt) / 0.25).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final path = _hexPath(x, y, _hexR * 0.94);

      if (claimed) {
        if (isNew) {
          canvas.drawPath(path, Paint()
            ..color = AppColors.primary.withValues(alpha: 0.55 * opacity)
            ..style = PaintingStyle.fill);
          canvas.drawPath(path, Paint()
            ..color = AppColors.primary.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
        } else {
          canvas.drawPath(path, Paint()
            ..color = AppColors.primary.withValues(alpha: 0.20 * opacity)
            ..style = PaintingStyle.fill);
          canvas.drawPath(path, Paint()
            ..color = AppColors.primary.withValues(alpha: 0.45 * opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6);
        }
      } else {
        canvas.drawPath(path, Paint()
          ..color = Colors.white.withValues(alpha: 0.04 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4);
      }
    }

    // Fade to background at bottom
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.55),
          Offset(0, size.height),
          [Colors.transparent, AppColors.darkBackground],
        ),
    );
  }

  @override
  bool shouldRepaint(_OnboardingHexPainter old) => old.t != t;
}
