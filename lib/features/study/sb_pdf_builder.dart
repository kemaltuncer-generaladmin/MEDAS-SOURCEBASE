import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/generated_content_parser.dart';
import '../../models/models.dart';
import '../../models/study_models.dart';
import 'sb_output_style.dart';

/// Builds a polished, branded, multi-page study PDF from a generated output.
///
/// The document mirrors the in-app study view: a branded cover header, then
/// every structured block (cards, quizzes, callouts, tables, decision trees,
/// timelines, mind maps, …) laid out cleanly with automatic pagination.
/// Turkish glyphs are guaranteed by embedding an Open Sans font; if the font
/// cannot be fetched the build still succeeds with the built-in fallback so a
/// PDF is *always* produced.
class SBPdfBuilder {
  SBPdfBuilder._();

  static _PdfFonts? _fonts;

  /// Public entry point. Returns the rendered PDF bytes.
  static Future<Uint8List> build({
    required GeneratedKind kind,
    required String title,
    String? sourceTitle,
    Map<String, dynamic>? content,
    String? contentText,
    String? createdLabel,
  }) async {
    final fonts = await _loadFonts();
    final doc = GeneratedContentParser.document(
        kind, content, title.trim().isEmpty ? 'SourceBase Çalışması' : title,
        contentText);

    final accent = _pdf(SBOutputStyle.outputColor(kind));
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      italic: fonts.italic,
      boldItalic: fonts.italic,
    );

    // Pre-fetch any inline images so the build itself never blocks on IO.
    final images = await _prefetchImages(doc);

    final pdf = pw.Document(
      title: doc.title,
      author: 'SourceBase · Medasi',
      creator: 'SourceBase',
      theme: theme,
    );

    final widgets = <pw.Widget>[
      _cover(doc, kind, accent, sourceTitle, createdLabel),
      pw.SizedBox(height: 18),
    ];

    if (doc.summary.trim().isNotEmpty &&
        !_blocksContainSummary(doc)) {
      widgets
        ..add(_summaryCard(doc.summary, accent))
        ..add(pw.SizedBox(height: 14));
    }

