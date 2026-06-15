import 'package:flutter/material.dart';

import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_motion.dart';
import 'sb_spacing.dart';
import 'sb_typography.dart';

enum SBButtonSize {
  small,
  medium,
  large;

  double get height => switch (this) {
        SBButtonSize.small => 44,
        SBButtonSize.medium => 48,
        SBButtonSize.large => 56,
      };

  TextStyle get font => switch (this) {
        SBButtonSize.small => SBTypography.labelMedium,
        SBButtonSize.medium => SBTypography.labelLarge,
        SBButtonSize.large => SBTypography.titleMedium,
      };

  double get iconSize => switch (this) {
        SBButtonSize.small => 18,
        SBButtonSize.medium => 20,
        SBButtonSize.large => 22,
      };

  double get horizontalPadding => switch (this) {
        SBButtonSize.small => 14,
        SBButtonSize.medium => 18,
        SBButtonSize.large => 22,
      };
}

enum SBButtonVariant { primary, secondary, text }

/// Port of SBButton with primary gradient, secondary outline and text styles.
class SBButton extends StatefulWidget {
  const SBButton(
    this.label, {
    super.key,
    this.icon,
    this.variant = SBButtonVariant.primary,
    this.size = SBButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
    required this.onPressed,
  });

  final String label;
  final String? icon;
  final SBButtonVariant variant;
  final SBButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final bool fullWidth;
  final VoidCallback onPressed;

  @override
  State<SBButton> createState() => _SBButtonState();
}

class _SBButtonState extends State<SBButton> {
  bool _pressed = false;

  bool get _enabled => !widget.isLoading && !widget.isDisabled;

  Color get _foreground {
    switch (widget.variant) {
      case SBButtonVariant.primary:
        return _enabled ? Colors.white : SBColors.muted;
      case SBButtonVariant.secondary:
      case SBButtonVariant.text:
        return _enabled ? SBColors.blue : SBColors.muted;
    }
  }

  double get _cornerRadius =>
      widget.variant == SBButtonVariant.text ? 10 : 12;

  @override
  Widget build(BuildContext context) {
    final decoration = switch (widget.variant) {
      SBButtonVariant.primary => BoxDecoration(
          gradient: _enabled ? SBColors.primaryGradient : null,
          color: _enabled ? null : SBColors.softLine,
          borderRadius: BorderRadius.circular(_cornerRadius),
          boxShadow: _enabled
              ? [
                  // Coloured glow that tightens on press.
                  BoxShadow(
                    color: SBColors.blue
                        .withValues(alpha: _pressed ? 0.18 : 0.38),
                    blurRadius: _pressed ? 8 : 20,
                    offset: Offset(0, _pressed ? 2 : 10),
                  ),
                  BoxShadow(
                    color: SBColors.indigo
                        .withValues(alpha: _pressed ? 0.10 : 0.22),
                    blurRadius: _pressed ? 4 : 12,
                    offset: Offset(0, _pressed ? 1 : 5),
                  ),
                ]
              : null,
        ),
      SBButtonVariant.secondary => BoxDecoration(
          gradient: _enabled
              ? LinearGradient(
                  colors: [
                    SBColors.blue.withValues(alpha: 0.12),
                    SBColors.cyan.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: _enabled ? null : SBColors.softLine.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(_cornerRadius),
          border: Border.all(
              color: _enabled
                  ? SBColors.blue.withValues(alpha: 0.55)
                  : SBColors.softLine,
              width: 1.5),
        ),
      SBButtonVariant.text => BoxDecoration(
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
    };

    // Glossy top highlight + hairline rim for the primary CTA.
    final BoxDecoration? gloss =
        (widget.variant == SBButtonVariant.primary && _enabled)
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(_cornerRadius),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.30),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22), width: 1),
              )
            : null;

    Widget content = Container(
      height: widget.size.height,
      width: widget.fullWidth ? double.infinity : null,
      padding:
          EdgeInsets.symmetric(horizontal: widget.size.horizontalPadding),
      decoration: decoration,
      foregroundDecoration: gloss,
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(
                  widget.variant == SBButtonVariant.primary
                      ? Colors.white
                      : SBColors.blue,
                ),
              ),
            ),
            const SizedBox(width: SBSpacing.sm),
          ] else if (widget.icon != null) ...[
            SBIcon(widget.icon!, size: widget.size.iconSize, color: _foreground),
            const SizedBox(width: SBSpacing.sm),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.size.font.copyWith(color: _foreground),
            ),
          ),
        ],
      ),
    );

    content = AnimatedOpacity(
      duration: SBMotion.pressSpringDuration,
      opacity: (widget.isLoading || !_enabled)
          ? 0.62
          : (_pressed ? 0.88 : 1),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: SBMotion.pressSpringDuration,
        curve: SBMotion.pressSpring,
        child: content,
      ),
    );

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _enabled ? widget.onPressed : null,
        child: content,
      ),
    );
  }
}
