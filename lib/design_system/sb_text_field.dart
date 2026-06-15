import 'package:flutter/material.dart';

import 'sb_colors.dart';
import 'sb_icons.dart';
import 'sb_spacing.dart';
import 'sb_typography.dart';

/// Port of SBTextField: leading tinted icon, focus border, secure-toggle eye.
class SBTextField extends StatefulWidget {
  const SBTextField({
    super.key,
    required this.icon,
    required this.hint,
    required this.controller,
    this.isSecure = false,
    this.keyboardType = TextInputType.text,
    this.onSubmit,
    this.onChanged,
  });

  final String icon;
  final String hint;
  final TextEditingController controller;
  final bool isSecure;
  final TextInputType keyboardType;
  final VoidCallback? onSubmit;
  final ValueChanged<String>? onChanged;

  @override
  State<SBTextField> createState() => _SBTextFieldState();
}

class _SBTextFieldState extends State<SBTextField> {
  bool _isSecureVisible = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: SBSpacing.lg),
      decoration: BoxDecoration(
        color: SBColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? SBColors.blue : SBColors.line,
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: SBColors.navy.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: SBIcon(widget.icon, size: 18, color: SBColors.blue),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.isSecure && !_isSecureVisible,
              keyboardType: widget.keyboardType,
              onSubmitted: (_) => widget.onSubmit?.call(),
              onChanged: widget.onChanged,
              style: SBTypography.bodyMedium.copyWith(color: SBColors.navy),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    SBTypography.bodyMedium.copyWith(color: SBColors.softText),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (widget.isSecure)
            GestureDetector(
              onTap: () =>
                  setState(() => _isSecureVisible = !_isSecureVisible),
              child: SBIcon(
                _isSecureVisible ? 'eye.slash' : 'eye',
                size: 18,
                color: SBColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}
