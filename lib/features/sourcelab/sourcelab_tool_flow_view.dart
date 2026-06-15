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
import '../../design_system/sb_status_badge.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';
import '../baseforce/baseforce_style.dart';
import '../baseforce/sb_generation_cost.dart';

/// Port of SourceLabToolFlowView: shared flow for the deep production tools
/// (plan, podcast, infographic, mind map, exam morning, clinical).
class SourceLabToolFlowView extends StatefulWidget {
  const SourceLabToolFlowView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.outputLabel,
    required this.icon,
    required this.tint,
    required this.controls,
    required this.previewSections,
  });

  final String title;
  final String subtitle;
  final GeneratedKind kind;
  final String outputLabel;
  final String icon;
  final Color tint;
  final List<String> controls;
  final List<String> previewSections;

  @override
  State<SourceLabToolFlowView> createState() => _SourceLabToolFlowViewState();
}

class _SourceLabToolFlowViewState extends State<SourceLabToolFlowView> {
  bool _isGenerating = false;
  late String _selectedControl =
      widget.controls.isNotEmpty ? widget.controls.first : 'Dengeli';
  SBQualityTier _selectedQuality = SBQualityTier.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  AppRoute get _factoryRoute => switch (widget.kind) {
        GeneratedKind.podcast => AppRoute.podcast,
        GeneratedKind.infographic => AppRoute.infographic,
        GeneratedKind.mindMap => AppRoute.mindMap,
        GeneratedKind.learningPlan => AppRoute.plan,
        GeneratedKind.examMorningSummary => AppRoute.examMorning,
        GeneratedKind.clinicalScenario => AppRoute.clinical,
        _ => AppRoute.baseForce,
      };

