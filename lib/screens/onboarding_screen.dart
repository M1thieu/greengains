import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/themes.dart';
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
    if (_currentPage < 3) {
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
    if (_signingIn) return;
    setState(() => _signingIn = true);

    try {
      await AuthService.signInWithGoogleUniversal();
      if (!mounted) return;
      AppSnackbars.showSuccess(context, 'Signed in successfully');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      print('❌ Sign-in error: $e');
      if (!mounted) return;
      setState(() => _signingIn = false);
      AppSnackbars.showError(context, 'Sign-in cancelled or failed');
    }
  }

  // Removed _skipSignIn() - all users must sign in with Google (no anonymous mode)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              _buildWelcomePage(theme, isDark),
              _buildFeaturesPage(theme, isDark),
              _buildImpactPage(theme, isDark),
              _buildSignInPage(theme, isDark),
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
                    4,
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
                if (_currentPage < 3)
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
                              child: const Text('Previous'),
                            ),
                          )
                        else
                          const SizedBox(width: 100),
                        SizedBox(
                          width: 120,
                          child: FilledButton(
                            onPressed: _nextPage,
                            child: const Text('Next'),
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
  Widget _buildWelcomePage(ThemeData theme, bool isDark) {
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.eco,
                size: 72,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              'Welcome to GreenGains',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Help create greener cities by passively collecting environmental sensor data.',
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

  // Page 2: Features
  Widget _buildFeaturesPage(ThemeData theme, bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.sensors,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              'Passive Collection',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Runs in the background while you go about your day. No interaction needed.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Icon(
              Icons.privacy_tip,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              'Privacy First',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Location sharing is optional and uses coarse positioning only.',
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

  // Page 3: Impact
  Widget _buildImpactPage(ThemeData theme, bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.show_chart,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              'Track Your Impact',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'See your contributions and help map environmental data for your city.',
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

  // Page 4: Sign In
  Widget _buildSignInPage(ThemeData theme, bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.card_giftcard,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            Text(
              'Unlock Rewards',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Sign in to access daily pot rewards and sync your data across devices.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXl),

            // Benefits list
            _buildBenefit(
              icon: Icons.eco,
              title: 'Daily Pot Rewards',
              description: 'Earn 10-100 credits every day',
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildBenefit(
              icon: Icons.cloud_sync,
              title: 'Cloud Sync',
              description: 'Access your data on any device',
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildBenefit(
              icon: Icons.leaderboard,
              title: 'Future Features',
              description: 'Leaderboards and competitions',
              isDark: isDark,
              theme: theme,
            ),

            const Spacer(),

            // Privacy Policy link
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                  children: [
                    const TextSpan(text: 'By continuing, you agree to our '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: AppFontWeights.medium,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WebViewScreen(
                                url: 'https://greengains.eremat.org/privacy-policy',
                                title: 'Privacy Policy',
                              ),
                            ),
                          );
                        },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: AppFontWeights.medium,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WebViewScreen(
                                url: 'https://greengains.eremat.org/terms-of-service',
                                title: 'Terms of Service',
                              ),
                            ),
                          );
                        },
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),

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
                        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
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
