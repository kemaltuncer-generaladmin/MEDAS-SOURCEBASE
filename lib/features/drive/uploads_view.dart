import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import '../../design_system/sb_status_badge.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';
import 'drive_direct_file_importer.dart';

enum _UploadFilter {
  all('Tümü', 'list.bullet'),
  active('İşleniyor', 'arrow.triangle.2.circlepath'),
  completed('Hazır', 'checkmark.circle'),
  failed('Tekrar dene', 'exclamationmark.triangle');

  const _UploadFilter(this.label, this.icon);

  final String label;
  final String icon;

  Color get color => switch (this) {
        _UploadFilter.all || _UploadFilter.active => SBColors.blue,
        _UploadFilter.completed => SBColors.green,
        _UploadFilter.failed => SBColors.red,
      };
}

/// Port of UploadsView.
class UploadsView extends StatefulWidget {
  const UploadsView({super.key});

  @override
  State<UploadsView> createState() => _UploadsViewState();
}

class _UploadsViewState extends State<UploadsView> {
  _UploadFilter _selectedFilter = _UploadFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  List<UploadTask> _filtered(List<UploadTask> uploads) => switch (
          _selectedFilter) {
        _UploadFilter.all => uploads,
        _UploadFilter.active => uploads
            .where((u) =>
                u.status == DriveItemStatus.uploading ||
                u.status == DriveItemStatus.processing)
            .toList(),
        _UploadFilter.completed => uploads
            .where((u) => u.status == DriveItemStatus.completed)
            .toList(),
        _UploadFilter.failed => uploads
            .where((u) => u.status == DriveItemStatus.failed)
            .toList(),
      };

  String get _emptyTitle => switch (_selectedFilter) {
        _UploadFilter.all => 'Henüz yükleme yok',
        _UploadFilter.active => 'Devam eden yükleme yok',
        _UploadFilter.completed => 'Hazır dosya yok',
        _UploadFilter.failed => 'Tekrar denenecek kaynak yok',
      };

