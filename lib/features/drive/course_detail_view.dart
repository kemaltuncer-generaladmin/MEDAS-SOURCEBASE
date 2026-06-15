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
import 'drive_direct_file_importer.dart';
import 'sb_node_creation.dart';

enum _CourseTab {
  sections('Bölümler', 'list.bullet.rectangle'),
  files('Dosyalar', 'doc.text'),
  details('Ayrıntılar', 'info.circle');

  const _CourseTab(this.label, this.icon);

  final String label;
  final String icon;
}

/// Port of CourseDetailView.
class CourseDetailView extends StatefulWidget {
  const CourseDetailView({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<CourseDetailView> {
  _CourseTab _selectedTab = _CourseTab.sections;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  DriveCourse? get _course =>
      context.read<WorkspaceStore>().course(widget.courseId);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final course = store.course(widget.courseId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text(
          course?.title ?? 'Ders',
          style: SBTypography.titleMedium.copyWith(color: SBColors.navy),
        ),
        actions: [
          if (course != null)
            PopupMenuButton<String>(
              icon: SBIcon('ellipsis.circle', size: 18, color: SBColors.navy),
              onSelected: (action) {
                if (action == 'rename') _showRenameCourse(course);
                if (action == 'delete') _confirmDeleteCourse(course);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: 'rename', child: Text('Yeniden adlandır')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
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
                  icon: 'book',
                  title: 'Ders yükleniyor',
                  message: 'Bölümler ve dosyalar hazırlanıyor...',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Ders yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else if (course != null) ...[
                SBEntrance(index: 0, child: _courseHeader(course)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 1, child: _tabSelector()),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 2, child: _tabContent(course, router)),
              ] else
                SBErrorState(
                  icon: 'book.closed',
                  title: 'Ders bulunamadı',
                  message:
                      'Bu ders silinmiş veya Drive verisi yenilenmiş olabilir.',
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

  Widget _courseHeader(DriveCourse course) {
    final tint = colorFromHex(course.iconColorHex);
    return SBSignatureHero(
      eyebrow: 'Ders alanı',
      title: course.title,
      message: course.description,
      icon: course.iconName,
      tint: tint,
      actions: Row(
        children: [
          SBButton(
            'Dosya yükle',
            icon: 'icloud.and.arrow.up',
            variant: SBButtonVariant.primary,
            size: SBButtonSize.small,
            onPressed: _showImporter,
          ),
          const SizedBox(width: SBSpacing.sm),
          SBButton(
            'Bölüm ekle',
            icon: 'folder.badge.plus',
            variant: SBButtonVariant.secondary,
            size: SBButtonSize.small,
            onPressed: _showCreateSection,
          ),
        ],
      ),
      footer: SBMetricRibbon(items: [
        SBMetricRibbonItem(
            icon: 'folder',
            value: '${course.sections.length}',
            label: 'bölüm',
            tint: tint),
        SBMetricRibbonItem(
            icon: 'doc',
            value: '${course.fileCount}',
            label: 'dosya',
            tint: SBColors.blue),
        SBMetricRibbonItem(
            icon: 'clock',
            value: course.updatedLabel,
            label: 'güncelleme',
            tint: SBColors.green),
      ]),
    );
  }

  Widget _tabSelector() {
    return SBCard(
      padding: 4,
      radius: 12,
      child: Row(
        children: [
          for (final tab in _CourseTab.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding:
                      const EdgeInsets.symmetric(vertical: SBSpacing.sm),
                  decoration: BoxDecoration(
                    color: _selectedTab == tab
                        ? SBColors.blue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      SBIcon(tab.icon,
                          size: 16,
                          color: _selectedTab == tab
                              ? Colors.white
                              : SBColors.muted),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: SBTypography.labelSmall.copyWith(
                          color: _selectedTab == tab
                              ? Colors.white
                              : SBColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabContent(DriveCourse course, AppRouter router) {
    switch (_selectedTab) {
      case _CourseTab.sections:
        return _sectionsTab(course, router);
      case _CourseTab.files:
        return _filesTab(course, router);
      case _CourseTab.details:
        return _detailsTab(course);
    }
  }

  Widget _sectionsTab(DriveCourse course, AppRouter router) {
    if (course.sections.isEmpty) {
      return const SBEmptyState(
        icon: 'folder.badge.plus',
        title: 'Bu derste henüz bölüm yok',
        message: 'Bölüm ekleyerek dosyalarını düzenlemeye başlayabilirsin.',
      );
    }
    return Column(
      children: [
        for (final section in course.sections) ...[
          _sectionCard(section, router),
          const SizedBox(height: SBSpacing.md),
        ],
      ],
    );
  }

  Widget _sectionCard(DriveSection section, AppRouter router) {
    final tint = colorFromHex(section.iconColorHex);
    return GestureDetector(
      onLongPress: () => _showSectionActions(section, router),
      child: SBCommandCard(
        tint: tint,
        onTap: () => router.navigate(AppRoute.folder(
            courseId: widget.courseId, sectionId: section.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SBIconTile(
                    icon: section.iconName, tint: tint, size: 42, radius: 12),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.titleSmall
                            .copyWith(color: SBColors.navy),
                      ),
                      const SizedBox(height: SBSpacing.xs),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: section.status == DriveItemStatus.draft
                                  ? SBColors.selectedBlue
                                  : SBColors.greenBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              section.status == DriveItemStatus.draft
                                  ? 'Beklemede'
                                  : 'Aktif',
                              style: SBTypography.caption.copyWith(
                                color:
                                    section.status == DriveItemStatus.draft
                                        ? SBColors.blue
                                        : SBColors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: SBSpacing.sm),
                          Text(
                            '${section.files.length} dosya',
                            style: SBTypography.caption
                                .copyWith(color: SBColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SBIcon('chevron.right', size: 14, color: SBColors.softText),
              ],
            ),
            const SizedBox(height: SBSpacing.md),
            if (section.files.isNotEmpty)
              Wrap(
                spacing: SBSpacing.xs,
                runSpacing: SBSpacing.xs,
                children: [
                  for (final file in section.files.take(3))
                    _miniFileChip(file),
                  if (section.files.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: SBColors.selectedBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${section.files.length - 3}',
                        style: SBTypography.caption
                            .copyWith(color: SBColors.blue),
                      ),
                    ),
                ],
              )
            else
              Text('Henüz dosya yok',
                  style:
                      SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _miniFileChip(DriveFile file) {
    final kind = sbFileKindFrom(file.kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SBColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kind.label,
              style: SBTypography.scaled(9, weight: FontWeight.bold)
                  .copyWith(color: kind.color)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.caption.copyWith(color: SBColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filesTab(DriveCourse course, AppRouter router) {
    final allFiles = [
      for (final s in course.sections) ...s.files,
    ];
    if (allFiles.isEmpty) {
      return const SBEmptyState(
        icon: 'doc.badge.plus',
        title: 'Bu derste henüz dosya yok',
        message: 'PDF, PPTX, DOCX, PPT veya DOC yükleyerek başlayabilirsin.',
      );
    }
    return Column(
      children: [
        for (final file in allFiles) ...[
          SBFileCard(
            title: file.title,
            kind: sbFileKindFrom(file.kind),
            status: sbStatusFrom(file.status),
            sizeLabel: file.sizeLabel,
            courseTitle: file.courseTitle,
            updatedLabel: file.updatedLabel,
            onTap: () => router.navigate(AppRoute.fileDetail(fileId: file.id)),
          ),
          const SizedBox(height: SBSpacing.md),
        ],
      ],
    );
  }

  Widget _detailsTab(DriveCourse course) {
    return Column(
      children: [
        SBCard(
          child: Column(
            children: [
              _detailRow('Ders adı', course.title),
              const SizedBox(height: SBSpacing.lg),
              _detailRow('Durum',
                  course.status == DriveItemStatus.draft ? 'Beklemede' : 'Aktif'),
              const SizedBox(height: SBSpacing.lg),
              _detailRow('Bölüm sayısı', '${course.sections.length}'),
              const SizedBox(height: SBSpacing.lg),
              _detailRow('Dosya sayısı', '${course.fileCount}'),
              const SizedBox(height: SBSpacing.lg),
              _detailRow('Son güncelleme', course.updatedLabel),
            ],
          ),
        ),
        const SizedBox(height: SBSpacing.md),
        SBCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SBIcon('doc.text', size: 17, color: SBColors.blue),
                  const SizedBox(width: SBSpacing.sm),
                  Text('Açıklama',
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy)),
                ],
              ),
              const SizedBox(height: SBSpacing.md),
              Text(
                course.description.isEmpty
                    ? 'Açıklama bulunmuyor.'
                    : course.description,
                style: SBTypography.bodyMedium
                    .copyWith(color: SBColors.navy, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: SBTypography.bodySmall.copyWith(color: SBColors.muted)),
        ),
        Expanded(
          child: Text(value,
              style: SBTypography.bodySmall.copyWith(color: SBColors.navy)),
        ),
      ],
    );
  }

  // MARK: - Actions

  void _showImporter() {
    final store = context.read<WorkspaceStore>();
    final course = _course;
    DriveDestination? destination;
    if (course != null && course.sections.isNotEmpty) {
      destination = DriveDestination(
        courseId: course.id,
        sectionId: course.sections.first.id,
        courseTitle: course.title,
        sectionTitle: course.sections.first.title,
      );
    }
    showDriveDirectFileImporter(
      context,
      initialDestination: destination ?? store.preferredUploadDestination,
      onComplete: (_) => setState(() => _selectedTab = _CourseTab.files),
    );
  }

  void _showCreateSection() {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    showCreateNodeSheet(
      context,
      heading: 'Bölüm oluştur',
      placeholder: 'Örn: Üst Ekstremite',
      confirmLabel: 'Oluştur',
      onCreate: (title, icon, color) async {
        final section = await store.createSection(
            courseId: widget.courseId,
            title: title,
            iconName: icon,
            colorHex: color);
        if (section != null) {
          router.navigate(AppRoute.folder(
              courseId: widget.courseId, sectionId: section.id));
        }
      },
    );
  }

  void _showRenameCourse(DriveCourse course) {
    final store = context.read<WorkspaceStore>();
    final controller = TextEditingController(text: course.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dersi yeniden adlandır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ders adı Drive boyunca güncellenir.'),
            const SizedBox(height: SBSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Ders adı'),
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
              store.renameCourse(widget.courseId, title: controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCourse(DriveCourse course) {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ders silinsin mi?'),
        content:
            Text('${course.title} içindeki bölüm ve dosyalar kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await store.deleteCourse(widget.courseId);
              router.popToRoot();
            },
            child: Text('Sil', style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }

  void _showSectionActions(DriveSection section, AppRouter router) {
    final store = context.read<WorkspaceStore>();
    showModalBottomSheet(
      context: context,
      backgroundColor: SBColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: SBIcon('folder', size: 18, color: SBColors.blue),
              title: const Text('Aç'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                router.navigate(AppRoute.folder(
                    courseId: widget.courseId, sectionId: section.id));
              },
            ),
            ListTile(
              leading: SBIcon('pencil', size: 18, color: SBColors.navy),
              title: const Text('Yeniden adlandır'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRenameSection(section, store);
              },
            ),
            ListTile(
              leading: SBIcon('trash', size: 18, color: SBColors.red),
              title: Text('Sil', style: TextStyle(color: SBColors.red)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteSection(section, store);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameSection(DriveSection section, WorkspaceStore store) {
    final controller = TextEditingController(text: section.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bölümü yeniden adlandır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bölüm adı Drive boyunca güncellenir.'),
            const SizedBox(height: SBSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Bölüm adı'),
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
              store.renameSection(section.id, title: controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSection(DriveSection section, WorkspaceStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bölüm silinsin mi?'),
        content: Text('${section.title} içindeki dosyalar kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              store.deleteSection(section.id);
              Navigator.of(context).pop();
            },
            child: Text('Sil', style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }
}
