import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_empty_state.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_file_card.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';
import '../baseforce/sb_generation_cost.dart';

enum _SummaryMode {
  quickReview('Hızlı'),
  examMorningCritical('Kritikler'),
  commonlyConfused('Karıştırılanlar'),
  clinicalTips('Klinik ipucu'),
  basicScienceMechanism('Mekanizma'),
  tusHighYield('TUS');

  const _SummaryMode(this.label);

  final String label;
}

enum _LengthTarget {
  threeMinutes('3 dk'),
  sevenMinutes('7 dk'),
  fifteenMinutes('15 dk'),
  detailedFinalReview('Detaylı');

  const _LengthTarget(this.label);

  final String label;
}

enum _OutputFormat {
  bulletPoints('Madde'),
  miniTable('Mini tablo'),
  clinicalTipCards('İpucu kartı'),
  questionAnswer('Soru-cevap'),
  algorithmicFlow('Akış');

  const _OutputFormat(this.label);

  final String label;
}

enum _Quality {
  economy('Ekonomik'),
  standard('Standart'),
  premium('Premium');

  const _Quality(this.label);

  final String label;
}

/// Port of ExamMorningView ("Sınav Sabahı").
class ExamMorningView extends StatefulWidget {
  const ExamMorningView({super.key});

  @override
  State<ExamMorningView> createState() => _ExamMorningViewState();
}

