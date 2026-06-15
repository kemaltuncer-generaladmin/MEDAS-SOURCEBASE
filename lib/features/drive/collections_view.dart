import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_empty_state.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_status_badge.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/models.dart';

enum _CollectionSort {
  newest('Yeni'),
  name('A-Z'),
  outputCount('Çok çalışma');

  const _CollectionSort(this.label);

  final String label;
}

/// Port of CollectionsView.
class CollectionsView extends StatefulWidget {
  const CollectionsView({super.key});

  @override
  State<CollectionsView> createState() => _CollectionsViewState();
}

class _CollectionsViewState extends State<CollectionsView> {
  GeneratedKind? _selectedKind;
  _CollectionSort _sortOrder = _CollectionSort.newest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  String _outputIcon(GeneratedKind kind) => switch (kind) {
        GeneratedKind.flashcard => 'rectangle.on.rectangle',
        GeneratedKind.question => 'questionmark.circle',
        GeneratedKind.summary => 'doc.text',
        GeneratedKind.examMorningSummary => 'alarm',
        GeneratedKind.algorithm => 'arrow.triangle.branch',
        GeneratedKind.comparison || GeneratedKind.table => 'tablecells',
        GeneratedKind.clinicalScenario => 'cross.case',
        GeneratedKind.learningPlan => 'calendar.badge.clock',
        GeneratedKind.podcast => 'headphones',
        GeneratedKind.infographic => 'chart.bar',
        GeneratedKind.mindMap => 'point.3.connected.trianglepath.dotted',
      };

  Color _outputColor(GeneratedKind kind) => switch (kind) {
        GeneratedKind.flashcard => SBColors.blue,
        GeneratedKind.question => SBColors.questionTint,
        GeneratedKind.summary ||
        GeneratedKind.examMorningSummary =>
          SBColors.purple,
        GeneratedKind.algorithm ||
        GeneratedKind.learningPlan =>
          SBColors.green,
        GeneratedKind.comparison ||
        GeneratedKind.table ||
        GeneratedKind.clinicalScenario =>
          SBColors.orange,
        GeneratedKind.podcast => SBColors.red,
        GeneratedKind.infographic => SBColors.cyan,
        GeneratedKind.mindMap => SBColors.navy,
      };

  List<CollectionBundle> _filtered(List<CollectionBundle> collections) {
    final filtered = _selectedKind == null
        ? collections
        : collections
            .where((b) => b.outputs.any((o) => o.kind == _selectedKind))
            .toList();
    switch (_sortOrder) {
      case _CollectionSort.newest:
        return filtered;
      case _CollectionSort.name:
        return [...filtered]
          ..sort((a, b) => a.file.title.compareTo(b.file.title));
      case _CollectionSort.outputCount:
        return [...filtered]
          ..sort((a, b) => b.outputs.length.compareTo(a.outputs.length));
    }
  }

