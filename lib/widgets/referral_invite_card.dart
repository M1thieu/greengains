import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/referral/referral_service.dart';
import '../utils/app_snackbars.dart';

class ReferralInviteCard extends StatefulWidget {
  const ReferralInviteCard({
    super.key,
    required this.user,
  });

  final User user;

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.diversity_3, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.referralInviteTitle,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.semibold),
                  ),
                ),
                if (_conversions != null && _conversions! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_conversions',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            // 3-step visual flow: Share → They join → You earn
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ReferralStep(icon: Icons.share_outlined, label: context.l10n.referralStepShare),
                _ReferralStepArrow(),
                _ReferralStep(icon: Icons.person_add_outlined, label: context.l10n.referralStepJoin),
                _ReferralStepArrow(),
                _ReferralStep(icon: Icons.attach_money, label: context.l10n.referralStepEarn),
              ],
            ),
            if (_conversions != null) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.referralConversions(_conversions!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _conversions! > 0
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: _buildCodeBar(
                context: context,
                theme: theme,
                referralCode: referralCode,
                referralLink: referralLink,
              ),
            ),
            if (_hasLoadError && !_isLoading) ...[
              const SizedBox(height: 6),
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
    required String? referralCode,
    required String? referralLink,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final codeText = Text(
          referralCode ?? (_hasLoadError ? context.l10n.errorGeneric : context.l10n.loading),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        final actionButtons = _buildCodeActions(
          context: context,
          referralCode: referralCode,
          referralLink: referralLink,
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              codeText,
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [actionButtons],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: codeText),
            const SizedBox(width: 8),
            actionButtons,
          ],
        );
      },
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
            icon: const Icon(Icons.refresh, size: 18),
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
          icon: const Icon(Icons.copy, size: 16),
          label: Text(context.l10n.referralCopyLink),
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
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
      child: Icon(
        Icons.arrow_forward_ios,
        size: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
