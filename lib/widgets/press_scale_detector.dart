import 'package:flutter/material.dart';
import '../core/themes.dart';

/// Subtle press-down scale. No overshoot: bouncy easing reads as gimmicky.
/// Static when the user asked the system to remove animations.
///
/// Always exposed to TalkBack as a button; icon-only uses pass
/// [semanticLabel] so the button has a spoken name.
class PressScaleDetector extends StatefulWidget {
  const PressScaleDetector({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  State<PressScaleDetector> createState() => _PressScaleDetectorState();
}

class _PressScaleDetectorState extends State<PressScaleDetector> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? AppTheme.pressScale : 1.0,
          duration: AppDurations.press,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
