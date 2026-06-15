import 'package:flutter/material.dart';

import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';

/// Port of BaseForceFactoryStyle: shared layout metrics for the factories.
class BaseForceFactoryStyle {
  BaseForceFactoryStyle._();

  static const double screenSpacing = SBSpacing.lg;
  static const double pagePadding = SBSpacing.lg;
  static const double panelSpacing = SBSpacing.md;
  static const double settingsSpacing = SBSpacing.lg;
  static const double controlSpacing = SBSpacing.sm;
  static const double panelRadius = 16;
  static const double nestedPanelRadius = 14;
  static const double controlRadius = 10;
  static const double chipRadius = 8;
  static const double iconTileSize = 42;
  static const double iconTileRadius = 12;

  static Widget panel({
    double spacing = panelSpacing,
    required List<Widget> children,
  }) {
    return SBCard(
      radius: panelRadius,
      child: _spacedColumn(spacing, children),
    );
  }

  static Widget nestedPanel({
    Color? borderColor,
    double spacing = panelSpacing,
    required List<Widget> children,
  }) {
    return SBCard(
      radius: nestedPanelRadius,
      borderColor: borderColor ?? SBColors.softLine,
      child: _spacedColumn(spacing, children),
    );
  }

  static Widget sourceRequiredPanel({required List<Widget> children}) {
    return nestedPanel(
      borderColor: SBColors.blue.withValues(alpha: 0.2),
      children: children,
    );
  }

  static Widget _spacedColumn(double spacing, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}

/// Shared quality tier used by every generation surface. Port of SBQualityTier.
enum SBQualityTier {
  economy('Ekonomik'),
  standard('Standart'),
  premium('Premium');

  const SBQualityTier(this.label);

  final String label;

  String get tier => name;

  String get icon => switch (this) {
        SBQualityTier.economy => 'leaf',
        SBQualityTier.standard => 'checkmark.seal',
        SBQualityTier.premium => 'crown',
      };

  String get subtitle => switch (this) {
        SBQualityTier.economy => 'En düşük MC • hızlı',
        SBQualityTier.standard => 'Dengeli MC • kaliteli',
        SBQualityTier.premium => 'En yüksek MC • en iyi',
      };
}

/// Port of SBQualityPicker.
class SBQualityPicker extends StatelessWidget {
  const SBQualityPicker({
    super.key,
    required this.selection,
    required this.onChanged,
    this.accent,
  });

  final SBQualityTier selection;
  final ValueChanged<SBQualityTier> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? SBColors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kalite',
            style: SBTypography.labelSmall.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                (constraints.maxWidth / (120 + SBSpacing.sm)).floor().clamp(1, 3);
            final width = (constraints.maxWidth -
                    SBSpacing.sm * (columns - 1)) /
                columns;
            return Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                for (final tier in SBQualityTier.values)
                  SizedBox(
                    width: width,
                    child: _tierButton(tier, accentColor),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tierButton(SBQualityTier tier, Color accentColor) {
    final isSelected = selection == tier;
    return GestureDetector(
      onTap: () => onChanged(tier),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SBSpacing.md, horizontal: SBSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : SBColors.white,
          borderRadius:
              BorderRadius.circular(BaseForceFactoryStyle.controlRadius),
          border: Border.all(
              color: isSelected ? accentColor : SBColors.softLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SBIcon(tier.icon,
                    size: 13,
                    color: isSelected ? Colors.white : SBColors.navy),
                const SizedBox(width: 6),
                Text(tier.label,
                    style: SBTypography.caption.copyWith(
                        color: isSelected ? Colors.white : SBColors.navy)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tier.subtitle,
              style: SBTypography.labelSmall.copyWith(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : SBColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
