import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';
import 'baseforce_style.dart';
import 'factory_shared.dart';
import 'sb_generation_cost.dart';

enum _AlgorithmMode {
  diagnostic('Tanı', 'arrow.triangle.branch'),
  treatment('Tedavi', 'waveform.path.ecg'),
  clinicalDecision('Karar', 'point.3.connected.trianglepath.dotted');

  const _AlgorithmMode(this.label, this.icon);

  final String label;
  final String icon;
}

enum _AlgorithmType {
  pathophysiology('Patofizyoloji', 'point.3.connected.trianglepath.dotted'),
  labInterpretation('Laboratuvar', 'testtube.2'),
  tusSolving('TUS çözüm', 'brain.head.profile'),
  emergency('Acil', 'cross.case');

  const _AlgorithmType(this.label, this.icon);

  final String label;
  final String icon;
}

enum _FlowFormat {
  flowchart('Akış şeması', 'arrow.triangle.branch'),
  decisionTree('Karar ağacı', 'point.3.connected.trianglepath.dotted'),
  stepwise('Basamaklı', 'list.number');

  const _FlowFormat(this.label, this.icon);

  final String label;
  final String icon;
}

enum _OutputFormat {
  yesNoBranching('Evet/Hayır', 'arrow.triangle.2.circlepath'),
  mechanismChain('Mekanizma zinciri', 'link'),
  tableFlow('Tablo + akış', 'tablecells');

  const _OutputFormat(this.label, this.icon);

  final String label;
  final String icon;
}

enum _DetailLevel {
  brief('Kısa', 'slider.horizontal.3'),
  balanced('Dengeli', 'scope'),
  detailed('Detaylı', 'list.bullet'),
  clinical('Klinik odaklı', 'cross.case'),
  exam('Sınav odaklı', 'graduationcap');

  const _DetailLevel(this.label, this.icon);

  final String label;
  final String icon;
}

enum _Quality {
  economy('Ekonomik', 'banknote'),
  standard('Standart', 'checkmark.circle'),
  premium('Premium', 'crown');

  const _Quality(this.label, this.icon);

  final String label;
  final String icon;
}

/// Port of AlgorithmFactoryView ("Akış Şeması").
class AlgorithmFactoryView extends StatefulWidget {
  const AlgorithmFactoryView({super.key});

  @override
  State<AlgorithmFactoryView> createState() => _AlgorithmFactoryViewState();
}

