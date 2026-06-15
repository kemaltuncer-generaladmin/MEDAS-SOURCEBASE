import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_router.dart';
import '../core/session_store.dart';
import '../core/workspace_store.dart';
import '../design_system/sb_colors.dart';
import '../design_system/sb_icons.dart';
import '../design_system/sb_loading_state.dart';
import '../design_system/sb_motion.dart';
import '../design_system/sb_spacing.dart';
import '../design_system/sb_typography.dart';
import '../features/auth/ecosystem_setup_view.dart';
import '../features/auth/forgot_password_view.dart';
import '../features/auth/login_view.dart';
import '../features/auth/register_view.dart';
import '../features/auth/reset_password_view.dart';
import '../features/auth/verify_email_view.dart';
import '../features/baseforce/algorithm_factory_view.dart';
import '../features/baseforce/baseforce_home_view.dart';
import '../features/baseforce/comparison_factory_view.dart';
import '../features/baseforce/flashcard_factory_view.dart';
import '../features/baseforce/generation_processing_view.dart';
import '../features/baseforce/question_factory_view.dart';
import '../features/baseforce/queue_view.dart';
import '../features/baseforce/result_view.dart';
import '../features/baseforce/source_picker_view.dart';
import '../features/baseforce/summary_factory_view.dart';
import '../features/central_ai/central_ai_view.dart';
import '../features/drive/collections_view.dart';
import '../features/drive/course_detail_view.dart';
import '../features/drive/drive_home_view.dart';
import '../features/drive/file_detail_view.dart';
import '../features/drive/folder_view.dart';
import '../features/drive/search_view.dart';
import '../features/drive/uploads_view.dart';
import '../features/profile/profile_menu_detail_view.dart';
import '../features/profile/profile_view.dart';
import '../features/profile/settings_view.dart';
import '../features/profile/store_view.dart';
import '../features/sourcelab/clinical_view.dart';
import '../features/sourcelab/exam_morning_view.dart';
import '../features/sourcelab/infographic_view.dart';
import '../features/sourcelab/mind_map_view.dart';
import '../features/sourcelab/plan_view.dart';
import '../features/sourcelab/podcast_view.dart';
import '../features/study/generated_output_study_view.dart';
import 'main_tab_view.dart';
import 'warm_launch_view.dart';

/// Port of RootView: warm launch gate, then routing, with the global toast
/// overlay pinned to the bottom edge.
class RootView extends StatefulWidget {
  const RootView({super.key});

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  bool _isWarmLaunching = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _isWarmLaunching = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final workspace = context.watch<WorkspaceStore>();

    Widget body;
    if (!session.isInitialized && session.initializationError == null) {
      body = const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(SBSpacing.lg),
          child: Center(
            child: SBLoadingState(
              icon: 'hourglass',
              title: 'SourceBase',
              message: 'Uygulama başlatılıyor...',
            ),
          ),
        ),
      );
    } else if (_isWarmLaunching) {
      body = const WarmLaunchView();
    } else {
      body = const MainNavigationView();
    }

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: SBMotion.softSpringDuration,
          switchInCurve: SBMotion.softSpring,
          child: body,
        ),
        if (workspace.toastMessage != null)
          Positioned(
            left: SBSpacing.lg,
            right: SBSpacing.lg,
            bottom: SBSpacing.lg + MediaQuery.of(context).padding.bottom,
            child: _SBToast(message: workspace.toastMessage!),
          ),
      ],
    );
  }
}

