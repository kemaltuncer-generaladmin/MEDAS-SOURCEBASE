import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_effects.dart';
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

enum _ClinicalType {
  tusCase('TUS vaka'),
  clinicalDecision('Karar'),
  emergencyApproach('Acil'),
  diagnosticCase('Tanı'),
  treatmentChoice('Tedavi'),
  basicToClinical('Temelden kliniğe');

  const _ClinicalType(this.label);

  final String label;
}

enum _Difficulty {
  easy('Kolay'),
  medium('Orta'),
  hard('Zor'),
  expert('Uzman');

  const _Difficulty(this.label);

  final String label;
}

enum _ClinicalLevel {
  singleCase('Tek vaka'),
  threeShortCases('3 vaka'),
  questionAnswerCase('Soru-cevap'),
  explainedCase('Açıklamalı'),
  stepwiseReasoning('Adım adım');

  const _ClinicalLevel(this.label);

  final String label;
}

enum _Quality {
  economy('Ekonomik'),
  standard('Standart'),
  premium('Premium');

  const _Quality(this.label);

  final String label;
}

/// Port of ClinicalView ("Klinik Senaryo").
class ClinicalView extends StatefulWidget {
  const ClinicalView({super.key});

  @override
  State<ClinicalView> createState() => _ClinicalViewState();
}

class _ClinicalViewState extends State<ClinicalView> {
  bool _isGenerating = false;
  _ClinicalType _clinicalType = _ClinicalType.tusCase;
  _Difficulty _difficulty = _Difficulty.medium;
  _ClinicalLevel _level = _ClinicalLevel.singleCase;
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
      GeneratedKind.clinicalScenario,
      sourceCount: readySourceCount,
      quality: _quality.label,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Klinik Senaryo',
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
                  icon: 'cross.case',
                  title: 'Klinik Senaryo yükleniyor',
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
                SBEntrance(
                  index: 0,
                  child: SBSignatureHero(
                    eyebrow: 'Klinik akıl yürütme',
                    title: 'Klinik Senaryo',
                    message: 'Kaynağı vaka pratiğine çevir.',
                    icon: 'cross.case.fill',
                    tint: SBColors.purple,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'books.vertical',
                          value: '${selectedSources.length}',
                          label: 'kaynak',
                          tint: SBColors.purple),
                      SBMetricRibbonItem(
                          icon: 'stethoscope',
                          value: _clinicalType.label,
                          label: 'senaryo',
                          tint: SBColors.orange),
                      SBMetricRibbonItem(
                          icon: 'chart.bar.fill',
                          value: _difficulty.label,
                          label: 'zorluk',
                          tint: SBColors.green),
                    ]),
                  ),
                ),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                    index: 1,
                    child: _step1Sources(store, router, selectedSources,
                        hasSources, blockedReasons)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                    index: 2,
                    child: _stepCard(2, 'Senaryo', [
                      for (final type in _ClinicalType.values)
                        _segmentButton(type.label, _clinicalType == type,
                            () => setState(() => _clinicalType = type)),
                    ])),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 3,
                  child: SBCard(
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _stepHeader(3, 'Zorluk ve biçim'),
                        const SizedBox(height: SBSpacing.md),
                        Wrap(
                          spacing: SBSpacing.sm,
                          runSpacing: SBSpacing.sm,
                          children: [
                            for (final diff in _Difficulty.values)
                              _segmentButton(
                                  diff.label,
                                  _difficulty == diff,
                                  () => setState(() => _difficulty = diff)),
                          ],
                        ),
                        const SizedBox(height: SBSpacing.md),
                        Wrap(
                          spacing: SBSpacing.sm,
                          runSpacing: SBSpacing.sm,
                          children: [
                            for (final level in _ClinicalLevel.values)
                              _segmentButton(level.label, _level == level,
                                  () => setState(() => _level = level)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                    index: 4,
                    child: _stepCard(4, 'Kalite', [
                      for (final quality in _Quality.values)
                        _segmentButton(quality.label, _quality == quality,
                            () => setState(() => _quality = quality)),
                    ])),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 5, child: _summaryBar(costLabel)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 6,
                  child: SBButton(
                    canGenerate
                        ? 'Senaryoyu hazırla • $costLabel'
                        : (hasSources ? 'Kaynak hazır değil' : 'Kaynak seç'),
                    icon: canGenerate
                        ? 'cross.case'
                        : (hasSources
                            ? 'exclamationmark.triangle'
                            : 'folder'),
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    isLoading: _isGenerating,
                    isDisabled:
                        _isGenerating || (hasSources && !canGenerate),
                    fullWidth: true,
                    onPressed: () {
                      if (canGenerate) {
                        _generate(store, router, selectedSources);
                      } else if (!hasSources) {
                        router.beginSourceSelection(
                            from: AppRoute.baseForce,
                            destination: SourcePickerDestination.toRoute(
                                AppRoute.clinical));
                      } else {
                        store.toast('Seçili kaynak hazır değil.');
                      }
                    },
                  ),
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
                        SourcePickerDestination.toRoute(AppRoute.clinical)),
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

  Widget _stepCard(int number, String title, List<Widget> chips) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepHeader(number, title),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: chips,
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
              BoxDecoration(color: SBColors.purple, shape: BoxShape.circle),
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
      onTap: () {
        SBHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SBSpacing.md, horizontal: SBSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? SBColors.purple : SBColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? SBColors.purple : SBColors.softLine),
        ),
        child: Text(
          label,
          style: SBTypography.labelSmall
              .copyWith(color: isSelected ? Colors.white : SBColors.navy),
        ),
      ),
    );
  }

  Widget _summaryBar(String costLabel) {
    return SBCard(
      radius: 16,
      child: Row(
        children: [
          const SBIconTile(
              icon: 'doc.text', tint: Color(0xFF7B3FF2), size: 42, radius: 12),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_clinicalType.label} • ${_difficulty.label} • ${_level.label}',
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy),
                ),
                const SizedBox(height: SBSpacing.xs),
                Text(
                  'Maliyet: $costLabel · son tutar üretimde netleşir',
                  style: SBTypography.caption.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
        ],
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

    final job = await store.enqueueGeneration(
      file: file,
      kind: GeneratedKind.clinicalScenario,
      label: 'Klinik Senaryo',
      surface: 'Üretim Klinik Senaryo',
      mode:
          '${_clinicalType.label} • ${_difficulty.label} • ${_level.label} • ${_quality.label}',
      extraOptions: {
        'scenario_type': _clinicalType.label,
        'difficulty': _difficulty.label,
        'output_format': _level.label,
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
