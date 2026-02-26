import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../services/auth/auth_service.dart';
import '../utils/app_snackbars.dart';
import 'webview_screen.dart';

/// Enhanced onboarding with 4 pages:
/// 1. Welcome
/// 2. Features (Passive + Privacy)
/// 3. Impact tracking
/// 4. Google Sign In (with skip option)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _signingIn = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleGoogleSignIn() async {
    // Capture l10n before async gap (Flutter best practice)
    final l10n = context.l10n;
    if (_signingIn) return;
    setState(() => _signingIn = true);

    try {
      await AuthService.signInWithGoogleUniversal();
      if (!mounted) return;
      AppSnackbars.showSuccess(context, l10n.signInSuccess);
      await Future.delayed(const Duration(milliseconds: 500));
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
          // PageView
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              _buildWelcomePage(theme, isDark, l10n),
              _buildFeaturesPage(theme, isDark, l10n),
              _buildSignInPage(theme, isDark, l10n),
            ],
          ),

          // Skip button removed - all users must sign in

          // Bottom navigation
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Page indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.primary
                            : AppColors.textTertiary(isDark),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Navigation buttons (only for pages 0-2)
                if (_currentPage < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          SizedBox(
                            width: 100,
                            child: OutlinedButton(
                              onPressed: _previousPage,
                              child: Text(l10n.buttonPrevious),
                            ),
                          )
                        else
                          const SizedBox(width: 100),
                        SizedBox(
                          width: 120,
                          child: FilledButton(
                            onPressed: _nextPage,
                            child: Text(l10n.buttonNext),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Page 1: Welcome
  Widget _buildWelcomePage(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco,
                size: 72,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              l10n.onboardingWelcomeTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              l10n.onboardingWelcomeSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
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

  // Page 2: How it works
  Widget _buildFeaturesPage(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            _buildBenefit(
              icon: Icons.bedtime_outlined,
              title: l10n.onboardingFeature1Title,
              description: l10n.onboardingFeature1Description,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildBenefit(
              icon: Icons.shield_outlined,
              title: l10n.onboardingFeature2Title,
              description: l10n.onboardingFeature2Description,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildBenefit(
              icon: Icons.map_outlined,
              title: l10n.onboardingFeature3Title,
              description: l10n.onboardingFeature3Description,
              isDark: isDark,
              theme: theme,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // Page 3: Impact
  // Page 3: Sign In
  Widget _buildSignInPage(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.hub_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              l10n.onboardingSignInTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              l10n.onboardingSignInSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXl),

            // Benefits list
            _buildBenefit(
              icon: Icons.eco,
              title: l10n.onboardingDailyPotRewards,
              description: l10n.onboardingDailyPotDescription,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildBenefit(
              icon: Icons.cloud_sync,
              title: l10n.onboardingCloudSync,
              description: l10n.onboardingCloudSyncDescription,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildBenefit(
              icon: Icons.leaderboard,
              title: l10n.onboardingFutureFeatures,
              description: l10n.onboardingFutureDescription,
              isDark: isDark,
              theme: theme,
            ),

            const Spacer(),

            // Privacy Policy link — split-placeholder pattern:
            // pass sentinel tokens into the localized template, then split
            // on them to extract the surrounding prose segments.
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
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
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
                                url:
                                    'https://greengains.eremat.org/privacy-policy',
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
                                url:
                                    'https://greengains.eremat.org/terms-of-service',
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

            // Official Google Sign-In Button
            InkWell(
              onTap: _signingIn ? null : _handleGoogleSignIn,
              borderRadius: BorderRadius.circular(4),
              child: _signingIn
                  ? Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                        borderRadius: BorderRadius.circular(4),
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
                      height: 56,
                      fit: BoxFit.contain,
                    ),
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // Anonymous mode removed - Google Sign In required for all users

            const SizedBox(height: AppTheme.spaceLg),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryAlpha(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