  String get _costLabel => SBGenerationCost.compactEstimate(widget.kind,
      quality: _selectedQuality.label);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;
    final readyFile = store.selectedReadyFiles.isNotEmpty
        ? store.selectedReadyFiles.first
        : null;
    final canGenerate = readyFile != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text(widget.title,
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      body: SBPageBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                SBLoadingState(
                  icon: widget.icon,
                  title: '${widget.title} yükleniyor',
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
                SBEntrance(index: 0, child: _hero(readyFile)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 1, child: _sourceCard(router, readyFile)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 2, child: _controlsCard()),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 3, child: _qualityCard()),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 4, child: _previewCard()),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 5,
                  child: SBButton(
                    canGenerate
                        ? (_isGenerating
                            ? 'Hazırlanıyor...'
                            : '${widget.outputLabel} hazırla • $_costLabel')
                        : 'Kaynak seç',
                    icon: canGenerate ? 'wand.and.stars' : 'folder',
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    isLoading: _isGenerating,
                    fullWidth: true,
                    onPressed: () {
                      if (canGenerate) {
                        _generate(store, router, readyFile);
                      } else {
                        router.beginSourceSelection(
                            from: AppRoute.baseForce,
                            destination:
                                SourcePickerDestination.toRoute(_factoryRoute));
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

  Widget _hero(DriveFile? readyFile) {
    return SBSignatureHero(
      eyebrow: 'Üretim aracı',
      title: widget.title,
      message: widget.subtitle,
      icon: widget.icon,
      tint: widget.tint,
      footer: SBMetricRibbon(items: [
        SBMetricRibbonItem(
            icon: 'doc.text',
            value: readyFile == null ? 'Yok' : 'Hazır',
            label: 'kaynak',
            tint: readyFile == null ? SBColors.orange : SBColors.green),
        SBMetricRibbonItem(
            icon: 'slider.horizontal.3',
            value: _selectedControl,
            label: 'odak',
            tint: widget.tint),
        SBMetricRibbonItem(
            icon: 'creditcard',
            value: _costLabel,
            label: 'tahmin',
            tint: SBColors.orange),
      ]),
    );
  }

  Widget _sourceCard(AppRouter router, DriveFile? readyFile) {
    return SBCard(
      radius: 16,
      borderColor: widget.tint.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Kaynak',
                    style: SBTypography.titleSmall
                        .copyWith(color: SBColors.navy)),
              ),
              GestureDetector(
                onTap: () => router.beginSourceSelection(
                    from: AppRoute.baseForce,
                    destination:
                        SourcePickerDestination.toRoute(_factoryRoute)),
                child: Text('Değiştir',
                    style:
                        SBTypography.labelSmall.copyWith(color: SBColors.blue)),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          if (readyFile != null)
            Row(
              children: [
                SBFileKindBadge(
                    kind: sbFileKindFrom(readyFile.kind), compact: true),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        readyFile.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.labelMedium
                            .copyWith(color: SBColors.navy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${readyFile.courseTitle} • ${readyFile.sectionTitle} • ${readyFile.sizeLabel}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.caption
                            .copyWith(color: SBColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SBSpacing.sm),
                const SBStatusBadge(status: SBStatus.ready, compact: true),
              ],
            )
          else
            SBEmptyState(
              icon: 'folder.badge.plus',
              title: 'Hazır kaynak seç',
              message:
                  'Üretime başlamadan önce kullanacağın hazır kaynağı seç.',
              actionLabel: 'Kaynak seç',
              onAction: () => router.beginSourceSelection(
                  from: AppRoute.baseForce,
                  destination: SourcePickerDestination.toRoute(_factoryRoute)),
            ),
        ],
      ),
    );
  }

  Widget _controlsCard() {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIconTile(
                  icon: 'slider.horizontal.3',
                  tint: widget.tint,
                  size: 38,
                  radius: 11),
              const SizedBox(width: SBSpacing.sm),
              Text('Çalışma odağı',
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy)),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final control in widget.controls)
                GestureDetector(
                  onTap: () {
                    SBHaptics.selection();
                    setState(() => _selectedControl = control);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SBSpacing.md, vertical: SBSpacing.sm),
                    decoration: BoxDecoration(
                      color: _selectedControl == control
                          ? widget.tint
                          : SBColors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: _selectedControl == control
                              ? widget.tint
                              : SBColors.softLine),
                    ),
                    child: Text(
                      control,
                      style: SBTypography.labelSmall.copyWith(
                          color: _selectedControl == control
                              ? Colors.white
                              : SBColors.navy),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qualityCard() {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIconTile(
                  icon: 'sparkles', tint: widget.tint, size: 38, radius: 11),
              const SizedBox(width: SBSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kalite',
                        style: SBTypography.titleSmall
                            .copyWith(color: SBColors.navy)),
                    const SizedBox(height: 3),
                    Text(_selectedQuality.subtitle,
                        style: SBTypography.caption
                            .copyWith(color: SBColors.muted)),
                  ],
                ),
              ),
              Text(_costLabel,
                  style:
                      SBTypography.caption.copyWith(color: SBColors.orange)),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Row(
            children: [
              for (var i = 0; i < SBQualityTier.values.length; i++) ...[
                if (i > 0) const SizedBox(width: SBSpacing.sm),
                Expanded(child: _qualityButton(SBQualityTier.values[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _qualityButton(SBQualityTier quality) {
    final isSelected = _selectedQuality == quality;
    return GestureDetector(
      onTap: () {
        SBHaptics.selection();
        setState(() => _selectedQuality = quality);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SBSpacing.md, horizontal: SBSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? widget.tint : SBColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? widget.tint : SBColors.softLine),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SBIcon(quality.icon,
                size: 14, color: isSelected ? Colors.white : SBColors.navy),
            const SizedBox(width: SBSpacing.xs),
            Flexible(
              child: Text(
                quality.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SBTypography.caption.copyWith(
                    color: isSelected ? Colors.white : SBColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIconTile(
                  icon: 'list.bullet.rectangle',
                  tint: widget.tint,
                  size: 38,
                  radius: 11),
              const SizedBox(width: SBSpacing.sm),
              Text('Çalışma ekranında',
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy)),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          for (var i = 0; i < widget.previewSections.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.tint.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: SBTypography.labelSmall
                            .copyWith(color: widget.tint)),
                  ),
                  const SizedBox(width: SBSpacing.md),
                  Expanded(
                    child: Text(widget.previewSections[i],
                        style: SBTypography.bodySmall
                            .copyWith(color: SBColors.navy)),
                  ),
                ],
              ),
            ),
            if (i < widget.previewSections.length - 1)
              const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Future<void> _generate(
      WorkspaceStore store, AppRouter router, DriveFile readyFile) async {
    final controlKey = switch (widget.kind) {
      GeneratedKind.mindMap => 'map_type',
      GeneratedKind.learningPlan => 'daily_time',
      GeneratedKind.infographic => 'infographic_type',
      _ => 'detail_level',
    };
    setState(() => _isGenerating = true);

    final job = await store.enqueueGeneration(
      file: readyFile,
      kind: widget.kind,
      label: widget.outputLabel,
      surface: 'Üretim ${widget.outputLabel}',
      mode: '$_selectedControl • ${_selectedQuality.label}',
      extraOptions: {
        controlKey: _selectedControl,
        'qualityTier': _selectedQuality.tier,
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
