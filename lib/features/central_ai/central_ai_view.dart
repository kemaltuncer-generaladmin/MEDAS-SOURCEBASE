import 'package:flutter/material.dart';

import '../../design_system/sb_background.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';

/// MedasiChat — kaynaklarınla sohbet özelliği yakında. Bu ekran şimdilik
/// aktif değil; canlı, animasyonlu bir "Çok Yakında" karşılaması gösterir.
class CentralAIView extends StatefulWidget {
  const CentralAIView({super.key});

  @override
  State<CentralAIView> createState() => _CentralAIViewState();
}

class _CentralAIViewState extends State<CentralAIView>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  late final AnimationController _halo = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  bool _appear = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _appear = true);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _halo.dispose();
    super.dispose();
  }

  static const _features = [
    ('text.bubble.fill', 'Kaynaklarınla sohbet', 'Notlarına dayalı, hızlı yanıtlar'),
    ('sparkles', 'Anında açıklama', 'Karışan konuları sohbetle netleştir'),
    ('bolt.fill', 'Tek dokunuş üretim', 'Sohbetten direkt çalışma materyaline'),
  ];

  @override
  Widget build(BuildContext context) {
    return SBPageBackground(
      tone: SBPageTone.warm,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SBSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _brandMark(),
                  const SizedBox(height: SBSpacing.xl),
                  _animatedIn(
                    delayMs: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: SBColors.vividGradient(SBColors.magenta),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: SBColors.magenta.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SBIcon('sparkles',
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('ÇOK YAKINDA',
                              style: SBTypography.labelSmall.copyWith(
                                color: Colors.white,
                                letterSpacing: 1.2,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: SBSpacing.lg),
                  _animatedIn(
                    delayMs: 80,
                    child: Text(
                      'MedasiChat',
                      textAlign: TextAlign.center,
                      style: SBTypography.scaled(36, weight: FontWeight.bold)
                          .copyWith(color: SBColors.navy),
                    ),
                  ),
                  const SizedBox(height: SBSpacing.sm),
                  _animatedIn(
                    delayMs: 140,
                    child: Text(
                      'Kaynaklarınla sohbet ederek çalışman çok yakında burada. '
                      'Şu an son rötuşları yapıyoruz.',
                      textAlign: TextAlign.center,
                      style: SBTypography.bodyMedium
                          .copyWith(color: SBColors.muted, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: SBSpacing.xl),
                  for (var i = 0; i < _features.length; i++)
                    _animatedIn(
                      delayMs: 200 + i * 70,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: SBSpacing.sm),
                        child: _featureRow(_features[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandMark() {
    return SizedBox(
      height: 168,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _halo]),
        builder: (context, _) {
          final p = Curves.easeInOut.transform(_pulse.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var ring = 0; ring < 3; ring++) _haloRing(ring),
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SBColors.violet.withValues(alpha: 0.28),
                      blurRadius: 50,
                      spreadRadius: 6 + 14 * p,
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.97 + 0.06 * p,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: SBColors.brandGradient,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: SBColors.blue.withValues(alpha: 0.42),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const SBIcon('text.bubble.fill',
                      size: 46, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _haloRing(int ring) {
    final t = (_halo.value + ring * 0.26) % 1.0;
    final size = 128.0 + ring * 40;
    final colors = [SBColors.cyan, SBColors.violet, SBColors.magenta];
    return Opacity(
      opacity: (1 - t) * 0.55,
      child: Transform.scale(
        scale: 0.85 + 0.3 * t,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors[ring % colors.length].withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureRow((String, String, String) feature) {
    final tint = [SBColors.cyan, SBColors.violet, SBColors.amber][
        _features.indexOf(feature) % 3];
    return Container(
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SBColors.softLine),
        boxShadow: [
          BoxShadow(
            color: SBColors.navy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: SBColors.tileGradient(tint),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: tint.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: SBIcon(feature.$1, size: 19, color: tint),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.$2,
                    style: SBTypography.titleSmall
                        .copyWith(color: SBColors.navy)),
                const SizedBox(height: 2),
                Text(feature.$3,
                    style: SBTypography.caption
                        .copyWith(color: SBColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedIn({required int delayMs, required Widget child}) {
    return AnimatedSlide(
      offset: _appear ? Offset.zero : const Offset(0, 0.12),
      duration: Duration(milliseconds: 500 + delayMs),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _appear ? 1 : 0,
        duration: Duration(milliseconds: 450 + delayMs),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