class _ExamMorningViewState extends State<ExamMorningView> {
  bool _isGenerating = false;
  _SummaryMode _summaryMode = _SummaryMode.examMorningCritical;
  _LengthTarget _lengthTarget = _LengthTarget.sevenMinutes;
  Set<_OutputFormat> _outputFormats = {
    _OutputFormat.bulletPoints,
    _OutputFormat.miniTable,
  };
  _Quality _quality = _Quality.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;
    final selectedSources = store.selectedSourceIds;
    final hasSources = selectedSources.isNotEmpty;
    final blockedReasons = [
      for (final id in selectedSources)
        if (store.file(id) != null &&
            !store.isReadyForGeneration(store.file(id)!))
          '${store.file(id)!.title}: Hazır değil',
    ];
    final canGenerate = hasSources && blockedReasons.isEmpty;
    final readySourceCount = selectedSources
        .map(store.file)
        .whereType<DriveFile>()
        .where(store.isReadyForGeneration)
        .length;
    final costLabel = SBGenerationCost.compactEstimate(
      GeneratedKind.examMorningSummary,
      sourceCount: readySourceCount,
      quality: _quality.label,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Sınav Sabahı',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      body: SBPageBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const SBLoadingState(
                  icon: 'bolt',
                  title: 'Sınav Sabahı yükleniyor',
                  message: 'Kaynaklar hazırlanıyor...',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else ...[
                SBSignatureHero(
                  eyebrow: 'Son tekrar',
                  title: 'Sınav Sabahı',
                  message: 'Kısa, yüksek verim tekrar.',
                  icon: 'alarm.fill',
                  tint: SBColors.orange,
                  footer: SBMetricRibbon(items: [
                    SBMetricRibbonItem(
                        icon: 'books.vertical',
                        value: '${selectedSources.length}',
                        label: 'kaynak',
                        tint: SBColors.orange),
                    SBMetricRibbonItem(
                        icon: 'timer',
                        value: _lengthTarget.label,
                        label: 'süre',
                        tint: SBColors.blue),
                    SBMetricRibbonItem(
                        icon: 'bolt',
                        value: _summaryMode.label,
                        label: 'mod',
                        tint: SBColors.purple),
                  ]),
                ),
                const SizedBox(height: SBSpacing.lg),
                _step1Sources(
                    store, router, selectedSources, hasSources, blockedReasons),
                const SizedBox(height: SBSpacing.lg),
                _step2SummaryMode(),
                const SizedBox(height: SBSpacing.lg),
                _step3LengthFormat(),
                const SizedBox(height: SBSpacing.lg),
                _step4Quality(readySourceCount),
                const SizedBox(height: SBSpacing.lg),
                SBButton(
                  canGenerate
                      ? 'Son tekrarı hazırla • $costLabel'
                      : (hasSources ? 'Kaynak hazır değil' : 'Kaynak seç'),
                  icon: canGenerate
                      ? 'alarm'
                      : (hasSources ? 'exclamationmark.triangle' : 'folder'),
                  variant: SBButtonVariant.primary,
                  size: SBButtonSize.large,
                  isLoading: _isGenerating,
                  isDisabled: _isGenerating || (hasSources && !canGenerate),
                  fullWidth: true,
                  onPressed: () {
                    if (canGenerate) {
                      _generate(store, router, selectedSources);
                    } else if (!hasSources) {
                      router.beginSourceSelection(
                          from: AppRoute.baseForce,
                          destination: SourcePickerDestination.toRoute(
                              AppRoute.examMorning));
                    } else {
                      store.toast('Seçili kaynak hazır değil.');
                    }
                  },
                ),
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step1Sources(WorkspaceStore store, AppRouter router,
      Set<String> selectedSources, bool hasSources, List<String> blockedReasons) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _stepHeader(1, 'Kaynak')),
              GestureDetector(
                onTap: () => router.beginSourceSelection(
                    from: AppRoute.baseForce,
                    destination:
                        SourcePickerDestination.toRoute(AppRoute.examMorning)),
                child: Row(
                  children: [
                    SBIcon('folder', size: 14, color: SBColors.blue),
                    const SizedBox(width: SBSpacing.xs),
                    Text(hasSources ? 'Değiştir' : 'Seç',
                        style: SBTypography.labelSmall
                            .copyWith(color: SBColors.blue)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          if (!hasSources)
            const SBEmptyState(
              icon: 'folder',
              title: 'Kaynak seçilmedi',
              message: 'Hazır bir kaynak seç.',
            )
          else
            Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                for (final sourceId in selectedSources)
                  if (store.file(sourceId) != null)
                    _sourceChip(store, store.file(sourceId)!),
              ],
            ),
          for (final reason in blockedReasons) ...[
            const SizedBox(height: SBSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.md),
              decoration: BoxDecoration(
                color: SBColors.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SBIcon('exclamationmark.triangle',
                      size: 16, color: SBColors.orange),
                  const SizedBox(width: SBSpacing.md),
                  Expanded(
                    child: Text(reason,
                        style: SBTypography.bodySmall
                            .copyWith(color: SBColors.navy)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sourceChip(WorkspaceStore store, DriveFile file) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SBFileKindBadge(kind: sbFileKindFrom(file.kind), compact: true),
          const SizedBox(width: SBSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.caption.copyWith(color: SBColors.navy),
            ),
          ),
          const SizedBox(width: SBSpacing.xs),
          GestureDetector(
            onTap: () => store.setSelectedSources(
                {...store.selectedSourceIds}..remove(file.id)),
            child:
                SBIcon('xmark.circle.fill', size: 14, color: SBColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _step2SummaryMode() {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepHeader(2, 'Mod'),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final mode in _SummaryMode.values)
                _segmentButton(mode.label, _summaryMode == mode,
                    () => setState(() => _summaryMode = mode)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step3LengthFormat() {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepHeader(3, 'Süre ve çalışma'),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final length in _LengthTarget.values)
                _segmentButton(length.label, _lengthTarget == length,
                    () => setState(() => _lengthTarget = length)),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final format in _OutputFormat.values)
                _formatButton(format.label, _outputFormats.contains(format),
                    () {
                  setState(() {
                    if (_outputFormats.contains(format)) {
                      if (_outputFormats.length > 1) {
                        _outputFormats = {..._outputFormats}..remove(format);
                      }
                    } else {
                      _outputFormats = {..._outputFormats, format};
                    }
                  });
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step4Quality(int readySourceCount) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepHeader(4, 'Kalite'),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final quality in _Quality.values)
                _segmentButton(quality.label, _quality == quality,
                    () => setState(() => _quality = quality)),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SBSpacing.md),
            decoration: BoxDecoration(
              color: SBColors.selectedBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SBIcon('creditcard', size: 16, color: SBColors.blue),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Text(
                    'Maliyet: ${SBGenerationCost.label(GeneratedKind.examMorningSummary, sourceCount: readySourceCount, quality: _quality.label)}.',
                    style:
                        SBTypography.bodySmall.copyWith(color: SBColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader(int number, String title) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration:
              BoxDecoration(color: SBColors.blue, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$number',
              style:
                  SBTypography.labelMedium.copyWith(color: Colors.white)),
        ),
        const SizedBox(width: SBSpacing.md),
        Text(title,
            style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
      ],
    );
  }

  Widget _segmentButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SBSpacing.md, horizontal: SBSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? SBColors.blue : SBColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? SBColors.blue : SBColors.softLine),
        ),
        child: Text(
          label,
          style: SBTypography.labelSmall
              .copyWith(color: isSelected ? Colors.white : SBColors.navy),
        ),
      ),
    );
  }

  Widget _formatButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SBSpacing.md, horizontal: SBSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? SBColors.selectedBlue : SBColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? SBColors.blue : SBColors.softLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              SBIcon('checkmark', size: 12, color: SBColors.blue),
              const SizedBox(width: SBSpacing.xs),
            ],
            Text(
              label,
              style: SBTypography.caption.copyWith(
                  color: isSelected ? SBColors.blue : SBColors.navy),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(WorkspaceStore store, AppRouter router,
      Set<String> selectedSources) async {
    DriveFile? file;
    for (final id in selectedSources) {
      final f = store.file(id);
      if (f != null && store.isReadyForGeneration(f)) {
        file = f;
        break;
      }
    }
    if (file == null) {
      store.toast('Önce hazır bir kaynak seç.');
      return;
    }
    setState(() => _isGenerating = true);

    final formats = _outputFormats.map((f) => f.label).toList()..sort();
    final job = await store.enqueueGeneration(
      file: file,
      kind: GeneratedKind.examMorningSummary,
      label: 'Sınav Sabahı Özeti',
      surface: 'Üretim Sınav Sabahı',
      mode:
          '${_summaryMode.label} • ${_lengthTarget.label} • ${_quality.label}',
      extraOptions: {
        'summary_mode': _summaryMode.label,
        'length_target': _lengthTarget.label,
        'output_format': formats.join('+'),
      },
    );
    if (!mounted) return;
    setState(() => _isGenerating = false);
    if (job != null) {
      SBHaptics.success();
      router.switchTab(AppRoute.baseForce);
      router.navigate(AppRoute.queue());
    }
  }
}