class _SBToast extends StatelessWidget {
  const _SBToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SBSpacing.md, vertical: SBSpacing.sm),
        decoration: BoxDecoration(
          color: SBColors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SBColors.softLine),
          boxShadow: [
            BoxShadow(
              color: SBColors.navy.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            SBIcon('checkmark.circle.fill', size: 17, color: SBColors.green),
            const SizedBox(width: SBSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: SBTypography.bodySmall.copyWith(color: SBColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Port of MainNavigationView: a Navigator whose root is derived from the
/// session state and whose pushed pages mirror `AppRouter.path`.
class MainNavigationView extends StatelessWidget {
  const MainNavigationView({super.key});

  /// Root surface, derived from session state. The ecosystem onboarding gate
  /// sits between email verification and the app: a logged-in, verified user
  /// without a shared profile is sent to the central onboarding (open to every
  /// faculty — no discipline restriction).
  Widget _rootView(SessionStore session) {
    if (!session.isLoggedIn) return const LoginView();
    if (session.needsEmailVerification) {
      return VerifyEmailView(email: session.email);
    }
    if (session.ecosystemSetupComplete) return const MainTabView();
    if (session.ecosystemBusy) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(SBSpacing.lg),
          child: Center(
            child: SBLoadingState(
              icon: 'hourglass',
              title: 'SourceBase',
              message: 'MedAsi kurulumun kontrol ediliyor...',
            ),
          ),
        ),
      );
    }
    return const EcosystemSetupView();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final router = context.watch<AppRouter>();

    final Widget root = _rootView(session);

    return Navigator(
      pages: [
        MaterialPage(key: const ValueKey('root'), child: root),
        for (var i = 0; i < router.path.length; i++)
          MaterialPage(
            key: ValueKey('route-$i-${router.path[i].kind.name}'),
            child: destinationView(router.path[i]),
          ),
      ],
      onDidRemovePage: (page) {
        if (page.key != const ValueKey('root') &&
            router.path.isNotEmpty) {
          router.pop();
        }
      },
    );
  }

  /// Port of `destinationView(for:)`.
  static Widget destinationView(AppRoute route) {
    switch (route.kind) {
      // Auth
      case AppRouteKind.login:
        return const LoginView();
      case AppRouteKind.register:
        return const RegisterView();
      case AppRouteKind.verifyEmail:
        return VerifyEmailView(email: route.params['email'] ?? '');
      case AppRouteKind.forgotPassword:
        return const ForgotPasswordView();
      case AppRouteKind.resetPassword:
        return const ResetPasswordView();

      // Main tabs
      case AppRouteKind.drive:
        return const DriveHomeView();
      case AppRouteKind.baseForce:
      case AppRouteKind.sourceLab:
        return const BaseForceHomeView();
      case AppRouteKind.centralAI:
        return const CentralAIView();
      case AppRouteKind.profile:
        return const ProfileView();

      // Drive sub-routes
      case AppRouteKind.courseDetail:
        return CourseDetailView(courseId: route.params['courseId'] ?? '');
      case AppRouteKind.folder:
        return FolderView(
          courseId: route.params['courseId'] ?? '',
          sectionId: route.params['sectionId'] ?? '',
        );
      case AppRouteKind.fileDetail:
        return FileDetailView(fileId: route.params['fileId'] ?? '');
      case AppRouteKind.uploads:
        return const UploadsView();
      case AppRouteKind.collections:
        return const CollectionsView();
      case AppRouteKind.search:
        return const SearchView();

      // BaseForce sub-routes
      case AppRouteKind.sourcePicker:
        return const SourcePickerView();
      case AppRouteKind.flashcardFactory:
        return const FlashcardFactoryView();
      case AppRouteKind.questionFactory:
        return const QuestionFactoryView();
      case AppRouteKind.summaryFactory:
        return const SummaryFactoryView();
      case AppRouteKind.algorithmFactory:
        return const AlgorithmFactoryView();
      case AppRouteKind.comparisonFactory:
        return const ComparisonFactoryView();
      case AppRouteKind.queue:
        return QueueView(
          surface: SourceBaseQueueSurface.values
              .byName(route.params['surface'] ?? 'all'),
        );
      case AppRouteKind.generationProcessing:
        return GenerationProcessingView(
          sourceFileId: route.params['sourceFileId'] ?? '',
          kindRawValue: route.params['kind'] ?? '',
          label: route.params['label'] ?? '',
          surface: route.params['surface'] ?? '',
          mode: route.params['mode'] ?? '',
          extraOptions: route.generationOptions,
        );
      case AppRouteKind.result:
        return ResultView(jobId: route.params['jobId'] ?? '');
      case AppRouteKind.studyOutput:
        return GeneratedOutputStudyView(
            outputId: route.params['outputId'] ?? '');

      // SourceLab sub-routes
      case AppRouteKind.examMorning:
        return const ExamMorningView();
      case AppRouteKind.clinical:
        return const ClinicalView();
      case AppRouteKind.plan:
        return const PlanView();
      case AppRouteKind.podcast:
        return const PodcastView();
      case AppRouteKind.infographic:
        return const InfographicView();
      case AppRouteKind.mindMap:
        return const MindMapView();

      // Profile sub-routes
      case AppRouteKind.store:
        return const StoreView();
      case AppRouteKind.settings:
        return const SettingsView();
      case AppRouteKind.profileMenu:
        return ProfileMenuDetailView(
            destination: route.params['destination'] ?? '');
    }
  }
}
