import 'package:flutter/material.dart';

import 'sb_button.dart';
import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_motion.dart';
import 'sb_spacing.dart';
import 'sb_typography.dart';

/// Context variants for error states.
enum SBErrorContext {
  generic,
  drive,
  baseForce,
  generation,
  network;

  Color get tint => switch (this) {
        SBErrorContext.generation => SBColors.orange,
        _ => SBColors.red,
      };

  String? get recoveryHint => switch (this) {
        SBErrorContext.drive => 'Bağlantını kontrol edip tekrar dene.',
        SBErrorContext.baseForce => 'Kaynak durumunu kontrol edebilirsin.',
        SBErrorContext.generation =>
          'Farklı bir kaynak veya mod deneyebilirsin.',
        SBErrorContext.network => 'İnternet bağlantını kontrol et.',
        SBErrorContext.generic => null,
      };
}

/// Port of SBErrorState.
class SBErrorState extends StatelessWidget {
  const SBErrorState({
    super.key,
    this.icon = 'exclamationmark.triangle',
    this.title = 'Bir sorun oluştu',
    required this.message,
    this.actionLabel = 'Tekrar dene',
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    this.context_ = SBErrorContext.generic,
  });

  final String icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;
  final SBErrorContext context_;

  @override
  Widget build(BuildContext context) {
    final tint = context_.tint;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SBSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: SBIcon(icon, size: 32, color: tint),
          ),
          const SizedBox(height: SBSpacing.xl),
          Text(title,
              style: SBTypography.heading3.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: SBTypography.bodyMedium
                .copyWith(color: SBColors.muted, height: 1.35),
          ),
          if (context_.recoveryHint != null)
            Padding(
              padding: const EdgeInsets.only(top: SBSpacing.sm),
              child: Text(
                context_.recoveryHint!,
                style: SBTypography.caption.copyWith(
                  color: SBColors.muted.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SBSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SBButton(
                  actionLabel!,
                  icon: 'arrow.clockwise',
                  variant: SBButtonVariant.primary,
                  onPressed: onAction!,
                ),
                if (secondaryLabel != null && onSecondaryAction != null) ...[
                  const SizedBox(width: SBSpacing.md),
                  SBButton(
                    secondaryLabel!,
                    icon: 'chevron.left',
                    variant: SBButtonVariant.secondary,
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

/// Port of SBInlineError.
class SBInlineError extends StatelessWidget {
  const SBInlineError(
      {super.key, required this.message, this.isWarning = false});

  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final tint = isWarning ? SBColors.warning : SBColors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: isWarning ? SBColors.warningBg : SBColors.redBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SBIcon(
            isWarning
                ? 'exclamationmark.triangle.fill'
                : 'xmark.circle.fill',
            size: 18,
            color: tint,
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Text(
              message,
              style: SBTypography.bodySmall
                  .copyWith(color: tint, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium completion surface shown when generation is queued or a result is
/// ready. Port of SBSuccessState.
class SBSuccessState extends StatefulWidget {
  const SBSuccessState({
    super.key,
    this.icon = 'checkmark.seal.fill',
    this.title = 'Hazır',
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tint,
  });

  final String icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tint;

  @override
  State<SBSuccessState> createState() => _SBSuccessStateState();
}

class _SBSuccessStateState extends State<SBSuccessState> {
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _appeared = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? SBColors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SBSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.06),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              AnimatedScale(
                scale: _appeared ? 1 : 0.6,
                duration: SBMotion.softSpringDuration,
                curve: SBMotion.softSpring,
                child: AnimatedOpacity(
                  opacity: _appeared ? 1 : 0,
                  duration: SBMotion.softSpringDuration,
                  child: SBIcon(widget.icon, size: 32, color: tint),
                ),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.xl),
          AnimatedOpacity(
            opacity: _appeared ? 1 : 0,
            duration: SBMotion.softSpringDuration,
            child: Column(
              children: [
                Text(widget.title,
                    style:
                        SBTypography.heading3.copyWith(color: SBColors.navy)),
                const SizedBox(height: SBSpacing.sm),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: SBTypography.bodyMedium
                      .copyWith(color: SBColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(height: SBSpacing.xl),
            AnimatedOpacity(
              opacity: _appeared ? 1 : 0,
              duration: SBMotion.softSpringDuration,
              child: SBButton(
                widget.actionLabel!,
                icon: 'arrow.right',
                onPressed: widget.onAction!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
