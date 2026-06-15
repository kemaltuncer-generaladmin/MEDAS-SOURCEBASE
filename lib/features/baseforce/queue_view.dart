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
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';
import '../study/sb_output_style.dart';

enum _JobStatus { pending, running, completed, failed }

enum _QueueFilter {
  all('Hepsi'),
  preparing('Hazırlanıyor'),
  ready('Hazır'),
  failed('Tekrar dene');

  const _QueueFilter(this.label);

  final String label;

  Color get color => switch (this) {
        _QueueFilter.all || _QueueFilter.preparing => SBColors.blue,
        _QueueFilter.ready => SBColors.green,
        _QueueFilter.failed => SBColors.red,
      };
}

class _JobState {
  const _JobState({
    required this.id,
    required this.outputId,
    required this.sourceFileId,
    required this.sourceTitle,
    required this.title,
    required this.kind,
    required this.status,
    required this.progress,
    this.errorMessage,
  });

  final String id;
  final String? outputId;
  final String sourceFileId;
  final String sourceTitle;
  final String title;
  final GeneratedKind kind;
  final _JobStatus status;
  final double progress;
  final String? errorMessage;
}

/// Port of QueueView ("Üretim Kuyruğu").
class QueueView extends StatefulWidget {
  const QueueView({super.key, this.surface = SourceBaseQueueSurface.all});

  final SourceBaseQueueSurface surface;

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  _QueueFilter _selectedFilter = _QueueFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  List<_JobState> _jobs(WorkspaceStore store) => [
        for (final job in store.generationJobs)
          _JobState(
            id: job.id,
            outputId: job.output?.id ?? job.outputId,
            sourceFileId: job.sourceFileId,
            sourceTitle: job.sourceTitle,
            title: SBOutputStyle.templateName(job.kind),
            kind: job.kind,
            status: switch (job.status) {
              SBGenerationStatus.queued => _JobStatus.pending,
              SBGenerationStatus.running => _JobStatus.running,
              SBGenerationStatus.completed => _JobStatus.completed,
              SBGenerationStatus.failed => _JobStatus.failed,
            },
            progress: job.progress,
            errorMessage: job.failureMessage,
          ),
      ];

