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

/// Port of SourcePickerView.
class SourcePickerView extends StatefulWidget {
  const SourcePickerView({super.key});

  @override
  State<SourcePickerView> createState() => _SourcePickerViewState();
}

class _SourcePickerViewState extends State<SourcePickerView> {
  Set<String> _selectedSources = {};
  final _searchQuery = TextEditingController();
  String? _selectedCourseFilterId;
  String? _selectedSectionFilterId;

  @override
  void initState() {
    super.initState();
    final store = context.read<WorkspaceStore>();
    _selectedSources = {...store.selectedSourceIds};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.loadWorkspace();
    });
  }

  @override
  void dispose() {
    _searchQuery.dispose();
    super.dispose();
  }

  List<DriveFile> _filteredFiles(WorkspaceStore store) {
    var files = store.allFiles;
    final course = store.course(_selectedCourseFilterId);
    if (course != null) {
      final ids = {
        for (final s in course.sections) ...s.files.map((f) => f.id)
      };
      files = files.where((f) => ids.contains(f.id)).toList();
    }
    final section = store.section(_selectedSectionFilterId);
    if (section != null) {
      final ids = section.files.map((f) => f.id).toSet();
      files = files.where((f) => ids.contains(f.id)).toList();
    }
    final query = _searchQuery.text.toLowerCase();
    if (query.isEmpty) return files;
    return files
        .where((f) =>
            f.title.toLowerCase().contains(query) ||
            f.courseTitle.toLowerCase().contains(query) ||
            f.sectionTitle.toLowerCase().contains(query))
        .toList();
  }

  String _sourceContextLabel(DriveFile file) {
    final course = file.courseTitle.trim();
    final section = file.sectionTitle.trim();
    if (course.isNotEmpty && section.isNotEmpty) return '$course / $section';
    return course.isEmpty ? section : course;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;
    final allFiles = store.allFiles;
    final readyCount =
        allFiles.where((f) => store.isReadyForGeneration(f)).length;
    final processingCount = allFiles
        .where((f) =>
            f.status == DriveItemStatus.processing ||
            f.status == DriveItemStatus.uploading)
        .length;
    final blockedCount = allFiles.length - readyCount - processingCount;
    final filteredFiles = _filteredFiles(store);
    final filteredReadyCount =
        filteredFiles.where((f) => store.isReadyForGeneration(f)).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Kaynak Seç',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      bottomNavigationBar: _selectedSources.isEmpty
          ? null
          : SBBottomCTA(
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_selectedSources.length} kaynak seçildi',
                              style: SBTypography.labelMedium
                                  .copyWith(color: SBColors.navy)),
                          const SizedBox(height: 2),
                          Text(
                            _selectedTraySubtitle(filteredFiles),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SBTypography.caption
                                .copyWith(color: SBColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SBSpacing.md),
                    SBButton(
                      'Çalışma türünü seç',
                      icon: 'arrow.right',
                      variant: SBButtonVariant.primary,
                      size: SBButtonSize.small,
                      onPressed: () =>
                          _continueWithSelection(store, router, filteredFiles),
                    ),
                  ],
                ),
              ),
            ),
      body: SBPageBackground(
        tone: SBPageTone.cool,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const SBLoadingState(
                  icon: 'folder',
                  title: 'Kaynaklar yükleniyor',
                  message: 'Drive dosyaları hazırlanıyor...',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Kaynaklar yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else ...[
                SBEntrance(
                  index: 0,
                  child: SBSignatureHero(
                    eyebrow: 'Ders kaynağı',
                    title: 'Hangi nottan çalışacaksın?',
                    message: _selectedSources.isEmpty
                        ? 'Hazır kaynağı seç. Sonraki ekranda üretim türünü aç.'
                        : '${_selectedSources.length} kaynak seçildi. Şimdi çalışma türünü seç.',
                    icon: 'doc.text.magnifyingglass',
                    tint: SBColors.blue,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'checkmark.circle',
                          value: '$readyCount',
                          label: 'hazır',
                          tint: SBColors.green),
                      SBMetricRibbonItem(
                          icon: 'hourglass',
                          value: '$processingCount',
                          label: 'işleniyor',
                          tint: SBColors.orange),
                      SBMetricRibbonItem(
                          icon: 'xmark.circle',
                          value: '$blockedCount',
                          label: 'uygun değil',
                          tint: SBColors.red),
                    ]),
                  ),
                ),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 1, child: _selectionGuide(store)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 2, child: _searchBox()),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 3, child: _sourceFilters(store)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 4,
                  child: _filesSection(store, router, allFiles, filteredFiles,
                      readyCount, filteredReadyCount),
                ),
              ],
              const SizedBox(height: 160),
            ],
          ),
        ),
      ),
    );
  }

  String _filterSummary(WorkspaceStore store) {
    final course = store.course(_selectedCourseFilterId)?.title;
    final section = store.section(_selectedSectionFilterId)?.title;
    if (course != null && section != null) return '$course / $section';
    if (course != null) return '$course içindeki kaynaklar';
    return 'Tüm Drive kaynakları';
  }

  Widget _selectionGuide(WorkspaceStore store) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIcon(
                _selectedSources.isEmpty ? 'hand.raised' : 'checkmark.seal.fill',
                size: 18,
                color: _selectedSources.isEmpty
                    ? SBColors.blue
                    : SBColors.green,
              ),
              const SizedBox(width: SBSpacing.sm),
              Expanded(
                child: Text(
                  _selectedSources.isEmpty
                      ? 'Sınav konuna en yakın hazır kaynağı seç'
                      : 'Seçim hazır',
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              _guideChip('Konu', _filterSummary(store), 'books.vertical',
                  SBColors.purple, _selectedCourseFilterId != null),
              _guideChip(
                  'Kaynak',
                  _selectedSources.isEmpty
                      ? 'Seçilmedi'
                      : '${_selectedSources.length} seçili',
                  'doc.text',
                  _selectedSources.isEmpty ? SBColors.orange : SBColors.green,
                  true),
              _guideChip('Sonra', 'Kart, soru, özet', 'bolt.fill',
                  SBColors.blue, _selectedSources.isNotEmpty),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideChip(
      String title, String value, String icon, Color tint, bool isActive) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(SBSpacing.sm),
      decoration: BoxDecoration(
        color: isActive
            ? tint.withValues(alpha: 0.08)
            : SBColors.field.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? tint.withValues(alpha: 0.18) : SBColors.softLine,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: SBIcon(icon, size: 15, color: tint),
          ),
          const SizedBox(width: SBSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SBTypography.labelMedium
                        .copyWith(color: SBColors.navy)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        SBTypography.caption.copyWith(color: SBColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SBColors.softLine),
      ),
      child: Row(
        children: [
          SBIcon('magnifyingglass', size: 18, color: SBColors.muted),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: TextField(
              controller: _searchQuery,
              style: SBTypography.bodyMedium.copyWith(color: SBColors.navy),
              decoration: InputDecoration(
                hintText: 'Ders, bölüm veya kaynak ara',
                hintStyle:
                    SBTypography.bodyMedium.copyWith(color: SBColors.softText),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceFilters(WorkspaceStore store) {
    final selectedCourse = store.course(_selectedCourseFilterId);
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SBIconTile(
                  icon: 'line.3.horizontal.decrease.circle',
                  tint: Color(0xFF0A5BFF),
                  size: 34,
                  radius: 10),
              const SizedBox(width: SBSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ders / bölüm',
                        style: SBTypography.titleSmall
                            .copyWith(color: SBColors.navy)),
                    const SizedBox(height: 2),
                    Text(_filterSummary(store),
                        style: SBTypography.caption
                            .copyWith(color: SBColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              _filterChip('Tüm dersler', _selectedCourseFilterId == null,
                  SBColors.blue, () {
                setState(() {
                  _selectedCourseFilterId = null;
                  _selectedSectionFilterId = null;
                });
              }),
              for (final course in store.workspace.courses
                  .where((c) => c.fileCount > 0))
                _filterChip(
                    course.title,
                    _selectedCourseFilterId == course.id,
                    SBColors.purple, () {
                  setState(() {
                    _selectedCourseFilterId = course.id;
                    _selectedSectionFilterId = null;
                  });
                }),
            ],
          ),
          if (selectedCourse != null && selectedCourse.sections.isNotEmpty) ...[
            const SizedBox(height: SBSpacing.md),
            Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                _filterChip('Tüm bölümler', _selectedSectionFilterId == null,
                    SBColors.blue, () {
                  setState(() => _selectedSectionFilterId = null);
                }),
                for (final section
                    in selectedCourse.sections.where((s) => s.files.isNotEmpty))
                  _filterChip(
                      section.title,
                      _selectedSectionFilterId == section.id,
                      SBColors.green, () {
                    setState(() => _selectedSectionFilterId = section.id);
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(
      String title, bool isSelected, Color tint, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SBHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SBSpacing.md, vertical: SBSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? tint : SBColors.white,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: isSelected ? tint : SBColors.softLine),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SBTypography.labelSmall
              .copyWith(color: isSelected ? Colors.white : SBColors.navy),
        ),
      ),
    );
  }

  Widget _filesSection(
    WorkspaceStore store,
    AppRouter router,
    List<DriveFile> allFiles,
    List<DriveFile> filteredFiles,
    int readyCount,
    int filteredReadyCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Kaynaklar',
                  style:
                      SBTypography.titleMedium.copyWith(color: SBColors.navy)),
            ),
            Text(
              _searchQuery.text.isEmpty
                  ? '$readyCount hazır'
                  : '$filteredReadyCount hazır',
              style: SBTypography.labelSmall.copyWith(color: SBColors.muted),
            ),
          ],
        ),
        const SizedBox(height: SBSpacing.md),
        SBCard(
          padding: 0,
          radius: 16,
          child: allFiles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(SBSpacing.lg),
                  child: SBEmptyState(
                    icon: 'folder.badge.plus',
                    title: 'Önce bir kaynak yükle',
                    message: "Drive'a dosya ekle, sonra buradan seç.",
                    badges: const ['PDF', 'PPTX', 'DOCX'],
                    actionLabel: "Drive'a git",
                    onAction: () {
                      router.sourcePickerDestination = null;
                      router.switchTab(AppRoute.drive);
                    },
                  ),
                )
              : filteredFiles.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(SBSpacing.lg),
                      child: SBEmptyState(
                        icon: 'magnifyingglass',
                        title: 'Sonuç yok',
                        message:
                            "Aramayı kısalt veya Drive'daki ders adına göre dene.",
                        actionLabel: 'Aramayı temizle',
                        onAction: () =>
                            setState(() => _searchQuery.clear()),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < filteredFiles.length; i++) ...[
                          _sourceRow(store, filteredFiles[i]),
                          if (i < filteredFiles.length - 1)
                            Divider(height: 1, color: SBColors.softLine),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _sourceRow(WorkspaceStore store, DriveFile file) {
    final isSelected = _selectedSources.contains(file.id);
    final isReady = store.isReadyForGeneration(file);

    return SBPressable(
      onTap: isReady
          ? () {
              SBHaptics.selection();
              setState(() {
                if (isSelected) {
                  _selectedSources = {..._selectedSources}..remove(file.id);
                } else {
                  _selectedSources = {..._selectedSources, file.id};
                }
              });
            }
          : null,
      child: Opacity(
        opacity: isReady ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(SBSpacing.md),
          color: isSelected
              ? SBColors.selectedBlue.withValues(alpha: 0.72)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected && isReady
                      ? SBColors.blue
                      : SBColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isReady
                        ? SBColors.blue
                        : SBColors.muted.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: isSelected && isReady
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: SBSpacing.md),
              SBFileKindBadge(kind: sbFileKindFrom(file.kind), compact: true),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy),
                    ),
                    const SizedBox(height: SBSpacing.xs),
                    Wrap(
                      spacing: SBSpacing.sm,
                      runSpacing: SBSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SBStatusBadge(
                            status: sbStatusFrom(file.status), compact: true),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SBColors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _sourceContextLabel(file),
                            maxLines: 1,
                            style: SBTypography.caption
                                .copyWith(color: SBColors.purple),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SBSpacing.sm),
              if (isReady)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isSelected ? 'Seçili' : 'Seç',
                      style: SBTypography.caption.copyWith(
                          color:
                              isSelected ? SBColors.blue : SBColors.muted),
                    ),
                    if (!isSelected) ...[
                      const SizedBox(height: SBSpacing.xs),
                      Text('üretime hazır',
                          style: SBTypography.caption
                              .copyWith(color: SBColors.softText)),
                    ],
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SBIcon('lock.fill', size: 16, color: SBColors.muted),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      file.status == DriveItemStatus.processing ||
                              file.status == DriveItemStatus.uploading
                          ? 'İşleniyor'
                          : 'Hazır değil',
                      style: SBTypography.caption
                          .copyWith(color: SBColors.softText),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _selectedTraySubtitle(List<DriveFile> filteredFiles) {
    for (final file in filteredFiles) {
      if (_selectedSources.contains(file.id)) {
        return _sourceContextLabel(file);
      }
    }
    return 'Çalışma türünü seçmeye hazırsın';
  }

  void _continueWithSelection(
      WorkspaceStore store, AppRouter router, List<DriveFile> filteredFiles) {
    store.setSelectedSources(_selectedSources);
    for (final file in filteredFiles) {
      if (_selectedSources.contains(file.id)) {
        store.selectFile(file);
        break;
      }
    }
    router.completeSourceSelection();
  }
}
