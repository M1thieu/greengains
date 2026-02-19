import 'package:flutter/material.dart';
import '../core/services/time_ago_service.dart';
import '../core/themes.dart';

/// Prominent banner showing current tracking status
/// Displays at top of home screen - user always knows if tracking is active
///
/// Usage:
/// ```dart
/// TrackingStatusBanner(
///   isTracking: _locationService.isRunning.value,
///   lastUpload: DateTime.now(),
/// )
/// ```
class TrackingStatusBanner extends StatelessWidget {
  final bool isTracking;
  final bool isPaused;
  final DateTime? lastUpload;
  final String? errorMessage;

  const TrackingStatusBanner({
    super.key,
    required this.isTracking,
    this.isPaused = false,
    this.lastUpload,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Error state takes priority
    if (errorMessage != null) {
      return _buildBanner(
        context: context,
        theme: theme,
        isDark: isDark,
        icon: Icons.cloud_off,
        iconColor: AppColors.error,
        backgroundColor: AppColors.error.withValues(alpha: 0.08),
        borderColor: AppColors.error.withValues(alpha: 0.35),
        title: 'Couldn\'t upload data',
        subtitle: 'Check your connection and try again',
        showAccent: false,
      );
    }

    // Active tracking state
    if (isTracking && !isPaused) {
      return _buildBanner(
        context: context,
        theme: theme,
        isDark: isDark,
        icon: Icons.sensors,
        iconColor: AppColors.success,
        backgroundColor: AppColors.primaryAlpha(0.08),
        borderColor: AppColors.primary.withValues(alpha: 0.2),
        title: 'Tracking Active',
        subtitle: lastUpload != null
            ? 'Contributing data in the background'
            : 'Collecting sensor data...',
        showPulse: true,
        showAccent: true,
      );
    }

    // Paused state
    if (isPaused) {
      final pausedSubtitle = lastUpload != null
          ? 'Last contribution ${TimeAgoService.format(lastUpload!)}'
          : 'No recent contributions';
      return _buildBanner(
        context: context,
        theme: theme,
        isDark: isDark,
        icon: Icons.pause_circle_outline,
        iconColor: AppColors.textSecondary(isDark),
        backgroundColor: AppColors.surfaceElevated(isDark),
        borderColor: AppColors.border(isDark),
        title: 'Tracking Paused',
        subtitle: pausedSubtitle,
        showAccent: false,
      );
    }

    // Stopped state
    return _buildBanner(
      context: context,
      theme: theme,
      isDark: isDark,
      icon: Icons.pause_circle_outline,
      iconColor: AppColors.textSecondary(isDark),
      backgroundColor: AppColors.surfaceElevated(isDark),
      borderColor: AppColors.border(isDark),
      title: 'Tracking Off',
      subtitle: 'Tap Start to begin contributing',
      showAccent: false,
    );
  }

  Widget _buildBanner({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    bool showPulse = false,
    bool showAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        gradient: showAccent ? AppGradients.surfaceGlow(isDark) : null,
        color: showAccent ? null : backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: borderColor, width: showAccent ? 1 : 1.2),
        boxShadow: isDark
            ? AppColors.elevationDark(active: showAccent)
            : AppColors.elevationLight(active: showAccent),
      ),
      child: Row(
        children: [
          // Icon with optional pulse animation
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceXs),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: showPulse
                ? _PulsingIcon(icon: icon, color: iconColor)
                : Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppFontWeights.bold,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing icon animation for active tracking state
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({
    required this.icon,
    required this.color,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 28,
          ),
        );
      },
    );
  }
}
