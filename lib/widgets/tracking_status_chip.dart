import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../widgets/time_ago_text.dart';

/// Compact status pill shown as a map overlay.
/// Flat, semi-transparent dark background — no blur (reduces render cost on map).
/// Shows: colored dot + state label + last upload timestamp.
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

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // State label
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            // Last upload (only when tracking)
            if (isTracking && !isPaused && lastUpload != null) ...[
              const SizedBox(width: 6),
              Container(width: 1, height: 12, color: Colors.white24),
              const SizedBox(width: 6),
              TimeAgoText(
                timestamp: lastUpload!,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
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