  int _count(List<CollectionBundle> collections, GeneratedKind kind) =>
      collections.fold(
          0, (sum, b) => sum + b.outputs.where((o) => o.kind == kind).length);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final collections = store.workspace.collections;
    final filtered = _filtered(collections);
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Koleksiyonlar',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
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
                  icon: 'rectangle.stack',
                  title: 'Hazırlanıyor',
                  message: 'Çalışmalar yükleniyor.',
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Koleksiyonlar yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                )
              else ...[
                Text('Kart, soru ve özetler.',
                    style: SBTypography.bodyMedium
                        .copyWith(color: SBColors.muted)),
                const SizedBox(height: SBSpacing.lg),
                _statsStrip(collections),
                const SizedBox(height: SBSpacing.lg),
                _filterBar(),
                const SizedBox(height: SBSpacing.lg),
                _sortSection(),
                const SizedBox(height: SBSpacing.lg),
                if (collections.isEmpty)
                  SBEmptyState(
                    icon: 'rectangle.stack.badge.plus',
                    title: 'Henüz koleksiyon yok',
                    message:
                        'Kart, soru veya özet üretince burada çalışırsın.',
                    badges: const ['Kart', 'Soru', 'Özet'],
                    actionLabel: 'Kaynak seçip üret',
                    onAction: () => router.beginSourceSelection(
                        from: AppRoute.baseForce,
                        destination: SourcePickerDestination.baseForceHome),
                  )
                else if (filtered.isEmpty)
                  SBEmptyState(
                    icon: 'line.3.horizontal.decrease.circle',
                    title: 'Bu filtrede koleksiyon yok',
                    message:
                        'Başka bir filtre seç veya yeni çalışma başlat.',
                    badges: const ['Yeni üretim'],
                    actionLabel: 'Filtreyi temizle',
                    onAction: () => setState(() => _selectedKind = null),
                  )
                else
                  Column(
                    children: [
                      for (final bundle in filtered) ...[
                        _collectionCard(store, router, bundle),
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

  Widget _statsStrip(List<CollectionBundle> collections) {
    return SBCard(
      radius: 16,
      child: Row(
        children: [
          _statItem('folder', '${collections.length}', 'Kaynak', SBColors.blue),
          _divider(),
          _statItem('rectangle.on.rectangle',
              '${_count(collections, GeneratedKind.flashcard)}', 'Kart',
              SBColors.green),
          _divider(),
          _statItem('questionmark.circle',
              '${_count(collections, GeneratedKind.question)}', 'Soru',
              SBColors.questionTint),
          _divider(),
          _statItem('doc.text',
              '${_count(collections, GeneratedKind.summary)}', 'Özet',
              SBColors.purple),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 34, color: SBColors.softLine);

  Widget _statItem(String icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SBIcon(icon, size: 16, color: color),
          const SizedBox(width: SBSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy)),
              const SizedBox(height: 2),
              Text(label,
                  style: SBTypography.caption.copyWith(color: SBColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Tümü', null, null),
          const SizedBox(width: SBSpacing.sm),
          _filterChip('Kart', 'rectangle.on.rectangle', GeneratedKind.flashcard),
          const SizedBox(width: SBSpacing.sm),
          _filterChip('Soru', 'questionmark.circle', GeneratedKind.question),
          const SizedBox(width: SBSpacing.sm),
          _filterChip('Özet', 'doc.text', GeneratedKind.summary),
          const SizedBox(width: SBSpacing.sm),
          _filterChip('Tablo', 'tablecells', GeneratedKind.table),
          const SizedBox(width: SBSpacing.sm),
          _filterChip('Podcast', 'headphones', GeneratedKind.podcast),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? icon, GeneratedKind? kind) {
    final isSelected = _selectedKind == kind;
    return GestureDetector(
      onTap: () => setState(() => _selectedKind = kind),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
            horizontal: SBSpacing.md, vertical: SBSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? SBColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? SBColors.blue : SBColors.softLine,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              SBIcon(icon,
                  size: 14,
                  color: isSelected ? Colors.white : SBColors.navy),
              const SizedBox(width: SBSpacing.xs),
            ],
            Text(label,
                style: SBTypography.labelSmall.copyWith(
                    color: isSelected ? Colors.white : SBColors.navy)),
          ],
        ),
      ),
    );
  }

  Widget _sortSection() {
    return Row(
      children: [
        Expanded(
          child: Text('Kaynaklar',
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        ),
        PopupMenuButton<_CollectionSort>(
          onSelected: (sort) => setState(() => _sortOrder = sort),
          itemBuilder: (context) => [
            for (final sort in _CollectionSort.values)
              PopupMenuItem(value: sort, child: Text(sort.label)),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_sortOrder.label,
                  style:
                      SBTypography.labelSmall.copyWith(color: SBColors.blue)),
              const SizedBox(width: SBSpacing.xs),
              SBIcon('chevron.down', size: 10, color: SBColors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _collectionCard(
      WorkspaceStore store, AppRouter router, CollectionBundle bundle) {
    final previewColor = _outputColor(bundle.previewKind);

    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: previewColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: SBIcon(_outputIcon(bundle.previewKind),
                    size: 20, color: previewColor),
              ),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy),
                    ),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      bundle.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.bodySmall
                          .copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
              if (bundle.outputs.isNotEmpty)
                const SBStatusBadge(status: SBStatus.ready, compact: true),
              PopupMenuButton<String>(
                icon: SBIcon('ellipsis', size: 16, color: SBColors.muted),
                onSelected: (action) {
                  switch (action) {
                    case 'open':
                      _openFile(store, router, bundle.file);
                    case 'flashcard':
                      _generate(store, router, bundle.file,
                          GeneratedKind.flashcard);
                    case 'question':
                      _generate(
                          store, router, bundle.file, GeneratedKind.question);
                    case 'summary':
                      _generate(
                          store, router, bundle.file, GeneratedKind.summary);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'open', child: Text('Kaynağı Aç')),
                  PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'flashcard', child: Text('Flashcard üret')),
                  PopupMenuItem(value: 'question', child: Text('Soru üret')),
                  PopupMenuItem(value: 'summary', child: Text('Özet üret')),
                ],
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.xs,
            runSpacing: SBSpacing.xs,
            children: [
              _infoPill('graduationcap', bundle.subject),
              _infoPill(
                  'square.stack.3d.up', '${bundle.outputs.length} çalışma'),
              _infoPill('doc', sbFileKindFrom(bundle.file.kind).label),
              _infoPill('clock', bundle.file.updatedLabel),
            ],
          ),
          if (bundle.outputs.isNotEmpty) ...[
            const SizedBox(height: SBSpacing.md),
            Column(
              children: [
                for (var i = 0;
                    i < (bundle.outputs.length > 3 ? 3 : bundle.outputs.length);
                    i++) ...[
                  SBPressable(
                    onTap: () => router.navigate(
                        AppRoute.studyOutput(outputId: bundle.outputs[i].id)),
                    child: _outputRow(bundle.outputs[i]),
                  ),
                  if (i < (bundle.outputs.length > 3 ? 3 : bundle.outputs.length) - 1)
                    Divider(height: 1, color: SBColors.softLine),
                ],
              ],
            ),
          ],
          const SizedBox(height: SBSpacing.md),
          Row(
            children: [
              GestureDetector(
                onTap: () => _openFile(store, context.read<AppRouter>(),
                    bundle.file),
                child: Row(
                  children: [
                    SBIcon('arrow.up.right.square',
                        size: 14, color: SBColors.blue),
                    const SizedBox(width: SBSpacing.xs),
                    Text('Kaynağı aç',
                        style: SBTypography.labelSmall
                            .copyWith(color: SBColors.blue)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _generate(store, context.read<AppRouter>(),
                    bundle.file, bundle.previewKind),
                child: Row(
                  children: [
                    SBIcon('bolt.fill', size: 14, color: previewColor),
                    const SizedBox(width: SBSpacing.xs),
                    Text('Benzer çalışma üret',
                        style: SBTypography.labelSmall
                            .copyWith(color: previewColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String icon, String text) {
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
            constraints: const BoxConstraints(maxWidth: 200),
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

  Widget _outputRow(GeneratedOutput output) {
    final color = _outputColor(output.kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SBSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: SBIcon(_outputIcon(output.kind), size: 16, color: color),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  output.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      SBTypography.labelSmall.copyWith(color: SBColors.navy),
                ),
                const SizedBox(height: SBSpacing.xs),
                Text(
                  output.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SBSpacing.sm),
          Text(output.updatedLabel,
              style: SBTypography.caption.copyWith(color: SBColors.softText)),
        ],
      ),
    );
  }

  void _openFile(WorkspaceStore store, AppRouter router, DriveFile file) {
    store.selectFile(file);
    router.navigate(AppRoute.fileDetail(fileId: file.id));
  }

  void _generate(WorkspaceStore store, AppRouter router, DriveFile file,
      GeneratedKind kind) {
    if (!store.isReadyForGeneration(file)) {
      store.toast('Bu kaynak hazır olmadan üretime alınamaz.');
      return;
    }
    store.enqueueDriveGeneration(file: file, kind: kind);
    router.navigate(
        AppRoute.queue(surface: SourceBaseQueueSurface.surfaceFor(kind)));
  }
}
