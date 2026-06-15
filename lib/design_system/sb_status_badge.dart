import 'package:flutter/material.dart';

import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_typography.dart';

enum SBStatus {
  ready,
  processing,
  uploading,
  failed,
  draft;

  String get label => switch (this) {
        SBStatus.ready => 'Hazır',
        SBStatus.processing => 'İşleniyor',
        SBStatus.uploading => 'Yükleniyor',
        SBStatus.failed => 'Tamamlanamadı',
        SBStatus.draft => 'Beklemede',
      };

  Color get color => switch (this) {
        SBStatus.ready => SBColors.green,
        SBStatus.processing || SBStatus.uploading => SBColors.blue,
        SBStatus.failed => SBColors.red,
        SBStatus.draft => SBColors.warning,
      };

  Color get backgroundColor => switch (this) {
        SBStatus.ready => SBColors.greenBg,
        SBStatus.processing || SBStatus.uploading => SBColors.selectedBlue,
        SBStatus.failed => SBColors.redBg,
        SBStatus.draft => SBColors.warningBg,
      };

  String get iconName => switch (this) {
        SBStatus.ready => 'checkmark.circle.fill',
        SBStatus.processing => 'hourglass',
        SBStatus.uploading => 'icloud.and.arrow.up',
        SBStatus.failed => 'exclamationmark.triangle.fill',
        SBStatus.draft => 'doc.fill',
      };
}

/// Port of SBStatusBadge.
class SBStatusBadge extends StatelessWidget {
  const SBStatusBadge({super.key, required this.status, this.compact = false});

  final SBStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spinning =
        status == SBStatus.processing || status == SBStatus.uploading;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            status.color.withValues(alpha: 0.18),
            status.color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinning)
            SizedBox(
              width: compact ? 11 : 14,
              height: compact ? 11 : 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation(status.color),
              ),
            )
          else
            SBIcon(status.iconName,
                size: compact ? 12 : 14, color: status.color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            status.label,
            style: SBTypography.scaled(compact ? 11 : 13,
                    weight: FontWeight.bold)
                .copyWith(color: status.color),
          ),
        ],
      ),
    );
  }
}
