import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../widgets/time_ago_text.dart';

// ── Chip layout constants ─────────────────────────────────────────────────────
const _kChipDotSize         = AppTheme.spaceXs;   // 8 — solid dot diameter
const _kChipDotArea         = AppTheme.spaceMd;   // 16 — pulse ring reserved area
const _kChipLabelSize       = 13.0;               // between bodySmall(12) and bodyMedium(14)
const _kChipTimeSize        = 12.0;               // matches bodySmall
const _kPulseCycle          = Duration(milliseconds: 1400);

/// Compact status pill shown as a map overlay.
/// Flat, semi-transparent dark background — no blur (reduces render cost on map).
/// Shows: live-pulse dot + state label + last upload timestamp.
///
/// The dot pulses outward when actively tracking (Strava / Uber live-indicator
/// pattern) and is static when paused or stopped.
class TrackingStatusChip extends StatefulWidget {
  const TrackingStatusChip({
    super.key,
    required this.isTracking,
    required this.isPaused,
    this.lastUpload,
    this.tileCount = 0,
    this.isUploading = false,
    this.pendingReadings = 0,
    this.onTap,
  });

  final bool isTracking;
  final bool isPaused;
  final DateTime? lastUpload;
  final int tileCount;
  final bool isUploading;
  /// Pending readings in buffer — shown inline when actively tracking.
  final int pendingReadings;
  final VoidCallback? onTap;

  @override
  State<TrackingStatusChip> createState() => _TrackingStatusChipState();
}

class _TrackingStatusChipState extends State<TrackingStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashCtrl;
  late final Animation<double> _flashOpacity;

  DateTime? _lastUploadSeen;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(TrackingStatusChip old) {
    super.didUpdateWidget(old);
    // New upload just landed — flash the chip
    if (widget.lastUpload != null && widget.lastUpload != _lastUploadSeen) {
      _lastUploadSeen = widget.lastUpload;
      _flashCtrl.forward(from: 0.0).then((_) => _flashCtrl.reverse());
    }
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (dotColor, label) = _state(l10n);
    final isActive = widget.isTracking && !widget.isPaused;

    return GestureDetector(
      onTap: widget.onTap != null
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _flashCtrl,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: _flashCtrl.value > 0
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: _flashOpacity.value * 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: child,
        ),
        child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm,
          vertical: AppTheme.spaceXs,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.mapOverlayGreen
              : AppColors.mapOverlayMid,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: isActive
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.40))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulseDot(color: dotColor, active: isActive),
            const SizedBox(width: AppTheme.spaceXs),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.darkTextPrimary,
                fontSize: _kChipLabelSize,
                fontWeight: AppFontWeights.semibold,
                letterSpacing: 0.1,
              ),
            ),
            // Paused: show zone count so user knows where they left off.
            if (widget.isPaused && widget.tileCount > 0) ...[
              const SizedBox(width: AppTheme.spaceXxs + 1),
              Text('·', style: TextStyle(color: AppColors.darkTextSecondary.withValues(alpha: 0.5), fontSize: _kChipLabelSize)),
              const SizedBox(width: AppTheme.spaceXxs + 1),
              Text(
                '${widget.tileCount} ${context.l10n.chipZones}',
                style: TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: _kChipTimeSize,
                ),
              ),
            ],
            if (widget.isPaused) ...[
              if (widget.isUploading) ...[
                const SizedBox(width: AppTheme.spaceXxs + 1),
                Text('·', style: TextStyle(color: AppColors.darkTextSecondary.withValues(alpha: 0.5), fontSize: _kChipLabelSize)),
                const SizedBox(width: AppTheme.spaceXxs + 1),
                const SizedBox(
                  width: _kChipTimeSize,
                  height: _kChipTimeSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkTextSecondary),
                  ),
                ),
              ] else if (widget.lastUpload != null) ...[
                const SizedBox(width: AppTheme.spaceXxs + 1),
                Text('·', style: TextStyle(color: AppColors.darkTextSecondary.withValues(alpha: 0.5), fontSize: _kChipLabelSize)),
                const SizedBox(width: AppTheme.spaceXxs + 1),
                TimeAgoText(
                  timestamp: widget.lastUpload!,
                  style: TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: _kChipTimeSize,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
    );
  }

  (Color, String) _state(AppLocalizations l10n) {
    if (widget.isTracking && !widget.isPaused) return (AppColors.primary, l10n.chipContributing);
    if (widget.isPaused) return (AppColors.warning, l10n.chipPaused);
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
