import 'dart:async';
import 'package:flutter/material.dart';
import '../core/themes.dart';

/// Reusable sensor data display card with live values
/// Shows icon, title, current value, and unit
/// Enhanced with subtle animations and better visual feedback
class SensorDataCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? value;
  final String unit;
  final bool enabled;
  final String statusLabel;
  final DateTime? updatedAt;

  const SensorDataCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.enabled,
    required this.statusLabel,
    this.updatedAt,
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
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.border(isDark),
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  ...AppColors.glowEffect(AppColors.primary, opacity: 0.12),
                  ...(isDark
                      ? AppColors.elevationDark(active: true)
                      : AppColors.elevationLight(active: true)),
                ]
              : (isDark
                  ? AppColors.elevationDark(active: false)
                  : AppColors.elevationLight(active: false)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isActive ? AppGradients.greenGlow : null,
                  color: isActive ? null : AppColors.surfaceElevated(isDark),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  // Add subtle inner glow for active icons
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: -2,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  size: AppIconSizes.sm,
                  color: isActive ? AppColors.primary : AppColors.textTertiary(isDark),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXxs),
                    // Value display with shimmer loading state
                    widget.value != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primaryAlpha(0.05) : null,
                              borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(height: 2),
                    Text(
                      widget.unit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                    // Timestamp display
                    if (widget.updatedAt != null) ...[
                      const SizedBox(height: 2),
                      _TimeSinceText(
                        timestamp: widget.updatedAt!,
                        prefix: '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary(isDark),
                          fontSize: 11,
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
  const _StatusBadge({required this.label, required this.active});

  final String label;
  final bool active;

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
            ? AppColors.primaryAlpha(0.15)
            : AppColors.border(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: active ? AppColors.primary : theme.colorScheme.outline,
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
      duration: const Duration(milliseconds: 1500),
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
            height: 24,
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase(widget.isDark),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      },
    );
  }
}

class _TimeSinceText extends StatefulWidget {
  final DateTime timestamp;
  final TextStyle? style;
  final String prefix;

  const _TimeSinceText({
    required this.timestamp,
    this.style,
    this.prefix = 'Updated ',
  });

  @override
  State<_TimeSinceText> createState() => _TimeSinceTextState();
}

class _TimeSinceTextState extends State<_TimeSinceText> {
  Timer? _timer;
  String _timeAgo = '';

  @override
  void initState() {
    super.initState();
    _updateTimeAgo();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateTimeAgo();
      }
    });
  }

  @override
  void didUpdateWidget(_TimeSinceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timestamp != oldWidget.timestamp) {
      _updateTimeAgo();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(widget.timestamp);

    String timeAgo;
    if (difference.inSeconds < 5) {
      timeAgo = 'just now';
    } else if (difference.inSeconds < 60) {
      timeAgo = '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      timeAgo = '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours}h ago';
    } else {
      timeAgo = '${difference.inDays}d ago';
    }

    if (mounted && timeAgo != _timeAgo) {
      setState(() {
        _timeAgo = timeAgo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}$_timeAgo',
      style: widget.style,
    );
  }
}
