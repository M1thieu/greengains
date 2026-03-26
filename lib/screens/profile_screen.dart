import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/extensions/context_extensions.dart';
import '../services/network/backend_client.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../core/app_preferences.dart';
import '../services/auth/auth_service.dart';
import '../utils/app_snackbars.dart';
// import '../widgets/referral_invite_card.dart'; // BETA: referral deferred to v1.1
import 'settings_screen.dart';

// ── Profile layout constants ──────────────────────────────────────────────────
const _kProfileEmptyIconSize = 80.0;
const _kAvatarRadius         = 48.0;           // 96px diameter — prominent header
const _kAvatarFallbackSize   = AppIconSizes.xl;
const _kAvatarRingWidth      = 2.5;            // gradient ring around avatar

/// Profile screen showing user information and quick stats
/// REDESIGNED: Compact layout that fits without scrolling
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingIn = false;

  int? _totalUploads;
  int? _daysActive;
  int? _coverageCells;

  @override
  void initState() {
    super.initState();
    _loadProfileStats();
  }

  Future<void> _loadProfileStats() async {
    try {
      final data = await BackendClient.get('/api/user/profile');
      final profile = UserProfileResponse.fromJson(data);
      if (mounted) {
        setState(() {
          _totalUploads = profile.totalUploads;
          _daysActive = profile.daysActive;
          _coverageCells = profile.coverageCells;
        });
      }
    } catch (_) {}
  }

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
            size: _kProfileEmptyIconSize,
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
            borderRadius: BorderRadius.circular(AppTheme.radiusMin),
            child: _signingIn
                ? Container(
                    height: 56,
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
          _buildImpactRow(theme, isDark, l10n),

          const Spacer(),

          const SizedBox(height: AppTheme.spaceMd),

          // SIGN OUT BUTTON (bottom pinned)
          if (!user.isAnonymous)
            TextButton.icon(
              onPressed: _handleSignOut,
              icon: Icon(Icons.logout, size: AppIconSizes.sm),
              label: Text(l10n.profileSignOut),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error.withValues(alpha: 0.75),
                minimumSize: const Size.fromHeight(48),
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

  /// 3-column impact stat row shown below the user header
  Widget _buildImpactRow(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final tiles = [
      (
        value: _totalUploads != null ? '$_totalUploads' : '—',
        label: l10n.statsTotal.toUpperCase(),
      ),
      (
        value: _daysActive != null ? '$_daysActive' : '—',
        label: l10n.statsDaysActive.toUpperCase(),
      ),
      (
        value: _coverageCells != null ? '$_coverageCells' : '—',
        label: l10n.statsCoverage.toUpperCase(),
      ),
    ];

    return Row(
      children: tiles.map((tile) {
        final isLast = tile == tiles.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : AppTheme.spaceSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: AppTheme.spaceSm + AppTheme.spaceXxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tile.value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: AppFontWeights.bold,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    tile.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.0,
                      color: AppColors.textTertiary(isDark),
                      letterSpacing: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Premium centered user header with gradient avatar ring
  Widget _buildCompactUserHeader(User user, ThemeData theme, bool isDark, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXl),
      child: Column(
        children: [
          // Avatar with gradient ring
          Container(
            padding: const EdgeInsets.all(_kAvatarRingWidth),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.pressure],
              ),
            ),
            child: CircleAvatar(
              radius: _kAvatarRadius,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              onBackgroundImageError: user.photoURL != null
                  ? (exception, stackTrace) {}
                  : null,
              child: user.photoURL == null
                  ? const Icon(Icons.person, size: _kAvatarFallbackSize)
                  : null,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          Text(
            user.displayName ?? l10n.profileUserFallback,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppFontWeights.bold,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (user.email != null) ...[
            const SizedBox(height: AppTheme.spaceXxxs),
            Text(
              user.email!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
          if (user.metadata.creationTime != null) ...[
            const SizedBox(height: AppTheme.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: AppTheme.spaceTiny,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha(0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                l10n.profileMemberSince(_formatDate(user.metadata.creationTime!)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: AppFontWeights.semibold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
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
      // Clear account-specific cache before signing out
      await AppPreferences.instance.clearReferralCode();
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