class _AlgorithmFactoryViewState extends State<AlgorithmFactoryView> {
  bool _isGenerating = false;
  _AlgorithmMode _algorithmMode = _AlgorithmMode.diagnostic;
  _AlgorithmType _algorithmType = _AlgorithmType.pathophysiology;
  _FlowFormat _flowFormat = _FlowFormat.flowchart;
  _OutputFormat _outputFormat = _OutputFormat.yesNoBranching;
  _DetailLevel _detailLevel = _DetailLevel.balanced;
  _Quality _quality = _Quality.standard;
  bool _colorfulNodes = true;
  bool _clinicalNotes = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  List<DriveFile> _readySources(WorkspaceStore store) => store.allFiles
      .where((f) =>
          store.selectedSourceIds.contains(f.id) &&
          store.isReadyForGeneration(f))
      .toList();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;
    final readySources = _readySources(store);
    final canGenerate = readySources.isNotEmpty;
    final sourceSummary =
        canGenerate ? '${readySources.length} kaynak seçildi' : 'Kaynak seç';
    final costLabel = SBGenerationCost.compactEstimate(
      GeneratedKind.algorithm,
      sourceCount: readySources.length,
      quality: _quality.label,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Akış Şeması',
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
                  icon: 'arrow.triangle.branch',
                  title: 'Algoritma yükleniyor',
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
                    eyebrow: 'Akış',
                    title: 'Akış şeması üret',
                    message: 'Süreci karar akışına çevir.',
                    icon: 'arrow.triangle.branch',
                    tint: SBColors.orange,
                    size: SBHeroSize.compact,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'doc.text.magnifyingglass',
                          value: sourceSummary,
                          label: 'kaynak',
                          tint: SBColors.blue),
                      SBMetricRibbonItem(
                          icon: _flowFormat.icon,
                          value: _flowFormat.label,
                          label: 'format',
                          tint: SBColors.orange),
                      SBMetricRibbonItem(
                          icon: _quality.icon,
                          value: _quality.label,
                          label: 'kalite',
                          tint: SBColors.purple),
                    ]),
                  ),
                ),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                    index: 1, child: _selectedSourcesSection(store, router)),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(index: 2, child: _settingsPanel()),
                if (_quality == _Quality.premium) ...[
                  const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                  SBEntrance(index: 3, child: _premiumNotice()),
                ],
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(index: 4, child: _togglesSection()),
                const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                SBEntrance(
                  index: 5,
                  child: SBButton(
                    'Akışı çiz • $costLabel',
                    icon: 'bolt.fill',
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    isLoading: _isGenerating,
                    isDisabled: !canGenerate,
                    fullWidth: true,
                    onPressed: () =>
                        _generate(store, router, readySources.firstOrNull),
                  ),
                ),
                if (!canGenerate) ...[
                  const SizedBox(height: BaseForceFactoryStyle.screenSpacing),
                  SBEntrance(
                    index: 6,
                    child: SBButton(
                      'Hazır kaynak seç',
                      icon: 'folder',
                      variant: SBButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => openFactorySourcePicker(
                          router, AppRoute.algorithmFactory),
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
            for (final sourceId in selectedSources)
              if (store.file(sourceId) != null)
                FactoryShared.sourceChip(store.file(sourceId)!),
            FactoryShared.addSourceChip(() =>
                openFactorySourcePicker(router, AppRoute.algorithmFactory)),
          ],
        ),
    ]);
  }

  Widget _settingsPanel() {
    return BaseForceFactoryStyle.panel(
      spacing: BaseForceFactoryStyle.settingsSpacing,
      children: [
        Text('Ayarlar',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        _settingsSection('Şablon', [
          for (final mode in _AlgorithmMode.values)
            _segmentButton(mode.label, mode.icon, _algorithmMode == mode,
                () => setState(() => _algorithmMode = mode)),
        ]),
        _settingsSection('Tip', [
          for (final type in _AlgorithmType.values)
            _segmentButton(type.label, type.icon, _algorithmType == type,
                () => setState(() => _algorithmType = type)),
        ]),
        _settingsSection('Biçim', [
          for (final format in _FlowFormat.values)
            _segmentButton(format.label, format.icon, _flowFormat == format,
                () => setState(() => _flowFormat = format)),
        ]),
        _settingsSection('Çalışma', [
          for (final format in _OutputFormat.values)
            _segmentButton(format.label, format.icon,
                _outputFormat == format,
                () => setState(() => _outputFormat = format)),
        ]),
        _settingsSection('Detay', [
          for (final level in _DetailLevel.values)
            _segmentButton(level.label, level.icon, _detailLevel == level,
                () => setState(() => _detailLevel = level)),
        ]),
        _settingsSection('Kalite', [
          for (final quality in _Quality.values)
            _segmentButton(quality.label, quality.icon, _quality == quality,
                () => setState(() => _quality = quality)),
        ]),
      ],
    );
  }

  Widget _settingsSection(String label, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactoryShared.settingLabel(label),
        const SizedBox(height: SBSpacing.sm),
        Wrap(
          spacing: SBSpacing.sm,
          runSpacing: SBSpacing.sm,
          children: chips,
        ),
      ],
    );
  }

  Widget _segmentButton(
      String label, String icon, bool isSelected, VoidCallback onTap) {
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SBIcon(icon,
                size: 14, color: isSelected ? Colors.white : SBColors.navy),
            const SizedBox(width: SBSpacing.xs),
            Text(
              label,
              style: SBTypography.caption.copyWith(
                  color: isSelected ? Colors.white : SBColors.navy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.selectedBlue,
        borderRadius:
            BorderRadius.circular(BaseForceFactoryStyle.controlRadius),
      ),
      child: Row(
        children: [
          SBIcon('creditcard', size: 18, color: SBColors.blue),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Text('Premium daha fazla MC kullanabilir.',
                style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _togglesSection() {
    return BaseForceFactoryStyle.panel(children: [
      FactoryShared.toggleRow(
        label: 'Renkli düğümler',
        value: _colorfulNodes,
        onChanged: (v) => setState(() => _colorfulNodes = v),
      ),
      FactoryShared.toggleRow(
        label: 'Klinik not ekle',
        value: _clinicalNotes,
        onChanged: (v) => setState(() => _clinicalNotes = v),
      ),
    ]);
  }

  Future<void> _generate(
      WorkspaceStore store, AppRouter router, DriveFile? file) async {
    if (file == null) {
      store.toast('Önce hazır bir kaynak seç.');
      return;
    }
    setState(() => _isGenerating = true);
    final mode = [
      _algorithmMode.label,
      _algorithmType.label,
      _flowFormat.label,
      _outputFormat.label,
      _detailLevel.label,
      _quality.label,
      _colorfulNodes ? 'renkli düğüm' : 'sade düğüm',
      _clinicalNotes ? 'klinik notlu' : 'klinik notsuz',
    ].join(' • ');

    final job = await store.enqueueGeneration(
      file: file,
      kind: GeneratedKind.algorithm,
      label: 'Klinik Algoritma',
      surface: 'Üret Algoritma',
      mode: mode,
      extraOptions: {
        'algorithm_type': _algorithmType.label,
        'output_format': _outputFormat.label,
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
