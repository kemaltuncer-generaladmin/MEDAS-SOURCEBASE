import 'package:flutter/material.dart';

import '../design_system/sb_background.dart';
import '../design_system/sb_colors.dart';
import '../design_system/sb_icons.dart';
import '../design_system/sb_spacing.dart';
import '../design_system/sb_typography.dart';

/// Port of WarmLaunchView: pulsing brand mark with expanding halos.
class WarmLaunchView extends StatefulWidget {
  const WarmLaunchView({super.key});

  @override
  State<WarmLaunchView> createState() => _WarmLaunchViewState();
}

class _WarmLaunchViewState extends State<WarmLaunchView>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  late final AnimationController _halo = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();
  bool _appear = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _appear = true);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SBPageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SBSpacing.xl),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  height: 230,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _halo]),
                    builder: (context, _) {
                      final p = Curves.easeInOut.transform(_pulse.value);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          for (var ring = 0; ring < 3; ring++)
                            _haloRing(ring),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      SBColors.blue.withValues(alpha: 0.22),
                                  blurRadius: 60,
                                  spreadRadius: 10 + 18 * p,
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.97 + 0.06 * p,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: SBColors.brandGradient,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: SBColors.white
                                        .withValues(alpha: 0.35)),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        SBColors.blue.withValues(alpha: 0.4),
                                    blurRadius: 28,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const SBIcon('books.vertical.fill',
                                  size: 44, color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: SBSpacing.xl),
                AnimatedOpacity(
                  opacity: _appear ? 1 : 0,
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: _appear ? Offset.zero : const Offset(0, 0.08),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      children: [
                        Text(
                          'SourceBase',
                          style:
                              SBTypography.scaled(40, weight: FontWeight.bold)
                                  .copyWith(color: SBColors.navy),
                        ),
                        const SizedBox(height: SBSpacing.sm),
                        Text(
                          'Kaynaklarını öğrenme sistemine dönüştür.',
                          textAlign: TextAlign.center,
                          style: SBTypography.bodyMedium
                              .copyWith(color: SBColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SBSpacing.xl),
                AnimatedOpacity(
                  opacity: _appear ? 1 : 0,
                  duration: const Duration(milliseconds: 550),
                  child: _loadingDots(),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _appear ? 1 : 0,
                  duration: const Duration(milliseconds: 550),
                  child: Text(
                    'Medasi ekosistemi · premium öğrenme deneyimi',
                    style:
                        SBTypography.caption.copyWith(color: SBColors.softText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _haloRing(int ring) {
    final t = (_halo.value + ring * 0.23) % 1.0;
    final size = 120.0 + ring * 46;
    return Opacity(
      opacity: (1 - t) * 0.7,
      child: Transform.scale(
        scale: 0.9 + 0.22 * t,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: SBColors.blue.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingDots() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              _dot(i),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    final t = Curves.easeInOut
        .transform(((_pulse.value + index * 0.18) % 1.0));
    return Opacity(
      opacity: 0.35 + 0.65 * t,
      child: Transform.scale(
        scale: 0.5 + 0.5 * t,
        child: Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: SBColors.blue, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
