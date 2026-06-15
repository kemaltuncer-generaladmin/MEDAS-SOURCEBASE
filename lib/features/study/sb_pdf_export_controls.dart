import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/workspace_store.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_empty_state.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';
import 'sb_output_style.dart';
import 'sb_pdf_builder.dart';

/// Reusable "save to section + export to branded PDF + share" control.
/// Port of SBPdfExportControls for saving and PDF handoff.
class SBPdfExportControls extends StatefulWidget {
  const SBPdfExportControls({super.key, required this.output});

  final GeneratedOutput output;

  @override
  State<SBPdfExportControls> createState() => _SBPdfExportControlsState();
}

class _SBPdfExportControlsState extends State<SBPdfExportControls> {
  bool _isExporting = false;
  bool _hasExport = false;
  String? _exportMessage;
  Uint8List? _pdfBytes;

  Color get _accent => SBOutputStyle.accent(widget.output.kind);

  @override
  Widget build(BuildContext context) {
    return SBCard(
      radius: 18,
      borderColor: _accent.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: const SBIcon(
                  'doc.richtext.fill',
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: SBSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium PDF',
                      style: SBTypography.titleSmall.copyWith(
                        color: SBColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tablet ve çıktı için düzenlenmiş çalışma paketi.',
                      style: SBTypography.caption.copyWith(
                        color: SBColors.muted,
                      ),
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
                child: SBButton(
                  'Bölüme kaydet',
                  icon: 'folder.badge.plus',
                  variant: SBButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: _showSavePicker,
                ),
              ),
              const SizedBox(width: SBSpacing.sm),
              Expanded(
                child: SBButton(
                  _isExporting ? 'Hazırlanıyor' : 'PDF paylaş',
                  icon: _isExporting ? 'hourglass' : 'square.and.arrow.up',
                  isLoading: _isExporting,
                  fullWidth: true,
                  onPressed: _prepareExport,
                ),
              ),
            ],
          ),
          if (_isExporting) ...[
            const SizedBox(height: SBSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.72,
                minHeight: 4,
                backgroundColor: SBColors.softLine,
                valueColor: AlwaysStoppedAnimation(_accent),
              ),
            ),
          ],
          if (_hasExport) ...[
            const SizedBox(height: SBSpacing.md),
            GestureDetector(
              onTap: _reshareOrPrint,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SBSpacing.md),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    SBIcon('square.and.arrow.up', size: 15, color: _accent),
                    const SizedBox(width: SBSpacing.sm),
                    Expanded(
                      child: Text(
                        'Tekrar paylaş veya yazdır',
                        style: SBTypography.labelMedium.copyWith(
                          color: _accent,
                        ),
                      ),
                    ),
                    SBIcon('chevron.right', size: 12, color: _accent),
                  ],
                ),
              ),
            ),
          ],
          if (_exportMessage != null) ...[
            const SizedBox(height: SBSpacing.md),
            SBInlineError(message: _exportMessage!, isWarning: true),
          ],
        ],
      ),
    );
  }

  Future<void> _prepareExport() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _exportMessage = null;
    });
    final store = context.read<WorkspaceStore>();
    final sourceTitle = store.file(widget.output.sourceFileId)?.title;
    try {
      final bytes = await SBPdfBuilder.fromOutput(
        widget.output,
        sourceTitle: sourceTitle,
      );
      if (!mounted) return;
      _pdfBytes = bytes;
      await Printing.sharePdf(
        bytes: bytes,
        filename: SBPdfBuilder.fileName(widget.output.title, widget.output.kind),
      );
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _hasExport = true;
      });
      store.toast('PDF hazır. Paylaşabilir veya yazdırabilirsin.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportMessage =
            'PDF oluşturulamadı. Lütfen tekrar dene. ($error)';
      });
    }
  }

  Future<void> _reshareOrPrint() async {
    final bytes = _pdfBytes;
    if (bytes == null) {
      await _prepareExport();
      return;
    }
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: SBPdfBuilder.fileName(widget.output.title, widget.output.kind),
      );
    } catch (_) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: SBPdfBuilder.fileName(widget.output.title, widget.output.kind),
      );
    }
  }

  void _showSavePicker() {
    final store = context.read<WorkspaceStore>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SBColors.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final courses = store.workspace.courses;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SBSpacing.sm,
                    vertical: SBSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          'Kapat',
                          style: SBTypography.bodyMedium.copyWith(
                            color: SBColors.blue,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Bölüme Kaydet',
                          textAlign: TextAlign.center,
                          style: SBTypography.titleMedium.copyWith(
                            color: SBColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 64),
                    ],
                  ),
                ),
                Expanded(
                  child: courses.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(SBSpacing.lg),
                          child: SBEmptyState(
                            icon: 'folder',
                            title: 'Henüz ders yok',
                            message:
                                "Önce Drive'da bir ders ve bölüm oluştur, sonra çıktıyı oraya kaydet.",
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(SBSpacing.lg),
                          children: [
                            for (final course in courses) ...[
                              Text(
                                course.title.toUpperCase(),
                                style: SBTypography.labelSmall.copyWith(
                                  color: SBColors.muted,
                                ),
                              ),
                              const SizedBox(height: SBSpacing.sm),
                              if (course.sections.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: SBSpacing.md,
                                  ),
                                  child: Text(
                                    'Bu derste bölüm yok',
                                    style: SBTypography.bodySmall.copyWith(
                                      color: SBColors.muted,
                                    ),
                                  ),
                                )
                              else
                                for (final section in course.sections)
                                  GestureDetector(
                                    onTap: () async {
                                      Navigator.of(sheetContext).pop();
                                      await store.saveOutput(
                                        widget.output.id,
                                        courseId: course.id,
                                        sectionId: section.id,
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        bottom: SBSpacing.sm,
                                      ),
                                      padding: const EdgeInsets.all(
                                        SBSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SBColors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: SBColors.softLine,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SBIcon(
                                            'tray.full',
                                            size: 16,
                                            color: SBColors.blue,
                                          ),
                                          const SizedBox(width: SBSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              section.title,
                                              style: SBTypography.bodyMedium
                                                  .copyWith(
                                                    color: SBColors.navy,
                                                  ),
                                            ),
                                          ),
                                          SBIcon(
                                            'chevron.right',
                                            size: 12,
                                            color: SBColors.softText,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              const SizedBox(height: SBSpacing.md),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
