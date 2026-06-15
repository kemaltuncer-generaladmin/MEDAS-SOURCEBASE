import 'package:flutter/material.dart';

import 'sb_button.dart';
import 'sb_card.dart';
import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_spacing.dart';
import 'sb_typography.dart';

/// Context variants provide branded, context-specific empty states
/// while sharing the same structural DNA.
enum SBEmptyStateContext {
  generic,
  drive,
  baseForce,
  generationWaiting,
  sourceMissing,
  completedSuccess;

  Color get tint => switch (this) {
        SBEmptyStateContext.generic ||
        SBEmptyStateContext.drive =>
          SBColors.blue,
        SBEmptyStateContext.baseForce => SBColors.cyan,
        SBEmptyStateContext.generationWaiting => SBColors.purple,
        SBEmptyStateContext.sourceMissing => SBColors.warning,
        SBEmptyStateContext.completedSuccess => SBColors.green,
      };

  String? get motivationLine => switch (this) {
        SBEmptyStateContext.drive =>
          'Her yüklenen kaynak seni bir adım öne taşır.',
        SBEmptyStateContext.baseForce =>
          'Doğru kaynak, güçlü çalışmanın ilk adımı.',
        SBEmptyStateContext.generationWaiting =>
          'Biraz sabır, kaliteli sonuç geliyor.',
        SBEmptyStateContext.completedSuccess =>
          'Harika iş. Şimdi çalışmaya geçebilirsin.',
        SBEmptyStateContext.sourceMissing =>
          'Uygun bir kaynak seçince devam edebilirsin.',
        SBEmptyStateContext.generic => null,
      };
}

/// Port of SBEmptyState.
class SBEmptyState extends StatelessWidget {
  const SBEmptyState({
    super.key,
    this.icon = 'folder',
    required this.title,
    required this.message,
    this.badges = const [],
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    this.context_ = SBEmptyStateContext.generic,
  });

  final String icon;
  final String title;
  final String message;
  final List<String> badges;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;
  final SBEmptyStateContext context_;

  @override
  Widget build(BuildContext context) {
    final tint = context_.tint;

    return SBCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: SBIcon(icon, size: 26, color: tint),
          ),
          const SizedBox(height: SBSpacing.lg),
          Text(title,
              style: SBTypography.heading2.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.lg),
          Text(
            message,
            style: SBTypography.bodyMedium
                .copyWith(color: SBColors.muted, height: 1.35),
          ),
          if (context_.motivationLine != null) ...[
            const SizedBox(height: SBSpacing.lg),
            Text(
              context_.motivationLine!,
              style: SBTypography.caption.copyWith(
                color: tint.withValues(alpha: 0.82),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: SBSpacing.lg),
            Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                for (final badge in badges)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(badge,
                        style:
                            SBTypography.labelSmall.copyWith(color: tint)),
                  ),
              ],
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SBSpacing.lg),
            Row(
              children: [
                SBButton(
                  actionLabel!,
                  icon: 'arrow.right',
                  variant: SBButtonVariant.primary,
                  size: SBButtonSize.small,
                  onPressed: onAction!,
                ),
                if (secondaryLabel != null && onSecondaryAction != null) ...[
                  const SizedBox(width: SBSpacing.md),
                  SBButton(
                    secondaryLabel!,
                    icon: 'arrow.up.right',
                    variant: SBButtonVariant.secondary,
                    size: SBButtonSize.small,
                    onPressed: onSecondaryAction!,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
