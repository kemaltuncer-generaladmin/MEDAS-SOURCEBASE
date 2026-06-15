import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
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

enum _SearchSort {
  newest('En yeni'),
  name('Ada göre'),
  course('Derse göre');

  const _SearchSort(this.label);

  final String label;
}

/// Port of SearchView.
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  SBFileKind? _kindFilter;
  SBStatus? _statusFilter;
  String? _courseFilter;
  String? _sectionFilter;
  bool _featuredOnly = false;
  _SearchSort _sortOrder = _SearchSort.newest;

  static const _statuses = [
    SBStatus.ready,
    SBStatus.processing,
    SBStatus.uploading,
    SBStatus.failed,
    SBStatus.draft,
  ];

  bool get _hasFilters =>
      _query.text.isNotEmpty ||
      _kindFilter != null ||
      _statusFilter != null ||
      _courseFilter != null ||
      _sectionFilter != null ||
      _featuredOnly ||
      _sortOrder != _SearchSort.newest;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<DriveFile> _results(List<DriveFile> files) {
    final queryLower = _query.text.toLowerCase();
    final filtered = files.where((file) {
      final matchesQuery = queryLower.isEmpty ||
          file.title.toLowerCase().contains(queryLower) ||
          file.courseTitle.toLowerCase().contains(queryLower) ||
          file.sectionTitle.toLowerCase().contains(queryLower) ||
          (file.tag?.toLowerCase().contains(queryLower) ?? false);
      return matchesQuery &&
          (_kindFilter == null || sbFileKindFrom(file.kind) == _kindFilter) &&
          (_statusFilter == null ||
              sbStatusFrom(file.status) == _statusFilter) &&
          (_courseFilter == null || file.courseTitle == _courseFilter) &&
          (_sectionFilter == null || file.sectionTitle == _sectionFilter) &&
          (!_featuredOnly || file.featured || file.selected);
    }).toList();

    switch (_sortOrder) {
      case _SearchSort.newest:
        return filtered;
      case _SearchSort.name:
        return filtered..sort((a, b) => a.title.compareTo(b.title));
      case _SearchSort.course:
        return filtered
          ..sort((a, b) => '${a.courseTitle}${a.sectionTitle}${a.title}'
              .compareTo('${b.courseTitle}${b.sectionTitle}${b.title}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final files = store.allFiles;
    final results = _results(files);
    final readyCount =
        files.where((f) => f.status == DriveItemStatus.completed).length;
    final processingCount = files
        .where((f) =>
            f.status == DriveItemStatus.processing ||
            f.status == DriveItemStatus.uploading)
        .length;

    final courses = files.map((f) => f.courseTitle).toSet().toList()..sort();
    final sections = (_courseFilter == null
            ? files
            : files.where((f) => f.courseTitle == _courseFilter))
        .map((f) => f.sectionTitle)
        .toSet()
        .toList()
      ..sort();

    final suggestions = <String>{
      ...courses.take(2),
      if (readyCount > 0) 'Hazır kaynaklar',
      if (files.any((f) => f.kind == DriveFileKind.pptx)) 'PPTX',
      if (files.any((f) => f.kind == DriveFileKind.pdf)) 'PDF',
      ...files.map((f) => f.tag).whereType<String>().take(2),
    }.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Arama',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
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
                  icon: 'magnifyingglass',
                  title: 'Arama hazırlanıyor',
                  message: 'Dosyalar yükleniyor...',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Arama yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else ...[
                SBEntrance(
                  index: 0,
                  child: SBSignatureHero(
                    eyebrow: 'Arama',
                    title: 'Kaynak bul',
                    message: '${files.length} kaynak içinde ara.',
                    icon: 'magnifyingglass',
                    tint: SBColors.cyan,
                    footer: SBMetricRibbon(items: [
                      SBMetricRibbonItem(
                          icon: 'checkmark.circle',
                          value: '$readyCount',
                          label: 'hazır',
                          tint: SBColors.green),
                      SBMetricRibbonItem(
                          icon: 'arrow.triangle.2.circlepath',
                          value: '$processingCount',
                          label: 'hazırlanıyor',
                          tint: SBColors.orange),
                      SBMetricRibbonItem(
                          icon: 'line.3.horizontal.decrease.circle',
                          value: _hasFilters ? '${results.length}' : '-',
                          label: 'sonuç',
                          tint: SBColors.cyan),
                    ]),
                  ),
                ),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 1, child: _searchInput()),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 2, child: _suggestedQueries(suggestions)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                    index: 3, child: _filterBar(courses, sections)),
                if (_hasFilters) ...[
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(index: 4, child: _resultHeader(results.length)),
                ],
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 5, child: _resultsList(router, results)),
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchInput() {
    final isFocused = _searchFocus.hasFocus;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isFocused
              ? SBColors.blue
              : SBColors.blue.withValues(alpha: 0.5),
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SBIcon('magnifyingglass', size: 18, color: SBColors.navy),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: TextField(
              controller: _query,
              focusNode: _searchFocus,
              style: SBTypography.bodyMedium.copyWith(color: SBColors.navy),
              decoration: InputDecoration(
                hintText: 'Ara...',
                hintStyle:
                    SBTypography.bodyMedium.copyWith(color: SBColors.softText),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_query.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _query.clear()),
              child: SBIcon('xmark.circle.fill',
                  size: 18, color: SBColors.muted),
            ),
        ],
      ),
    );
  }

  Widget _suggestedQueries(List<String> suggestions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final suggestion in suggestions) ...[
            GestureDetector(
              onTap: () => _applySuggestion(suggestion),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SBSpacing.md, vertical: SBSpacing.sm),
                decoration: BoxDecoration(
                  color: SBColors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: SBColors.softLine),
                ),
                child: Row(
                  children: [
                    SBIcon('arrow.up.left', size: 12, color: SBColors.navy),
                    const SizedBox(width: SBSpacing.xs),
                    Text(suggestion,
                        style: SBTypography.caption
                            .copyWith(color: SBColors.navy)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _filterBar(List<String> courses, List<String> sections) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterMenu<String?>(
            icon: 'book',
            label: _courseFilter ?? 'Ders',
            isActive: _courseFilter != null,
            items: [
              const PopupMenuItem(value: null, child: Text('Tüm Dersler')),
              for (final course in courses)
                PopupMenuItem(value: course, child: Text(course)),
            ],
            onSelected: (course) => setState(() {
              _courseFilter = course;
              _sectionFilter = null;
            }),
          ),
          const SizedBox(width: SBSpacing.sm),
          _filterMenu<String?>(
            icon: 'list.bullet',
            label: _sectionFilter ?? 'Bölüm',
            isActive: _sectionFilter != null,
            items: [
              const PopupMenuItem(value: null, child: Text('Tüm Bölümler')),
              for (final section in sections)
                PopupMenuItem(value: section, child: Text(section)),
            ],
            onSelected: (section) =>
                setState(() => _sectionFilter = section),
          ),
          const SizedBox(width: SBSpacing.sm),
          _filterMenu<SBFileKind?>(
            icon: 'doc',
            label: _kindFilter?.label ?? 'Tür',
            isActive: _kindFilter != null,
            items: [
              const PopupMenuItem(value: null, child: Text('Tüm Türler')),
              for (final kind in SBFileKind.values)
                PopupMenuItem(value: kind, child: Text(kind.label)),
            ],
            onSelected: (kind) => setState(() => _kindFilter = kind),
          ),
          const SizedBox(width: SBSpacing.sm),
          _filterMenu<SBStatus?>(
            icon: 'arrow.triangle.2.circlepath',
            label: _statusFilter?.label ?? 'Durum',
            isActive: _statusFilter != null,
            items: [
              const PopupMenuItem(value: null, child: Text('Tüm Durumlar')),
              for (final status in _statuses)
                PopupMenuItem(value: status, child: Text(status.label)),
            ],
            onSelected: (status) => setState(() => _statusFilter = status),
          ),
          const SizedBox(width: SBSpacing.sm),
          _filterPill('star', 'Favori', _featuredOnly,
              () => setState(() => _featuredOnly = !_featuredOnly)),
          if (_hasFilters) ...[
            const SizedBox(width: SBSpacing.sm),
            _filterPill('xmark', 'Temizle', true, _clearFilters),
          ],
        ],
      ),
    );
  }

  Widget _filterMenu<T>({
    required String icon,
    required String label,
    required bool isActive,
    required List<PopupMenuEntry<T>> items,
    required void Function(T) onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: _chipDecoration(
        isActive: isActive,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SBIcon(icon,
                size: 14, color: isActive ? SBColors.blue : SBColors.muted),
            const SizedBox(width: SBSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SBTypography.caption.copyWith(
                    color: isActive ? SBColors.blue : SBColors.navy),
              ),
            ),
            const SizedBox(width: SBSpacing.xs),
            SBIcon('chevron.down',
                size: 10,
                color: isActive ? SBColors.blue : SBColors.softText),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(
      String icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _chipDecoration(
        isActive: isActive,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SBIcon(icon,
                size: 14, color: isActive ? SBColors.blue : SBColors.muted),
            const SizedBox(width: SBSpacing.xs),
            Text(label,
                style: SBTypography.caption.copyWith(
                    color: isActive ? SBColors.blue : SBColors.navy)),
          ],
        ),
      ),
    );
  }

  Widget _chipDecoration({required bool isActive, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.sm),
      decoration: BoxDecoration(
        color: isActive ? SBColors.selectedBlue : SBColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? SBColors.blue.withValues(alpha: 0.22)
              : SBColors.softLine,
        ),
      ),
      child: child,
    );
  }

  Widget _resultHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Text('$count sonuç bulundu',
              style:
                  SBTypography.bodyMedium.copyWith(color: SBColors.muted)),
        ),
        PopupMenuButton<_SearchSort>(
          onSelected: (sort) => setState(() => _sortOrder = sort),
          itemBuilder: (context) => [
            for (final sort in _SearchSort.values)
              PopupMenuItem(value: sort, child: Text(sort.label)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SBSpacing.md, vertical: SBSpacing.sm),
            decoration: BoxDecoration(
              color: SBColors.selectedBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SBColors.softLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SBIcon('arrow.up.arrow.down', size: 14, color: SBColors.navy),
                const SizedBox(width: SBSpacing.xs),
                Text(_sortOrder.label,
                    style: SBTypography.labelSmall
                        .copyWith(color: SBColors.navy)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultsList(AppRouter router, List<DriveFile> results) {
    if (!_hasFilters) {
      return const SBEmptyState(
        icon: 'magnifyingglass',
        title: 'Ara',
        message: 'Dosya, ders veya bölüm yaz.',
        badges: ['Hazır kaynaklar', 'PPTX sunumlar', 'Flashcard'],
      );
    }
    if (results.isEmpty) {
      return SBEmptyState(
        icon: 'magnifyingglass',
        title: 'Sonuç yok',
        message: 'Aramayı veya filtreleri değiştir.',
        badges: const ['Filtreleri temizle', 'Hazır kaynakları göster'],
        actionLabel: 'Filtreleri temizle',
        onAction: _clearFilters,
      );
    }
    return Column(
      children: [
        for (final file in results) ...[
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

  void _clearFilters() {
    setState(() {
      _query.clear();
      _kindFilter = null;
      _statusFilter = null;
      _courseFilter = null;
      _sectionFilter = null;
      _featuredOnly = false;
      _sortOrder = _SearchSort.newest;
    });
  }

  void _applySuggestion(String text) {
    _clearFilters();
    setState(() {
      switch (text) {
        case 'Hazır kaynaklar':
          _statusFilter = SBStatus.ready;
        case 'PPTX':
          _kindFilter = SBFileKind.pptx;
        case 'PDF':
          _kindFilter = SBFileKind.pdf;
        default:
          _query.text = text;
      }
    });
  }
}