  List<_JobState> _filtered(List<_JobState> jobs) => switch (_selectedFilter) {
        _QueueFilter.all => jobs,
        _QueueFilter.preparing => jobs
            .where((j) =>
                j.status == _JobStatus.pending ||
                j.status == _JobStatus.running)
            .toList(),
        _QueueFilter.ready =>
          jobs.where((j) => j.status == _JobStatus.completed).toList(),
        _QueueFilter.failed =>
          jobs.where((j) => j.status == _JobStatus.failed).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;
    final jobs = _jobs(store);
    final filteredJobs = _filtered(jobs);
    final runningCount = jobs
        .where((j) =>
            j.status == _JobStatus.pending || j.status == _JobStatus.running)
        .length;
    final completedCount =
        jobs.where((j) => j.status == _JobStatus.completed).length;
    final failedCount =
        jobs.where((j) => j.status == _JobStatus.failed).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text('Üretim Kuyruğu',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      body: SBPageBackground(
        tone: SBPageTone.cool,
        child: RefreshIndicator(
          onRefresh: () => store.refreshGenerationQueue(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(SBSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  const SBLoadingState(
                    icon: 'clock',
                    title: 'Üretim Kuyruğu açılıyor',
                    message: 'Üretimler güncelleniyor.',
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
                      eyebrow: 'Üretim takibi',
                      title: 'Üretim Kuyruğu',
                      message:
                          'Başlayan, hazırlanan ve hazır olan tüm üretimler burada.',
                      icon: 'checkmark.seal.fill',
                      tint: SBColors.blue,
                      size: SBHeroSize.compact,
                      footer: SBMetricRibbon(items: [
                        SBMetricRibbonItem(
                            icon: 'hourglass',
                            value: '$runningCount',
                            label: 'aktif',
                            tint: SBColors.blue),
                        SBMetricRibbonItem(
                            icon: 'checkmark.circle',
                            value: '$completedCount',
                            label: 'hazır',
                            tint: SBColors.green),
                        SBMetricRibbonItem(
                            icon: 'arrow.clockwise',
                            value: '$failedCount',
                            label: 'tekrar',
                            tint: SBColors.red),
                      ]),
                    ),
                  ),
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(index: 1, child: _filterBar()),
                  const SizedBox(height: SBSpacing.lg),
                  SBEntrance(
                    index: 2,
                    child: filteredJobs.isEmpty
                        ? const SBCard(
                            child: SBEmptyState(
                              icon: 'clock.badge.questionmark',
                              title: 'Henüz üretim yok',
                              message: 'Üretim başlayınca burada görünür.',
                              badges: [
                                'Başladı',
                                'Hazırlanıyor',
                                'Hazır',
                                'Tekrar dene'
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              for (final job in filteredJobs) ...[
                                _jobRow(store, router, job),
                                const SizedBox(height: SBSpacing.md),
                              ],
                            ],
                          ),
                  ),
                ],
                const SizedBox(height: 156),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Wrap(
      spacing: SBSpacing.sm,
      runSpacing: SBSpacing.sm,
      children: [
        for (final filter in _QueueFilter.values)
          GestureDetector(
            onTap: () {
              SBHaptics.selection();
              setState(() => _selectedFilter = filter);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: SBSpacing.md, vertical: SBSpacing.sm),
              decoration: BoxDecoration(
                color: _selectedFilter == filter
                    ? filter.color
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _selectedFilter == filter
                      ? filter.color
                      : SBColors.softLine,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter != _QueueFilter.all) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _selectedFilter == filter
                              ? Colors.white
                              : filter.color,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: SBSpacing.xs),
                  ],
                  Text(
                    filter.label,
                    style: SBTypography.labelSmall.copyWith(
                        color: _selectedFilter == filter
                            ? Colors.white
                            : SBColors.navy),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _jobRow(WorkspaceStore store, AppRouter router, _JobState job) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SBIconTile(
                  icon: SBOutputStyle.outputIcon(job.kind),
                  tint: _statusColor(job.status),
                  size: 42,
                  radius: 12),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy),
                    ),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      job.sourceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          SBTypography.caption.copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
              _statusBadge(job.status),
            ],
          ),
          if (job.status == _JobStatus.running ||
              job.status == _JobStatus.pending) ...[
            const SizedBox(height: SBSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progress,
                minHeight: 6,
                backgroundColor: SBColors.softLine,
                valueColor: AlwaysStoppedAnimation(SBColors.blue),
              ),
            ),
          ],
          if (job.errorMessage != null) ...[
            const SizedBox(height: SBSpacing.md),
            Text(job.errorMessage!,
                style: SBTypography.bodySmall.copyWith(color: SBColors.red)),
          ],
          const SizedBox(height: SBSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(_progressLabel(job),
                    style:
                        SBTypography.caption.copyWith(color: SBColors.muted)),
              ),
              _actionButton(store, router, job),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(_JobStatus status) {
    final (label, color) = switch (status) {
      _JobStatus.pending => ('Başladı', SBColors.blue),
      _JobStatus.running => ('Hazırlanıyor', SBColors.blue),
      _JobStatus.completed => ('Hazır', SBColors.green),
      _JobStatus.failed => ('Tamamlanamadı', SBColors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: SBTypography.caption.copyWith(color: color)),
    );
  }

  String _progressLabel(_JobState job) => switch (job.status) {
        _JobStatus.pending => 'Kuyruğa eklendi',
        _JobStatus.running =>
          'Hazırlanıyor • ${(job.progress * 100).round()}%',
        _JobStatus.completed => 'Açmaya hazır',
        _JobStatus.failed => 'Tekrar deneyebilirsin',
      };

  Color _statusColor(_JobStatus status) => switch (status) {
        _JobStatus.pending || _JobStatus.running => SBColors.blue,
        _JobStatus.completed => SBColors.green,
        _JobStatus.failed => SBColors.red,
      };

  Widget _actionButton(WorkspaceStore store, AppRouter router, _JobState job) {
    switch (job.status) {
      case _JobStatus.completed:
        return SBButton(
          'Detayı aç',
          icon: 'arrow.up.right.square',
          variant: SBButtonVariant.primary,
          size: SBButtonSize.small,
          onPressed: () {
            if (job.outputId != null) {
              router.navigate(AppRoute.studyOutput(outputId: job.outputId!));
            } else {
              router.navigate(AppRoute.result(jobId: job.id));
            }
          },
        );
      case _JobStatus.failed:
        return SBButton(
          'Tekrar dene',
          icon: 'arrow.clockwise',
          variant: SBButtonVariant.secondary,
          size: SBButtonSize.small,
          onPressed: () async {
            final storeJob = store.job(job.id);
            if (storeJob != null) {
              await store.retryJob(storeJob);
            } else {
              final file = store.file(job.sourceFileId);
              if (file != null) {
                await store.enqueueDriveGeneration(file: file, kind: job.kind);
              } else {
                store.toast("Kaynak bulunamadı. Drive'dan yeniden seç.");
              }
            }
            await store.refreshGenerationQueue();
          },
        );
      case _JobStatus.pending:
      case _JobStatus.running:
        return SBButton(
          'İptal',
          icon: 'xmark',
          variant: SBButtonVariant.secondary,
          size: SBButtonSize.small,
          onPressed: () async {
            final storeJob = store.job(job.id);
            if (storeJob != null) {
              await store.cancelJob(storeJob);
            } else {
              store.toast('Kuyruk güncellendi. Tekrar kontrol et.');
            }
            await store.refreshGenerationQueue();
          },
        );
    }
  }
}
