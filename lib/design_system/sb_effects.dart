import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_typography.dart';

/// A dimensional icon container: gradient fill, hairline highlight and a soft
/// tinted glow. Port of SBIconTile.
class SBIconTile extends StatelessWidget {
  const SBIconTile({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 48,
    this.radius = 14,
  });

  final String icon;
  final Color tint;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: SBColors.tileGradient(tint),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: tint.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.center,
        ),
      ),
      alignment: Alignment.center,
      child: SBIcon(icon, size: size * 0.42, color: tint),
    );
  }
}

/// A premium circular progress indicator with a gradient stroke, a soft
/// pulsing glow and the percentage in the centre. Port of SBProgressRing.
class SBProgressRing extends StatefulWidget {
  const SBProgressRing({
    super.key,
    required this.progress,
    required this.tint,
    this.lineWidth = 12,
    this.diameter = 132,
  });

  final double progress;
  final Color tint;
  final double lineWidth;
  final double diameter;

  @override
  State<SBProgressRing> createState() => _SBProgressRingState();
}

class _SBProgressRingState extends State<SBProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_glow.value);
              return Transform.scale(
                scale: 0.92 + 0.13 * t,
                child: Container(
                  width: d * 0.7,
                  height: d * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.tint.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.tint.withValues(alpha: 0.12),
                        blurRadius: 24,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          CustomPaint(
            size: Size(d, d),
            painter: _RingPainter(
              progress: widget.progress,
              tint: widget.tint,
              lineWidth: widget.lineWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(widget.progress * 100).round()}',
                style: SBTypography.scaled(d * 0.26, weight: FontWeight.bold)
                    .copyWith(color: SBColors.navy),
              ),
              Text('%',
                  style: SBTypography.labelSmall
                      .copyWith(color: SBColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.progress, required this.tint, required this.lineWidth});

  final double progress;
  final Color tint;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - lineWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..color = tint.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius, track);

    final sweep = 2 * math.pi * progress.clamp(0.001, 1.0);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          tint.withValues(alpha: 0.5),
          tint,
          SBColors.lift(tint, 0.2),
          SBColors.cyan,
          SBColors.violet,
          tint,
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.tint != tint;
}

/// A celebratory burst — expanding tinted rings behind a popping gradient
/// badge with a check mark. Plays once on mount; drop it on completion /
/// success surfaces (generation done, saved, etc.).
class SBSuccessBurst extends StatefulWidget {
  const SBSuccessBurst({
    super.key,
    this.icon = 'checkmark',
    this.tint,
    this.size = 96,
    this.repeat = false,
  });

  final String icon;
  final Color? tint;
  final double size;
  final bool repeat;

  @override
  State<SBSuccessBurst> createState() => _SBSuccessBurstState();
}

class _SBSuccessBurstState extends State<SBSuccessBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.repeat) {
      _c.repeat();
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? SBColors.green;
    final d = widget.size;
    return SizedBox(
      width: d,
      height: d,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final pop = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var ring = 0; ring < 3; ring++) _ring(ring, tint, d),
              Transform.scale(
                scale: 0.4 + 0.6 * pop,
                child: Container(
                  width: d * 0.52,
                  height: d * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SBColors.deepGradient(tint),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.45),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: SBIcon(widget.icon,
                      size: d * 0.26, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int ring, Color tint, double d) {
    final t = ((_c.value + ring * 0.22) % 1.0);
    final eased = Curves.easeOut.transform(t);
    return Opacity(
      opacity: (1 - eased) * 0.6,
      child: Container(
        width: d * (0.5 + eased * 0.8),
        height: d * (0.5 + eased * 0.8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: tint.withValues(alpha: 0.5), width: 2 * (1 - eased) + 0.5),
        ),
      ),
    );
  }
}
