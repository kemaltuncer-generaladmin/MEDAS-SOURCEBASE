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
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_status_badge.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';
import '../study/sb_output_style.dart';
import 'drive_move_sheet.dart';

/// Port of FileDetailView.
class FileDetailView extends StatefulWidget {
  const FileDetailView({super.key, required this.fileId});

  final String fileId;

  @override
  State<FileDetailView> createState() => _FileDetailViewState();
}

class _FileDetailViewState extends State<FileDetailView> {
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  String _readinessMessage(DriveFile file) {
    if (file.statusMessage?.isNotEmpty == true) return file.statusMessage!;
    return switch (file.status) {
      DriveItemStatus.completed => 'Kaynak üretime hazır.',
      DriveItemStatus.processing =>
        'Kaynak hazırlanıyor. Hazır olunca üretim başlatabilirsin.',
      DriveItemStatus.uploading => 'Yükleme devam ediyor.',
      DriveItemStatus.failed =>
        'Dosya işlenemedi. Farklı bir dosya deneyebilirsin.',
      DriveItemStatus.draft => 'Kaynak henüz hazır değil.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final file = store.file(widget.fileId);
    final isReady = file != null && store.isReadyForGeneration(file);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Dosya Detayı',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        actions: [
          if (file != null)
            PopupMenuButton<String>(
              icon: SBIcon('ellipsis.circle', size: 18, color: SBColors.navy),
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    _showRename(file);
                  case 'move':
                    _showMove(file);
                  case 'retry':
                    store.retryFileProcessing(file.id);
                  case 'delete':
                    _confirmDelete(file);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'rename', child: Text('Yeniden adlandır')),
                const PopupMenuItem(value: 'move', child: Text('Taşı')),
                if (file.status == DriveItemStatus.failed ||
                    file.status == DriveItemStatus.processing)
                  const PopupMenuItem(
                      value: 'retry', child: Text('İşlemeyi tekrar dene')),
                PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Sil', style: TextStyle(color: SBColors.red))),
              ],
            ),
        ],
      ),
      body: SBPageBackground(
        tone: SBPageTone.warm,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (store.isLoading && !store.hasLoadedWorkspace)
                const SBLoadingState(
                  icon: 'doc',
                  title: 'Dosya yükleniyor',
                  message: 'Dosya bilgileri hazırlanıyor...',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Dosya yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else if (file != null) ...[
                SBEntrance(index: 0, child: _fileInfoCard(file)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 1, child: _locationRow(file)),
                if (!isReady) ...[
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(index: 2, child: _readinessNotice(store, file)),
                ],
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                    index: 3,
                    child: _studyActionsSection(store, router, file, isReady)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                    index: 4,
                    child: _generatedOutputsSection(router, file, isReady)),
              ] else
                SBErrorState(
                  icon: 'doc.questionmark',
                  title: 'Dosya bulunamadı',
                  message:
                      'Bu kaynak silinmiş veya Drive verisi yenilenmiş olabilir.',
                  actionLabel: "Drive'a dön",
                  onAction: () => router.popToRoot(),
                ),
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileInfoCard(DriveFile file) {
    final kind = sbFileKindFrom(file.kind);
    return SBSignatureHero(
      eyebrow: kind.label,
      title: file.title,
      message: _readinessMessage(file),
      icon: 'doc.text.fill',
      tint: kind.color,
      actions: Wrap(
        spacing: SBSpacing.sm,
        runSpacing: SBSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SBStatusBadge(status: sbStatusFrom(file.status), compact: true),
          _metaItem('folder', file.courseTitle),
          _metaItem('list.bullet', file.sectionTitle),
        ],
      ),
      footer: SBMetricRibbon(items: [
        SBMetricRibbonItem(
            icon: 'doc', value: file.sizeLabel, label: 'boyut', tint: kind.color),
        SBMetricRibbonItem(
            icon: 'number',
            value: file.pageLabel,
            label: 'sayfa',
            tint: SBColors.blue),
        SBMetricRibbonItem(
            icon: 'calendar',
            value: file.updatedLabel,
            label: 'güncelleme',
            tint: SBColors.green),
      ]),
    );
  }

  Widget _metaItem(String icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SBIcon(icon, size: 12, color: SBColors.muted),
        const SizedBox(width: 4),
        Text(text,
            style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
      ],
    );
  }

  Widget _locationRow(DriveFile file) {
    return SBCard(
      padding: SBSpacing.md,
      radius: 12,
      child: Wrap(
        spacing: SBSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SBIcon('folder', size: 16, color: SBColors.muted),
          Text(file.courseTitle,
              style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          SBIcon('chevron.right', size: 12, color: SBColors.navy),
          Text(file.sectionTitle,
              style: SBTypography.bodySmall.copyWith(color: SBColors.blue)),
        ],
      ),
    );
  }

  Widget _readinessNotice(WorkspaceStore store, DriveFile file) {
    final canRetry = file.status == DriveItemStatus.failed ||
        file.status == DriveItemStatus.processing;
    final message = canRetry && file.status == DriveItemStatus.processing
        ? '${_readinessMessage(file)} Uzun sürdüyse işlemeyi yeniden başlatabilirsin.'
        : _readinessMessage(file);

    return SBCard(
      padding: SBSpacing.md,
      radius: 12,
      backgroundColor: SBColors.selectedBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SBIcon('info.circle', size: 18, color: SBColors.blue),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Text(message,
                    style: SBTypography.bodySmall
                        .copyWith(color: SBColors.muted, height: 1.25)),
              ),
            ],
          ),
          if (canRetry) ...[
            const SizedBox(height: SBSpacing.md),
            SBButton(
              _isRetrying
                  ? 'Yeniden başlatılıyor...'
                  : 'İşlemeyi yeniden başlat',
              icon: 'arrow.clockwise',
              variant: SBButtonVariant.secondary,
              size: SBButtonSize.small,
              isLoading: _isRetrying,
              onPressed: () async {
                if (_isRetrying) return;
                setState(() => _isRetrying = true);
                await store.retryFileProcessing(file.id);
                if (mounted) setState(() => _isRetrying = false);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _studyActionsSection(
      WorkspaceStore store, AppRouter router, DriveFile file, bool isReady) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bu kaynakla çalış',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.md),
        if (isReady)
          SBCard(
            radius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _routeCard(
                  icon: 'bolt.fill',
                  title: 'Hızlı çalışma',
                  subtitle: 'Ezber kartı, test ve son tekrar',
                  color: SBColors.blue,
                  onTap: () {
                    store.setSelectedSources({file.id});
                    store.selectFile(file);
                    router.beginSourceSelection(
                        from: AppRoute.baseForce,
                        destination: SourcePickerDestination.baseForceHome);
                  },
                ),
                const SizedBox(height: SBSpacing.md),
                _routeCard(
                  icon: 'flask',
                  title: 'Üretim araçları',
                  subtitle: 'Vaka, plan, dinleme ve görsel özet',
                  color: SBColors.purple,
                  onTap: () {
                    store.setSelectedSources({file.id});
                    store.selectFile(file);
                    router.beginSourceSelection(
                        from: AppRoute.sourceLab,
                        destination: SourcePickerDestination.sourceLabHome);
                  },
                ),
                const SizedBox(height: SBSpacing.lg),
                Wrap(
                  spacing: SBSpacing.sm,
                  runSpacing: SBSpacing.sm,
                  children: [
                    _quickChip('rectangle.on.rectangle', 'Kart',
                        SBColors.blue, () => _generate(GeneratedKind.flashcard)),
                    _quickChip('questionmark.circle', 'Soru',
                        SBColors.questionTint,
                        () => _generate(GeneratedKind.question)),
                    _quickChip('doc.text', 'Özet', SBColors.purple,
                        () => _generate(GeneratedKind.summary)),
                  ],
                ),
              ],
            ),
          )
        else
          SBEmptyState(
            icon: file.status == DriveItemStatus.failed
                ? 'exclamationmark.triangle'
                : 'hourglass',
            title: file.status == DriveItemStatus.failed
                ? 'Kaynak işlenemedi'
                : 'Dosya hazır değil',
            message: _readinessMessage(file),
          ),
      ],
    );
  }

  Widget _routeCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SBCommandCard(
      tint: color,
      onTap: onTap,
      child: Row(
        children: [
          SBIconTile(icon: icon, tint: color, size: 40, radius: 12),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        SBTypography.labelMedium.copyWith(color: SBColors.navy)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
          SBIcon('chevron.right', size: 14, color: color),
        ],
      ),
    );
  }

  Widget _quickChip(
      String icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SBColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SBIcon(icon, size: 14, color: color),
            const SizedBox(width: SBSpacing.xs),
            Text(label,
                style: SBTypography.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _generatedOutputsSection(
      AppRouter router, DriveFile file, bool isReady) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Bu kaynaktan üretilenler',
                  style: SBTypography.titleMedium
                      .copyWith(color: SBColors.navy)),
            ),
            if (file.generated.isNotEmpty)
              GestureDetector(
                onTap: () => router.navigate(AppRoute.collections),
                child: Text('Tümünü gör',
                    style: SBTypography.labelSmall
                        .copyWith(color: SBColors.blue)),
              ),
          ],
        ),
        const SizedBox(height: SBSpacing.md),
        SBCard(
          padding: 0,
          radius: 14,
          child: file.generated.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(SBSpacing.xl),
                  child: Column(
                    children: [
                      SBIcon('rectangle.stack.badge.plus',
                          size: 28,
                          color: SBColors.muted.withValues(alpha: 0.5)),
                      const SizedBox(height: SBSpacing.md),
                      Text('Henüz çalışma yok',
                          style: SBTypography.bodySmall
                              .copyWith(color: SBColors.muted)),
                      const SizedBox(height: SBSpacing.md),
                      Text(
                        isReady
                            ? 'Yukarıdaki seçeneklerden biriyle çalışma başlatabilirsin.'
                            : 'Kaynak hazır olunca çalışmalar burada görünür.',
                        textAlign: TextAlign.center,
                        style: SBTypography.caption
                            .copyWith(color: SBColors.softText),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < file.generated.length; i++) ...[
                      SBPressable(
                        onTap: () => router.navigate(AppRoute.studyOutput(
                            outputId: file.generated[i].id)),
                        child: _generatedRow(file.generated[i]),
                      ),
                      if (i < file.generated.length - 1)
                        Divider(height: 1, color: SBColors.softLine),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _generatedRow(GeneratedOutput output) {
    return Padding(
      padding: const EdgeInsets.all(SBSpacing.md),
      child: Row(
        children: [
          SBIcon(SBOutputStyle.outputIcon(output.kind),
              size: 22, color: SBOutputStyle.outputColor(output.kind)),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(output.title,
                    style:
                        SBTypography.titleSmall.copyWith(color: SBColors.navy)),
                const SizedBox(height: SBSpacing.xs),
                Text(
                  output.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      SBTypography.bodySmall.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SBSpacing.sm),
          Text(output.updatedLabel,
              style: SBTypography.caption.copyWith(color: SBColors.muted)),
          const SizedBox(width: SBSpacing.sm),
          SBIcon('chevron.right', size: 14, color: SBColors.softText),
        ],
      ),
    );
  }

  // MARK: - Actions

  Future<void> _generate(GeneratedKind kind) async {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final file = store.file(widget.fileId);
    if (file == null) return;
    await store.enqueueDriveGeneration(file: file, kind: kind);
    router.navigate(
        AppRoute.queue(surface: SourceBaseQueueSurface.surfaceFor(kind)));
  }

  void _showRename(DriveFile file) {
    final store = context.read<WorkspaceStore>();
    final controller = TextEditingController(text: file.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosyayı yeniden adlandır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Drive içinde görünen kaynak adını günceller.'),
            const SizedBox(height: SBSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Dosya adı'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              store.renameFile(file.id, title: controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showMove(DriveFile file) {
    final store = context.read<WorkspaceStore>();
    String? currentSectionId;
    for (final course in store.workspace.courses) {
      for (final section in course.sections) {
        if (section.files.any((f) => f.id == widget.fileId)) {
          currentSectionId = section.id;
        }
      }
    }
    showDriveMoveSheet(
      context,
      fileCount: 1,
      currentSectionId: currentSectionId,
      onMove: (destination) {
        store.moveFiles([file.id],
            courseId: destination.courseId, sectionId: destination.sectionId);
      },
    );
  }

  void _confirmDelete(DriveFile file) {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosya silinsin mi?'),
        content: Text('${file.title} Drive alanından kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await store.deleteFiles([file.id]);
              router.popToRoot();
            },
            child: Text('Sil', style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }
}
