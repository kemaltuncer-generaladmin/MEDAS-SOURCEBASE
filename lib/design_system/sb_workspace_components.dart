import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'sb_background.dart';
import 'sb_card.dart';
import 'sb_colors.dart';
import 'sb_effects.dart';
import 'sb_file_card.dart';
import 'sb_icons.dart';
import 'sb_motion.dart';
import 'sb_premium_visuals.dart';
import 'sb_spacing.dart';
import 'sb_status_badge.dart';
import 'sb_typography.dart';

SBFileKind sbFileKindFrom(DriveFileKind kind) =>
    SBFileKind.values.byName(kind.name);

SBStatus sbStatusFrom(DriveItemStatus status) => switch (status) {
      DriveItemStatus.completed => SBStatus.ready,
      DriveItemStatus.processing => SBStatus.processing,
      DriveItemStatus.uploading => SBStatus.uploading,
      DriveItemStatus.failed => SBStatus.failed,
      DriveItemStatus.draft => SBStatus.draft,
    };

/// Port of SBWorkspaceShell: scrollable page with ambient background.
class SBWorkspaceShell extends StatelessWidget {
  const SBWorkspaceShell({
    super.key,
    this.spacing = SBSpacing.lg,
    this.showsBottomGuard = true,
    this.tone = SBPageTone.neutral,
    required this.children,
  });

  final double spacing;
  final bool showsBottomGuard;
  final SBPageTone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SBPageBackground(
      tone: tone,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: SBSpacing.lg,
          right: SBSpacing.lg,
          top: SBSpacing.sm,
          bottom: SBSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
            if (showsBottomGuard) const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Port of SBTopBar.
class SBTopBar extends StatelessWidget {
  const SBTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.onSearch,
    this.onNotifications,
  });

  final String title;
  final String? subtitle;
  final String? leadingIcon;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leadingIcon != null) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SBColors.selectedBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: SBIcon(leadingIcon!, size: 19, color: SBColors.blue),
          ),
          const SizedBox(width: SBSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SBTypography.heading1.copyWith(color: SBColors.navy),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      SBTypography.bodySmall.copyWith(color: SBColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: SBSpacing.md),
        if (onSearch != null) _topButton('magnifyingglass', onSearch!),
        if (onNotifications != null) ...[
          const SizedBox(width: SBSpacing.xs),
          _topButton('bell', onNotifications!),
        ],
      ],
    );
  }

  Widget _topButton(String icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: SBColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SBColors.softLine),
        ),
        alignment: Alignment.center,
        child: SBIcon(icon, size: 18, color: SBColors.navy),
      ),
    );
  }
}

/// Port of SBHeroPanel.
class SBHeroPanel extends StatelessWidget {
  const SBHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    this.tint,
    this.actions,
  });

  final String eyebrow;
  final String title;
  final String message;
  final String icon;
  final Color? tint;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    return SBCard(
      padding: SBSpacing.xl,
      radius: 18,
      borderColor: SBColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: t.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: SBIcon(icon, size: 24, color: t),
              ),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow.toUpperCase(),
                        style: SBTypography.labelSmall.copyWith(color: t)),
                    const SizedBox(height: SBSpacing.xs),
                    Text(title,
                        style: SBTypography.heading2
                            .copyWith(color: SBColors.navy)),
                    const SizedBox(height: SBSpacing.xs),
                    Text(message,
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          if (actions != null) ...[
            const SizedBox(height: SBSpacing.lg),
            actions!,
          ],
        ],
      ),
    );
  }
}

/// Port of SBActionTile.
class SBActionTile extends StatelessWidget {
  const SBActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tint,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    return SBPressable(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: SBIcon(icon, size: 20, color: t),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        SBTypography.titleSmall.copyWith(color: SBColors.navy)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      SBTypography.bodySmall.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
          SBIcon('chevron.right', size: 13, color: SBColors.softText),
        ],
      ),
    );
  }
}

/// Port of SBNotice.
class SBNotice extends StatelessWidget {
  const SBNotice({
    super.key,
    this.icon = 'info.circle',
    required this.message,
    this.tint,
  });

  final String icon;
  final String message;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: t.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SBIcon(icon, size: 18, color: t),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Text(message,
                style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          ),
        ],
      ),
    );
  }
}

/// Port of SBSourceRow.
class SBSourceRow extends StatelessWidget {
  const SBSourceRow({
    super.key,
    required this.file,
    this.isSelected = false,
    required this.onTap,
  });

