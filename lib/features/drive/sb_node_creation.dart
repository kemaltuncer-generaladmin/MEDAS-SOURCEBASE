import 'package:flutter/material.dart';

import '../../design_system/sb_background.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';

/// Port of `Color(hex:)`.
Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length == 6) {
    final value = int.tryParse(cleaned, radix: 16);
    if (value != null) {
      return Color(0xFF000000 | value);
    }
  }
  return SBColors.blue;
}

/// Curated palettes for course / section symbols. Port of SBNodePalette.
class SBNodePalette {
  SBNodePalette._();

  static const symbols = [
    'book.closed',
    'brain.head.profile',
    'heart.text.square',
    'cross.case',
    'stethoscope',
    'lungs',
    'pills',
    'flask',
    'function',
    'list.bullet.rectangle',
    'graduationcap',
    'atom',
    'waveform.path.ecg',
    'bandage',
    'eye',
    'folder',
  ];

  static const colors = [
    '#0A5BFF',
    '#08C7D6',
    '#7B3FF2',
    '#12AE55',
    '#FF6B13',
    '#FF3B3B',
    '#07123F',
    '#0FA3A3',
  ];

  static const defaultSymbol = 'book.closed';
  static const defaultColor = '#0A5BFF';
}

/// Shows the create sheet for courses/sections. Port of SBCreateNodeSheet.
Future<void> showCreateNodeSheet(
  BuildContext context, {
  required String heading,
  required String placeholder,
  required String confirmLabel,
  required void Function(String title, String iconName, String colorHex)
      onCreate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SBCreateNodeSheet(
      heading: heading,
      placeholder: placeholder,
      confirmLabel: confirmLabel,
      onCreate: onCreate,
    ),
  );
}

class SBCreateNodeSheet extends StatefulWidget {
  const SBCreateNodeSheet({
    super.key,
    required this.heading,
    required this.placeholder,
    required this.confirmLabel,
    required this.onCreate,
  });

  final String heading;
  final String placeholder;
  final String confirmLabel;
  final void Function(String title, String iconName, String colorHex) onCreate;

  @override
  State<SBCreateNodeSheet> createState() => _SBCreateNodeSheetState();
}

class _SBCreateNodeSheetState extends State<SBCreateNodeSheet> {
  final _title = TextEditingController();
  final _nameFocus = FocusNode();
  String _selectedSymbol = SBNodePalette.defaultSymbol;
  String _selectedColor = SBNodePalette.defaultColor;

  bool get _canCreate => _title.text.trim().isNotEmpty;

  Color get _color => colorFromHex(_selectedColor);

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nameFocus.requestFocus());
  }

  @override
  void dispose() {
    _title.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.86,
          child: SBPageBackground(
            tone: SBPageTone.warm,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _toolbar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(SBSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _previewCard(),
                          const SizedBox(height: SBSpacing.lg),
                          _nameField(),
                          const SizedBox(height: SBSpacing.lg),
                          _symbolPicker(),
                          const SizedBox(height: SBSpacing.lg),
                          _colorPicker(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Vazgeç',
                style: SBTypography.bodyMedium.copyWith(color: SBColors.blue)),
          ),
          Expanded(
            child: Text(
              widget.heading,
              textAlign: TextAlign.center,
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy),
            ),
          ),
          TextButton(
            onPressed: _canCreate
                ? () {
                    widget.onCreate(
                        _title.text.trim(), _selectedSymbol, _selectedColor);
                    Navigator.of(context).pop();
                  }
                : null,
            child: Text(
              widget.confirmLabel,
              style: SBTypography.labelMedium.copyWith(
                  color: _canCreate ? SBColors.blue : SBColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    return Container(
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: SBIcon(_selectedSymbol, size: 21, color: _color),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title.text.isEmpty ? widget.placeholder : _title.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.titleMedium.copyWith(
                    color: _title.text.isEmpty
                        ? SBColors.softText
                        : SBColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Önizleme',
                    style:
                        SBTypography.caption.copyWith(color: SBColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameField() {
    final focused = _nameFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ad',
            style: SBTypography.labelMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.sm),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: SBSpacing.lg),
          decoration: BoxDecoration(
            color: SBColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? SBColors.blue : SBColors.line,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: TextField(
              controller: _title,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              style: SBTypography.bodyMedium.copyWith(color: SBColors.navy),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: SBTypography.bodyMedium
                    .copyWith(color: SBColors.softText),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _symbolPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sembol',
            style: SBTypography.labelMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final symbol in SBNodePalette.symbols) ...[
                _symbolButton(symbol),
                const SizedBox(width: SBSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _symbolButton(String symbol) {
    final isSelected = symbol == _selectedSymbol;
    return GestureDetector(
      onTap: () => setState(() => _selectedSymbol = symbol),
      child: Container(
        width: 50,
        height: 48,
        decoration: BoxDecoration(
          color:
              isSelected ? _color.withValues(alpha: 0.14) : SBColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _color.withValues(alpha: 0.5)
                : SBColors.softLine,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: SBIcon(symbol,
            size: 20, color: isSelected ? _color : SBColors.muted),
      ),
    );
  }

  Widget _colorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Renk',
            style: SBTypography.labelMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final hex in SBNodePalette.colors) ...[
                _colorButton(hex),
                const SizedBox(width: SBSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _colorButton(String hex) {
    final swatch = colorFromHex(hex);
    final isSelected = _selectedColor == hex;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = hex),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: swatch,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? SBColors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: swatch.withValues(alpha: 0.4),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
