import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sb_colors.dart';

/// Tab-level tonal bias for subtle subconscious differentiation. Each tone
/// seeds the drifting aurora with a slightly different vivid palette.
enum SBPageTone {
  neutral,
  warm, // Drive — warmer, amber/coral led
  cool, // BaseForce — cooler, cyan/violet led
  study; // Study — balanced violet/teal

  List<Color> get auroraPalette {
    switch (this) {
      case SBPageTone.neutral:
        return [SBColors.blue, SBColors.cyan, SBColors.violet, SBColors.amber];
      case SBPageTone.warm:
        return [SBColors.amber, SBColors.coral, SBColors.magenta, SBColors.blue];
      case SBPageTone.cool:
        return [SBColors.cyan, SBColors.blue, SBColors.violet, SBColors.teal];
      case SBPageTone.study:
        return [SBColors.violet, SBColors.blue, SBColors.magenta, SBColors.teal];
    }
  }
}

/// Living, breathing page background for dense study workflows. A handful of
/// vivid light-blobs drift slowly behind the content giving every screen an
/// "aurora" depth without distracting from the work. Port + amplification of
/// SBAmbientBackground.
class SBAmbientBackground extends StatefulWidget {
  const SBAmbientBackground({super.key, this.tone = SBPageTone.neutral});

  final SBPageTone tone;

  @override
  State<SBAmbientBackground> createState() => _SBAmbientBackgroundState();
}

class _SBAmbientBackgroundState extends State<SBAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base vertical wash for depth.
        DecoratedBox(
            decoration: BoxDecoration(gradient: SBColors.pageGradient)),
        // Drifting aurora blobs.
        RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  t: _controller.value,
                  palette: widget.tone.auroraPalette,
                  dark: SBColors.isDark,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        // Soft light fall from the top keeps headers crisp and readable.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                SBColors.white.withValues(alpha: SBColors.isDark ? 0.28 : 0.42),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _Blob {
  const _Blob(this.colorIndex, this.baseX, this.baseY, this.ampX, this.ampY,
      this.speedX, this.speedY, this.radius, this.phase);

  final int colorIndex;
  final double baseX;
  final double baseY;
  final double ampX;
  final double ampY;
  final double speedX;
  final double speedY;
  final double radius; // fraction of longest side
  final double phase;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t, required this.palette, required this.dark});

  final double t;
  final List<Color> palette;
  final bool dark;

  static const List<_Blob> _blobs = [
    _Blob(0, 0.18, 0.16, 0.10, 0.08, 1.0, 0.8, 0.62, 0.0),
    _Blob(1, 0.82, 0.24, 0.12, 0.10, 0.8, 1.1, 0.55, 1.1),
    _Blob(2, 0.30, 0.78, 0.14, 0.09, 1.2, 0.7, 0.66, 2.2),
    _Blob(3, 0.78, 0.82, 0.10, 0.12, 0.7, 1.0, 0.50, 3.3),
    _Blob(0, 0.52, 0.46, 0.16, 0.12, 0.9, 0.9, 0.46, 4.4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final twoPi = 2 * math.pi;
    final maxSide = size.longestSide;
    final blobAlpha = dark ? 0.28 : 0.22;

    for (final b in _blobs) {
      final color = palette[b.colorIndex % palette.length];
      final cx =
          size.width * (b.baseX + b.ampX * math.sin(twoPi * t * b.speedX + b.phase));
      final cy = size.height *
          (b.baseY + b.ampY * math.cos(twoPi * t * b.speedY + b.phase * 1.3));
      final radius = maxSide * b.radius;
      final center = Offset(cx, cy);
      // Gentle breathing on the radius.
      final breathe = 1 + 0.06 * math.sin(twoPi * t * 0.5 + b.phase);
      final r = radius * breathe;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: blobAlpha),
            color.withValues(alpha: blobAlpha * 0.4),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      if (dark) paint.blendMode = BlendMode.screen;
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.dark != dark || old.palette != palette;
}

/// Wraps page content with the ambient SourceBase background.
/// Port of `.sbPageBackground(tone:)`.
class SBPageBackground extends StatelessWidget {
  const SBPageBackground(
      {super.key, this.tone = SBPageTone.neutral, required this.child});

  final SBPageTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SBAmbientBackground(tone: tone),
        child,
      ],
    );
  }
}
