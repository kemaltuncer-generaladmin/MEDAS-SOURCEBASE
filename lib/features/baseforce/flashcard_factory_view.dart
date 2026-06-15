import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';
import 'baseforce_style.dart';
import 'factory_shared.dart';
import 'sb_generation_cost.dart';

enum _CardStyle {
  classic('Klasik', 'rectangle.on.rectangle', 'classic'),
  cloze('Cloze', 'ellipsis', 'cloze'),
  rapidReview('Hızlı', 'arrow.triangle.2.circlepath', 'rapid_review');

  const _CardStyle(this.label, this.icon, this.backendValue);

  final String label;
  final String icon;
  final String backendValue;
}

enum _Difficulty {
  easy('Kolay'),
  medium('Orta'),
  hard('Zor');

  const _Difficulty(this.label);

  final String label;

  Color get color => switch (this) {
        _Difficulty.easy => SBColors.green,
        _Difficulty.medium => SBColors.orange,
        _Difficulty.hard => SBColors.red,
      };
}

/// Port of FlashcardFactoryView.
class FlashcardFactoryView extends StatefulWidget {
  const FlashcardFactoryView({super.key});

  @override
  State<FlashcardFactoryView> createState() => _FlashcardFactoryViewState();
}

class _FlashcardFactoryViewState extends State<FlashcardFactoryView> {
  bool _isGenerating = false;
  _CardStyle _cardStyle = _CardStyle.classic;
  int _cardCount = 10;
  _Difficulty _difficulty = _Difficulty.medium;
  bool _extractKeyConcepts = true;
  bool _addHints = true;
  SBQualityTier _quality = SBQualityTier.standard;

  static const _allowedCardCounts = [5, 10, 15, 20, 25];

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
      GeneratedKind.flashcard,
      requestedCount: _cardCount,
      quality: _quality.label,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Flashcard',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      body: SBPageBackground(
        tone: SBPageTone.cool,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(BaseForceFactoryStyle.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const SBLoadingState(
                  icon: 'rectangle.on.rectangle',
                  title: 'Flashcard çalışması yükleniyor',
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
                    eyebrow: 'Aktif hatırlama',
                    title: 'Ezber kartlarını hazırla',
                    message:
                        'Tanım, mekanizma ve sık karıştırılan noktaları kısa karta çevir.',
                    icon: 'rectangle.on.rectangle',
                    tint: SBColors.blue,
                    mode: SBHeroMode.selection,
                    size: SBHeroSize.compact,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'rectangle.on.rectangle',
                          value: '$_cardCount',
                          label: 'kart',
                          tint: SBColors.blue),
                      SBMetricRibbonItem(
                          icon: 'chart.bar.fill',
                          value: _difficulty.label,
                          label: 'zorluk',
                          tint: _difficulty.color),
                      SBMetricRibbonItem(
                          icon: 'doc.text',
                          value: readyFile == null ? 'Yok' : 'Hazır',
                          label: 'kaynak',
                          tint: readyFile == null
                              ? SBColors.orange
                              : SBColors.green),
                    ]),
                  ),
                ),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                  index: 1,
                  child: FactoryShared.sourcesPanel(
                    store: store,
                    prompt:
                        'Hazır bir kaynak seç; kartları birkaç saniyede hazırlayalım.',
                    selectedSources: store.selectedSourceIds,
                    onOpenSourcePicker: () => openFactorySourcePicker(
                        router, AppRoute.flashcardFactory),
                  ),
                ),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(index: 2, child: _settingsPanel()),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                  index: 3,
                  child: SBButton(
                    'Kartları birkaç saniyede hazırla • $costLabel',
                    icon: 'bolt.fill',
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    isLoading: _isGenerating,
                    isDisabled: !canGenerate,
                    fullWidth: true,
                    onPressed: () => _generate(store, router, readyFile),
                  ),
                ),
                if (!canGenerate) ...[
                  const SizedBox(
                      height: BaseForceFactoryStyle.screenSpacing),
                  SBEntrance(
                    index: 4,
                    child: SBButton(
                      'Hazır kaynak seç',
                      icon: 'folder',
                      variant: SBButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => openFactorySourcePicker(
                          router, AppRoute.flashcardFactory),
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

  Widget _settingsPanel() {
    return BaseForceFactoryStyle.panel(
      spacing: BaseForceFactoryStyle.settingsSpacing,
      children: [
        FactoryShared.settingsHeader(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FactoryShared.settingLabel('Stil'),
            const SizedBox(height: SBSpacing.sm),
            Row(
              children: [
                for (var i = 0; i < _CardStyle.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: SBSpacing.sm),
                  FactoryShared.segmentButton(
                    label: _CardStyle.values[i].label,
                    icon: _CardStyle.values[i].icon,
                    isSelected: _cardStyle == _CardStyle.values[i],
                    onTap: () =>
                        setState(() => _cardStyle = _CardStyle.values[i]),
                  ),
                ],
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FactoryShared.settingLabel('Sayı'),
            const SizedBox(height: SBSpacing.sm),
            FactoryShared.countGrid(
              counts: _allowedCardCounts,
              selected: _cardCount,
              onChanged: (count) => setState(() => _cardCount = count),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FactoryShared.settingLabel('Zorluk'),
            const SizedBox(height: SBSpacing.sm),
            Row(
              children: [
                for (var i = 0; i < _Difficulty.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: SBSpacing.sm),
                  FactoryShared.coloredChip(
                    label: _Difficulty.values[i].label,
                    color: _Difficulty.values[i].color,
                    isSelected: _difficulty == _Difficulty.values[i],
                    onTap: () =>
                        setState(() => _difficulty = _Difficulty.values[i]),
                  ),
                ],
              ],
            ),
          ],
        ),
        Column(
          children: [
            FactoryShared.toggleRow(
              label: 'Kavram çıkar',
              value: _extractKeyConcepts,
              onChanged: (v) => setState(() => _extractKeyConcepts = v),
            ),
            const SizedBox(height: SBSpacing.sm),
            FactoryShared.toggleRow(
              label: 'İpucu ekle',
              value: _addHints,
              onChanged: (v) => setState(() => _addHints = v),
            ),
          ],
        ),
        SBQualityPicker(
          selection: _quality,
          onChanged: (tier) => setState(() => _quality = tier),
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
      _cardStyle.label,
      _difficulty.label,
      '$_cardCount kart',
      _extractKeyConcepts ? 'önemli kavram çıkar' : 'tüm kapsamdan seç',
      _addHints ? 'ipucu ekle' : 'ipucu ekleme',
      _quality.label,
    ].join(' • ');

    final job = await store.enqueueGeneration(
      file: readyFile,
      kind: GeneratedKind.flashcard,
      label: 'Flashcard Seti',
      surface: 'Üret Flashcard',
      mode: mode,
      extraOptions: {
        'card_style': _cardStyle.backendValue,
        'difficulty': _difficulty.label,
        'extract_key_concepts': '$_extractKeyConcepts',
        'add_hints': '$_addHints',
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
