import 'package:flutter/material.dart';
import '../core/themes.dart';

/// Subtle press-down scale — value and duration from AppTheme/AppDurations tokens.
class PressScaleDetector extends StatefulWidget {
  const PressScaleDetector({super.key, required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<PressScaleDetector> createState() => _PressScaleDetectorState();
}

class _PressScaleDetectorState extends State<PressScaleDetector> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? AppTheme.pressScale : 1.0,
        duration: AppDurations.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
