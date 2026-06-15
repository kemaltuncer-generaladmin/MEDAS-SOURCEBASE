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
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';
import '../study/sb_output_style.dart';
import 'drive_direct_file_importer.dart';
import 'drive_move_sheet.dart';

enum _SortOrder {
  newest('En yeni'),
  name('Ada göre'),
  kind('Türe göre');

  const _SortOrder(this.label);

  final String label;
}

/// Port of FolderView: file list of a section with filter/sort, multi-select
/// tray, move/delete actions and saved study outputs.
class FolderView extends StatefulWidget {
  const FolderView(
      {super.key, required this.courseId, required this.sectionId});

  final String courseId;
  final String sectionId;

  @override
  State<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends State<FolderView> {
  Set<String> _selectedFileIds = {};
  SBFileKind? _kindFilter;
  _SortOrder _sortOrder = _SortOrder.newest;

  bool get _hasSelection => _selectedFileIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  List<DriveFile> _visibleFiles(DriveSection section) {
    final filtered = _kindFilter == null
        ? section.files
        : section.files
            .where((f) => sbFileKindFrom(f.kind) == _kindFilter)
            .toList();
    switch (_sortOrder) {
      case _SortOrder.newest:
        return filtered;
      case _SortOrder.name:
        return [...filtered]..sort((a, b) => a.title.compareTo(b.title));
      case _SortOrder.kind:
        return [...filtered]
          ..sort((a, b) => a.kind.name.compareTo(b.kind.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final course = store.course(widget.courseId);
    final section = store.section(widget.sectionId);
    final courseTitle = course?.title ?? '';
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text(
          section?.title ?? 'Bölüm',
          style: SBTypography.titleMedium.copyWith(color: SBColors.navy),
        ),
      ),
      body: SBPageBackground(
        tone: SBPageTone.warm,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const SBLoadingState(
                  icon: 'folder',
                  title: 'Bölüm yükleniyor',
                  message: 'Dosyalar hazırlanıyor...',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Bölüm yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else if (section == null)
                SBErrorState(
                  icon: 'folder.badge.questionmark',
                  title: 'Bölüm bulunamadı',
                  message:
                      'Bu bölüm silinmiş veya Drive verisi yenilenmiş olabilir.',
                  actionLabel: "Drive'a dön",
                  onAction: () => router.popToRoot(),
                )
              else ...[
                if (courseTitle.isNotEmpty)
                  Text(
                    '$courseTitle • ${_visibleFiles(section).length} dosya',
                    style:
                        SBTypography.bodySmall.copyWith(color: SBColors.muted),
                  ),
                const SizedBox(height: SBSpacing.lg),
                _actionButtons(section),
                const SizedBox(height: SBSpacing.lg),
                _toolbarSection(),
                const SizedBox(height: SBSpacing.lg),
                _filesList(store, router, section),
                _outputsList(router, section),
                if (_hasSelection) ...[
                  const SizedBox(height: SBSpacing.lg),
                  _selectionTray(store, router, section),
                ],
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButtons(DriveSection section) {
    return Row(
      children: [
        Expanded(
          child: SBButton(
            'Dosya yükle',
            icon: 'plus',
            variant: SBButtonVariant.primary,
            size: SBButtonSize.small,
            fullWidth: true,
            onPressed: () => _showImporter(section),
          ),
        ),
        const SizedBox(width: SBSpacing.md),
        Expanded(
          child: SBButton(
            _hasSelection ? 'Seçimi Kaldır' : 'Tümünü Seç',
            icon: _hasSelection ? 'xmark.circle' : 'checkmark.circle',
            variant: SBButtonVariant.secondary,
            size: SBButtonSize.small,
            fullWidth: true,
            onPressed: () {
              setState(() {
                if (_hasSelection) {
                  _selectedFileIds = {};
                } else {
                  _selectedFileIds =
                      _visibleFiles(section).map((f) => f.id).toSet();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _toolbarSection() {
    return SBCard(
      padding: SBSpacing.md,
      radius: 12,
      child: Row(
        children: [
          PopupMenuButton<SBFileKind?>(
            onSelected: (kind) => setState(() => _kindFilter = kind),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Tümü')),
              for (final kind in [
                SBFileKind.pdf,
                SBFileKind.pptx,
                SBFileKind.docx,
                SBFileKind.ppt,
                SBFileKind.doc,
              ])
                PopupMenuItem(value: kind, child: Text(kind.label)),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SBIcon('line.3.horizontal.decrease.circle',
                    size: 16, color: SBColors.navy),
                const SizedBox(width: SBSpacing.xs),
                Text(_kindFilter?.label ?? 'Filtrele',
                    style: SBTypography.labelSmall
                        .copyWith(color: SBColors.navy)),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: SBSpacing.lg),
            color: SBColors.line,
          ),
          PopupMenuButton<_SortOrder>(
            onSelected: (order) => setState(() => _sortOrder = order),
            itemBuilder: (context) => [
              for (final order in _SortOrder.values)
                PopupMenuItem(value: order, child: Text(order.label)),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SBIcon('arrow.up.arrow.down', size: 16, color: SBColors.navy),
                const SizedBox(width: SBSpacing.xs),
                Text(_sortOrder.label,
                    style: SBTypography.labelSmall
                        .copyWith(color: SBColors.navy)),
                const SizedBox(width: SBSpacing.xs),
                SBIcon('chevron.down', size: 10, color: SBColors.navy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filesList(
      WorkspaceStore store, AppRouter router, DriveSection section) {
    final visibleFiles = _visibleFiles(section);

    if (section.files.isEmpty) {
      if (section.savedOutputs.isEmpty) {
        return const SBEmptyState(
          icon: 'doc.badge.plus',
          title: 'Bu bölümde henüz dosya yok',
          message: 'Yeni dosyalar yükleyerek başlayabilirsin.',
        );
      }
      return const SizedBox.shrink();
    }
    if (visibleFiles.isEmpty) {
      return const SBEmptyState(
        icon: 'line.3.horizontal.decrease.circle',
        title: 'Bu filtrede dosya yok',
        message: 'Dosya türü filtresini temizleyerek tekrar deneyebilirsin.',
      );
    }
    return Column(
      children: [
        for (final file in visibleFiles) ...[
          _fileRow(store, router, file),
          const SizedBox(height: SBSpacing.md),
        ],
      ],
    );
  }

  Widget _fileRow(WorkspaceStore store, AppRouter router, DriveFile file) {
    final isSelected = _selectedFileIds.contains(file.id);
    final kind = sbFileKindFrom(file.kind);

    return SBCard(
      radius: 14,
      borderColor: isSelected
          ? SBColors.blue.withValues(alpha: 0.4)
          : SBColors.softLine,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (isSelected) {
                _selectedFileIds = {..._selectedFileIds}..remove(file.id);
              } else {
                _selectedFileIds = {..._selectedFileIds, file.id};
              }
            }),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? SBColors.blue : SBColors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected ? SBColors.blue : SBColors.line,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: SBSpacing.sm),
          SBFileKindBadge(kind: kind),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  router.navigate(AppRoute.fileDetail(fileId: file.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        SBTypography.titleSmall.copyWith(color: SBColors.navy),
                  ),
                  const SizedBox(height: SBSpacing.xs),
                  Wrap(
                    spacing: SBSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kind.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(kind.label,
                            style: SBTypography.caption
                                .copyWith(color: kind.color)),
                      ),
                      Text(file.pageLabel,
                          style: SBTypography.caption
                              .copyWith(color: SBColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SBSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(file.sizeLabel,
                  style:
                      SBTypography.labelSmall.copyWith(color: SBColors.navy)),
              const SizedBox(height: SBSpacing.xs),
              Text(file.updatedLabel,
                  style: SBTypography.caption.copyWith(color: SBColors.muted)),
            ],
          ),
          _fileMenu(store, router, file),
        ],
      ),
    );
  }

  Widget _fileMenu(WorkspaceStore store, AppRouter router, DriveFile file) {
    return PopupMenuButton<String>(
      icon: SBIcon('ellipsis', size: 17, color: SBColors.muted),
      onSelected: (action) {
        switch (action) {
          case 'open':
            router.navigate(AppRoute.fileDetail(fileId: file.id));
          case 'select':
            store.toggleSource(file);
          case 'move':
            _showMoveSheet({file.id});
          case 'retry':
            store.retryFileProcessing(file.id);
          case 'delete':
            _confirmDeleteFile(file);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'open', child: Text('Aç')),
        const PopupMenuItem(value: 'select', child: Text('Üretim için seç')),
        const PopupMenuItem(value: 'move', child: Text('Taşı')),
        if (file.status == DriveItemStatus.failed)
          const PopupMenuItem(
              value: 'retry', child: Text('İşlemeyi tekrar dene')),
        PopupMenuItem(
            value: 'delete',
            child: Text('Sil', style: TextStyle(color: SBColors.red))),
      ],
    );
  }

  Widget _outputsList(AppRouter router, DriveSection section) {
    final outputs = section.savedOutputs;
    if (outputs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: SBSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SBIcon('sparkles.rectangle.stack',
                  size: 16, color: SBColors.purple),
              const SizedBox(width: SBSpacing.sm),
              Text('Çalışmalar',
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy)),
              const SizedBox(width: SBSpacing.sm),
              Text('${outputs.length}',
                  style: SBTypography.caption.copyWith(color: SBColors.muted)),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          for (final output in outputs) ...[
            _outputRow(router, output),
            const SizedBox(height: SBSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _outputRow(AppRouter router, GeneratedOutput output) {
    final accent = SBOutputStyle.accent(output.kind);
    return GestureDetector(
      onTap: () => router.navigate(AppRoute.studyOutput(outputId: output.id)),
      child: SBCard(
        radius: 14,
        borderColor: accent.withValues(alpha: 0.18),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: SBIcon(SBOutputStyle.icon(output.kind),
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    output.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        SBTypography.titleSmall.copyWith(color: SBColors.navy),
                  ),
                  const SizedBox(height: SBSpacing.xs),
                  Wrap(
                    spacing: SBSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          SBOutputStyle.templateName(output.kind),
                          style:
                              SBTypography.caption.copyWith(color: accent),
                        ),
                      ),
                      Text(output.updatedLabel,
                          style: SBTypography.caption
                              .copyWith(color: SBColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            SBIcon('chevron.right', size: 13, color: SBColors.softText),
          ],
        ),
      ),
    );
  }

  Widget _selectionTray(
      WorkspaceStore store, AppRouter router, DriveSection section) {
    return SBCard(
      radius: 14,
      borderColor: SBColors.blue.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_selectedFileIds.length} öğe seçildi',
              style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.xs),
          Text('Seçili kaynaklardan hızlıca çalışma üret.',
              style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              _trayAction('doc.text', 'Özet', SBColors.purple,
                  () => _generateSelected(GeneratedKind.summary, section)),
              _trayAction('rectangle.on.rectangle', 'Flashcard',
                  SBColors.green,
                  () => _generateSelected(GeneratedKind.flashcard, section)),
              _trayAction('rectangle.stack', 'Koleksiyonlar', SBColors.navy,
                  () => router.navigate(AppRoute.collections)),
              _trayAction('folder.badge.gearshape', 'Taşı', SBColors.blue,
                  () => _showMoveSheet(_selectedFileIds)),
              _trayAction(
                  'trash', 'Sil', SBColors.red, _confirmBulkDelete),
              _trayAction('xmark', 'Temizle', SBColors.muted,
                  () => setState(() => _selectedFileIds = {})),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trayAction(
      String icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 58,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SBIcon(icon, size: 22, color: color),
            const SizedBox(height: SBSpacing.xs),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SBTypography.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  // MARK: - Actions

  void _showImporter(DriveSection section) {
    final store = context.read<WorkspaceStore>();
    final course = store.course(widget.courseId);
    showDriveDirectFileImporter(
      context,
      initialDestination: DriveDestination(
        courseId: widget.courseId,
        sectionId: widget.sectionId,
        courseTitle: course?.title ?? '',
        sectionTitle: section.title,
      ),
      onComplete: (_) {},
    );
  }

  void _showMoveSheet(Set<String> fileIds) {
    final store = context.read<WorkspaceStore>();
    showDriveMoveSheet(
      context,
      fileCount: fileIds.length,
      currentSectionId: widget.sectionId,
      onMove: (destination) async {
        await store.moveFiles(fileIds.toList(),
            courseId: destination.courseId, sectionId: destination.sectionId);
        setState(() => _selectedFileIds = {});
      },
    );
  }

  void _confirmDeleteFile(DriveFile file) {
    final store = context.read<WorkspaceStore>();
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
            onPressed: () {
              store.deleteFiles([file.id]);
              Navigator.of(context).pop();
            },
            child: Text('Sil', style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete() {
    final store = context.read<WorkspaceStore>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seçili dosyalar silinsin mi?'),
        content: Text(
            '${_selectedFileIds.length} dosya Drive alanından kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              store.deleteFiles(_selectedFileIds.toList());
              setState(() => _selectedFileIds = {});
              Navigator.of(context).pop();
            },
            child: Text('Sil', style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }

  void _generateSelected(GeneratedKind kind, DriveSection section) {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final selectedFiles = _visibleFiles(section)
        .where((f) =>
            _selectedFileIds.contains(f.id) && store.isReadyForGeneration(f))
        .toList();
    if (selectedFiles.isEmpty) {
      store.toast('Üretim için hazır bir dosya seç.');
      return;
    }

    store.setSelectedSources(selectedFiles.map((f) => f.id).toSet());
    store.enqueueDriveGeneration(
      file: selectedFiles.first,
      kind: kind,
      sourceIds: selectedFiles.map((f) => f.id).toSet(),
    );
    router.navigate(
        AppRoute.queue(surface: SourceBaseQueueSurface.surfaceFor(kind)));
    setState(() => _selectedFileIds = {});
  }
}
