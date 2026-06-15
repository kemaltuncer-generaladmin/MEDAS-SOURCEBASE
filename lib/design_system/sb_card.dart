import 'package:flutter/material.dart';

import 'sb_colors.dart';
import 'sb_motion.dart';
import 'sb_spacing.dart';

/// Port of SBCard: white surface, raised gradient edge and layered shadows so
/// cards read as floating above the page, not painted onto it.
class SBCard extends StatelessWidget {
  const SBCard({
    super.key,
    this.padding = SBSpacing.cardPadding,
    this.radius = 12,
    this.backgroundColor,
    this.borderColor,
    this.showShadow = true,
    required this.child,
  });

  final double padding;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showShadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? SBColors.white;
    final border = borderColor ?? SBColors.softLine;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: SBColors.navy.withValues(alpha: 0.065),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: SBColors.navy.withValues(alpha: 0.035),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: GradientBoxBorder(
          gradient: LinearGradient(
            colors: [SBColors.white.withValues(alpha: 0.82), border],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      padding: EdgeInsets.all(padding),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

/// Port of SBTappableCard with the pressable spring style.
class SBTappableCard extends StatelessWidget {
  const SBTappableCard({
    super.key,
    this.padding = SBSpacing.cardPadding,
    this.radius = 12,
    this.backgroundColor,
    this.borderColor,
    required this.onTap,
    required this.child,
  });

  final double padding;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SBPressable(
      onTap: onTap,
      child: SBCard(
        padding: padding,
        radius: radius,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        child: child,
      ),
    );
  }
}

/// 1px gradient border used by SBCard's raised edge.
class GradientBoxBorder extends BoxBorder {
  const GradientBoxBorder({required this.gradient, this.width = 1});

  final Gradient gradient;
  final double width;

  @override
  BorderSide get top => BorderSide.none;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  bool get isUniform => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(Canvas canvas, Rect rect,
      {TextDirection? textDirection,
      BoxShape shape = BoxShape.rectangle,
      BorderRadius? borderRadius}) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final rrect = (borderRadius ?? BorderRadius.zero)
        .toRRect(rect)
        .deflate(width / 2);
    canvas.drawRRect(rrect, paint);
  }

  @override
  ShapeBorder scale(double t) =>
      GradientBoxBorder(gradient: gradient, width: width * t);
}