  final DriveFile file;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SBSpacing.md),
        color: SBColors.white,
        child: Row(
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
                        SBTypography.titleSmall.copyWith(color: SBColors.navy),
                  ),
                  const SizedBox(height: SBSpacing.xs),
                  Text(
                    '${file.courseTitle} • ${file.updatedLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SBTypography.caption.copyWith(color: SBColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SBSpacing.sm),
            SBStatusBadge(status: sbStatusFrom(file.status), compact: true),
            if (isSelected) ...[
              const SizedBox(width: SBSpacing.sm),
              Icon(Icons.check_circle, color: SBColors.blue, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// Port of SBGenerationCard.
class SBGenerationCard extends StatelessWidget {
  const SBGenerationCard({
    super.key,
    required this.output,
    required this.sourceTitle,
    required this.onTap,
  });

  final GeneratedOutput output;
  final String sourceTitle;
  final VoidCallback onTap;

  String get _icon => switch (output.kind) {
        GeneratedKind.flashcard => 'rectangle.on.rectangle',
        GeneratedKind.question => 'questionmark.circle',
        GeneratedKind.summary => 'doc.text',
        GeneratedKind.examMorningSummary => 'alarm',
        GeneratedKind.algorithm => 'arrow.triangle.branch',
        GeneratedKind.comparison || GeneratedKind.table => 'tablecells',
        GeneratedKind.clinicalScenario => 'cross.case',
        GeneratedKind.learningPlan => 'calendar.badge.clock',
        GeneratedKind.podcast => 'headphones',
        GeneratedKind.infographic => 'chart.bar',
        GeneratedKind.mindMap => 'point.3.connected.trianglepath.dotted',
      };

  Color get _color => switch (output.kind) {
        GeneratedKind.flashcard => SBColors.blue,
        GeneratedKind.question || GeneratedKind.infographic => SBColors.cyan,
        GeneratedKind.summary ||
        GeneratedKind.examMorningSummary ||
        GeneratedKind.mindMap ||
        GeneratedKind.comparison ||
        GeneratedKind.table =>
          SBColors.purple,
        GeneratedKind.algorithm ||
        GeneratedKind.podcast ||
        GeneratedKind.clinicalScenario =>
          SBColors.orange,
        GeneratedKind.learningPlan => SBColors.green,
      };

  @override
  Widget build(BuildContext context) {
    return SBTappableCard(
      radius: 16,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: SBIcon(_icon, size: 17, color: _color),
              ),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      output.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sourceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          SBTypography.caption.copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SBSpacing.sm),
              const SBStatusBadge(status: SBStatus.ready, compact: true),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Text(
            output.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.bodySmall.copyWith(color: SBColors.navy),
          ),
        ],
      ),
    );
  }
}

/// Port of SBQuickContinueSurface.
class SBQuickContinueSurface extends StatelessWidget {
  const SBQuickContinueSurface({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.metadata,
    required this.actionLabel,
    required this.icon,
    this.tint,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String message;
  final String metadata;
  final String actionLabel;
  final String icon;
  final Color? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    return SBBreathing(
      child: SBCommandCard(
        tint: t,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SBIconTile(icon: icon, tint: t, size: 46, radius: 14),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow.toUpperCase(),
                          style: SBTypography.labelSmall.copyWith(color: t)),
                      const SizedBox(height: SBSpacing.xs),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.titleSmall
                            .copyWith(color: SBColors.navy),
                      ),
                      const SizedBox(height: SBSpacing.xs),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.bodySmall
                            .copyWith(color: SBColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SBSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SBTypography.caption.copyWith(color: SBColors.muted),
                  ),
                ),
                const SizedBox(width: SBSpacing.sm),
                Text(actionLabel,
                    style: SBTypography.labelSmall.copyWith(color: t)),
                const SizedBox(width: 4),
                SBIcon('arrow.right', size: 12, color: t),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Port of SBWorkspaceMomentumRibbon.
class SBWorkspaceMomentumRibbon extends StatelessWidget {
  const SBWorkspaceMomentumRibbon({
    super.key,
    required this.readyCount,
    required this.outputCount,
    required this.focusTitle,
  });

  final int readyCount;
  final int outputCount;
  final String focusTitle;

  @override
  Widget build(BuildContext context) {
    return SBCard(
      padding: SBSpacing.md,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Bugünkü momentum',
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.md),
          SBMetricRibbon(items: [
            SBMetricRibbonItem(
                icon: 'checkmark.seal',
                value: '$readyCount',
                label: 'hazır kaynak',
                tint: SBColors.green),
            SBMetricRibbonItem(
                icon: 'sparkles.rectangle.stack',
                value: '$outputCount',
                label: 'çalışma',
                tint: SBColors.purple),
            SBMetricRibbonItem(
                icon: 'stethoscope',
                value: focusTitle,
                label: 'odak konu',
                tint: SBColors.cyan),
          ]),
        ],
      ),
    );
  }
}

/// Port of SBBottomCTA: frosted bar pinned above the bottom edge.
class SBBottomCTA extends StatelessWidget {
  const SBBottomCTA({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(SBSpacing.md),
          decoration: BoxDecoration(
            color: SBColors.white.withValues(alpha: 0.72),
            border: Border(top: BorderSide(color: SBColors.softLine)),
          ),
          child: child,
        ),
      ),
    );
  }
}
