import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
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

enum _ComparisonType {
  disease('Hastalık'),
  drug('İlaç'),
  mechanism('Mekanizma'),
  clinicalFinding('Klinik bulgu'),
  diagnosisTreatment('Tanı-tedavi'),
  basicScience('Temel bilim'),
  tusConfusables('TUS tuzakları');

  const _ComparisonType(this.label);

  final String label;
}

enum _TableFormat {
  classicTable('Klasik'),
  columnBased('Sütun'),
  distinguishingClue('İpucu'),
  diagnosisTestTreatment('Tanı-tedavi'),
  plusMinus('Artı-eksi'),
  miniSummaryPlusTable('Özet + tablo');

  const _TableFormat(this.label);

  final String label;
}

enum _DetailLevel {
  brief('Kısa'),
  balanced('Dengeli'),
  detailed('Detaylı'),
  clinical('Klinik odaklı'),
  exam('Sınav odaklı');

  const _DetailLevel(this.label);

  final String label;
}

enum _QualityTier {
  economy('Ekonomik'),
  standard('Standart'),
  premium('Premium');

  const _QualityTier(this.label);

  final String label;
}

/// Port of ComparisonFactoryView ("Karşılaştırma Tablosu").
class ComparisonFactoryView extends StatefulWidget {
  const ComparisonFactoryView({super.key});

  @override
  State<ComparisonFactoryView> createState() => _ComparisonFactoryViewState();
}

class _ComparisonFactoryViewState extends State<ComparisonFactoryView> {
  bool _isGenerating = false;
  _ComparisonType _comparisonType = _ComparisonType.disease;
  _TableFormat _tableFormat = _TableFormat.classicTable;
  _DetailLevel _detailLevel = _DetailLevel.balanced;
  _QualityTier _qualityTier = _QualityTier.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  List<DriveFile> _selectedFiles(WorkspaceStore store) => store.allFiles
      .where((f) =>
          store.selectedSourceIds.contains(f.id) &&
          store.isReadyForGeneration(f))
      .toList();

