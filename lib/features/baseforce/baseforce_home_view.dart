import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/session_store.dart';
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
import '../../models/discipline_profile.dart';
import '../../models/models.dart';
import '../study/sb_output_style.dart';

class _ProductionTool {
  const _ProductionTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    this.isDeepTool = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final AppRoute route;
  final bool isDeepTool;
}

/// Port of BaseForceHomeView ("Üret" tab).
class BaseForceHomeView extends StatefulWidget {
  const BaseForceHomeView({super.key});

  @override
  State<BaseForceHomeView> createState() => _BaseForceHomeViewState();
}

class _BaseForceHomeViewState extends State<BaseForceHomeView> {
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
    final session = context.watch<SessionStore>();
    final router = context.read<AppRouter>();
    final profile = DisciplineOptionProfile.getProfile(session.department);
    final isLoading = store.isLoading && !store.hasLoadedWorkspace;

    final latestGenerations = store.latestGeneratedPairs.take(3).toList();
    final activeBaseForceJobs = store.generationJobs
        .where((j) => SourceBaseQueueSurface.all.includes(j.kind) && j.isActive)
        .length;

    return SBPageBackground(
      tone: SBPageTone.cool,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SBSpacing.lg),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Üret',
                  style: SBTypography.heading1.copyWith(color: SBColors.navy)),
              const SizedBox(height: SBSpacing.lg),
              if (isLoading)
                const SBLoadingState(
                  icon: 'bolt.fill',
                  title: 'Üret yükleniyor',
                  message: 'Kaynaklar ve üretimler hazırlanıyor...',
                  context_: SBLoadingContext.baseForce,
                )
              else if (store.errorMessage != null)
                SBErrorState(
                  title: 'Üret yüklenemedi',
                  message: store.errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onAction: () => store.refresh(),
                  context_: SBErrorContext.baseForce,
                )
              else ...[
                SBEntrance(
                  index: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hazır kaynaklarını çalışma materyaline dönüştür.',
                        style: SBTypography.heading3
                            .copyWith(color: SBColors.navy),
                      ),
                      const SizedBox(height: SBSpacing.sm),
                      Text(
                        profile.heroSubtitle,
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 1,
                  child: _productionToolsSection(
                      store, router, profile, activeBaseForceJobs),
                ),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 2, child: _quickContinueSection(store, router)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 3,
                  child: _recentGenerationsSection(
                      store, router, latestGenerations),
                ),
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickContinueSection(WorkspaceStore store, AppRouter router) {
    final entry = store.quickContinueOutput;
    if (entry != null) {
      return SBQuickContinueSurface(
        eyebrow: 'Kaldığın yer',
        title: entry.output.title,
        message: 'Son çalışmana kaldığın yerden dön.',
        metadata: '${entry.file.courseTitle} • ${entry.output.updatedLabel}',
        actionLabel: 'Aç',
        icon: SBOutputStyle.outputIcon(entry.output.kind),
        tint: SBOutputStyle.outputColor(entry.output.kind),
        onTap: () =>
            router.navigate(AppRoute.studyOutput(outputId: entry.output.id)),
      );
    }
    final file = store.quickContinueReadyFile;
    if (file != null) {
      return SBQuickContinueSurface(
        eyebrow: 'Kaldığın yer',
        title: file.title,
        message:
            'Hazır kaynak seçili. Üretim modunu seçip hemen başlayabilirsin.',
        metadata: '${file.courseTitle} • ${file.updatedLabel}',
        actionLabel: 'Bu kaynakla üret',
        icon: 'doc.text',
        tint: SBColors.cyan,
        onTap: () {
          store.setSelectedSources({file.id});
          store.selectFile(file);
          router.beginSourceSelection(
              from: AppRoute.baseForce,
              destination: SourcePickerDestination.baseForceHome);
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _productionToolsSection(
    WorkspaceStore store,
    AppRouter router,
    DisciplineOptionProfile profile,
    int activeBaseForceJobs,
  ) {
    final mainTools = [
      for (final tool in profile.mainKinds)
        _ProductionTool(
          icon: tool.icon,
          title: tool.title,
          subtitle: tool.subtitle,
          color: SBOutputStyle.outputColor(tool.kind),
          route: tool.kind.factoryRoute,
        ),
      _ProductionTool(
        icon: 'clock',
        title: 'Üretim Kuyruğu',
        subtitle: activeBaseForceJobs == 0
            ? 'Başlayan üretimleri takip et'
            : '$activeBaseForceJobs üretim hazırlanıyor',
        color: SBColors.blue,
        route: AppRoute.queue(),
      ),
    ];

    final deepTools = [
      for (final tool in profile.deepKinds)
        _ProductionTool(
          icon: tool.icon,
          title: tool.title,
          subtitle: tool.subtitle,
          color: SBOutputStyle.outputColor(tool.kind),
          route: tool.kind.deepRoute,
          isDeepTool: true,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SBSectionHeader(title: 'Üretim türleri'),
        const SizedBox(height: SBSpacing.md),
        _toolGroup(store, router, 'Ana', mainTools),
        const SizedBox(height: SBSpacing.md),
        _toolGroup(store, router, 'Görsel ve sesli üretim', deepTools),
      ],
    );
  }

  Widget _toolGroup(WorkspaceStore store, AppRouter router, String title,
      List<_ProductionTool> tools) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: SBTypography.labelMedium.copyWith(color: SBColors.muted)),
        const SizedBox(height: SBSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / (154 + SBSpacing.sm))
                .floor()
                .clamp(1, 4);
            final width = (constraints.maxWidth -
                    SBSpacing.sm * (columns - 1)) /
                columns;
            return Wrap(
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.sm,
              children: [
                for (final tool in tools)
                  SizedBox(
                    width: width,
                    child: _factoryTile(store, router, tool),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _factoryTile(
      WorkspaceStore store, AppRouter router, _ProductionTool tool) {
    return SBCommandCard(
      tint: tool.color,
      onTap: () {
        if (tool.isDeepTool) {
          router.navigate(tool.route);
        } else if (tool.route.kind == AppRouteKind.queue) {
          router.navigate(tool.route);
        } else if (store.selectedReadyFiles.isEmpty) {
          router.beginSourceSelection(
              from: AppRoute.baseForce,
              destination: SourcePickerDestination.toRoute(tool.route));
        } else {
          router.navigate(tool.route);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIconTile(
                  icon: tool.icon, tint: tool.color, size: 42, radius: 12),
              const Spacer(),
              SBIcon('chevron.right', size: 13, color: SBColors.softText),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          SizedBox(
            height: 42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      SBTypography.titleSmall.copyWith(color: SBColors.navy),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    tool.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        SBTypography.caption.copyWith(color: SBColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentGenerationsSection(
    WorkspaceStore store,
    AppRouter router,
    List<({DriveFile file, GeneratedOutput output})> latestGenerations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SBSectionHeader(
          title: 'Son çalışmalar',
          action: 'Tümünü gör',
          onAction: () => router.navigate(AppRoute.queue()),
        ),
        const SizedBox(height: SBSpacing.md),
        if (latestGenerations.isEmpty)
          SBEmptyState(
            icon: 'rectangle.stack.badge.plus',
            title: 'Henüz çalışma yok',
            message:
                'Bir kaynak seçip çalışma başlattığında burada görünür.',
            badges: const ['Flashcard', 'Soru', 'Özet'],
            actionLabel: 'Başla',
            onAction: () => router.beginSourceSelection(
                from: AppRoute.baseForce,
                destination: SourcePickerDestination.baseForceHome),
            context_: SBEmptyStateContext.baseForce,
          )
        else
          Column(
            children: [
              for (final entry in latestGenerations) ...[
                _generationCard(store, router, entry.file, entry.output),
                const SizedBox(height: SBSpacing.md),
              ],
            ],
          ),
      ],
    );
  }

  Widget _generationCard(WorkspaceStore store, AppRouter router,
      DriveFile file, GeneratedOutput output) {
    final color = SBOutputStyle.outputColor(output.kind);
    return SBCard(
      radius: 16,
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: SBIcon(SBOutputStyle.outputIcon(output.kind),
                    size: 18, color: color),
              ),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SBOutputStyle.outputKindLabel(output.kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy),
                    ),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      file.title,
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
          const SizedBox(height: SBSpacing.md),
          Text(
            output.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: SBTypography.bodySmall.copyWith(color: SBColors.navy),
          ),
          const SizedBox(height: SBSpacing.md),
          Text(output.updatedLabel,
              style: SBTypography.caption.copyWith(color: SBColors.softText)),
          const SizedBox(height: SBSpacing.md),
          Row(
            children: [
              SBButton(
                'Aç',
                icon: 'arrow.up.right.square',
                variant: SBButtonVariant.primary,
                size: SBButtonSize.small,
                onPressed: () => router
                    .navigate(AppRoute.studyOutput(outputId: output.id)),
              ),
              const SizedBox(width: SBSpacing.sm),
              SBButton(
                'Tekrar üret',
                icon: 'arrow.clockwise',
                variant: SBButtonVariant.secondary,
                size: SBButtonSize.small,
                onPressed: () async {
                  await store.enqueueDriveGeneration(
                      file: file, kind: output.kind);
                  router.navigate(AppRoute.queue());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
