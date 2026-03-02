import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../widgets/time_ago_text.dart';

// ── Chip layout constants ─────────────────────────────────────────────────────
const _kChipDotSize   = AppTheme.spaceXs;    // 8 — solid dot diameter
const _kChipDotArea   = AppTheme.spaceMd;    // 16 — reserved area for pulse ring (2× dot)
const _kChipDividerH  = AppTheme.spaceSm;    // 12 — separator line height
const _kChipLabelSize = 13.0;               // between bodySmall(12) and bodyMedium(14)
const _kChipTimeSize  = 12.0;               // matches bodySmall
const _kPulseCycle    = Duration(milliseconds: 1400); // one pulse cycle

/// Compact status pill shown as a map overlay.
/// Flat, semi-transparent dark background — no blur (reduces render cost on map).
/// Shows: live-pulse dot + state label + last upload timestamp.
///
/// The dot pulses outward when actively tracking (Strava / Uber live-indicator
/// pattern) and is static when paused or stopped.
class TrackingStatusChip extends StatelessWidget {
  const TrackingStatusChip({
    super.key,
    required this.isTracking,
    required this.isPaused,
    this.lastUpload,
  });

  final bool isTracking;
  final bool isPaused;
  final DateTime? lastUpload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (dotColor, label) = _state(l10n);
    final isActive = isTracking && !isPaused;

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm,
          vertical: AppTheme.spaceXs,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live pulse dot — animates when actively tracking
            _PulseDot(color: dotColor, active: isActive),
            const SizedBox(width: AppTheme.spaceXs),
            // State label
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: _kChipLabelSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            // Last upload (tracking or paused — hidden only when fully stopped)
            if ((isTracking || isPaused) && lastUpload != null) ...[
              const SizedBox(width: AppTheme.spaceXxs),
              Container(
                width: 1,
                height: _kChipDividerH,
                color: Colors.white24,
              ),
              const SizedBox(width: AppTheme.spaceXxs),
              TimeAgoText(
                timestamp: lastUpload!,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: _kChipTimeSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, String) _state(AppLocalizations l10n) {
    if (isTracking && !isPaused) return (AppColors.primary, l10n.chipContributing);
    if (isPaused) return (AppColors.warning, l10n.chipPaused);
    return (Colors.grey, l10n.chipTapStart);
  }
}

/// Pulsing dot indicator for "live" state.
///
/// When [active] is true: a translucent ring grows from the dot center and fades
/// out, creating a heartbeat-style live signal (Strava / Uber pattern).
/// When [active] is false: renders a plain static circle.
///
/// Layout: always occupies [_kChipDotArea] × [_kChipDotArea] so the chip
/// width stays stable when switching between active and inactive.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kPulseCycle);
    // Ring grows from dot size to exactly fill the dot-area SizedBox (scale = 2.0),
    // fading to transparent — stays within the reserved layout space.
    _ringScale   = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _ctrl.repeat();
    } else if (!widget.active && old.active) {
      _ctrl
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kChipDotArea,
      height: _kChipDotArea,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring — only rendered + animated when active
          if (widget.active)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Transform.scale(
                scale: _ringScale.value,
                child: Container(
                  width: _kChipDotSize,
                  height: _kChipDotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: _ringOpacity.value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          // Solid dot — always visible
          Container(
            width: _kChipDotSize,
            height: _kChipDotSize,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
