import 'package:flutter/material.dart';
import '../core/themes.dart';
import 'time_ago_text.dart';

// ── SensorDataCard layout constants ──────────────────────────────────────────
const _kSensorIconPad     = AppTheme.spaceXs;     //  8 — icon container padding
const _kSensorValuePadH   = AppTheme.spaceXs;     //  8 — value pill h-padding
const _kSensorValuePadV   = AppTheme.spaceXxxs;   //  2 — value pill v-padding
const _kSensorValueRadius = AppTheme.radiusSm;    //  8 — value + shimmer pill radius
const _kSensorUnitLineH   = 1.2;                  // line-height for unit text
const _kSensorTimeSize    = 11.0;                 // font size for update timestamp
const _kShimmerW          = 120.0;               // shimmer placeholder width
const _kShimmerH          = AppTheme.spaceLg;     // 24 — shimmer placeholder height
const _kShimmerDuration   = Duration(milliseconds: 1500);

/// Reusable sensor data display card with live values
/// Shows icon, title, current value, and unit
/// Enhanced with subtle animations and better visual feedback
class SensorDataCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? value;
  final String? rawValue;
  final String unit;
  final bool enabled;
  final String statusLabel;
  final DateTime? updatedAt;
  final Color? accentColor;

  const SensorDataCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.rawValue,
    required this.unit,
    required this.enabled,
    required this.statusLabel,
    this.updatedAt,
    this.accentColor,
  });

  @override
  State<SensorDataCard> createState() => _SensorDataCardState();
}

class _SensorDataCardState extends State<SensorDataCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _previousValue;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: AppDurations.medium,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: AppMotion.standard),
    );
  }

  @override
  void didUpdateWidget(SensorDataCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger subtle pulse when value changes
    if (widget.value != null &&
        widget.value != _previousValue &&
        _previousValue != null) {
      _pulseController.forward().then((_) => _pulseController.reverse());
    }
    _previousValue = widget.value;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _accent => widget.accentColor ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = widget.enabled && widget.value != null;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          // surfaceElevated: floats above sheet (surface), no green tint
          color: AppColors.surfaceElevated(isDark),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            // Active: slightly more visible emerald border (informative, not decorative)
            // Inactive: standard border
            color: isActive
                ? _accent.withValues(alpha: 0.35)
                : AppColors.border(isDark),
            width: 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(_kSensorIconPad),
                decoration: BoxDecoration(
                  // Flat icon bg: primary tint when active, surfaceActive when not.
                  // No gradient, no glow — Linear/Vercel flat icon style.
                  color: isActive
                      ? _accent.withValues(alpha: 0.12)
                      : AppColors.surfaceActive(isDark),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  widget.icon,
                  size: AppIconSizes.sm,
                  color: isActive
                      ? _accent
                      : AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: AppFontWeights.semibold,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        _StatusBadge(
                          label: widget.statusLabel,
                          active: isActive,
                          accentColor: _accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXxs),
                    // Value display with shimmer loading state
                    widget.value != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _kSensorValuePadH,
                              vertical: _kSensorValuePadV,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? _accent.withValues(alpha: 0.05) : null,
                              borderRadius: BorderRadius.circular(_kSensorValueRadius),
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: AppDurations.fast,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                    color: isActive
                                        ? AppColors.textPrimary(isDark)
                                        : AppColors.textSecondary(isDark),
                                    fontWeight: isActive ? AppFontWeights.semibold : FontWeight.normal,
                                  ) ??
                                  const TextStyle(),
                              child: Text(widget.value!),
                            ),
                          )
                        : _ShimmerLoading(isDark: isDark),
                    if (widget.rawValue != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.rawValue!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary(isDark),
                          height: _kSensorUnitLineH,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    // Timestamp display
                    if (widget.updatedAt != null) ...[
                      const SizedBox(height: AppTheme.spaceXxxs),
                      TimeAgoText(
                        timestamp: widget.updatedAt!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary(isDark),
                          fontSize: _kSensorTimeSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.active, required this.accentColor});

  final String label;
  final bool active;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXxs,
      ),
      decoration: BoxDecoration(
        color: active
            ? accentColor.withValues(alpha: 0.15)
            : AppColors.border(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: active ? accentColor : theme.colorScheme.outline,
          fontWeight: AppFontWeights.semibold,
        ),
      ),
    );
  }
}

/// Shimmer loading animation for sensor data
class _ShimmerLoading extends StatefulWidget {
  final bool isDark;

  const _ShimmerLoading({required this.isDark});

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: _kShimmerDuration,
      vsync: this,
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _shimmerAnimation.value,
          child: Container(
            height: _kShimmerH,
            width: _kShimmerW,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase(widget.isDark),
              borderRadius: BorderRadius.circular(_kSensorValueRadius),
            ),
          ),
        );
      },
    );
  }
}

