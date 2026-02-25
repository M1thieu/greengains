import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/themes.dart';
import '../core/extensions/context_extensions.dart';
import '../services/daily_pot_service.dart';
import '../data/models/daily_pot.dart';
import '../utils/app_snackbars.dart';

/// Daily login widget - compact daily pot progress + claim action.
class DailyLoginWidget extends StatefulWidget {
  const DailyLoginWidget({super.key});

  @override
  State<DailyLoginWidget> createState() => _DailyLoginWidgetState();
}

class _DailyLoginWidgetState extends State<DailyLoginWidget>
    with SingleTickerProviderStateMixin {
  final _service = DailyPotService.instance;
  late AnimationController _jiggleController;
  late Animation<double> _jiggleAnimation;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _jiggleController = AnimationController(
      duration: AppDurations.medium,
      vsync: this,
    )..repeat(reverse: true);
    _jiggleAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _jiggleController, curve: AppMotion.standard),
    );
  }

  @override
  void dispose() {
    _jiggleController.dispose();
    super.dispose();
  }

  Future<void> _claimReward() async {
    if (_claiming) return;
    setState(() => _claiming = true);

    HapticFeedback.heavyImpact();
    final claimedAmount = await _service.claimPot();
    final l10n = context.l10n;

    if (!mounted) return;
    setState(() => _claiming = false);

    if (claimedAmount > 0) {
      HapticFeedback.heavyImpact();
      AppSnackbars.showSuccess(context, l10n.dailyPotClaimed(claimedAmount));
    } else {
      AppSnackbars.showInfo(context, l10n.dailyPotAlreadyClaimed);
    }
  }

  void _showLockedFeedback() {
    final pot = _service.pot.value;
    if (pot == null) return;
    final l10n = context.l10n;

    HapticFeedback.lightImpact();

    if (pot.hasClaimedToday) {
      AppSnackbars.showInfo(context, l10n.dailyPotAlreadyClaimed);
    } else if (!pot.isUnlocked) {
      final remaining = pot.uploadsRequired - pot.uploadsToday;
      AppSnackbars.showInfo(
        context,
        l10n.dailyPotNeedMoreUploads(remaining, remaining == 1 ? '' : 's'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<DailyPot?>(
      valueListenable: _service.pot,
      builder: (context, pot, _) {
        if (pot == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: pot.canClaim ? _claimReward : _showLockedFeedback,
          child: AnimatedBuilder(
            animation: _jiggleAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: pot.canClaim ? _jiggleAnimation.value : 0,
                child: child,
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: pot.progress,
                      strokeWidth: 3,
                      backgroundColor: AppColors.surfaceElevated(isDark).withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(
                        pot.isUnlocked ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: pot.canClaim
                          ? const LinearGradient(
                              colors: AppColors.gradientGreen,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: pot.canClaim ? null : AppColors.surfaceElevated(isDark),
                      boxShadow: pot.canClaim
                          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.eco, size: 18, color: pot.canClaim ? Colors.white : AppColors.primary),
                        if (!pot.isUnlocked)
                          Icon(
                            Icons.lock,
                            size: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
