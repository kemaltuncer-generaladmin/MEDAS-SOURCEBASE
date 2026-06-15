import 'package:flutter/material.dart';

import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';

/// Port of RichResultContentView: renders raw generation text as structured
/// blocks (headings, bullets, key-values).
class RichResultContentView extends StatelessWidget {
  const RichResultContentView({
    super.key,
    required this.kind,
    required this.title,
    required this.sourceTitle,
    required this.contentText,
  });

  final GeneratedKind kind;
  final String title;
  final String sourceTitle;
  final String contentText;

  Color get _tint => switch (kind) {
        GeneratedKind.flashcard ||
        GeneratedKind.comparison ||
        GeneratedKind.table =>
          SBColors.blue,
        GeneratedKind.question || GeneratedKind.infographic => SBColors.cyan,
        GeneratedKind.summary ||
        GeneratedKind.examMorningSummary ||
        GeneratedKind.mindMap =>
          SBColors.purple,
        GeneratedKind.algorithm ||
        GeneratedKind.clinicalScenario =>
          SBColors.orange,
        GeneratedKind.learningPlan => SBColors.green,
        GeneratedKind.podcast => SBColors.red,
      };

  String get _icon => switch (kind) {
        GeneratedKind.flashcard => 'rectangle.on.rectangle',
        GeneratedKind.question => 'questionmark.circle',
        GeneratedKind.summary => 'doc.text',
        GeneratedKind.examMorningSummary => 'alarm',
        GeneratedKind.algorithm => 'arrow.triangle.branch',
        GeneratedKind.comparison || GeneratedKind.table => 'tablecells',
        GeneratedKind.clinicalScenario => 'cross.case',
        GeneratedKind.learningPlan => 'calendar.badge.clock',
        GeneratedKind.podcast => 'waveform',
        GeneratedKind.infographic => 'chart.bar.doc.horizontal',
        GeneratedKind.mindMap => 'point.3.connected.trianglepath.dotted',
      };

  @override
  Widget build(BuildContext context) {
    final blocks = _ResultContentParser.blocks(contentText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: SBIcon(_icon, size: 20, color: _tint),
            ),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: SBTypography.titleMedium
                          .copyWith(color: SBColors.navy)),
                  const SizedBox(height: 4),
                  Text(
                    sourceTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SBTypography.caption.copyWith(color: SBColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: SBSpacing.md),
        if (blocks.isEmpty)
          SBCard(
            radius: 16,
            child: Text(contentText,
                style: SBTypography.bodyMedium.copyWith(color: SBColors.navy)),
          )
        else
          for (final block in blocks) ...[
            _blockView(block),
            const SizedBox(height: SBSpacing.md),
          ],
      ],
    );
  }

  Widget _blockView(_ResultContentBlock block) {
    return SBCard(
      radius: 16,
      borderColor: _tint.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (block.title != null) ...[
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: _tint, shape: BoxShape.circle),
                ),
                const SizedBox(width: SBSpacing.sm),
                Expanded(
                  child: Text(block.title!,
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy)),
                ),
              ],
            ),
            const SizedBox(height: SBSpacing.sm),
          ],
          for (final line in block.lines) ...[
            _lineView(line),
            const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _lineView(_ResultContentLine line) {
    switch (line.type) {
      case _LineType.paragraph:
        return Text(line.text,
            style: SBTypography.bodyMedium.copyWith(color: SBColors.navy));
      case _LineType.bullet:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 5,
                height: 5,
                decoration:
                    BoxDecoration(color: _tint, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: SBSpacing.sm),
            Expanded(
              child: Text(line.text,
                  style:
                      SBTypography.bodySmall.copyWith(color: SBColors.muted)),
            ),
          ],
        );
      case _LineType.keyValue:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SBSpacing.sm),
          decoration: BoxDecoration(
            color: _tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.key!,
                  style: SBTypography.caption.copyWith(color: _tint)),
              const SizedBox(height: 3),
              Text(line.text,
                  style:
                      SBTypography.bodySmall.copyWith(color: SBColors.navy)),
            ],
          ),
        );
    }
  }
}

enum _LineType { paragraph, bullet, keyValue }

class _ResultContentLine {
  const _ResultContentLine(this.type, this.text, [this.key]);

  final _LineType type;
  final String text;
  final String? key;
}

class _ResultContentBlock {
  const _ResultContentBlock(this.title, this.lines);

  final String? title;
  final List<_ResultContentLine> lines;
}

class _ResultContentParser {
  static List<_ResultContentBlock> blocks(String text) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return [];

    final blocks = <_ResultContentBlock>[];
    String? currentTitle;
    var currentLines = <_ResultContentLine>[];

    void flush() {
      if (currentTitle == null && currentLines.isEmpty) return;
      blocks.add(_ResultContentBlock(currentTitle, currentLines));
      currentTitle = null;
      currentLines = [];
    }

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      final heading = _headingText(line);
      if (heading != null) {
        flush();
        currentTitle = heading;
        continue;
      }
      currentLines.add(_contentLine(line));
    }
    flush();
    return blocks;
  }

  static String? _headingText(String line) {
    if (line.startsWith('#')) {
      final t = line.replaceAll(RegExp(r'^[#\s]+'), '').trim();
      return t.isEmpty ? null : t;
    }
    if (!line.startsWith('-') &&
        !line.startsWith('•') &&
        !line.contains(':') &&
        line.length <= 64 &&
        (line == line.toUpperCase() || line.endsWith(':')) &&
        line.length > 3) {
      final t = line.replaceAll(RegExp(r':+$'), '').trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static _ResultContentLine _contentLine(String line) {
    final strippedBullet = line
        .replaceFirst(RegExp(r'^\s*[-•]\s*'), '')
        .replaceFirst(RegExp(r'^\s*\d+[\.)]\s*'), '')
        .trim();

    if (strippedBullet != line) {
      return _ResultContentLine(_LineType.bullet, strippedBullet);
    }

    final colon = line.indexOf(':');
    if (colon > 0) {
      final key = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty && key.length <= 36) {
        return _ResultContentLine(_LineType.keyValue, value, key);
      }
    }

    return _ResultContentLine(_LineType.paragraph, line);
  }
}