  String get _emptyMessage => switch (_selectedFilter) {
        _UploadFilter.all =>
          'PDF, PPTX, DOCX, PPT veya DOC dosyanı ekledikten sonra durum takibi burada görünür.',
        _UploadFilter.active =>
          'Yeni dosya seçtiğinde yükleme ilerlemesi burada görünür.',
        _UploadFilter.completed =>
          'Metni çıkarılıp üretime hazır olan dosyalar burada görünür.',
        _UploadFilter.failed =>
          'Tamamlanmayan yüklemeleri buradan yeniden başlatabilirsin.',
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final uploads = store.workspace.uploads;
    final filteredUploads = _filtered(uploads);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Hazır kaynaklar',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        actions: [
          TextButton.icon(
            onPressed: _showImporter,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni dosya'),
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
                  icon: 'icloud',
                  title: 'Yüklemeler alınıyor',
                  message: 'Dosya durumları hazırlanıyor...',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Yüklemeler alınamadı',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else ...[
                _filterBar(),
                const SizedBox(height: SBSpacing.lg),
                if (uploads.isEmpty)
                  SBEmptyState(
                    icon: 'icloud.and.arrow.up',
                    title: _emptyTitle,
                    message: _emptyMessage,
                    badges: const ['PDF', 'PPTX', 'DOCX', 'PPT', 'DOC'],
                    actionLabel: 'Yeni dosya',
                    onAction: _showImporter,
                  )
                else if (filteredUploads.isEmpty)
                  SBEmptyState(
                    icon: 'line.3.horizontal.decrease.circle',
                    title: _emptyTitle,
                    message: _emptyMessage,
                    badges: const ['Durum takibi'],
                    actionLabel: 'Filtreyi temizle',
                    onAction: () =>
                        setState(() => _selectedFilter = _UploadFilter.all),
                  )
                else
                  Column(
                    children: [
                      for (final upload in filteredUploads) ...[
                        _uploadCard(store, upload),
                        const SizedBox(height: SBSpacing.md),
                      ],
                    ],
                  ),
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _UploadFilter.values) ...[
            _filterChip(filter),
            const SizedBox(width: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(_UploadFilter filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
            horizontal: SBSpacing.md, vertical: SBSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? filter.color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? filter.color
                : filter.color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SBIcon(filter.icon,
                size: 14, color: isSelected ? Colors.white : filter.color),
            const SizedBox(width: SBSpacing.xs),
            Text(filter.label,
                style: SBTypography.labelSmall.copyWith(
                    color: isSelected ? Colors.white : filter.color)),
          ],
        ),
      ),
    );
  }

  Widget _uploadCard(WorkspaceStore store, UploadTask upload) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SBFileKindBadge(kind: sbFileKindFrom(upload.file.kind)),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      upload.file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.titleMedium
                          .copyWith(color: SBColors.navy),
                    ),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      '${upload.file.sizeLabel} • ${upload.file.pageLabel}',
                      style: SBTypography.bodySmall
                          .copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.xs,
            runSpacing: SBSpacing.xs,
            children: [
              _metaPill('folder',
                  '${upload.file.courseTitle} › ${upload.file.sectionTitle}'),
              _metaPill('clock', upload.file.updatedLabel),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          _uploadStateView(store, upload),
        ],
      ),
    );
  }

  Widget _metaPill(String icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: SBColors.field.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SBIcon(icon, size: 11, color: SBColors.muted),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.caption.copyWith(color: SBColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadStateView(WorkspaceStore store, UploadTask upload) {
    switch (upload.status) {
      case DriveItemStatus.completed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SBStatusBadge(status: SBStatus.ready, compact: true),
            const SizedBox(height: SBSpacing.sm),
            Text('Kaynak hazır. Üret ekranında kullanılabilir.',
                style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          ],
        );
      case DriveItemStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SBStatusBadge(status: SBStatus.failed, compact: true),
            const SizedBox(height: SBSpacing.sm),
            Text(
              upload.errorLabel ??
                  upload.file.statusMessage ??
                  'Kaynak hazırlanamadı.',
              style: SBTypography.bodySmall.copyWith(color: SBColors.muted),
            ),
            const SizedBox(height: SBSpacing.sm),
            SBButton(
              'Tekrar dene',
              icon: 'arrow.clockwise',
              variant: SBButtonVariant.secondary,
              size: SBButtonSize.small,
              onPressed: () => store.retryFileProcessing(upload.file.id),
            ),
          ],
        );
      case DriveItemStatus.processing:
        return _processingView(
          title: 'Kaynak işleniyor',
          message: 'Metin çıkarılıyor ve üretime hazırlanıyor.',
          progress: upload.progress,
          tags: [upload.file.sizeLabel, upload.file.pageLabel],
        );
      case DriveItemStatus.uploading:
        return _processingView(
          title: 'Dosya yükleniyor',
          message: 'Bu işlem dosya boyutuna göre kısa sürebilir.',
          progress: upload.progress,
          tags: [upload.file.sizeLabel],
        );
      case DriveItemStatus.draft:
        return const SBStatusBadge(status: SBStatus.draft, compact: true);
    }
  }

  Widget _processingView({
    required String title,
    required String message,
    required double progress,
    required List<String> tags,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(SBColors.blue),
              ),
            ),
            const SizedBox(width: SBSpacing.sm),
            Text(title,
                style:
                    SBTypography.labelMedium.copyWith(color: SBColors.blue)),
          ],
        ),
        const SizedBox(height: SBSpacing.sm),
        Text(message,
            style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
        const SizedBox(height: SBSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: SBColors.softLine,
            valueColor: AlwaysStoppedAnimation(SBColors.blue),
          ),
        ),
        const SizedBox(height: SBSpacing.sm),
        Wrap(
          spacing: SBSpacing.xs,
          runSpacing: SBSpacing.xs,
          children: [
            for (final tag in tags) _progressTag(tag),
            _progressTag('İlerleme ${(progress * 100).round()}%'),
          ],
        ),
      ],
    );
  }

  Widget _progressTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SBColors.selectedBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child:
          Text(text, style: SBTypography.caption.copyWith(color: SBColors.blue)),
    );
  }

  void _showImporter() {
    final store = context.read<WorkspaceStore>();
    showDriveDirectFileImporter(
      context,
      initialDestination: store.preferredUploadDestination,
      onComplete: (_) =>
          setState(() => _selectedFilter = _UploadFilter.all),
    );
  }
}
