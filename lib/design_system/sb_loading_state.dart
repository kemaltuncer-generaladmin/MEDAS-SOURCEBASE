import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_spacing.dart';
import 'sb_typography.dart';

/// Context variants for loading states.
enum SBLoadingContext {
  generic,
  drive,
  baseForce,
  generation;

  Color get tint => switch (this) {
        SBLoadingContext.generic || SBLoadingContext.drive => SBColors.blue,
        SBLoadingContext.baseForce => SBColors.cyan,
        SBLoadingContext.generation => SBColors.purple,
      };

  String? get calmLine => switch (this) {
        SBLoadingContext.drive => 'Kaynakların düzenleniyor...',
        SBLoadingContext.baseForce => 'Üretim araçları hazırlanıyor...',
        SBLoadingContext.generation => 'Kaliteli sonuç biraz zaman alır.',
        SBLoadingContext.generic => null,
      };
}

/// Port of SBLoadingState: header chip plus shimmering skeleton cards.
class SBLoadingState extends StatelessWidget {
  const SBLoadingState({
    super.key,
    this.icon = 'hourglass',
    this.title = 'Yükleniyor',
    this.message = 'Lütfen bekleyin...',
    this.context_ = SBLoadingContext.generic,
  });

  final String icon;
  final String title;
  final String message;
  final SBLoadingContext context_;

  @override
  Widget build(BuildContext context) {
    final tint = context_.tint;

    return Shimmer.fromColors(
      baseColor: SBColors.navy.withValues(alpha: 0.85),
      highlightColor: SBColors.navy.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: SBIcon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: SBTypography.titleMedium
                            .copyWith(color: SBColors.navy)),
                    const SizedBox(height: 5),
                    Text(message,
                        style: SBTypography.caption
                            .copyWith(color: SBColors.muted)),
                    if (context_.calmLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          context_.calmLine!,
                          style: SBTypography.caption.copyWith(
                            color: tint.withValues(alpha: 0.72),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.lg),
          for (var i = 0; i < 3; i++) ...[
            const SBSkeletonCard(),
            if (i < 2) const SizedBox(height: SBSpacing.lg),
          ],
        ],
      ),
    );
  }
}

/// A single loading card used inside skeleton states.
class SBSkeletonCard extends StatelessWidget {
  const SBSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar({double? width, required double height}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: SBColors.field,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(SBSpacing.lg),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SBColors.field,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(height: 13),
                const SizedBox(height: SBSpacing.sm),
                bar(width: 160, height: 11),
                const SizedBox(height: SBSpacing.sm),
                bar(width: 90, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of SBInlineLoading.
class SBInlineLoading extends StatelessWidget {
  const SBInlineLoading({super.key, this.message = 'Yükleniyor...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SBSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(SBColors.blue),
            ),
          ),
          const SizedBox(width: SBSpacing.md),
          Text(message,
              style:
                  SBTypography.bodyMedium.copyWith(color: SBColors.muted)),
        ],
      ),
    );
  }
}
