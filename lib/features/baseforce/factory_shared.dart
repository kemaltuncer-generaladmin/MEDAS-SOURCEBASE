import 'package:flutter/material.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_effects.dart';
import '../../design_system/sb_file_card.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';
import 'baseforce_style.dart';

/// Shared building blocks used by every BaseForce factory screen.
class FactoryShared {
  FactoryShared._();

  /// Port of the factories' `sourcesPanel`.
  static Widget sourcesPanel({
    required WorkspaceStore store,
    required String prompt,
    required Set<String> selectedSources,
    required VoidCallback onOpenSourcePicker,
    Color tint = const Color(0xFF0A5BFF),
  }) {
    return BaseForceFactoryStyle.panel(children: [
      Row(
        children: [
          SBIconTile(
            icon: 'doc.text',
            tint: tint,
            size: BaseForceFactoryStyle.iconTileSize,
            radius: BaseForceFactoryStyle.iconTileRadius,
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Text(prompt,
                style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
          ),
        ],
      ),
      if (selectedSources.isEmpty)
        sourceRequiredCard(tint: tint)
      else
        for (final sourceId in selectedSources)
          if (store.file(sourceId) != null)
            selectedSourceCard(
                file: store.file(sourceId)!, onChange: onOpenSourcePicker),
      addSourceButton(
        isEmpty: selectedSources.isEmpty,
        onTap: onOpenSourcePicker,
        tint: tint,
      ),
    ]);
  }

  static Widget sourceRequiredCard({Color tint = const Color(0xFF0A5BFF)}) {
    return BaseForceFactoryStyle.sourceRequiredPanel(children: [
      Row(
        children: [
          SBIconTile(
            icon: 'doc.text.magnifyingglass',
            tint: tint,
            size: BaseForceFactoryStyle.iconTileSize,
            radius: BaseForceFactoryStyle.iconTileRadius,
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Text('Hazır bir kaynak seç',
                style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
          ),
        ],
      ),
      Text('Üretime seçili kaynakla hemen geç.',
          style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
      Wrap(
        spacing: SBSpacing.xs,
        runSpacing: SBSpacing.xs,
        children: [
          tagChip(label: 'Hazır kaynak', color: tint),
          tagChip(label: 'PDF / PPT(X) / DOC(X)', color: SBColors.purple),
        ],
      ),
    ]);
  }

  static Widget selectedSourceCard(
      {required DriveFile file, required VoidCallback onChange}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: BaseForceFactoryStyle.nestedPanel(children: [
        Row(
          children: [
            SBFileKindBadge(kind: sbFileKindFrom(file.kind), compact: true),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        SBTypography.labelSmall.copyWith(color: SBColors.navy),
                  ),
                  const SizedBox(height: SBSpacing.xs),
                  Text(
                    '${file.courseTitle} • ${file.sectionTitle} • ${file.sizeLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        SBTypography.caption.copyWith(color: SBColors.muted),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onChange,
              child:
                  SBIcon('xmark.circle.fill', size: 18, color: SBColors.muted),
            ),
          ],
        ),
      ]),
    );
  }

  static Widget addSourceButton({
    required bool isEmpty,
    required VoidCallback onTap,
    Color tint = const Color(0xFF0A5BFF),
  }) {
    return SBCommandCard(
      tint: tint,
      onTap: onTap,
      child: Row(
        children: [
          SBIconTile(icon: 'plus', tint: tint, size: 44, radius: 13),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmpty ? 'Hazır kaynak seç' : 'Kaynağı değiştir',
                  style: SBTypography.labelMedium.copyWith(color: tint),
                ),
                const SizedBox(height: SBSpacing.xs),
                Text(
                  isEmpty
                      ? "Drive'dan hazır kaynak seç."
                      : 'Başka bir Drive kaynağı seç.',
                  style: SBTypography.caption.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Settings panel header with the sliders icon.
  static Widget settingsHeader({Color tint = const Color(0xFF0A5BFF)}) {
    return Row(
      children: [
        SBIconTile(
          icon: 'slider.horizontal.3',
          tint: tint,
          size: BaseForceFactoryStyle.iconTileSize,
          radius: BaseForceFactoryStyle.iconTileRadius,
        ),
        const SizedBox(width: SBSpacing.md),
        Text('Ayarlar',
            style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
      ],
    );
  }

  static Widget settingLabel(String text) => Text(text,
      style: SBTypography.labelSmall.copyWith(color: SBColors.navy));

  /// Icon + label segmented button used by the style pickers.
  static Widget segmentButton({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color tint = const Color(0xFF0A5BFF),
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: SBSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? tint : SBColors.white,
            borderRadius:
                BorderRadius.circular(BaseForceFactoryStyle.controlRadius),
            border:
                Border.all(color: isSelected ? tint : SBColors.softLine),
          ),
          child: Column(
            children: [
              SBIcon(icon,
                  size: 18, color: isSelected ? Colors.white : SBColors.navy),
              const SizedBox(height: SBSpacing.xs),
              Text(
                label,
                style: SBTypography.caption.copyWith(
                    color: isSelected ? Colors.white : SBColors.navy),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Numeric count chip grid.
  static Widget countGrid({
    required List<int> counts,
    required int selected,
    required ValueChanged<int> onChanged,
    Color tint = const Color(0xFF0A5BFF),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / (54 + SBSpacing.sm)).floor().clamp(1, 8);
        final width =
            (constraints.maxWidth - SBSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: SBSpacing.sm,
          runSpacing: SBSpacing.sm,
          children: [
            for (final count in counts)
              GestureDetector(
                onTap: () => onChanged(count),
                child: Container(
                  width: width,
                  padding:
                      const EdgeInsets.symmetric(vertical: SBSpacing.sm),
                  decoration: BoxDecoration(
                    color: selected == count ? tint : SBColors.white,
                    borderRadius: BorderRadius.circular(
                        BaseForceFactoryStyle.controlRadius),
                    border: Border.all(
                        color:
                            selected == count ? tint : SBColors.softLine),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: SBTypography.labelSmall.copyWith(
                        color:
                            selected == count ? Colors.white : SBColors.navy),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Outline chip that fills with [color] when selected.
  static Widget coloredChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: SBSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius:
                BorderRadius.circular(BaseForceFactoryStyle.chipRadius),
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: SBTypography.labelSmall
                .copyWith(color: isSelected ? Colors.white : color),
          ),
        ),
      ),
    );
  }

  static Widget toggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color tint = const Color(0xFF0A5BFF),
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: SBTypography.bodySmall.copyWith(color: SBColors.navy)),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: tint),
      ],
    );
  }

  /// Compact source chip used by the chip-style source sections.
  static Widget sourceChip(DriveFile file) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius:
            BorderRadius.circular(BaseForceFactoryStyle.chipRadius),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SBFileKindBadge(kind: sbFileKindFrom(file.kind), compact: true),
          const SizedBox(width: SBSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  file.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(color: SBColors.navy),
                ),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  '${file.courseTitle} • ${file.sectionTitle} • ${file.sizeLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(color: SBColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Kaynak ekle" chip.
  static Widget addSourceChip(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SBSpacing.md, vertical: SBSpacing.sm),
        decoration: BoxDecoration(
          color: SBColors.white,
          borderRadius:
              BorderRadius.circular(BaseForceFactoryStyle.chipRadius),
          border: Border.all(
              color: SBColors.blue.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SBIcon('plus', size: 14, color: SBColors.blue),
            const SizedBox(width: SBSpacing.xs),
            Text('Kaynak ekle',
                style: SBTypography.caption.copyWith(color: SBColors.blue)),
          ],
        ),
      ),
    );
  }

  /// Full-width stacked segment button (text only).
  static Widget stackedSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color tint = const Color(0xFF0A5BFF),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: SBSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? tint : SBColors.white,
          borderRadius:
              BorderRadius.circular(BaseForceFactoryStyle.controlRadius),
          border: Border.all(color: isSelected ? tint : SBColors.softLine),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: SBTypography.labelSmall
              .copyWith(color: isSelected ? Colors.white : SBColors.navy),
        ),
      ),
    );
  }

  /// Panel header row with small leading icon.
  static Widget panelLabel(String icon, String label,
      {Color tint = const Color(0xFF0A5BFF)}) {
    return Row(
      children: [
        SBIcon(icon, size: 14, color: tint),
        const SizedBox(width: SBSpacing.xs),
        Text(label,
            style: SBTypography.labelSmall.copyWith(color: SBColors.navy)),
      ],
    );
  }

  static Widget tagChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: SBTypography.caption.copyWith(color: color)),
    );
  }
}

/// Convenience: open the source picker targeting [route].
void openFactorySourcePicker(AppRouter router, AppRoute route) {
  router.beginSourceSelection(
      from: AppRoute.baseForce,
      destination: SourcePickerDestination.toRoute(route));
}
