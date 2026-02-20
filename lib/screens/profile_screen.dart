import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../services/auth/auth_service.dart';
import '../utils/app_snackbars.dart';
import '../widgets/referral_invite_card.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

/// Profile screen showing user information and quick stats
/// REDESIGNED: Compact layout that fits without scrolling
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingIn = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = context.theme;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: l10n.navSettings,
          ),
        ],
      ),
      body: user == null
          ? _buildSignedOutState(theme, isDark, l10n)
          : _buildSignedInState(user, theme, isDark, l10n),
    );
  }

  /// Signed-out state - show Google Sign In option
  /// Users should sign in to unlock daily pot rewards and sync data
  Widget _buildSignedOutState(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Padding(
      padding: AppTheme.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            l10n.profileNotSignedIn,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppFontWeights.semibold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            l10n.profileSignInPrompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // Google Sign In Button
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
        ],
      ),
    );
  }

  /// Handle Google Sign In - preserves existing tracking data
  Future<void> _handleGoogleSignIn() async {
    final l10n = context.l10n; // capture before async gap
    if (_signingIn) return;
    setState(() => _signingIn = true);

    try {
      await AuthService.signInWithGoogleUniversal();
      if (!mounted) return;
      AppSnackbars.showSuccess(context, l10n.signInSuccess);
      setState(() {}); // Trigger rebuild to show signed-in state
    } catch (e) {
      debugPrint('Sign-in error: $e');
      if (!mounted) return;
      setState(() => _signingIn = false);
      AppSnackbars.showError(context, l10n.signInError);
    }
  }

  /// REDESIGNED: Compact signed-in state (no scrolling required)
  Widget _buildSignedInState(User user, ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Padding(
      padding: AppTheme.pagePadding,
      child: Column(
        children: [
          // COMPACT USER HEADER (~100px)
          _buildCompactUserHeader(user, theme, isDark, l10n),

          const SizedBox(height: AppTheme.spaceMd),

          // REFERRAL CARD (critical for monetization)
          ReferralInviteCard(user: user),

          const SizedBox(height: AppTheme.spaceMd),

          // COMPACT STATISTICS NAVIGATION (~70px)
          _buildCompactStatsCard(theme, isDark, l10n),

          const Spacer(), // Pushes sign out to bottom if screen is taller

          const SizedBox(height: AppTheme.spaceMd),

          // SIGN OUT BUTTON (bottom pinned)
          if (!user.isAnonymous)
            OutlinedButton.icon(
              onPressed: _handleSignOut,
              icon: const Icon(Icons.logout),
              label: Text(l10n.profileSignOut),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(56),
              ),
            )
          else
            // Anonymous users: Show informational text
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        l10n.profileAnonymousNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// COMPACT USER HEADER: Horizontal layout, smaller avatar, inline member badge
  Widget _buildCompactUserHeader(User user, ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Row(
          children: [
            // Smaller avatar (40px radius instead of 48px)
            CircleAvatar(
              radius: 40,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              onBackgroundImageError: user.photoURL != null
                  ? (exception, stackTrace) {
                      // Log error silently, fallback to icon child
                    }
                  : null,
              child: user.photoURL == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: AppTheme.spaceMd),

            // Compact info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name (single line)
                  Text(
                    user.displayName ?? l10n.profileUserFallback,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: AppFontWeights.semibold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spaceXxs),

                  // Inline member since (no container, just text)
                  if (user.metadata.creationTime != null)
                    Text(
                      l10n.profileMemberSince(_formatDate(user.metadata.creationTime!)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// COMPACT STATISTICS NAVIGATION: Single-line ListTile instead of multi-line card
  Widget _buildCompactStatsCard(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Card(
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const StatisticsScreen(),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryAlpha(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bar_chart,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          l10n.profileViewStats,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: AppFontWeights.semibold,
          ),
        ),
        subtitle: Text(
          l10n.profileContributionsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textTertiary(isDark),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('MMM y', locale).format(date);
  }

  Future<void> _handleSignOut() async {
    final l10n = context.l10n; // capture before async gap
    HapticFeedback.lightImpact();
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {});
        AppSnackbars.showSuccess(context, l10n.profileSignedOut);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbars.showError(context, l10n.errorGeneric);
      }
    }
  }
}
