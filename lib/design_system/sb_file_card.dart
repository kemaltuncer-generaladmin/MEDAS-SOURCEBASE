import 'package:flutter/material.dart';

import 'sb_card.dart';
import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_motion.dart';
import 'sb_spacing.dart';
import 'sb_status_badge.dart';
import 'sb_typography.dart';

enum SBFileKind {
  pdf,
  pptx,
  docx,
  ppt,
  doc,
  zip;

  String get label => name.toUpperCase();

  Color get color => switch (this) {
        SBFileKind.pdf => const Color.fromRGBO(255, 48, 48, 1),
        SBFileKind.pptx => SBColors.orange,
        SBFileKind.docx => SBColors.blue,
        SBFileKind.ppt => const Color.fromRGBO(209, 74, 31, 1),
        SBFileKind.doc => const Color.fromRGBO(20, 107, 242, 1),
        SBFileKind.zip => SBColors.purple,
      };
}

/// Port of SBFileKindBadge with the folded-corner triangle.
class SBFileKindBadge extends StatelessWidget {
  const SBFileKindBadge({super.key, required this.kind, this.compact = false});

  final SBFileKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 44.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: kind.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(compact ? 6 : 8),
            ),
            alignment: Alignment.center,
            child: Text(
              kind.label,
              style: SBTypography.scaled(compact ? 9 : 11,
                      weight: FontWeight.bold)
                  .copyWith(color: kind.color),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              size: Size(size * 0.25, size * 0.25),
              painter: _FoldCornerPainter(kind.color.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoldCornerPainter extends CustomPainter {
  _FoldCornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FoldCornerPainter old) => old.color != color;
}

/// Port of SBFileCard.
class SBFileCard extends StatelessWidget {
  const SBFileCard({
    super.key,
    required this.title,
    required this.kind,
    required this.status,
    required this.sizeLabel,
    required this.courseTitle,
    required this.updatedLabel,
    required this.onTap,
    this.actionSlot,
  });

  final String title;
  final SBFileKind kind;
  final SBStatus status;
  final String sizeLabel;
  final String courseTitle;
  final String updatedLabel;
  final VoidCallback onTap;
  final Widget? actionSlot;

  @override
  Widget build(BuildContext context) {
    return SBPressable(
      onTap: onTap,
      child: SBCard(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SBFileKindBadge(kind: kind),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.titleSmall
                            .copyWith(color: SBColors.navy),
                      ),
                      const SizedBox(height: SBSpacing.xs),
                      Wrap(
                        spacing: SBSpacing.sm,
                        runSpacing: SBSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SBStatusBadge(status: status, compact: true),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kind.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              kind.label,
                              style: SBTypography.caption
                                  .copyWith(color: kind.color),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SBSpacing.md),
            Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                _metaPill('folder', courseTitle),
                _metaPill('doc', sizeLabel),
              ],
            ),
            const SizedBox(height: SBSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Güncellendi: $updatedLabel',
                    style: SBTypography.caption
                        .copyWith(color: SBColors.softText),
                  ),
                ),
                actionSlot ?? _openLabel(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill(String icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: SBColors.field.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SBIcon(icon, size: 11, color: SBColors.muted),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.caption.copyWith(color: SBColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SBColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('Detayı aç',
          style: SBTypography.labelSmall.copyWith(color: SBColors.blue)),
    );
  }
}
