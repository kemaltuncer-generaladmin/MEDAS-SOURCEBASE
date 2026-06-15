import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_effects.dart';
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
import 'baseforce_style.dart';
import 'factory_shared.dart';
import 'sb_generation_cost.dart';

enum _QuestionType {
  multipleChoice('Test'),
  clinicalCase('Klinik Vaka'),
  qlinik('Klinik');

  const _QuestionType(this.label);

  final String label;
}

enum _Difficulty {
  easy('Kolay'),
  medium('Orta'),
  hard('Zor'),
  veryHard('Çok Zor');

  const _Difficulty(this.label);

  final String label;
}

/// Port of QuestionFactoryView.
class QuestionFactoryView extends StatefulWidget {
  const QuestionFactoryView({super.key});

  @override
  State<QuestionFactoryView> createState() => _QuestionFactoryViewState();
}

class _QuestionFactoryViewState extends State<QuestionFactoryView> {
  bool _isGenerating = false;
  _QuestionType _questionType = _QuestionType.multipleChoice;
  _Difficulty _difficulty = _Difficulty.medium;
  int _questionCount = 20;
  bool _addExplanation = true;
  SBQualityTier _quality = SBQualityTier.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  DriveFile? _readyFile(WorkspaceStore store) {
    for (final file in store.allFiles) {
      if (store.selectedSourceIds.contains(file.id) &&
          store.isReadyForGeneration(file)) {
        return file;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;
    final readyFile = _readyFile(store);
    final canGenerate = readyFile != null;
    final costLabel = SBGenerationCost.compactEstimate(
      GeneratedKind.question,
      requestedCount: _questionCount,
      quality: _quality.label,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Soru Çözümü',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      body: SBPageBackground(
        tone: SBPageTone.cool,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BaseForceFactoryStyle.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const SBLoadingState(
                  icon: 'questionmark.circle',
                  title: 'Soru çözümü yükleniyor',
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
                    eyebrow: 'Çözüm pratiği',
                    title: 'Soru setini hazırla',
                    message:
                        'Kaynağı 5 şıklı, açıklamalı sınav pratiğine çevir.',
                    icon: 'questionmark.circle.fill',
                    tint: SBColors.cyan,
                    size: SBHeroSize.compact,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'doc.text',
                          value: '$_questionCount',
                          label: 'soru',
                          tint: SBColors.cyan),
                      SBMetricRibbonItem(
                          icon: 'chart.bar.fill',
                          value: _difficulty.label,
                          label: 'zorluk',
                          tint: SBColors.orange),
                      SBMetricRibbonItem(
                          icon: 'checkmark.bubble.fill',
                          value: _addExplanation ? 'Açık' : 'Kısa',
                          label: 'açıklama',
                          tint: SBColors.green),
                    ]),
                  ),
                ),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                    index: 1, child: _selectedSourcesSection(store, router)),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(index: 2, child: _settingsPanel()),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                  index: 3,
                  child: SBButton(
                    'Soru setini hazırla • $costLabel',
                    icon: 'wand.and.stars',
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    isLoading: _isGenerating,
                    isDisabled: !canGenerate,
                    fullWidth: true,
                    onPressed: () => _generate(store, router, readyFile),
                  ),
                ),
                if (!canGenerate) ...[
                  const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                  SBEntrance(
                    index: 4,
                    child: SBButton(
                      'Hazır kaynak seç',
                      icon: 'folder',
                      variant: SBButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => openFactorySourcePicker(
                          router, AppRoute.questionFactory),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedSourcesSection(WorkspaceStore store, AppRouter router) {
    final selectedSources = store.selectedSourceIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kaynak',
            style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.md),
        if (selectedSources.isEmpty)
          SBCommandCard(
            tint: SBColors.cyan,
            onTap: () =>
                openFactorySourcePicker(router, AppRoute.questionFactory),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SBIconTile(
                        icon: 'doc.text.magnifyingglass',
                        tint: SBColors.cyan,
                        size: 42,
                        radius: 12),
                    const SizedBox(width: SBSpacing.md),
                    Text('Önce bir kaynak seç',
                        style: SBTypography.titleSmall
                            .copyWith(color: SBColors.navy)),
                  ],
                ),
                const SizedBox(height: SBSpacing.md),
                Text('Hazır bir kaynak seç.',
                    style:
                        SBTypography.bodySmall.copyWith(color: SBColors.muted)),
                const SizedBox(height: SBSpacing.md),
                Wrap(
                  spacing: SBSpacing.xs,
                  children: [
                    FactoryShared.tagChip(
                        label: 'Hazır kaynak', color: SBColors.blue),
                    FactoryShared.tagChip(
                        label: 'PDF / PPT(X) / DOC(X)',
                        color: SBColors.purple),
                  ],
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final sourceId in selectedSources)
                if (store.file(sourceId) != null)
                  _sourceChip(store.file(sourceId)!),
              GestureDetector(
                onTap: () =>
                    openFactorySourcePicker(router, AppRoute.questionFactory),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SBSpacing.md, vertical: SBSpacing.sm),
                  decoration: BoxDecoration(
                    color: SBColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: SBColors.blue.withValues(alpha: 0.3),
                        width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SBIcon('plus', size: 14, color: SBColors.blue),
                      const SizedBox(width: SBSpacing.xs),
                      Text('Kaynak ekle',
                          style: SBTypography.caption
                              .copyWith(color: SBColors.blue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _sourceChip(DriveFile file) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  file.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(color: SBColors.navy),
                ),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  '${file.courseTitle} • ${file.sectionTitle} • ${file.sizeLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(color: SBColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsPanel() {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _settingHeader('list.bullet', 'Tip'),
          const SizedBox(height: SBSpacing.sm),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final type in _QuestionType.values)
                _segmentButton(type.label, _questionType == type,
                    () => setState(() => _questionType = type)),
            ],
          ),
          Divider(height: SBSpacing.xxl, color: SBColors.softLine),
          _settingHeader('chart.bar', 'Zorluk'),
          const SizedBox(height: SBSpacing.sm),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final diff in _Difficulty.values)
                _segmentButton(diff.label, _difficulty == diff,
                    () => setState(() => _difficulty = diff)),
            ],
          ),
          Divider(height: SBSpacing.xxl, color: SBColors.softLine),
          FactoryShared.settingLabel('Sayı'),
          const SizedBox(height: SBSpacing.sm),
          _stepper(),
          Divider(height: SBSpacing.xxl, color: SBColors.softLine),
          FactoryShared.toggleRow(
            label: 'Açıklama',
            value: _addExplanation,
            onChanged: (v) => setState(() => _addExplanation = v),
          ),
          const SizedBox(height: SBSpacing.lg),
          SBQualityPicker(
            selection: _quality,
            onChanged: (tier) => setState(() => _quality = tier),
          ),
        ],
      ),
    );
  }

  Widget _settingHeader(String icon, String label) {
    return Row(
      children: [
        SBIcon(icon, size: 14, color: SBColors.blue),
        const SizedBox(width: SBSpacing.xs),
        Text(label,
            style: SBTypography.labelSmall.copyWith(color: SBColors.navy)),
      ],
    );
  }

  Widget _segmentButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SBSpacing.md, horizontal: SBSpacing.lg),
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

  Widget _stepper() {
    const range = (5, 50);
    const step = 5;
    final canDecrease = _questionCount > range.$1;
    final canIncrease = _questionCount < range.$2;

    return Row(
      children: [
        GestureDetector(
          onTap: canDecrease
              ? () => setState(() => _questionCount -= step)
              : null,
          child: SBIcon('minus.circle.fill',
              size: 28,
              color: canDecrease ? SBColors.blue : SBColors.softLine),
        ),
        Expanded(
          child: Text(
            '$_questionCount',
            textAlign: TextAlign.center,
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy),
          ),
        ),
        GestureDetector(
          onTap: canIncrease
              ? () => setState(() => _questionCount += step)
              : null,
          child: SBIcon('plus.circle.fill',
              size: 28,
              color: canIncrease ? SBColors.blue : SBColors.softLine),
        ),
      ],
    );
  }

  Future<void> _generate(
      WorkspaceStore store, AppRouter router, DriveFile? readyFile) async {
    if (readyFile == null) {
      store.toast('Önce hazır bir kaynak seç.');
      return;
    }
    setState(() => _isGenerating = true);
    final mode = [
      _questionType.label,
      _difficulty.label,
      '$_questionCount soru',
      '5 şıklı',
      _addExplanation ? 'açıklamalı' : 'kısa geri bildirimli',
      '5 şık',
      _quality.label,
    ].join(' • ');

    final job = await store.enqueueGeneration(
      file: readyFile,
      kind: GeneratedKind.question,
      label: 'Soru Seti',
      surface: 'Üret Soru Çözümü',
      mode: mode,
      extraOptions: {
        'question_type': _questionType.label,
        'difficulty': _difficulty.label,
        'explanations': '$_addExplanation',
      },
    );
    if (!mounted) return;
    setState(() => _isGenerating = false);
    if (job != null) {
      SBHaptics.success();
      router.navigate(AppRoute.queue());
    }
  }
}
