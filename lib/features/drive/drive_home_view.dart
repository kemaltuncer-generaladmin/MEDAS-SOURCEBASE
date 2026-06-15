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
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_status_badge.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';
import '../study/sb_output_style.dart';
import 'drive_direct_file_importer.dart';
import 'sb_node_creation.dart';

/// Port of DriveHomeView.
class DriveHomeView extends StatefulWidget {
  const DriveHomeView({super.key});

  @override
  State<DriveHomeView> createState() => _DriveHomeViewState();
}

class _DriveHomeViewState extends State<DriveHomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final workspace = store.workspace;

    final allFiles = store.allFiles;
    final readyFiles =
        allFiles.where((f) => store.isReadyForGeneration(f)).toList();
    final readyCount = readyFiles.length;
    final processingCount = allFiles
        .where((f) =>
            f.status == DriveItemStatus.processing ||
            f.status == DriveItemStatus.uploading)
        .length;
    final recentReadyFiles = readyFiles.take(4).toList();
    final quickContinueOutput = store.quickContinueOutput;
    final quickContinueFile = store.quickContinueReadyFile;

    return SBPageBackground(
      tone: SBPageTone.warm,
      child: RefreshIndicator(
        onRefresh: () => store.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (store.isLoading && !store.hasLoadedWorkspace)
                  const SBLoadingState(
                    icon: 'folder',
                    title: 'Drive yükleniyor',
                    message: 'Kaynakların hazırlanıyor...',
                  )
                else if (store.errorMessage != null)
                  SBErrorState(
                    title: 'Drive yüklenemedi',
                    message: store.errorMessage!,
                    actionLabel: 'Tekrar dene',
                    onAction: () => store.refresh(),
                  )
                else ...[
                  SBEntrance(
                    index: 0,
                    child: SBPageHeader(
                      title: 'Drive',
                      subtitle:
                          'Kaynak yükle, hazır olanı seç ve üretime geç.',
                      primaryIcon: 'magnifyingglass',
                      onPrimary: () => router.navigate(AppRoute.search),
                    ),
                  ),
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(
                    index: 1,
                    child: _workspaceHero(store, router, readyCount,
                        processingCount, quickContinueFile,
                        collectionCount: workspace.collections.length),
                  ),
                  if (quickContinueOutput != null) ...[
                    const SizedBox(height: SBSpacing.lg),
                    SBEntrance(
                      index: 2,
                      child: SBQuickContinueSurface(
                        eyebrow: 'Kaldığın yer',
                        title: quickContinueOutput.output.title,
                        message: 'Son çalışmana kaldığın yerden dön.',
                        metadata:
                            '${quickContinueOutput.file.courseTitle} • ${quickContinueOutput.output.updatedLabel}',
                        actionLabel: 'Aç',
                        icon: SBOutputStyle.outputIcon(
                            quickContinueOutput.output.kind),
                        tint: SBOutputStyle.outputColor(
                            quickContinueOutput.output.kind),
                        onTap: () => router.navigate(AppRoute.studyOutput(
                            outputId: quickContinueOutput.output.id)),
                      ),
                    ),
                  ],
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(
                    index: 3,
                    child: SBWorkspaceMomentumRibbon(
                      readyCount: readyCount,
                      outputCount: store.totalGeneratedOutputCount,
                      focusTitle: store.momentumFocusTitle,
                    ),
                  ),
                  if (store.uploadPhase != SBUploadPhase.idle) ...[
                    const SizedBox(height: SBSpacing.lg),
                    SBNotice(
                      icon: store.uploadPhase == SBUploadPhase.error
                          ? 'exclamationmark.triangle'
                          : 'icloud.and.arrow.up',
                      message: store.uploadPhase.message,
                      tint: store.uploadPhase == SBUploadPhase.error
                          ? SBColors.red
                          : SBColors.blue,
                    ),
                  ],
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(
                    index: 4,
                    child: _coursesSection(store, router),
                  ),
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(
                    index: 5,
                    child: _readySourcesSection(
                        router, recentReadyFiles, processingCount),
                  ),
                  if (workspace.collections.isNotEmpty) ...[
                    const SizedBox(height: SBSpacing.lg),
                    SBEntrance(
                      index: 6,
                      child: _collectionsSection(workspace, router),
                    ),
                  ],
                ],
                const SizedBox(height: 156),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _workspaceHero(
    WorkspaceStore store,
    AppRouter router,
    int readyCount,
    int processingCount,
    DriveFile? quickContinueFile, {
    required int collectionCount,
  }) {
    return SBSignatureHero(
      eyebrow: 'Bugünkü çalışma',
      title: 'Bugün nereden devam edelim?',
      message: readyCount == 0
          ? 'PDF, PPTX, DOCX, PPT veya DOC yükle. Hazır olduğunda tek dokunuşla Üret ekranına geç.'
          : '$readyCount kaynak hazır. Hazır kaynağı seçebilir ya da yeni kaynak ekleyebilirsin.',
      icon: 'folder.badge.gearshape',
      tint: SBColors.blue,
      mode: SBHeroMode.action,
      actions: quickContinueFile != null
          ? Column(
              children: [
                SBButton(
                  'Hazır kaynakla devam et',
                  icon: 'arrow.right.circle.fill',
                  variant: SBButtonVariant.primary,
                  fullWidth: true,
                  onPressed: () =>
                      _selectSourceAndOpenBaseForce(quickContinueFile),
                ),
                const SizedBox(height: SBSpacing.sm),
                SBButton(
                  'Yeni kaynak yükle',
                  icon: 'icloud.and.arrow.up',
                  variant: SBButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: _showImporter,
                ),
              ],
            )
          : Column(
              children: [
                SBButton(
                  'Yeni kaynak yükle',
                  icon: 'icloud.and.arrow.up',
                  variant: SBButtonVariant.primary,
                  fullWidth: true,
                  onPressed: _showImporter,
                ),
                if (processingCount > 0) ...[
                  const SizedBox(height: SBSpacing.sm),
                  SBButton(
                    'Hazırlananları gör',
                    icon: 'clock',
                    variant: SBButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => router.navigate(AppRoute.uploads),
                  ),
                ],
              ],
            ),
      footer: SBMetricRibbon(items: [
        SBMetricRibbonItem(
            icon: 'checkmark.seal',
            value: '$readyCount',
            label: 'hazır',
            tint: SBColors.green),
        SBMetricRibbonItem(
            icon: 'clock',
            value: '$processingCount',
            label: 'hazırlanıyor',
            tint: SBColors.orange),
        SBMetricRibbonItem(
            icon: 'rectangle.stack',
            value: '$collectionCount',
            label: 'koleksiyon',
            tint: SBColors.purple),
      ]),
    );
  }

  Widget _readySourcesSection(
      AppRouter router, List<DriveFile> recentReadyFiles, int processingCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SBSectionHeader(title: 'Hazır kaynaklar'),
        const SizedBox(height: SBSpacing.md),
        if (recentReadyFiles.isEmpty)
          SBEmptyState(
            icon: processingCount > 0 ? 'hourglass' : 'folder.badge.plus',
            title: processingCount > 0
                ? 'Kaynak işleniyor'
                : 'Henüz hazır kaynak yok',
            message: processingCount > 0
                ? 'Metin çıkınca burada seçip çalışma seti hazırlayabilirsin.'
                : 'Bir ders notu yükle. Hazır olunca buradan çalışmaya geç.',
            badges: const ['PDF', 'PPTX', 'DOCX'],
            context_: SBEmptyStateContext.drive,
          )
        else
          Column(
            children: [
              for (final file in recentReadyFiles) ...[
                SBFileCard(
                  title: file.title,
                  kind: sbFileKindFrom(file.kind),
                  status: sbStatusFrom(file.status),
                  sizeLabel: file.sizeLabel,
                  courseTitle: file.courseTitle,
                  updatedLabel: file.updatedLabel,
                  onTap: () =>
                      router.navigate(AppRoute.fileDetail(fileId: file.id)),
                ),
                const SizedBox(height: SBSpacing.md),
              ],
            ],
          ),
      ],
    );
  }

  Widget _coursesSection(WorkspaceStore store, AppRouter router) {
    final courses = store.workspace.courses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SBSectionHeader(
          title: 'Derslerim',
          action: courses.isEmpty ? null : 'Ders ekle',
          onAction: _showCreateCourse,
        ),
        const SizedBox(height: SBSpacing.md),
        if (courses.isEmpty)
          SBEmptyState(
            icon: 'plus.rectangle.on.folder',
            title: 'Ders yok',
            message: 'Ders oluştur, kaynakları içine at.',
            badges: const ['Ders', 'Bölüm', 'Kaynak'],
            actionLabel: 'Ders oluştur',
            onAction: _showCreateCourse,
            context_: SBEmptyStateContext.drive,
          )
        else
          SBCard(
            child: Column(
              children: [
                for (final course in courses.take(3)) ...[
                  SBPressable(
                    onTap: () => router
                        .navigate(AppRoute.courseDetail(courseId: course.id)),
                    child: _courseRow(course),
                  ),
                  if (course.id != courses.take(3).last.id)
                    Divider(color: SBColors.softLine, height: SBSpacing.lg),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _courseRow(DriveCourse course) {
    final tint = colorFromHex(course.iconColorHex);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SBSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: SBIcon(course.iconName, size: 22, color: tint),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy),
                ),
                const SizedBox(height: SBSpacing.xs),
                Text(
                  '${course.sections.length} bölüm • ${course.fileCount} dosya',
                  style:
                      SBTypography.bodySmall.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: course.status == DriveItemStatus.draft
                  ? SBColors.selectedBlue
                  : SBColors.greenBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              course.status == DriveItemStatus.draft ? 'Beklemede' : 'Aktif',
              style: SBTypography.caption.copyWith(
                color: course.status == DriveItemStatus.draft
                    ? SBColors.blue
                    : SBColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionsSection(DriveWorkspaceData workspace, AppRouter router) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SBSectionHeader(
          title: 'Son koleksiyonlar',
          action: workspace.collections.isEmpty ? null : 'Koleksiyonlar',
          onAction: () => router.navigate(AppRoute.collections),
        ),
        const SizedBox(height: SBSpacing.md),
        for (final bundle in workspace.collections.take(3)) ...[
          _collectionCard(bundle, router),
          const SizedBox(height: SBSpacing.md),
        ],
      ],
    );
  }

  Widget _collectionCard(CollectionBundle bundle, AppRouter router) {
    final output = bundle.outputs.isNotEmpty ? bundle.outputs.first : null;
    return SBCard(
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SBColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: SBIcon('bolt.fill', size: 18, color: SBColors.blue),
              ),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      output?.title ?? 'Koleksiyon',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy),
                    ),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      bundle.file.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          SBTypography.caption.copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
              const SBStatusBadge(status: SBStatus.ready, compact: true),
            ],
          ),
          if (output != null) ...[
            const SizedBox(height: SBSpacing.md),
            Text(
              output.detail,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.bodySmall.copyWith(color: SBColors.navy),
            ),
          ],
          const SizedBox(height: SBSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  bundle.file.updatedLabel,
                  style:
                      SBTypography.caption.copyWith(color: SBColors.softText),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (output != null) {
                    router.navigate(
                        AppRoute.studyOutput(outputId: output.id));
                  } else {
                    router.navigate(AppRoute.collections);
                  }
                },
                child: Text('Çalış',
                    style: SBTypography.labelSmall
                        .copyWith(color: SBColors.blue)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImporter() {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    showDriveDirectFileImporter(
      context,
      initialDestination: store.preferredUploadDestination,
      onComplete: (uploaded) {
        if (uploaded) router.navigate(AppRoute.uploads);
      },
    );
  }

  void _showCreateCourse() {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    showCreateNodeSheet(
      context,
      heading: 'Ders oluştur',
      placeholder: 'Örn: Anatomi',
      confirmLabel: 'Oluştur',
      onCreate: (title, icon, color) async {
        final course = await store.createCourse(
            title: title, iconName: icon, colorHex: color);
        if (course != null) {
          router.navigate(AppRoute.courseDetail(courseId: course.id));
        }
      },
    );
  }

  void _selectSourceAndOpenBaseForce(DriveFile file) {
    final store = context.read<WorkspaceStore>();
    final router = context.read<AppRouter>();
    store.setSelectedSources({file.id});
    store.selectFile(file);
    store.toast('Kaynak seçildi. Üretim türünü seç.');
    router.beginSourceSelection(
        from: AppRoute.baseForce,
        destination: SourcePickerDestination.baseForceHome);
  }
}
