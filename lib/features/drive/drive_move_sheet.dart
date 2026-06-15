import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_empty_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';

/// Port of DriveMoveSheet.
Future<void> showDriveMoveSheet(
  BuildContext context, {
  required int fileCount,
  String? currentSectionId,
  required void Function(DriveDestination destination) onMove,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DriveMoveSheet(
      fileCount: fileCount,
      currentSectionId: currentSectionId,
      onMove: onMove,
    ),
  );
}

class DriveMoveSheet extends StatefulWidget {
  const DriveMoveSheet({
    super.key,
    required this.fileCount,
    this.currentSectionId,
    required this.onMove,
  });

  final int fileCount;
  final String? currentSectionId;
  final void Function(DriveDestination destination) onMove;

  @override
  State<DriveMoveSheet> createState() => _DriveMoveSheetState();
}

class _DriveMoveSheetState extends State<DriveMoveSheet> {
  DriveDestination? _selectedDestination;

  bool get _canMove =>
      _selectedDestination != null &&
      _selectedDestination!.sectionId != widget.currentSectionId;

  @override
  void initState() {
    super.initState();
    final destinations = context.read<WorkspaceStore>().availableDestinations;
    _selectedDestination = destinations
            .where((d) => d.sectionId != widget.currentSectionId)
            .firstOrNull ??
        destinations.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final destinations = store.availableDestinations;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: SBPageBackground(
          tone: SBPageTone.warm,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Kapat',
                            style: SBTypography.bodyMedium
                                .copyWith(color: SBColors.blue)),
                      ),
                      Expanded(
                        child: Text(
                          'Taşı',
                          textAlign: TextAlign.center,
                          style: SBTypography.titleMedium
                              .copyWith(color: SBColors.navy),
                        ),
                      ),
                      const SizedBox(width: 64),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(SBSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SBPageHeader(
                          title: 'Hedef seç',
                          subtitle:
                              '${widget.fileCount} dosya taşınacak ders ve bölümü seç.',
                        ),
                        const SizedBox(height: SBSpacing.lg),
                        if (destinations.isEmpty)
                          const SBEmptyState(
                            icon: 'folder.badge.plus',
                            title: 'Taşıma hedefi yok',
                            message:
                                'Dosyaları taşımak için en az bir ders ve bölüm gerekir.',
                          )
                        else
                          Column(
                            children: [
                              for (final destination in destinations) ...[
                                _destinationButton(destination),
                                const SizedBox(height: SBSpacing.sm),
                              ],
                            ],
                          ),
                        const SizedBox(height: SBSpacing.lg),
                        SBButton(
                          'Seçili bölüme taşı',
                          icon: 'folder.badge.gearshape',
                          variant: SBButtonVariant.primary,
                          size: SBButtonSize.large,
                          isDisabled: !_canMove,
                          fullWidth: true,
                          onPressed: () {
                            if (!_canMove) {
                              store.toast('Farklı bir hedef bölüm seç.');
                              return;
                            }
                            widget.onMove(_selectedDestination!);
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destinationButton(DriveDestination destination) {
    final isSelected = _selectedDestination == destination;
    final isCurrent = destination.sectionId == widget.currentSectionId;

    return GestureDetector(
      onTap: () => setState(() => _selectedDestination = destination),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.all(SBSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? SBColors.selectedBlue : SBColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? SBColors.blue.withValues(alpha: 0.24)
                : SBColors.softLine,
          ),
        ),
        child: Row(
          children: [
            SBIcon(
              isSelected ? 'checkmark.circle.fill' : 'folder',
              size: 18,
              color: isSelected ? SBColors.blue : SBColors.muted,
            ),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.courseTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SBTypography.labelMedium
                        .copyWith(color: SBColors.navy),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isCurrent
                        ? '${destination.sectionTitle} • mevcut'
                        : destination.sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SBTypography.caption.copyWith(
                        color:
                            isCurrent ? SBColors.orange : SBColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
