import 'package:flutter/material.dart';

import 'sb_card.dart';
import 'sb_colors.dart';
import 'sb_effects.dart';
import 'sb_icons.dart';
import 'sb_motion.dart';
import 'sb_spacing.dart';
import 'sb_typography.dart';

enum SBHeroMode { action, progress, selection }

/// Hero size controls padding and icon scale.
enum SBHeroSize { full, compact }

/// Port of SBPageHeader: large title + subtitle with round icon buttons.
class SBPageHeader extends StatelessWidget {
  const SBPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.primaryIcon,
    this.secondaryIcon,
    this.onPrimary,
    this.onSecondary,
  });

  final String title;
  final String subtitle;
  final String? primaryIcon;
  final String? secondaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SBTypography.heading1.copyWith(color: SBColors.navy),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SBTypography.bodyMedium.copyWith(color: SBColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: SBSpacing.md),
        if (primaryIcon != null && onPrimary != null)
          _RoundIconButton(icon: primaryIcon!, onTap: onPrimary!),
        if (secondaryIcon != null && onSecondary != null) ...[
          const SizedBox(width: SBSpacing.xs),
          _RoundIconButton(icon: secondaryIcon!, onTap: onSecondary!),
        ],
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SBPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: SBColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SBColors.softLine),
          boxShadow: [
            BoxShadow(
              color: SBColors.navy.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: SBIcon(icon, size: 18, color: SBColors.navy),
      ),
    );
  }
}

/// Port of SBGradientHero.
class SBGradientHero extends StatelessWidget {
  const SBGradientHero({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tint,
    this.size = SBHeroSize.full,
    this.actions,
    this.footer,
  });

