import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sb_colors.dart';

/// Centralised motion language for SourceBase — durations and curves
/// approximating the spring timings of the iOS app.
class SBMotion {
  SBMotion._();

  static const Duration springDuration = Duration(milliseconds: 380);
  static const Duration softSpringDuration = Duration(milliseconds: 550);
  static const Duration pressSpringDuration = Duration(milliseconds: 280);
  static const Duration easeDuration = Duration(milliseconds: 250);
  static const Duration completionPulseDuration = Duration(milliseconds: 600);
  static const Duration breatheDuration = Duration(milliseconds: 2000);

  static const Curve spring = Curves.easeOutBack;
  static const Curve softSpring = Curves.easeOutCubic;
  static const Curve pressSpring = Curves.easeOut;
  static const Curve ease = Curves.easeInOut;

  /// Per-item delay used by staggered entrance animations.
  static Duration stagger(int index, {double step = 0.06, int cap = 8}) =>
      Duration(
          milliseconds:
              ((index < cap ? index : cap) * step * 1000).round());
}

/// Haptic feedback helper mirroring SBHaptics.
class SBHaptics {
  SBHaptics._();

  static void tap() => HapticFeedback.lightImpact();
  static void success() => HapticFeedback.mediumImpact();
  static void selection() => HapticFeedback.selectionClick();
}

/// Fades and lifts a child in on first build, staggered by [index] so a
/// column of cards cascades into place. Port of `.sbEntrance(_:)`.
class SBEntrance extends StatefulWidget {
  const SBEntrance({super.key, this.index = 0, required this.child});

  final int index;
  final Widget child;

  @override
  State<SBEntrance> createState() => _SBEntranceState();
}

class _SBEntranceState extends State<SBEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: SBMotion.softSpringDuration);
  late final CurvedAnimation _anim =
      CurvedAnimation(parent: _controller, curve: SBMotion.softSpring);

  @override
  void initState() {
    super.initState();
    Future.delayed(SBMotion.stagger(widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _anim.value)),
          child: Transform.scale(
            scale: 0.985 + 0.015 * _anim.value,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}

/// A tappable wrapper that adds the calm spring press-scale used across the
/// app (port of `SBPressStyle` / `PressableCardStyle`).
class SBPressable extends StatefulWidget {
  const SBPressable({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<SBPressable> createState() => _SBPressableState();
}

class _SBPressableState extends State<SBPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: SBMotion.pressSpringDuration,
        curve: SBMotion.pressSpring,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.92 : 1,
          duration: SBMotion.pressSpringDuration,
          child: widget.child,
        ),
      ),
    ),
    );
  }
}

/// Subtle breathing emphasis for quick-continue surfaces.
class SBBreathing extends StatefulWidget {
  const SBBreathing({super.key, required this.child});

  final Widget child;

  @override
  State<SBBreathing> createState() => _SBBreathingState();
}

class _SBBreathingState extends State<SBBreathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: SBMotion.breatheDuration)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1 + 0.008 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SBRadiusForGlow.radius),
              boxShadow: [
                BoxShadow(
                  color: SBColors.blue.withValues(alpha: 0.03 + 0.05 * t),
                  blurRadius: 8 + 4 * t,
                  offset: Offset(0, 4 + 2 * t),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class SBRadiusForGlow {
  static const double radius = 18;
}
