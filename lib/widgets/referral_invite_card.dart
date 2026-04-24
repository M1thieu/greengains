import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/referral/referral_service.dart';
import '../utils/app_snackbars.dart';

// ── ReferralInviteCard layout constants ───────────────────────────────────────
const _kReferralAvatarSize = AppTheme.spaceXl + AppTheme.spaceXs;  // 40 — header icon circle
const _kConvBadgePadH      = AppTheme.spaceXs;                     //  8 — conversions badge h-pad
const _kConvBadgePadV      = AppTheme.spaceXxxs;                   //  2 — conversions badge v-pad
const _kConvBadgeRadius    = AppTheme.radiusMd;                    // 12 — conversions badge radius
const _kCodePad            = AppTheme.spaceSm;                     // 12 — code container padding
const _kCodeRadius         = AppTheme.radiusMd;                    // 12 — code container radius
const _kStepCircleSize     = AppTheme.spaceXl + AppTheme.spaceXs;  // 40 — step icon circle
const _kStepArrowPad       = AppTheme.spaceXxs;                    //  4 — arrow left/right inset
const _kStepArrowIconSize  = AppTheme.spaceSm;                     // 12 — chevron icon size

class ReferralInviteCard extends StatefulWidget {
  const ReferralInviteCard({
    super.key,
    required this.user,
    this.neighborhoodName,
  });

  final User user;
  /// Primary neighborhood name — when set, shows a geographic hook line
  /// ("Help map Belleville — every neighbor fills in what you haven't reached.")
  final String? neighborhoodName;

  @override
  State<ReferralInviteCard> createState() => _ReferralInviteCardState();
}

class _ReferralInviteCardState extends State<ReferralInviteCard> {
  int? _conversions;
  String? _referralCode;
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    // Show cached code immediately — no spinner if we already have it
    final cached = AppPreferences.instance.referralCode;
    if (cached != null) {
      _referralCode = cached;
      _isLoading = false;
    }
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    if (_referralCode == null) {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });
    }

    try {
      // Run code and stats in parallel
      final results = await Future.wait([
        ReferralService.instance.fetchReferralCode(),
        ReferralService.instance.fetchStats(),
      ]);

      final code = results[0] as String?;
      final stats = results[1] as ({int invitesShared, int conversions})?;

      if (!mounted) return;
      setState(() {
        _conversions = stats?.conversions ?? 0;
        _referralCode = code;
        _isLoading = false;
        _hasLoadError = code == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _conversions = 0;
        _isLoading = false;
        // Keep existing cached code if we have it; only flag error if never loaded
        if (_referralCode == null) _hasLoadError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final referralCode = _referralCode;
    final referralLink = referralCode == null
        ? null
        : 'https://greengains.eremat.org/invite/$referralCode';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: AppColors.border(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: _kReferralAvatarSize,
                  height: _kReferralAvatarSize,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAlpha(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.diversity_3, color: AppColors.primary, size: AppIconSizes.md),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Text(
                    context.l10n.referralInviteTitle,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.semibold),
                  ),
                ),
                if (_conversions != null && _conversions! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kConvBadgePadH,
                      vertical: _kConvBadgePadV,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.12),
                      borderRadius: BorderRadius.circular(_kConvBadgeRadius),
                    ),
                    child: Text(
                      '$_conversions',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.neighborhoodName != null) ...[
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                context.l10n.referralNeighborhoodHook(widget.neighborhoodName!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceMd),
            // 3-step visual flow: Share → They join → You earn
            Row(
              children: [
                Expanded(child: _ReferralStep(icon: Icons.share_outlined, label: context.l10n.referralStepShare)),
                _ReferralStepArrow(),
                Expanded(child: _ReferralStep(icon: Icons.person_add_outlined, label: context.l10n.referralStepJoin)),
                _ReferralStepArrow(),
                Expanded(child: _ReferralStep(icon: Icons.map_outlined, label: context.l10n.referralStepEarn)),
              ],
            ),
            if (_conversions != null) ...[
              const SizedBox(height: AppTheme.spaceXxs),
              Text(
                context.l10n.referralConversions(_conversions!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _conversions! > 0
                      ? AppColors.primary
                      : AppColors.textSecondary(isDark),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceSm),
            Container(
              padding: const EdgeInsets.all(_kCodePad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kCodeRadius),
                color: AppColors.surfaceElevated(isDark),
                border: Border.all(color: AppColors.border(isDark)),
              ),
              child: _buildCodeBar(
                context: context,
                theme: theme,
                isDark: isDark,
                referralCode: referralCode,
                referralLink: referralLink,
              ),
            ),
            if (_hasLoadError && !_isLoading) ...[
              const SizedBox(height: AppTheme.spaceXxs),
              Text(
                context.l10n.errorGeneric,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBar({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required String? referralCode,
    required String? referralLink,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            referralCode ?? (_hasLoadError ? context.l10n.errorGeneric : context.l10n.loading),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: AppFontWeights.semibold,
              letterSpacing: 0.5,
              color: AppColors.textPrimary(isDark),
            ),
          ),
        ),
        _buildCodeActions(
          context: context,
          referralCode: referralCode,
          referralLink: referralLink,
        ),
      ],
    );
  }

  Widget _buildCodeActions({
    required BuildContext context,
    required String? referralCode,
    required String? referralLink,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasLoadError && !_isLoading)
          IconButton(
            tooltip: context.l10n.buttonRetry,
            onPressed: _loadReferralData,
            icon: const Icon(Icons.refresh, size: AppIconSizes.sm),
          ),
        TextButton.icon(
          onPressed: referralLink == null
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: referralLink));
                  await ReferralService.instance.registerReferralInvite(
                    referralCode: referralCode!,
                  );
                  if (context.mounted) {
                    AppSnackbars.showInfo(context, context.l10n.referralLinkCopied);
                  }
                },
          icon: const Icon(Icons.copy, size: AppIconSizes.xs),
          label: Text(context.l10n.referralCopyLink),
        ),
        IconButton(
          tooltip: context.l10n.referralShareLink,
          onPressed: referralLink == null
              ? null
              : () async {
                  await ReferralService.instance.registerReferralInvite(
                    referralCode: referralCode!,
                  );
                  await SharePlus.instance.share(ShareParams(
                    uri: Uri.parse(referralLink),
                  ));
                },
          icon: const Icon(Icons.ios_share, size: AppIconSizes.sm),
        ),
      ],
    );
  }
}

class _ReferralStep extends StatelessWidget {
  const _ReferralStep({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: _kStepCircleSize,
          height: _kStepCircleSize,
          decoration: BoxDecoration(
            color: AppColors.primaryAlpha(0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: AppIconSizes.sm, color: AppColors.primary),
        ),
        const SizedBox(height: AppTheme.spaceXxs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            fontWeight: AppFontWeights.medium,
          ),
        ),
      ],
    );
  }
}

class _ReferralStepArrow extends StatelessWidget {
  const _ReferralStepArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppTheme.spaceMd,
        left: _kStepArrowPad,
        right: _kStepArrowPad,
      ),
      child: Icon(
        Icons.arrow_forward_ios,
        size: _kStepArrowIconSize,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}
