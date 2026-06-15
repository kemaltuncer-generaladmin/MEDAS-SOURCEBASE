import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_router.dart';
import '../core/workspace_store.dart';
import '../design_system/sb_background.dart';
import '../design_system/sb_colors.dart';
import '../design_system/sb_icons.dart';
import '../design_system/sb_motion.dart';
import '../design_system/sb_typography.dart';
import '../features/baseforce/baseforce_home_view.dart';
import '../features/central_ai/central_ai_view.dart';
import '../features/drive/drive_home_view.dart';
import '../features/profile/profile_view.dart';

class _MainTabItem {
  const _MainTabItem({
    required this.route,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.tint,
  });

  final AppRoute route;
  final String title;
  final String icon;
  final String selectedIcon;
  final Color tint;
}

/// Port of MainTabView: floating glass tab bar over the active tab content.
class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  static final _tabs = [
    _MainTabItem(
        route: AppRoute.drive,
        title: 'Drive',
        icon: 'folder',
        selectedIcon: 'folder.fill',
        tint: SBColors.blue),
    _MainTabItem(
        route: AppRoute.baseForce,
        title: 'Üret',
        icon: 'bolt',
        selectedIcon: 'bolt.fill',
        tint: SBColors.violet),
    _MainTabItem(
        route: AppRoute.centralAI,
        title: 'MedasiChat',
        icon: 'text.bubble',
        selectedIcon: 'text.bubble.fill',
        tint: SBColors.cyan),
    _MainTabItem(
        route: AppRoute.profile,
        title: 'Profil',
        icon: 'person',
        selectedIcon: 'person.fill',
        tint: SBColors.magenta),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = context.watch<AppRouter>();

    final Widget current = switch (router.selectedTab.kind) {
      AppRouteKind.drive => const DriveHomeView(),
      AppRouteKind.baseForce ||
      AppRouteKind.sourceLab =>
        const BaseForceHomeView(),
      AppRouteKind.centralAI => const CentralAIView(),
      AppRouteKind.profile => const ProfileView(),
      _ => const DriveHomeView(),
    };

    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SBAmbientBackground(),
          Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: current,
          ),
        ],
      ),
      bottomNavigationBar: _tabBar(router),
    );
  }

  Widget _tabBar(AppRouter router) {
    return SafeArea(
      top: false,
      child: Container(
        color: SBColors.page.withValues(alpha: 0.96),
        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
        child: Container(
          padding: const EdgeInsets.only(
              left: 10, right: 10, top: 10, bottom: 8),
          decoration: BoxDecoration(
            color: SBColors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: SBColors.softLine.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: SBColors.navy.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: SBColors.navy.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _tabButton(_tabs[i], router)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(_MainTabItem item, AppRouter router) {
    final isSelected = router.selectedTab == item.route;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SBHaptics.selection();
        router.switchTab(item.route);
      },
      child: AnimatedContainer(
        duration: SBMotion.springDuration,
        curve: SBMotion.softSpring,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? SBColors.vividGradient(item.tint) : null,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: item.tint.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.16 : 1,
              duration: SBMotion.springDuration,
              curve: SBMotion.spring,
              child: SBIcon(
                isSelected ? item.selectedIcon : item.icon,
                size: 19,
                color: isSelected ? Colors.white : SBColors.muted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.scaled(10,
                      weight:
                          isSelected ? FontWeight.w700 : FontWeight.w500)
                  .copyWith(
                      color: isSelected ? Colors.white : SBColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
