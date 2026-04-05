import 'dart:async';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../services/auth/auth_service.dart';
import '../services/network/backend_client.dart';
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

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
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

      AppSnackbars.showSuccess(context, l10n.signInSuccess);
      await Future.delayed(AppDurations.medium);
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      debugPrint('Sign-in error: $e');
      if (!mounted) return;
      setState(() => _signingIn = false);
      AppSnackbars.showError(context, l10n.signInError);
    }
  }

  // Removed _skipSignIn() - all users must sign in with Google (no anonymous mode)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      body: Stack(
        children: [
          // PageView — 2 pages: Welcome → Sign In
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              _buildWelcomePage(theme, isDark, l10n),
              _buildSignInPage(theme, isDark, l10n),
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
                    2,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.eco,
              size: _kWelcomeHeroSize,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              l10n.onboardingWelcomeTitle,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: AppFontWeights.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              '${l10n.onboardingFeature1Title} · ${l10n.onboardingFeature2Title} · ${l10n.onboardingFeature3Title}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
          ],
        ),
      ),
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
}