  List<DriveFile> _blockedFiles(WorkspaceStore store) => [
        for (final id in store.selectedSourceIds)
          if (store.file(id) != null &&
              !store.isReadyForGeneration(store.file(id)!))
            store.file(id)!,
      ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;
    final selectedFiles = _selectedFiles(store);
    final blockedFiles = _blockedFiles(store);
    final canGenerate = selectedFiles.isNotEmpty && blockedFiles.isEmpty;
    final costLabel = SBGenerationCost.compactEstimate(
      GeneratedKind.comparison,
      sourceCount: selectedFiles.length,
      quality: _qualityTier.label,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Karşılaştırma Tablosu',
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
                  icon: 'tablecells',
                  title: 'Karşılaştırma Tablosu yükleniyor',
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
                    eyebrow: 'Karşılaştırma',
                    title: 'Neyi ayıralım?',
                    message: 'Benzer kavramları kısa tabloya çevir.',
                    icon: 'tablecells.fill',
                    tint: SBColors.cyan,
                    size: SBHeroSize.compact,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'book',
                          value: '${selectedFiles.length}',
                          label: 'kaynak',
                          tint: SBColors.green),
                      SBMetricRibbonItem(
                          icon: 'list.bullet',
                          value: _detailLevel.label,
                          label: 'yoğunluk',
                          tint: SBColors.purple),
                      SBMetricRibbonItem(
                          icon: 'target',
                          value: _qualityTier.label,
                          label: 'kalite',
                          tint: SBColors.orange),
                    ]),
                  ),
                ),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                    index: 1,
                    child: _sourcesPanel(
                        store, router, selectedFiles, blockedFiles)),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(index: 2, child: _comparisonTypePanel()),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(index: 3, child: _tableSettingsPanel()),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                  index: 4,
                  child: SBButton(
                    'Tabloyu hazırla • $costLabel',
                    icon: 'tablecells',
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    isLoading: _isGenerating,
                    isDisabled: !canGenerate,
                    fullWidth: true,
                    onPressed: () =>
                        _generate(store, router, selectedFiles),
                  ),
                ),
                if (!canGenerate) ...[
                  const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                  SBEntrance(
                    index: 5,
                    child: SBButton(
                      'Karşılaştırılacak kaynakları seç',
                      icon: 'folder',
                      variant: SBButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => openFactorySourcePicker(
                          router, AppRoute.comparisonFactory),
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

  Widget _sourcesPanel(WorkspaceStore store, AppRouter router,
      List<DriveFile> selectedFiles, List<DriveFile> blockedFiles) {
    return BaseForceFactoryStyle.panel(children: [
      Row(
        children: [
          const SBIconTile(
            icon: 'doc.text.magnifyingglass',
            tint: Color(0xFF0A5BFF),
            size: BaseForceFactoryStyle.iconTileSize,
            radius: BaseForceFactoryStyle.iconTileRadius,
          ),
          const SizedBox(width: SBSpacing.md),
          Text('Kaynak (${selectedFiles.length})',
              style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
        ],
      ),
      if (selectedFiles.isEmpty)
        FactoryShared.sourceRequiredCard()
      else
        for (final file in selectedFiles)
          BaseForceFactoryStyle.nestedPanel(children: [
            Row(
              children: [
                SBFileKindBadge(
                    kind: sbFileKindFrom(file.kind), compact: true),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.labelSmall
                            .copyWith(color: SBColors.navy),
                      ),
                      const SizedBox(height: SBSpacing.xs),
                      Text(
                        '${file.sizeLabel} • Hazır',
                        style: SBTypography.caption
                            .copyWith(color: SBColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ]),
      for (final file in blockedFiles)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SBSpacing.md),
          decoration: BoxDecoration(
            color: SBColors.warningBg,
            borderRadius:
                BorderRadius.circular(BaseForceFactoryStyle.controlRadius),
          ),
          child: Row(
            children: [
              SBIcon('exclamationmark.triangle',
                  size: 16, color: SBColors.orange),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Text('${file.title}: Hazır değil',
                    style: SBTypography.bodySmall
                        .copyWith(color: SBColors.navy)),
              ),
            ],
          ),
        ),
      SBCommandCard(
        tint: SBColors.blue,
        onTap: () =>
            openFactorySourcePicker(router, AppRoute.comparisonFactory),
        child: Row(
          children: [
            const SBIconTile(
                icon: 'plus', tint: Color(0xFF0A5BFF), size: 44, radius: 13),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karşılaştırılacak kaynak ekle',
                      style: SBTypography.labelMedium
                          .copyWith(color: SBColors.blue)),
                  const SizedBox(height: SBSpacing.xs),
                  Text("Drive'dan ikinci bir hazır kaynak seç.",
                      style: SBTypography.caption
                          .copyWith(color: SBColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _comparisonTypePanel() {
    return BaseForceFactoryStyle.panel(children: [
      Row(
        children: [
          const SBIconTile(
            icon: 'arrow.left.arrow.right',
            tint: Color(0xFF0A5BFF),
            size: BaseForceFactoryStyle.iconTileSize,
            radius: BaseForceFactoryStyle.iconTileRadius,
          ),
          const SizedBox(width: SBSpacing.md),
          Text('Tip',
              style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
        ],
      ),
      Wrap(
        spacing: SBSpacing.sm,
        runSpacing: SBSpacing.sm,
        children: [
          for (final type in _ComparisonType.values)
            _segmentButton(type.label, _comparisonType == type,
                () => setState(() => _comparisonType = type)),
        ],
      ),
    ]);
  }

  Widget _tableSettingsPanel() {
    return BaseForceFactoryStyle.panel(
      spacing: BaseForceFactoryStyle.settingsSpacing,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FactoryShared.settingLabel('Format'),
            const SizedBox(height: SBSpacing.sm),
            Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                for (final format in _TableFormat.values)
                  _segmentButton(format.label, _tableFormat == format,
                      () => setState(() => _tableFormat = format)),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FactoryShared.settingLabel('Detay'),
            const SizedBox(height: SBSpacing.sm),
            Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                for (final level in _DetailLevel.values)
                  _segmentButton(level.label, _detailLevel == level,
                      () => setState(() => _detailLevel = level)),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FactoryShared.settingLabel('Kalite'),
            const SizedBox(height: SBSpacing.sm),
            Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                for (final tier in _QualityTier.values)
                  _segmentButton(tier.label, _qualityTier == tier,
                      () => setState(() => _qualityTier = tier)),
              ],
            ),
          ],
        ),
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
          borderRadius:
              BorderRadius.circular(BaseForceFactoryStyle.controlRadius),
          border: Border.all(
              color: isSelected ? SBColors.blue : SBColors.softLine),
        ),
        child: Text(
          label,
          style: SBTypography.caption
              .copyWith(color: isSelected ? Colors.white : SBColors.navy),
        ),
      ),
    );
  }

  Future<void> _generate(WorkspaceStore store, AppRouter router,
      List<DriveFile> selectedFiles) async {
    final file = selectedFiles.firstOrNull;
    if (file == null) {
      store.toast('Önce hazır bir kaynak seç.');
      return;
    }
    setState(() => _isGenerating = true);
    final mode = [
      _comparisonType.label,
      _tableFormat.label,
      _detailLevel.label,
      _qualityTier.label,
      '${selectedFiles.length} kaynak',
      'mobil tablo',
    ].join(' • ');

    final job = await store.enqueueGeneration(
      file: file,
      kind: GeneratedKind.comparison,
      label: 'Karşılaştırma Tablosu',
      surface: 'Üret Karşılaştırma',
      mode: mode,
      extraOptions: {
        'comparison_type': _comparisonType.label,
        'table_format': _tableFormat.label,
        'detail_level': _detailLevel.label,
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
