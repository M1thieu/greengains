import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/extensions/context_extensions.dart';
import '../core/events/app_events.dart';
import '../services/network/backend_client.dart';
import '../core/constants.dart';
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
  const ProfileScreen({super.key, this.onViewStats});

  /// Called when the user taps "View Statistics" — used by AppShell to switch tabs.
  final VoidCallback? onViewStats;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingIn = false;

  int? _totalUploads;
  int? _daysActive;
  int? _coverageCells;
  // Previous display values — so count-up never resets to 0 on reload
  double _prevTotalUploads = 0;
  double _prevDaysActive = 0;
  double _prevKm2 = 0;

  StreamSubscription<ProfileUpdatedEvent>? _profileSub;

  @override
  void initState() {
    super.initState();
    // One-time fetch on init — covers the case where Stats tab hasn't loaded yet.
    // Subsequent updates (on upload) come from ProfileUpdatedEvent emitted by Stats.
    _loadProfileStats();
    _profileSub = AppEventBus.instance
        .on<ProfileUpdatedEvent>()
        .listen((event) {
      if (mounted) {
        setState(() {
          _totalUploads = event.totalUploads;
          _daysActive = event.daysActive;
          _coverageCells = event.coverageCells;
        });
      }
    });
  }

  Future<void> _loadProfileStats() async {
    try {
      final data = await BackendClient.get(kApiUserProfile);
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
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = context.theme;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    // Signed-out: plain scaffold with app bar
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          actions: [_settingsButton(context, l10n)],
        ),
        body: _buildSignedOutState(theme, isDark, l10n),
      );
    }

    // Signed-in: collapsing SliverAppBar — avatar expands, shrinks on scroll
    return Scaffold(
      body: _buildSignedInState(user, theme, isDark, l10n),
    );
  }

  Widget _settingsButton(BuildContext context, AppLocalizations l10n) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
      tooltip: l10n.navSettings,
    );
  }

  /// Signed-out state - show Google Sign In option
  /// Users should sign in to unlock daily pot rewards and sync data
  Widget _buildSignedOutState(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final navBottom = MediaQuery.paddingOf(context).bottom + AppTheme.floatingNavHeight + AppTheme.spaceSm;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceLg, navBottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - navBottom - AppTheme.spaceMd,
        ),
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

  Widget _buildSignedInState(User user, ThemeData theme, bool isDark, AppLocalizations l10n) {
    final navBottom = MediaQuery.paddingOf(context).bottom + AppTheme.floatingNavHeight + AppTheme.spaceSm;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          actions: [_settingsButton(context, l10n)],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: SafeArea(
              bottom: false,
              child: _buildCompactUserHeader(user, theme, isDark, l10n),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.spaceLg,
            AppTheme.spaceMd,
            AppTheme.spaceLg,
            navBottom,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildImpactRow(theme, isDark, l10n),
              if (widget.onViewStats != null) ...[
                const SizedBox(height: AppTheme.spaceSm),
                _buildViewStatsButton(theme, isDark, l10n),
              ],
              const SizedBox(height: AppTheme.spaceXl),
              _buildAccountSection(user, theme, isDark, l10n),
              const SizedBox(height: AppTheme.spaceSm),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildViewStatsButton(ThemeData theme, bool isDark, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          widget.onViewStats!();
        },
        icon: const Icon(Icons.bar_chart, size: AppIconSizes.sm),
        label: Text(l10n.profileViewStats),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          minimumSize: const Size.fromHeight(AppTheme.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }

  /// Account section — sign out + anonymous notice.
  Widget _buildAccountSection(User user, ThemeData theme, bool isDark, AppLocalizations l10n) {
    if (!user.isAnonymous) {
      return TextButton.icon(
        onPressed: _handleSignOut,
        icon: Icon(Icons.logout, size: AppIconSizes.sm),
        label: Text(l10n.profileSignOut),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error.withValues(alpha: 0.75),
          minimumSize: const Size.fromHeight(AppTheme.minTouchTarget),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant, size: AppIconSizes.sm),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              l10n.profileAnonymousNote,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  /// 3-column impact stat row shown below the user header
  Widget _buildImpactRow(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final km2 = _coverageCells != null ? (_coverageCells! * 0.1053) : null;
    final kmDisplay = km2 == null ? '—' : (km2 < 1.0 ? km2.toStringAsFixed(2) : km2.toStringAsFixed(1));
    final tiles = [
      (
        value: _totalUploads != null ? '$_totalUploads' : '—',
        label: l10n.statsDataPtsLabel.toUpperCase(),
        color: AppColors.pressure,
      ),
      (
        value: _daysActive != null ? '$_daysActive' : '—',
        label: l10n.statsDaysActive.toUpperCase(),
        color: AppColors.movement,
      ),
      (
        value: kmDisplay,
        label: l10n.statsKmMapped.toUpperCase(),
        color: AppColors.quality,
      ),
    ];

    final numericValues = [
      _totalUploads?.toDouble(),
      _daysActive?.toDouble(),
      km2,
    ];
    final prevValues = [_prevTotalUploads, _prevDaysActive, _prevKm2];

    return Row(
      children: tiles.indexed.map((entry) {
        final (i, tile) = entry;
        final numeric = numericValues[i];
        final valueStyle = theme.textTheme.titleLarge?.copyWith(
          fontWeight: AppFontWeights.bold,
          letterSpacing: -0.5,
          height: 1.0,
        );
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < tiles.length - 1 ? AppTheme.spaceSm : 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceSm + AppTheme.spaceXxs,
                AppTheme.spaceSm + AppTheme.spaceXxs,
                AppTheme.spaceSm,
                AppTheme.spaceSm + AppTheme.spaceXxs,
              ),
              decoration: AppTheme.kpiCard(isDark: isDark, accentColor: tile.color),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (numeric != null)
                    TweenAnimationBuilder<double>(
                      key: ValueKey(numeric),
                      tween: Tween(begin: prevValues[i], end: numeric),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      onEnd: () {
                        if (i == 0) { _prevTotalUploads = numeric; }
                        else if (i == 1) { _prevDaysActive = numeric; }
                        else { _prevKm2 = numeric; }
                      },
                      builder: (_, v, __) {
                        final display = i == 2
                            ? (v < 1.0 ? v.toStringAsFixed(2) : v.toStringAsFixed(1))
                            : v.round().toString();
                        return Text(display, style: valueStyle);
                      },
                    )
                  else
                    Text(tile.value, style: valueStyle),
                  const SizedBox(height: AppTheme.spaceXxxs),
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
      child: Column(
        children: [
          // Avatar with subtle ring
          Container(
            padding: const EdgeInsets.all(_kAvatarRingWidth),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.25),
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