  final String icon;
  final String title;
  final String message;
  final Color? tint;
  final SBHeroSize size;
  final Widget? actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    final compact = size == SBHeroSize.compact;
    final iconSize = compact ? 42.0 : 54.0;
    final radius = compact ? 20.0 : 26.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? SBSpacing.lg : SBSpacing.xl),
      decoration: BoxDecoration(
        gradient: SBColors.heroWash(t),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SBColors.softLine),
        boxShadow: [
          BoxShadow(
            color: t.withValues(alpha: 0.10),
            blurRadius: compact ? 14 : 24,
            offset: Offset(0, compact ? 8 : 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: t.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(compact ? 12 : 16),
                ),
                alignment: Alignment.center,
                child: SBIcon(icon, size: compact ? 18 : 24, color: t),
              ),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (compact
                              ? SBTypography.heading3
                              : SBTypography.heading2)
                          .copyWith(color: SBColors.navy),
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Text(
                      message,
                      style: (compact
                              ? SBTypography.bodySmall
                              : SBTypography.bodyMedium)
                          .copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions != null) ...[
            SizedBox(height: compact ? SBSpacing.md : SBSpacing.lg),
            actions!,
          ],
          if (footer != null) ...[
            SizedBox(height: compact ? SBSpacing.md : SBSpacing.lg),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Port of SBSignatureHero with the diagonal hatch background.
class SBSignatureHero extends StatelessWidget {
  const SBSignatureHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    this.tint,
    this.mode = SBHeroMode.progress,
    this.size = SBHeroSize.full,
    this.actions,
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String message;
  final String icon;
  final Color? tint;
  final SBHeroMode mode;
  final SBHeroSize size;
  final Widget? actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    final compact = size == SBHeroSize.compact;
    final cornerRadius = compact ? 18.0 : 24.0;

    final backgroundGradient = switch (mode) {
      SBHeroMode.action => LinearGradient(
          colors: [
            t.withValues(alpha: 0.08),
            SBColors.white,
            SBColors.field.withValues(alpha: 0.52),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      SBHeroMode.progress => LinearGradient(
          colors: [
            t.withValues(alpha: 0.12),
            SBColors.white,
            SBColors.field.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      SBHeroMode.selection => LinearGradient(
          colors: [
            t.withValues(alpha: 0.06),
            SBColors.field.withValues(alpha: 0.92),
            SBColors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        boxShadow: [
          BoxShadow(
            color: t.withValues(alpha: 0.14),
            blurRadius: compact ? 16 : 28,
            offset: Offset(0, compact ? 8 : 16),
          ),
          BoxShadow(
            color: SBColors.navy.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(gradient: backgroundGradient)),
            ),
            if (mode != SBHeroMode.action)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DiagonalHatchPainter(
                    color: t.withValues(
                        alpha: mode == SBHeroMode.progress ? 0.055 : 0.035),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SBColors.white.withValues(alpha: 0.72),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? SBSpacing.lg : SBSpacing.xl),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cornerRadius),
                border: GradientBoxBorder(
                  gradient: LinearGradient(
                    colors: [
                      SBColors.white.withValues(alpha: 0.96),
                      t.withValues(alpha: 0.20),
                      SBColors.softLine,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SBIconTile(
                        icon: icon,
                        tint: t,
                        size: compact ? 44 : 58,
                        radius: compact ? 13 : 17,
                      ),
                      const SizedBox(width: SBSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow.toUpperCase(),
                              style: SBTypography.labelSmall.copyWith(
                                color: t,
                                letterSpacing: 0.4,
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 7),
                            Text(
                              title,
                              style: (compact
                                      ? SBTypography.heading3
                                      : SBTypography.heading2)
                                  .copyWith(color: SBColors.navy),
                            ),
                            SizedBox(height: compact ? 4 : 7),
                            Text(
                              message,
                              style: (compact
                                      ? SBTypography.bodySmall
                                      : SBTypography.bodyMedium)
                                  .copyWith(color: SBColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (actions != null) ...[
                    SizedBox(height: compact ? SBSpacing.md : SBSpacing.lg),
                    actions!,
                  ],
                  if (footer != null) ...[
                    SizedBox(height: compact ? SBSpacing.md : SBSpacing.lg),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagonalHatchPainter extends CustomPainter {
  _DiagonalHatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 28.0;
    var x = -size.height;
    while (x < size.width + size.height) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
      x += spacing;
    }
  }

  @override
  bool shouldRepaint(_DiagonalHatchPainter old) => old.color != color;
}

/// Port of SBCommandCard.
class SBCommandCard extends StatelessWidget {
  const SBCommandCard({
    super.key,
    this.tint,
    required this.onTap,
    required this.child,
  });

  final Color? tint;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    return SBPressable(
      onTap: onTap,
      child: SBCard(
        radius: 18,
        borderColor: t.withValues(alpha: 0.12),
        child: child,
      ),
    );
  }
}

class SBMetricRibbonItem {
  const SBMetricRibbonItem({
    required this.icon,
    required this.value,
    required this.label,
    this.tint,
  });

  final String icon;
  final String value;
  final String label;
  final Color? tint;
}

/// Port of SBMetricRibbon: adaptive grid of small metric chips.
class SBMetricRibbon extends StatelessWidget {
  const SBMetricRibbon({super.key, required this.items});

  final List<SBMetricRibbonItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 118.0;
        final columns = (constraints.maxWidth / (minWidth + SBSpacing.sm))
            .floor()
            .clamp(1, items.length);
        final itemWidth = (constraints.maxWidth -
                SBSpacing.sm * (columns - 1)) /
            columns;

        return Wrap(
          spacing: SBSpacing.sm,
          runSpacing: SBSpacing.sm,
          children: [
            for (final item in items)
              SizedBox(width: itemWidth, child: _ribbonTile(item)),
          ],
        );
      },
    );
  }

  Widget _ribbonTile(SBMetricRibbonItem item) {
    final tint = item.tint ?? SBColors.blue;
    return Container(
      padding: const EdgeInsets.all(SBSpacing.sm),
      decoration: BoxDecoration(
        color: SBColors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: SBIcon(item.icon, size: 13, color: tint),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.titleMedium
                      .copyWith(color: SBColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.caption.copyWith(color: SBColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Port of SBMetricTile.
class SBMetricTile extends StatelessWidget {
  const SBMetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.tint,
  });

  final String icon;
  final String value;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SBColors.blue;
    return Container(
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SBColors.softLine),
        boxShadow: [
          BoxShadow(
            color: SBColors.navy.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: SBIcon(icon, size: 17, color: t),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.caption.copyWith(color: SBColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Port of SBSectionHeader.
class SBSectionHeader extends StatelessWidget {
  const SBSectionHeader(
      {super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        ),
        if (action != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action!,
                    style:
                        SBTypography.labelSmall.copyWith(color: SBColors.blue)),
                const SizedBox(width: 4),
                SBIcon('chevron.right', size: 12, color: SBColors.blue),
              ],
            ),
          ),
      ],
    );
  }
}

class SBToolIconStripItem {
  const SBToolIconStripItem({
    required this.icon,
    required this.title,
    required this.tint,
    required this.onTap,
  });

  final String icon;
  final String title;
  final Color tint;
  final VoidCallback onTap;
}

/// Port of SBToolIconStrip.
class SBToolIconStrip extends StatelessWidget {
  const SBToolIconStrip({super.key, required this.items});

  final List<SBToolIconStripItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SBColors.softLine),
        boxShadow: [
          BoxShadow(
            color: SBColors.navy.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: SBSpacing.sm),
            Expanded(
              child: GestureDetector(
                onTap: items[i].onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: items[i].tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child:
                          SBIcon(items[i].icon, size: 20, color: items[i].tint),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      items[i].title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.scaled(10.5,
                              weight: FontWeight.w600)
                          .copyWith(color: SBColors.navy),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