    for (final block in doc.blocks) {
      final w = _block(block, accent, kind, images);
      if (w != null) {
        widgets
          ..add(w)
          ..add(pw.SizedBox(height: 14));
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 40),
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(doc, accent),
        footer: (context) => _footer(context, accent),
        build: (context) => widgets,
      ),
    );

    return pdf.save();
  }

  /// Convenience builder straight from a [GeneratedOutput].
  static Future<Uint8List> fromOutput(GeneratedOutput output,
          {String? sourceTitle}) =>
      build(
        kind: output.kind,
        title: output.title,
        sourceTitle: sourceTitle,
        content: output.content,
        contentText: output.contentText,
        createdLabel: output.updatedLabel,
      );

  static String fileName(String title, GeneratedKind kind) {
    final base = title.trim().isEmpty
        ? SBOutputStyle.outputKindLabel(kind)
        : title.trim();
    final safe = base
        .replaceAll(RegExp(r'[^\w\sğüşöçıİĞÜŞÖÇ-]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final clipped = safe.length > 60 ? safe.substring(0, 60) : safe;
    return 'SourceBase_$clipped.pdf';
  }

  // MARK: - Fonts

  static Future<_PdfFonts> _loadFonts() async {
    if (_fonts != null) return _fonts!;
    try {
      _fonts = _PdfFonts(
        regular: await PdfGoogleFonts.openSansRegular(),
        bold: await PdfGoogleFonts.openSansBold(),
        italic: await PdfGoogleFonts.openSansItalic(),
      );
    } catch (_) {
      // Offline / blocked: still produce a valid PDF with the core fonts.
      _fonts = _PdfFonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      );
    }
    return _fonts!;
  }

  // MARK: - Cover & chrome

  static pw.Widget _cover(SBStudyDocument doc, GeneratedKind kind,
      PdfColor accent, String? sourceTitle, String? createdLabel) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(22),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [accent, _mix(accent, PdfColors.black, 0.22)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('SOURCEBASE',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 2)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(SBOutputStyle.outputKindLabel(kind),
                    style: pw.TextStyle(
                        color: accent,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10)),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(doc.title,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 24)),
          if (doc.subtitle.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(doc.subtitle,
                style: pw.TextStyle(
                    color: _mix(PdfColors.white, accent, 0.12),
                    fontSize: 12)),
          ],
          pw.SizedBox(height: 14),
          pw.Row(children: [
            if (sourceTitle != null && sourceTitle.trim().isNotEmpty)
              _coverChip('Kaynak: ${sourceTitle.trim()}'),
            if (sourceTitle != null && sourceTitle.trim().isNotEmpty)
              pw.SizedBox(width: 8),
            _coverChip(createdLabel?.trim().isNotEmpty == true
                ? createdLabel!.trim()
                : 'SourceBase ile üretildi'),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _coverChip(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: pw.BoxDecoration(
          color: PdfColor(1, 1, 1, 0.18),
          borderRadius: pw.BorderRadius.circular(999),
        ),
        child: pw.Text(text,
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
      );

  static pw.Widget _runningHeader(SBStudyDocument doc, PdfColor accent) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: _line, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SourceBase',
              style: pw.TextStyle(
                  color: accent, fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text(doc.title,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: const pw.TextStyle(color: _muted, fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context, PdfColor accent) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Medasi ekosistemi · sourcebase.medasi.com.tr',
              style: const pw.TextStyle(color: _muted, fontSize: 8)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(
                  color: accent, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ],
      ),
    );
  }

  // MARK: - Blocks

  static pw.Widget _summaryCard(String summary, PdfColor accent) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _tint(accent, 0.06),
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: _tint(accent, 0.30), width: 0.8),
        ),
        child: pw.Text(summary,
            style: const pw.TextStyle(
                color: _ink, fontSize: 11, lineSpacing: 3)),
      );

  static pw.Widget? _block(SBStudyBlock block, PdfColor accent,
      GeneratedKind kind, Map<String, Uint8List> images) {
    switch (block.type) {
      case SBStudyBlockType.paragraph:
        if ((block.text ?? '').trim().isEmpty) return null;
        return pw.Text(block.text!,
            style: const pw.TextStyle(
                color: _ink, fontSize: 11, lineSpacing: 3));

      case SBStudyBlockType.calloutList:
        return _calloutBlock(block, accent);

      case SBStudyBlockType.steps:
        return _stepsBlock(block, accent);

      case SBStudyBlockType.cards:
        return _cardsBlock(block, accent);

      case SBStudyBlockType.quiz:
        return _quizBlock(block, accent);

      case SBStudyBlockType.table:
        return _tableBlock(block, accent);

      case SBStudyBlockType.decisions:
        return _decisionsBlock(block, accent);

      case SBStudyBlockType.qa:
        return _qaBlock(block, accent);

      case SBStudyBlockType.keyValues:
        return _keyValuesBlock(block, accent);

      case SBStudyBlockType.timeline:
        return _timelineBlock(block, accent);

      case SBStudyBlockType.mindBranches:
        return _mindBlock(block, accent);

      case SBStudyBlockType.audio:
        return _audioBlock(block, accent);

      case SBStudyBlockType.image:
        return _imageBlock(block, accent, images);
    }
  }

  static pw.Widget _sectionTitle(String title, PdfColor accent) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 4, height: 15, color: accent),
          pw.SizedBox(width: 8),
          pw.Text(title,
              style: pw.TextStyle(
                  color: _ink, fontWeight: pw.FontWeight.bold, fontSize: 14)),
        ],
      );

  static PdfColor _calloutColor(SBCalloutStyle? style, PdfColor accent) {
    switch (style) {
      case SBCalloutStyle.mustKnow:
        return PdfColor.fromInt(0xFF0A5BFF);
      case SBCalloutStyle.redFlag:
        return PdfColor.fromInt(0xFFFF3B47);
      case SBCalloutStyle.confused:
        return PdfColor.fromInt(0xFF8A45F7);
      case SBCalloutStyle.tip:
        return PdfColor.fromInt(0xFF12B95B);
      case SBCalloutStyle.objective:
        return PdfColor.fromInt(0xFF00CDE2);
      case SBCalloutStyle.plain:
      case null:
        return accent;
    }
  }

  static pw.Widget _calloutBlock(SBStudyBlock block, PdfColor accent) {
    final color = _calloutColor(block.calloutStyle, accent);
    final items = block.items ?? const [];
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: _tint(color, 0.06),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text((block.title ?? '').toUpperCase(),
              style: pw.TextStyle(
                  color: color, fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
          pw.SizedBox(height: 8),
          for (final item in items) _bullet(item, color),
        ],
      ),
    );
  }

  static pw.Widget _bullet(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4, right: 7),
              width: 4,
              height: 4,
              decoration:
                  pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
            ),
            pw.Expanded(
              child: pw.Text(text,
                  style: const pw.TextStyle(
                      color: _ink, fontSize: 10.5, lineSpacing: 2.5)),
            ),
          ],
        ),
      );

  static pw.Widget _stepsBlock(SBStudyBlock block, PdfColor accent) {
    final items = block.items ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(block.title ?? 'Adımlar', accent),
        pw.SizedBox(height: 10),
        for (var i = 0; i < items.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 20,
                  height: 20,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                      color: accent, shape: pw.BoxShape.circle),
                  child: pw.Text('${i + 1}',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10)),
                ),
                pw.SizedBox(width: 9),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(items[i],
                        style: const pw.TextStyle(
                            color: _ink, fontSize: 11, lineSpacing: 2.5)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _cardsBlock(SBStudyBlock block, PdfColor accent) {
    final cards = block.cards ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Flashcard Destesi (${cards.length})', accent),
        pw.SizedBox(height: 10),
        for (var i = 0; i < cards.length; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 9),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(11),
              border: pw.Border.all(color: _line, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pill('${i + 1}', accent),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(cards[i].front,
                          style: pw.TextStyle(
                              color: _ink,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11.5)),
                    ),
                  ],
                ),
                if (cards[i].back.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(cards[i].back,
                      style: const pw.TextStyle(
                          color: _ink, fontSize: 10.5, lineSpacing: 2.5)),
                ],
                if (cards[i].explanation.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(cards[i].explanation,
                      style: pw.TextStyle(
                          color: _muted,
                          fontSize: 9.5,
                          fontStyle: pw.FontStyle.italic,
                          lineSpacing: 2)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _quizBlock(SBStudyBlock block, PdfColor accent) {
    final questions = block.quizQuestions ?? const [];
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Soru Bankası (${questions.length})', accent),
        pw.SizedBox(height: 10),
        for (var qi = 0; qi < questions.length; qi++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 11),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(11),
              border: pw.Border.all(color: _line, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${qi + 1}. ${questions[qi].text}',
                    style: pw.TextStyle(
                        color: _ink,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        lineSpacing: 2.5)),
                pw.SizedBox(height: 8),
                for (var oi = 0; oi < questions[qi].options.length; oi++)
                  _quizOption(
                    '${letters[oi % letters.length]}) ${questions[qi].options[oi]}',
                    isCorrect: oi == questions[qi].correctIndex,
                    accent: accent,
                  ),
                if (questions[qi].explanation.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 7),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      color: _tint(accent, 0.07),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.RichText(
                      text: pw.TextSpan(children: [
                        pw.TextSpan(
                            text: 'Açıklama: ',
                            style: pw.TextStyle(
                                color: accent,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9.5)),
                        pw.TextSpan(
                            text: questions[qi].explanation,
                            style: const pw.TextStyle(
                                color: _ink, fontSize: 9.5, lineSpacing: 2)),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _quizOption(String text,
      {required bool isCorrect, required PdfColor accent}) {
    final green = PdfColor.fromInt(0xFF12B95B);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: pw.BoxDecoration(
        color: isCorrect ? _tint(green, 0.10) : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(
            color: isCorrect ? green : _line, width: isCorrect ? 1 : 0.6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(text,
                style: pw.TextStyle(
                    color: isCorrect ? _mix(green, PdfColors.black, 0.2) : _ink,
                    fontWeight:
                        isCorrect ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontSize: 10)),
          ),
          if (isCorrect)
            pw.Text('  Doğru',
                style: pw.TextStyle(
                    color: green,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.5)),
        ],
      ),
    );
  }

  static pw.Widget _tableBlock(SBStudyBlock block, PdfColor accent) {
    final t = block.table;
    if (t == null || t.headers.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(block.title ?? 'Tablo', accent),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: {
            for (var i = 0; i < t.headers.length; i++)
              i: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _tint(accent, 0.12)),
              children: [
                for (final h in t.headers)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(7),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            color: _mix(accent, PdfColors.black, 0.18),
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9.5)),
                  ),
              ],
            ),
            for (var r = 0; r < t.rows.length; r++)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: r.isEven ? PdfColors.white : _softGrey),
                children: [
                  for (var c = 0; c < t.headers.length; c++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                          c < t.rows[r].length ? t.rows[r][c] : '',
                          style: const pw.TextStyle(
                              color: _ink, fontSize: 9.5, lineSpacing: 2)),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _decisionsBlock(SBStudyBlock block, PdfColor accent) {
    final nodes = block.decisionNodes ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(block.title ?? 'Karar Düğümleri', accent),
        pw.SizedBox(height: 10),
        for (var i = 0; i < nodes.length; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _line, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pill('${i + 1}', accent),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(nodes[i].title,
                          style: pw.TextStyle(
                              color: _ink,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11)),
                    ),
                  ],
                ),
                if ((nodes[i].detail ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(nodes[i].detail!,
                      style: const pw.TextStyle(
                          color: _ink, fontSize: 10, lineSpacing: 2.5)),
                ],
                if ((nodes[i].yes ?? '').trim().isNotEmpty)
                  _branchLine('Evet', nodes[i].yes!,
                      PdfColor.fromInt(0xFF12B95B)),
                if ((nodes[i].no ?? '').trim().isNotEmpty)
                  _branchLine(
                      'Hayır', nodes[i].no!, PdfColor.fromInt(0xFFFF3B47)),
                for (final s in nodes[i].substeps) ...[
                  pw.SizedBox(height: 3),
                  _bullet(s, accent),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _branchLine(String label, String text, PdfColor color) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: pw.BoxDecoration(
                color: _tint(color, 0.12),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(label,
                  style: pw.TextStyle(
                      color: color,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8.5)),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: pw.Text(text,
                  style: const pw.TextStyle(
                      color: _ink, fontSize: 10, lineSpacing: 2)),
            ),
          ],
        ),
      );

  static pw.Widget _qaBlock(SBStudyBlock block, PdfColor accent) {
    final pairs = block.qaPairs ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(block.title ?? 'Sorular', accent),
        pw.SizedBox(height: 10),
        for (final qa in pairs)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: _softGrey,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('S: ${qa.question}',
                    style: pw.TextStyle(
                        color: _ink,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10.5,
                        lineSpacing: 2)),
                if (qa.answer.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text('C: ${qa.answer}',
                      style: const pw.TextStyle(
                          color: _ink, fontSize: 10, lineSpacing: 2.5)),
                ],
                if ((qa.explanation ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(qa.explanation!,
                      style: pw.TextStyle(
                          color: _muted,
                          fontStyle: pw.FontStyle.italic,
                          fontSize: 9.5,
                          lineSpacing: 2)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _keyValuesBlock(SBStudyBlock block, PdfColor accent) {
    final kvs = block.keyValues ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(block.title ?? 'Bilgiler', accent),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: _line, width: 0.8),
          ),
          child: pw.Column(
            children: [
              for (final kv in kvs)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 120,
                        child: pw.Text(kv.key,
                            style: pw.TextStyle(
                                color: accent,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10)),
                      ),
                      pw.Expanded(
                        child: pw.Text(kv.value,
                            style: const pw.TextStyle(
                                color: _ink, fontSize: 10, lineSpacing: 2.5)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _timelineBlock(SBStudyBlock block, PdfColor accent) {
    final entries = block.timelineEntries ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(block.title ?? 'Plan', accent),
        pw.SizedBox(height: 10),
        for (var i = 0; i < entries.length; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _line, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    _pill('${i + 1}', accent),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(entries[i].title,
                          style: pw.TextStyle(
                              color: _ink,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11)),
                    ),
                    if ((entries[i].meta ?? '').trim().isNotEmpty)
                      pw.Text(entries[i].meta!,
                          style: pw.TextStyle(
                              color: accent,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9)),
                  ],
                ),
                for (final item in entries[i].items) ...[
                  pw.SizedBox(height: 4),
                  _bullet(item, accent),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _mindBlock(SBStudyBlock block, PdfColor accent) {
    final branches = block.mindBranches ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(block.title ?? 'Dallar', accent),
        pw.SizedBox(height: 10),
        for (final b in branches)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: _tint(accent, 0.05),
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(b.label,
                    style: pw.TextStyle(
                        color: _ink,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11.5)),
                for (final child in b.children) ...[
                  pw.SizedBox(height: 4),
                  _bullet(child, accent),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _audioBlock(SBStudyBlock block, PdfColor accent) {
    final segments = block.podcastSegments ?? const [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Anlatım Metni', accent),
        pw.SizedBox(height: 10),
        for (final s in segments)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 9),
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _line, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(s.title,
                        style: pw.TextStyle(
                            color: accent,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11)),
                    if (s.durationLabel.trim().isNotEmpty)
                      pw.Text(s.durationLabel,
                          style: const pw.TextStyle(
                              color: _muted, fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text(s.text,
                    style: const pw.TextStyle(
                        color: _ink, fontSize: 10.5, lineSpacing: 3)),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _imageBlock(
      SBStudyBlock block, PdfColor accent, Map<String, Uint8List> images) {
    final bytes = images[block.id];
    if (bytes == null) {
      return _calloutBlock(
        SBStudyBlock.calloutList(block.id, block.title ?? 'Görsel',
            const ['Görsel uygulama içinde görüntülenebilir.'],
            SBCalloutStyle.plain),
        accent,
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if ((block.title ?? '').trim().isNotEmpty) ...[
          _sectionTitle(block.title!, accent),
          pw.SizedBox(height: 10),
        ],
        pw.ClipRRect(
          horizontalRadius: 12,
          verticalRadius: 12,
          child: pw.Image(pw.MemoryImage(bytes),
              fit: pw.BoxFit.contain),
        ),
      ],
    );
  }

  static pw.Widget _pill(String text, PdfColor accent) => pw.Container(
        width: 20,
        height: 20,
        alignment: pw.Alignment.center,
        decoration:
            pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9.5)),
      );

  // MARK: - Images prefetch

  static Future<Map<String, Uint8List>> _prefetchImages(
      SBStudyDocument doc) async {
    final result = <String, Uint8List>{};
    for (final block in doc.blocks) {
      if (block.type == SBStudyBlockType.image &&
          (block.url ?? '').startsWith('http')) {
        try {
          final res = await http
              .get(Uri.parse(block.url!))
              .timeout(const Duration(seconds: 6));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            result[block.id] = res.bodyBytes;
          }
        } catch (_) {
          // Ignore — the image block degrades to a note.
        }
      }
    }
    return result;
  }

  static bool _blocksContainSummary(SBStudyDocument doc) =>
      doc.blocks.any((b) =>
          b.type == SBStudyBlockType.paragraph &&
          (b.text ?? '').trim() == doc.summary.trim());

  // MARK: - Colour helpers

  static const PdfColor _ink = PdfColor.fromInt(0xFF0A1326);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5E6B8E);
  static const PdfColor _line = PdfColor.fromInt(0xFFE6ECF5);
  static const PdfColor _softGrey = PdfColor.fromInt(0xFFF5F8FC);

  static PdfColor _pdf(Color c) => PdfColor(c.r, c.g, c.b);

  static PdfColor _tint(PdfColor c, double alpha) =>
      PdfColor(c.red, c.green, c.blue, alpha);

  static PdfColor _mix(PdfColor a, PdfColor b, double t) => PdfColor(
        a.red + (b.red - a.red) * t,
        a.green + (b.green - a.green) * t,
        a.blue + (b.blue - a.blue) * t,
      );
}

class _PdfFonts {
  _PdfFonts({required this.regular, required this.bold, required this.italic});

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
}
