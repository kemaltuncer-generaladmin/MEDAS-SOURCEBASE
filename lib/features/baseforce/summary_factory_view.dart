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

enum _SummaryLength {
  onePage('1 sayfa'),
  threePages('3 sayfa'),
  ultraBrief('Ultra kısa');

  const _SummaryLength(this.label);

  final String label;
}

enum _SummaryFocus {
  highYield('High-yield'),
  criticalPoints('Kritikler'),
  teacherEmphasis('Hoca vurgusu');

  const _SummaryFocus(this.label);

  final String label;
}

/// Port of SummaryFactoryView ("Sınav Sabahı Özeti").
class SummaryFactoryView extends StatefulWidget {
  const SummaryFactoryView({super.key});

  @override
  State<SummaryFactoryView> createState() => _SummaryFactoryViewState();
}

class _SummaryFactoryViewState extends State<SummaryFactoryView> {
  bool _isGenerating = false;
  _SummaryLength _summaryLength = _SummaryLength.onePage;
  _SummaryFocus _summaryFocus = _SummaryFocus.highYield;
  bool _markTerms = true;
  bool _toTable = true;
  bool _checklist = true;
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
    final costLabel = SBGenerationCost.compactEstimate(GeneratedKind.summary,
        quality: _quality.label);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Sınav Sabahı Özeti',
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
                  icon: 'doc.text',
                  title: 'Sınav Sabahı Özeti yükleniyor',
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
                    eyebrow: 'Sınav sabahı',
                    title: 'Son tekrarı hazırla',
                    message:
                        'Yüksek getirili başlıkları, tabloları ve kontrol listesini tek ekrana topla.',
                    icon: 'doc.text.fill',
                    tint: SBColors.purple,
                    size: SBHeroSize.compact,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'doc.text',
                          value: _summaryLength.label,
                          label: 'uzunluk',
                          tint: SBColors.purple),
                      SBMetricRibbonItem(
                          icon: 'target',
                          value: _summaryFocus.label,
                          label: 'odak',
                          tint: SBColors.blue),
                      SBMetricRibbonItem(
                          icon: 'square.stack.3d.up',
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
                    index: 1, child: _selectedSourcesSection(store, router)),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(index: 2, child: _settingsGrid()),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                  index: 3,
                  child: SBButton(
                    'Son tekrarı hazırla • $costLabel',
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
                  const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                  SBEntrance(
                    index: 4,
                    child: SBButton(
                      'Hazır kaynak seç',
                      icon: 'folder',
                      variant: SBButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => openFactorySourcePicker(
                          router, AppRoute.summaryFactory),
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
    return BaseForceFactoryStyle.panel(children: [
      Text('Kaynak',
          style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
      if (selectedSources.isEmpty)
        FactoryShared.sourceRequiredCard()
      else
        Wrap(
          spacing: SBSpacing.sm,
          runSpacing: SBSpacing.sm,
          children: [
            for (final sourceId in selectedSources.take(3))
              if (store.file(sourceId) != null)
                FactoryShared.sourceChip(store.file(sourceId)!),
            FactoryShared.addSourceChip(() =>
                openFactorySourcePicker(router, AppRoute.summaryFactory)),
          ],
        ),
    ]);
  }

  Widget _settingsGrid() {
    return Column(
      children: [
        BaseForceFactoryStyle.panel(children: [
          FactoryShared.panelLabel('doc.text', 'Uzunluk'),
          for (final length in _SummaryLength.values)
            FactoryShared.stackedSegmentButton(
              label: length.label,
              isSelected: _summaryLength == length,
              onTap: () => setState(() => _summaryLength = length),
            ),
        ]),
        const SizedBox(height: BaseForceFactoryStyle.panelSpacing),
        BaseForceFactoryStyle.panel(children: [
          FactoryShared.panelLabel('target', 'Odak'),
          for (final focus in _SummaryFocus.values)
            FactoryShared.stackedSegmentButton(
              label: focus.label,
              isSelected: _summaryFocus == focus,
              onTap: () => setState(() => _summaryFocus = focus),
            ),
        ]),
        const SizedBox(height: BaseForceFactoryStyle.panelSpacing),
        BaseForceFactoryStyle.panel(children: [
          FactoryShared.panelLabel('highlighter', 'Ekler'),
          FactoryShared.toggleRow(
            label: 'Terimleri işaretle',
            value: _markTerms,
            onChanged: (v) => setState(() => _markTerms = v),
          ),
          FactoryShared.toggleRow(
            label: 'Tabloya dönüştür',
            value: _toTable,
            onChanged: (v) => setState(() => _toTable = v),
          ),
          FactoryShared.toggleRow(
            label: 'Kontrol listesi ekle',
            value: _checklist,
            onChanged: (v) => setState(() => _checklist = v),
          ),
        ]),
        const SizedBox(height: BaseForceFactoryStyle.panelSpacing),
        BaseForceFactoryStyle.panel(children: [
          SBQualityPicker(
            selection: _quality,
            onChanged: (tier) => setState(() => _quality = tier),
          ),
        ]),
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
      _summaryLength.label,
      _summaryFocus.label,
      _markTerms ? 'terim vurgulu' : 'terim vurgusuz',
      _toTable ? 'mini tablolu' : 'düz metin',
      _checklist ? 'kontrol listeli' : 'kontrol listesiz',
      _quality.label,
    ].join(' • ');

    final job = await store.enqueueGeneration(
      file: readyFile,
      kind: GeneratedKind.summary,
      label: 'Sınav Sabahı Özeti',
      surface: 'Üret Özet',
      mode: mode,
      extraOptions: {
        'summary_mode': _summaryFocus.label,
        'length_target': _summaryLength.label,
        'output_format':
            _toTable ? 'bullet_points+mini_table' : 'bullet_points',
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
