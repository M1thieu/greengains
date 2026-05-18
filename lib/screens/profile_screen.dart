import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import '../core/extensions/context_extensions.dart';
import '../core/events/app_events.dart';
import '../services/network/backend_client.dart';
import '../core/constants.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../core/app_preferences.dart';
import '../services/auth/auth_service.dart';
import '../utils/app_snackbars.dart';
import '../widgets/referral_invite_card.dart';
import 'settings_screen.dart';


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
  int? _currentStreak;
  int? _longestStreak;
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
          _currentStreak = profile.currentStreak;
          _longestStreak = profile.longestStreak;
        });
      }
    } catch (e) {
      debugPrint('Profile stats load failed: $e');
    }
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
      body: RefreshIndicator(
        onRefresh: _loadProfileStats,
        color: AppColors.primary,
        child: _buildSignedInState(user, theme, isDark, l10n),
      ),
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
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryAlpha(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_outlined, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            l10n.profileUnlockTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppFontWeights.semibold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            l10n.profileUnlockBody,
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
    final topPad = MediaQuery.paddingOf(context).top;
    final navBottom = MediaQuery.paddingOf(context).bottom + AppTheme.floatingNavHeight + AppTheme.spaceSm;
    final name = user.displayName ?? l10n.profileUserFallback;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadProfileStats,
          color: AppColors.primary,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                AppTheme.spaceLg, topPad + AppTheme.spaceXxl + AppTheme.spaceSm, AppTheme.spaceLg, navBottom),
            children: [
              // ── Avatar + identity ─────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.10),
                        border: Border.all(color: AppColors.primary, width: 2.5),
                      ),
                      child: ClipOval(
                        child: user.photoURL != null
                            ? CachedNetworkImage(
                                imageUrl: user.photoURL!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Shimmer.fromColors(
                                  baseColor: AppColors.shimmerBase(isDark),
                                  highlightColor: AppColors.shimmerHighlight(isDark),
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (_, __, ___) => Center(
                                  child: Text(
                                    initial,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: AppFontWeights.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initial,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: AppFontWeights.bold,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: AppFontWeights.bold,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.metadata.creationTime != null) ...[
                      const SizedBox(height: AppTheme.spaceXxs),
                      Text(
                        l10n.profileMemberSince(_formatDate(user.metadata.creationTime!)),
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeXs,
                          color: AppColors.primary,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXl),

              // ── Streak hero ────────────────────────────────────────────
              _buildStreakHero(theme, isDark, l10n),
              const SizedBox(height: AppTheme.spaceSm),

              // ── Impact stats row ───────────────────────────────────────
              _buildImpactRow(theme, isDark, l10n),
              const SizedBox(height: AppTheme.spaceMd),

              // ── Referral ───────────────────────────────────────────────
              ReferralInviteCard(
                user: user,
                neighborhoodName: AppPreferences.instance.territoryLabel,
              ),
            ],
          ),
        ),
        // Settings gear — pinned top-right, always visible
        Positioned(
          top: topPad + AppTheme.spaceXxs,
          right: AppTheme.spaceXs,
          child: Material(
            color: AppColors.surfaceElevated(isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceXs),
                child: Icon(
                  Icons.settings_outlined,
                  size: AppIconSizes.sm,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileDetail({required String title, required String value, required String explain, required Color color}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) {
        final bottomPad = MediaQuery.paddingOf(context).bottom + AppTheme.spaceMd;
        return Padding(
          padding: EdgeInsets.fromLTRB(AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceLg, bottomPad),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(isDark).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: AppTheme.spaceMd),
            Text(value, style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: AppFontWeights.bold,
              letterSpacing: -1.0,
              height: 1.0,
              color: color,
            )),
            const SizedBox(height: AppTheme.spaceXxxs),
            Text(title, style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: AppFontWeights.semibold,
              color: AppColors.textSecondary(isDark),
              letterSpacing: 0.6,
            )),
            const SizedBox(height: AppTheme.spaceMd),
            Text(explain, style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
              height: 1.5,
            )),
            const SizedBox(height: AppTheme.spaceMd),
          ]),
        );
      },
    );
  }

  Widget _buildStreakHero(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final current = _currentStreak ?? 0;
    final longest = _longestStreak ?? 0;
    final active = current > 0;

    return GestureDetector(
      onTap: () => _showProfileDetail(
        title: l10n.statsCurrentStreakLabel,
        value: '$current ${l10n.statsDaysUnit}',
        explain: l10n.profileStreakExplain,
        color: active ? AppColors.primary : AppColors.textSecondary(isDark),
      ),
      child: Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceElevated(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: active ? AppColors.primary.withValues(alpha: 0.40) : AppColors.border(isDark),
          width: active ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Big streak number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.statsCurrentStreakLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeXs,
                    fontWeight: AppFontWeights.semibold,
                    color: active ? AppColors.primary : AppColors.textSecondary(isDark),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXxs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$current',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: AppFontWeights.bold,
                        color: active ? AppColors.primary : AppColors.textPrimary(isDark),
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceXs),
                    Text(
                      l10n.statsDaysUnit,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: active ? AppColors.primary.withValues(alpha: 0.7) : AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
                if (longest > 0) ...[
                  const SizedBox(height: AppTheme.spaceXxs),
                  Text(
                    '${l10n.statsLongestLabel}: $longest ${l10n.statsDaysUnit}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Decorative bolt icon
          Icon(
            Icons.bolt_rounded,
            size: 56,
            color: active
                ? AppColors.primary.withValues(alpha: 0.22)
                : AppColors.textTertiary(isDark).withValues(alpha: 0.15),
          ),
        ],
      ),
      ),
    );
  }

  /// 3-column impact stat row shown below the user header
  Widget _buildImpactRow(ThemeData theme, bool isDark, AppLocalizations l10n) {
    final km2 = _coverageCells != null ? (_coverageCells! * kKm2PerCell) : null;
    final kmDisplay = (km2 == null || km2 == 0.0) ? '—' : (km2 < 1.0 ? km2.toStringAsFixed(2) : km2.toStringAsFixed(1));
    final tiles = [
      (
        value: _totalUploads != null ? '$_totalUploads' : '—',
        label: l10n.statsDataPtsLabel.toUpperCase(),
        color: AppColors.pressure,
        icon: Icons.cloud_upload_outlined,
      ),
      (
        value: _daysActive != null ? '$_daysActive' : '—',
        label: l10n.statsDaysActive.toUpperCase(),
        color: AppColors.movement,
        icon: Icons.calendar_today_outlined,
      ),
      (
        value: kmDisplay,
        label: l10n.statsKmMapped.toUpperCase(),
        color: AppColors.quality,
        icon: Icons.map_outlined,
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
          color: tile.color,
        );
        const textAlign = TextAlign.center;
        final isKm2 = i == 2;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < tiles.length - 1 ? AppTheme.spaceSm : 0),
            child: GestureDetector(
              onTap: isKm2 && km2 != null && km2 > 0 ? () => _showProfileDetail(
                title: l10n.statsKmMapped.toUpperCase(),
                value: kmDisplay,
                explain: l10n.profileTileAreaExplain(kmDisplay),
                color: AppColors.quality,
              ) : null,
              child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(isDark),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.border(isDark)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(tile.icon, size: AppIconSizes.xs, color: tile.color),
                  const SizedBox(height: AppTheme.spaceXxs),
                  if (numeric != null && numeric > 0)
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
                        return Text(display, style: valueStyle, textAlign: textAlign);
                      },
                    )
                  else if (numericValues[i] == null)
                    Shimmer.fromColors(
                      baseColor: AppColors.shimmerBase(isDark),
                      highlightColor: AppColors.shimmerHighlight(isDark),
                      child: Container(
                        width: 40, height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMin),
                        ),
                      ),
                    )
                  else
                    Text(tile.value, style: valueStyle, textAlign: textAlign),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  Text(
                    tile.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppTheme.fontSizeXs,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      }).toList(),
    );
  }


  String _formatDate(DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('MMM y', locale).format(date);
  }
}


