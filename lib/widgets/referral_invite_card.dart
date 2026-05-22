import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/referral/referral_service.dart';

class ReferralInviteCard extends StatefulWidget {
  const ReferralInviteCard({
    super.key,
    required this.user,
    this.neighborhoodName,
  });

  final User user;
  final String? neighborhoodName;

  @override
  State<ReferralInviteCard> createState() => _ReferralInviteCardState();
}

class _ReferralInviteCardState extends State<ReferralInviteCard> {
  String? _referralCode;
  int _conversions = 0;
  bool _hasLoadError = false;
  bool _hasShared = false;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const _kMaxPolls = 3;
  static const _kPollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _hasShared = AppPreferences.instance.referralShared;
    final cached = AppPreferences.instance.referralCode;
    if (cached != null) {
      _referralCode = cached;
    }
    _loadReferralData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    if (_referralCode == null) setState(() { _hasLoadError = false; });
    try {
      final results = await Future.wait([
        ReferralService.instance.fetchReferralCode(),
        ReferralService.instance.fetchStats(),
      ]);
      final code = results[0] as String?;
      final stats = results[1] as ({int invitesShared, int conversions})?;
      if (!mounted) return;
      final prevConversions = _conversions;
      final newConversions = stats?.conversions ?? 0;
      setState(() {
        _referralCode = code;
        _conversions = newConversions;
        _hasLoadError = code == null;
      });
      if (prevConversions == 0 && newConversions > 0) {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { if (_referralCode == null) _hasLoadError = true; });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(_kPollInterval, (_) async {
      if (!mounted || _pollCount >= _kMaxPolls) { _pollTimer?.cancel(); return; }
      _pollCount++;
      await _loadReferralData();
      if (_conversions > 0) _pollTimer?.cancel();
    });
  }

  Future<void> _share() async {
    final code = _referralCode;
    if (code == null) return;
    final l10n = context.l10n;
    final text = l10n.referralShareText(code);
    await ReferralService.instance.registerReferralInvite(referralCode: code);
    await SharePlus.instance.share(ShareParams(text: text));
    if (!mounted) return;
    unawaited(AppPreferences.instance.setReferralShared());
    setState(() => _hasShared = true);
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final canShare = _referralCode != null;

    final String bodyText;
    if (_hasShared && _conversions == 0) {
      bodyText = l10n.referralWaiting;
    } else if (_conversions > 0) {
      bodyText = _conversions == 1
          ? l10n.referralFirstJoined
          : l10n.referralConversions(_conversions);
    } else {
      bodyText = widget.neighborhoodName != null
          ? l10n.referralNeighborhoodHook(widget.neighborhoodName!)
          : l10n.referralInviteDescription;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryAlpha(0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.primaryAlpha(0.20), width: AppBorderWidths.hairline),
      ),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primaryAlpha(0.14), shape: BoxShape.circle),
            child: Icon(
              _conversions > 0 ? Icons.people_rounded : Icons.people_outline_rounded,
              color: AppColors.primary,
              size: AppIconSizes.xs,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Align(
                key: ValueKey(bodyText),
                alignment: Alignment.centerLeft,
                child: Text(
                  bodyText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _conversions > 0 ? AppColors.primary : AppColors.textPrimary(isDark),
                    fontWeight: _conversions > 0 ? AppFontWeights.semibold : AppFontWeights.medium,
                    height: AppLineHeights.snug,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: AppTheme.spaceSm),

          if (_hasLoadError && !canShare)
            _IconBtn(icon: Icons.refresh_rounded, onPressed: _loadReferralData)
          else if (_hasShared && _conversions == 0)
            _WaitingDots()
          else
            _ShareBtn(
              label: _hasShared ? l10n.referralShareAgain : l10n.referralShareLink,
              enabled: canShare,
              onPressed: _share,
            ),
        ],
      ),
    );
  }
}

class _WaitingDots extends StatefulWidget {
  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (1 - (phase - 0.5).abs() * 2).clamp(0.25, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ShareBtn extends StatefulWidget {
  const _ShareBtn({required this.label, required this.enabled, required this.onPressed});
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_ShareBtn> createState() => _ShareBtnState();
}

class _ShareBtnState extends State<_ShareBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) { setState(() => _pressed = false); widget.onPressed(); } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? 2.5 : 0, 0),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.primaryAlpha(0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          boxShadow: (_pressed || !active) ? [] : [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm + AppTheme.spaceXxxs,
          vertical: AppTheme.spaceXs,
        ),
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: AppFontWeights.semibold,
            color: active ? AppColors.darkTextPrimary : AppColors.primaryAlpha(0.50),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34, height: 34,
      child: Material(
        color: AppColors.primaryAlpha(0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onPressed,
          child: Icon(icon, size: AppIconSizes.xs, color: AppColors.primary),
        ),
      ),
    );
  }
}
