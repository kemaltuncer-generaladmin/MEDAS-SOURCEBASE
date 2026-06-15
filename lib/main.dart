import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'app/root_view.dart';
import 'core/app_router.dart';
import 'core/session_store.dart';
import 'core/workspace_store.dart';
import 'design_system/sb_colors.dart';
import 'design_system/sb_responsive_shell.dart';
import 'design_system/sb_typography.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SourceBaseApp());
}

class SourceBaseApp extends StatefulWidget {
  const SourceBaseApp({super.key});

  @override
  State<SourceBaseApp> createState() => _SourceBaseAppState();
}

class _SourceBaseAppState extends State<SourceBaseApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncBrightness();
    SessionStore.shared.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(_syncBrightness);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the central onboarding browser: re-check the shared
    // profile so a now-complete setup lets the user into the app.
    if (state == AppLifecycleState.resumed) {
      final session = SessionStore.shared;
      if (session.isLoggedIn && !session.ecosystemSetupComplete) {
        session.refreshEcosystemSetup();
      }
    }
  }

  void _syncBrightness() {
    SBColors.brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SessionStore.shared),
        ChangeNotifierProvider.value(value: WorkspaceStore.shared),
        ChangeNotifierProvider.value(value: AppRouter.shared),
      ],
      child: MaterialApp(
        title: 'SourceBase',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SBScrollBehavior(),
        builder: (context, child) {
          final session = context.watch<SessionStore>();
          final router = context.watch<AppRouter>();
          final content = child ?? const SizedBox.shrink();
          final isAuthSurface =
              !session.isLoggedIn ||
              session.needsEmailVerification ||
              (session.isLoggedIn && !session.ecosystemSetupComplete) ||
              router.path.any(
                (route) => switch (route.kind) {
                  AppRouteKind.login ||
                  AppRouteKind.register ||
                  AppRouteKind.verifyEmail ||
                  AppRouteKind.forgotPassword ||
                  AppRouteKind.resetPassword => true,
                  _ => false,
                },
              );

          return isAuthSurface ? content : SBResponsiveShell(child: content);
        },
        theme: ThemeData(
          useMaterial3: true,
          brightness: SBColors.brightness,
          scaffoldBackgroundColor: SBColors.page,
          colorScheme: ColorScheme.fromSeed(
            seedColor: SBColors.blue,
            brightness: SBColors.brightness,
          ),
          textTheme: TextTheme(
            headlineLarge: SBTypography.heading1,
            headlineMedium: SBTypography.heading2,
            titleLarge: SBTypography.titleLarge,
            titleMedium: SBTypography.titleMedium,
            bodyLarge: SBTypography.bodyLarge,
            bodyMedium: SBTypography.bodyMedium,
            bodySmall: SBTypography.bodySmall,
          ),
        ),
        home: const RootView(),
      ),
    );
  }
}
