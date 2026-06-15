import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_effects.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_status_badge.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';
import '../study/sb_output_style.dart';
import 'result_content.dart';

class _GenerationResult {
  const _GenerationResult({
    required this.kind,
    required this.title,
    required this.sourceFileId,
    required this.sourceTitle,
    this.createdAtLabel,
    required this.contentText,
  });

  final GeneratedKind kind;
  final String title;
  final String sourceFileId;
  final String sourceTitle;
  final String? createdAtLabel;
  final String contentText;

  String? get mcCostLabel => null;
}

/// Port of ResultView.
class ResultView extends StatefulWidget {
  const ResultView({super.key, required this.jobId});

  final String jobId;

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  _GenerationResult? _result;
  bool _isLoading = true;
  String? _errorMessage;
  bool _didForwardToStudy = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _monitorResult());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _monitorResult({bool force = false}) async {
    if (force) {
      _didForwardToStudy = false;
      setState(() => _errorMessage = null);
    }
    await _loadResult();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_didForwardToStudy || !mounted) {
        timer.cancel();
        return;
      }
      final store = context.read<WorkspaceStore>();
      final stillActive =
          store.generationJobs.any((j) => j.id == widget.jobId && j.isActive);
      await _loadResult();
      if (!stillActive && !_didForwardToStudy) timer.cancel();
    });
  }

  GeneratedOutput? _findOutput(WorkspaceStore store) {
    for (final file in store.allFiles) {
      for (final output in file.generated) {
        if (output.jobId == widget.jobId || output.id == widget.jobId) {
          return output;
        }
      }
    }
    for (final bundle in store.workspace.collections) {
      for (final output in bundle.outputs) {
        if (output.jobId == widget.jobId || output.id == widget.jobId) {
          return output;
        }
      }
    }
    return null;
  }

  Future<void> _loadResult() async {
    if (!mounted) return;
    final store = context.read<WorkspaceStore>();
    await store.loadWorkspace();
    if (!mounted) return;

    final output = _findOutput(store);
    if (output != null) {
      _forwardToStudy(output.id);
      return;
    }

    final job = store.job(widget.jobId);
    if (job != null) {
      final outputId = job.output?.id ?? job.outputId;
      if (outputId != null && outputId.trim().isNotEmpty) {
        _forwardToStudy(outputId);
        return;
      }
      if (job.status == SBGenerationStatus.failed) {
        setState(() {
          _result = null;
          _errorMessage = job.failureMessage ?? 'Üretim tamamlanamadı.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _result = _GenerationResult(
          kind: job.kind,
          title: job.output?.title ?? job.kind.titleLabel,
          sourceFileId: job.sourceFileId,
          sourceTitle: job.sourceTitle,
          createdAtLabel: job.output?.updatedLabel,
          contentText: job.output?.contentText ??
              job.output?.detail ??
              _progressText(job),
        );
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _result = null;
      _errorMessage = store.errorMessage;
      _isLoading = false;
    });
  }

  String _progressText(SBWorkspaceGenerationJob job) => switch (job.status) {
        SBGenerationStatus.queued => 'Çalışma kuyruğa eklendi.',
        SBGenerationStatus.running =>
          'Hazırlanıyor • ${(job.progress * 100).round()}%',
        SBGenerationStatus.completed => 'Çalışma hazır. Kaydediliyor.',
        SBGenerationStatus.failed =>
          job.failureMessage ?? 'Üretim tamamlanamadı.',
      };

  void _forwardToStudy(String outputId) {
    final trimmed = outputId.trim();
    if (trimmed.isEmpty || _didForwardToStudy) return;
    _didForwardToStudy = true;
    _pollTimer?.cancel();
    setState(() => _isLoading = false);
    context
        .read<AppRouter>()
        .replaceCurrent(AppRoute.studyOutput(outputId: trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text(result?.title ?? 'Çalışma',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      body: SBPageBackground(
        tone: SBPageTone.cool,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const SBLoadingState(
                  icon: 'checkmark.seal',
                  title: 'Sonuç yükleniyor',
                  message: 'Üretim sonucu hazırlanıyor...',
                )
              else if (_errorMessage != null)
                SBErrorState(
                  title: 'Sonuç yüklenemedi',
                  message: _errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => _monitorResult(force: true),
                )
              else if (result != null) ...[
                SBEntrance(index: 0, child: _headerHero(result)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 0, child: _resultPreviewCard(result)),
                const SizedBox(height: SBSpacing.lg),
                if (result.contentText.trim().isNotEmpty)
                  SBEntrance(
                    index: 1,
                    child: RichResultContentView(
                      kind: result.kind,
                      title: result.title,
                      sourceTitle: result.sourceTitle,
                      contentText: result.contentText,
                    ),
                  )
                else
                  SBEntrance(index: 1, child: _emptyContentCard()),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                    index: 2,
                    child: _quickActionsSection(store, router, result)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 3,
                  child: SBButton(
                    'Çalışma görünümünde aç',
                    icon: 'play.rectangle',
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    fullWidth: true,
                    onPressed: () {
                      final output = _findOutput(store);
                      if (output == null) {
                        store.toast('Hazır çalışma bulunamadı.');
                        return;
                      }
                      router.navigate(
                          AppRoute.studyOutput(outputId: output.id));
                    },
                  ),
                ),
              ] else ...[
                Text('Çalışma hazır olunca burada görünür.',
                    style: SBTypography.bodyMedium
                        .copyWith(color: SBColors.muted)),
                const SizedBox(height: SBSpacing.lg),
                SBCard(
                  child: Padding(
                    padding: const EdgeInsets.all(SBSpacing.xl),
                    child: Column(
                      children: [
                        SBIcon('doc.text.magnifyingglass',
                            size: 32, color: SBColors.blue),
                        const SizedBox(height: SBSpacing.md),
                        Text('Sonuç bekleniyor',
                            style: SBTypography.titleSmall
                                .copyWith(color: SBColors.navy)),
                        const SizedBox(height: SBSpacing.md),
                        Text(
                          'Kaynağından bir çalışma başlatıp burada açabilirsin.',
                          textAlign: TextAlign.center,
                          style: SBTypography.bodySmall
                              .copyWith(color: SBColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SBSpacing.lg),
                SBButton(
                  'Yeni çalışma başlat',
                  icon: 'bolt.fill',
                  variant: SBButtonVariant.secondary,
                  size: SBButtonSize.large,
                  fullWidth: true,
                  onPressed: () => _regenerate(store, router),
                ),
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerHero(_GenerationResult result) {
    final tint = SBOutputStyle.outputColor(result.kind);
    return SBSignatureHero(
      eyebrow: 'Sonuç',
      title: '${SBOutputStyle.outputKindLabel(result.kind)} hazır',
      message:
          '${result.sourceTitle} kaynağından üretildi. Şimdi oku, kopyala ya da koleksiyonda aç.',
      icon: SBOutputStyle.outputIcon(result.kind),
      tint: tint,
      footer: SBMetricRibbon(items: [
        SBMetricRibbonItem(
            icon: 'checkmark.seal.fill',
            value: 'Hazır',
            label: 'durum',
            tint: SBColors.green),
        SBMetricRibbonItem(
            icon: 'doc.text',
            value: SBOutputStyle.outputKindLabel(result.kind),
            label: 'tür',
            tint: tint),
        SBMetricRibbonItem(
            icon: 'creditcard',
            value: result.mcCostLabel ?? 'Güvenli',
            label: 'MC',
            tint: SBColors.orange),
      ]),
    );
  }

  Widget _resultPreviewCard(_GenerationResult result) {
    final tint = SBOutputStyle.outputColor(result.kind);
    return SBCard(
      radius: 18,
      borderColor: tint.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIconTile(
                  icon: SBOutputStyle.outputIcon(result.kind),
                  tint: tint,
                  size: 46,
                  radius: 13),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(SBOutputStyle.outputKindLabel(result.kind),
                        style: SBTypography.titleSmall
                            .copyWith(color: SBColors.navy)),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      result.sourceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          SBTypography.caption.copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
              const SBStatusBadge(status: SBStatus.ready, compact: true),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Text(
            _previewText(result.contentText),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.bodySmall.copyWith(color: SBColors.navy),
          ),
          const SizedBox(height: SBSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(result.createdAtLabel ?? 'Bugün',
                    style: SBTypography.caption
                        .copyWith(color: SBColors.softText)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(result.mcCostLabel ?? 'Kaydedildi',
                    style: SBTypography.labelSmall.copyWith(color: tint)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyContentCard() {
    return SBCard(
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.all(SBSpacing.xl),
        child: Column(
          children: [
            SBIcon('exclamationmark.triangle',
                size: 32, color: SBColors.orange),
            const SizedBox(height: SBSpacing.md),
            Text('İçerik hazırlanamadı',
                style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
            const SizedBox(height: SBSpacing.md),
            Text('Kuyruktan tekrar deneyebilirsin.',
                textAlign: TextAlign.center,
                style:
                    SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _quickActionsSection(
      WorkspaceStore store, AppRouter router, _GenerationResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sonraki adımlar',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _quickAction('doc.on.doc', 'Metni kopyala',
                  SBColors.green, () => _export(store, result)),
            ),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: _quickAction(
                  'doc.text.magnifyingglass',
                  'Kaynağı aç',
                  SBColors.orange,
                  () => router.navigate(
                      AppRoute.fileDetail(fileId: result.sourceFileId))),
            ),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: _quickAction(
                  'arrow.triangle.2.circlepath',
                  'Aynı kaynaktan tekrar üret',
                  SBColors.purple,
                  () => _regenerate(store, router)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickAction(
      String icon, String label, Color color, VoidCallback onTap) {
    return SBCommandCard(
      tint: color,
      onTap: onTap,
      child: Column(
        children: [
          SBIconTile(icon: icon, tint: color, size: 56, radius: 14),
          const SizedBox(height: SBSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.caption.copyWith(color: SBColors.navy),
          ),
        ],
      ),
    );
  }

  String _previewText(String content) {
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return 'Önizleme henüz hazır değil.';
    if (cleaned.length <= 180) return cleaned;
    return '${cleaned.substring(0, 177).trim()}...';
  }

  void _export(WorkspaceStore store, _GenerationResult result) {
    final text =
        '${result.title}\nKaynak: ${result.sourceTitle}\n\n${result.contentText}';
    Clipboard.setData(ClipboardData(text: text));
    store.toast('Sonuç metni panoya kopyalandı.');
  }

  void _regenerate(WorkspaceStore store, AppRouter router) {
    final result = _result;
    if (result != null) {
      store.setSelectedSources({result.sourceFileId});
      final file = store.file(result.sourceFileId);
      if (file != null) store.selectFile(file);
    }
    final route = switch (_result?.kind) {
      GeneratedKind.flashcard => AppRoute.flashcardFactory,
      GeneratedKind.question => AppRoute.questionFactory,
      GeneratedKind.summary ||
      GeneratedKind.examMorningSummary =>
        AppRoute.summaryFactory,
      GeneratedKind.algorithm => AppRoute.algorithmFactory,
      GeneratedKind.comparison ||
      GeneratedKind.table =>
        AppRoute.comparisonFactory,
      _ => AppRoute.baseForce,
    };
    router.beginSourceSelection(
        from: AppRoute.baseForce,
        destination: SourcePickerDestination.toRoute(route));
  }
}
