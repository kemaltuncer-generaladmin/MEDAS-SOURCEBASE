import 'package:flutter/foundation.dart';

import '../models/models.dart';

enum SourceBaseQueueSurface {
  all,
  baseForce,
  sourceLab;

  /// Port of `SourceBaseQueueSurface.surface(for:)`.
  static SourceBaseQueueSurface surfaceFor(GeneratedKind kind) =>
      switch (kind) {
        GeneratedKind.examMorningSummary ||
        GeneratedKind.clinicalScenario ||
        GeneratedKind.learningPlan ||
        GeneratedKind.podcast ||
        GeneratedKind.infographic ||
        GeneratedKind.mindMap =>
          SourceBaseQueueSurface.sourceLab,
        _ => SourceBaseQueueSurface.baseForce,
      };

  bool includes(GeneratedKind kind) => switch (this) {
        SourceBaseQueueSurface.all => true,
        _ => SourceBaseQueueSurface.surfaceFor(kind) == this,
      };
}

/// Port of `GeneratedKind.factoryRoute` / `.deepRoute`.
extension GeneratedKindRoutes on GeneratedKind {
  AppRoute get factoryRoute => switch (this) {
        GeneratedKind.flashcard => AppRoute.flashcardFactory,
        GeneratedKind.question => AppRoute.questionFactory,
        GeneratedKind.summary ||
        GeneratedKind.examMorningSummary =>
          AppRoute.summaryFactory,
        GeneratedKind.algorithm => AppRoute.algorithmFactory,
        GeneratedKind.comparison ||
        GeneratedKind.table =>
          AppRoute.comparisonFactory,
        _ => deepRoute,
      };

  AppRoute get deepRoute => switch (this) {
        GeneratedKind.clinicalScenario => AppRoute.clinical,
        GeneratedKind.examMorningSummary => AppRoute.examMorning,
        GeneratedKind.learningPlan => AppRoute.plan,
        GeneratedKind.podcast => AppRoute.podcast,
        GeneratedKind.infographic => AppRoute.infographic,
        GeneratedKind.mindMap => AppRoute.mindMap,
        _ => factoryRoute,
      };
}

enum AppRouteKind {
  // Auth
  login,
  register,
  verifyEmail,
  forgotPassword,
  resetPassword,

  // Main tabs
  drive,
  baseForce,
  centralAI,
  sourceLab,
  profile,

  // Drive sub-routes
  courseDetail,
  folder,
  fileDetail,
  uploads,
  collections,
  search,

  // BaseForce sub-routes
  sourcePicker,
  flashcardFactory,
  questionFactory,
  summaryFactory,
  algorithmFactory,
  comparisonFactory,
  queue,
  generationProcessing,
  result,
  studyOutput,

  // SourceLab sub-routes
  examMorning,
  clinical,
  plan,
  podcast,
  infographic,
  mindMap,

  // Profile sub-routes
  store,
  settings,
  profileMenu,
}

/// Port of AppRoute: a route kind plus its payload parameters.
@immutable
class AppRoute {
  const AppRoute(this.kind, [this.params = const {}]);

  final AppRouteKind kind;
  final Map<String, String> params;

  // Auth
  static const login = AppRoute(AppRouteKind.login);
  static const register = AppRoute(AppRouteKind.register);
  static AppRoute verifyEmail({required String email}) =>
      AppRoute(AppRouteKind.verifyEmail, {'email': email});
  static const forgotPassword = AppRoute(AppRouteKind.forgotPassword);
  static const resetPassword = AppRoute(AppRouteKind.resetPassword);

  // Tabs
  static const drive = AppRoute(AppRouteKind.drive);
  static const baseForce = AppRoute(AppRouteKind.baseForce);
  static const centralAI = AppRoute(AppRouteKind.centralAI);
  static const sourceLab = AppRoute(AppRouteKind.sourceLab);
  static const profile = AppRoute(AppRouteKind.profile);

  // Drive
  static AppRoute courseDetail({required String courseId}) =>
      AppRoute(AppRouteKind.courseDetail, {'courseId': courseId});
  static AppRoute folder(
          {required String courseId, required String sectionId}) =>
      AppRoute(
          AppRouteKind.folder, {'courseId': courseId, 'sectionId': sectionId});
  static AppRoute fileDetail({required String fileId}) =>
      AppRoute(AppRouteKind.fileDetail, {'fileId': fileId});
  static const uploads = AppRoute(AppRouteKind.uploads);
  static const collections = AppRoute(AppRouteKind.collections);
  static const search = AppRoute(AppRouteKind.search);

  // BaseForce
  static const sourcePicker = AppRoute(AppRouteKind.sourcePicker);
  static const flashcardFactory = AppRoute(AppRouteKind.flashcardFactory);
  static const questionFactory = AppRoute(AppRouteKind.questionFactory);
  static const summaryFactory = AppRoute(AppRouteKind.summaryFactory);
  static const algorithmFactory = AppRoute(AppRouteKind.algorithmFactory);
  static const comparisonFactory = AppRoute(AppRouteKind.comparisonFactory);
  static AppRoute queue(
          {SourceBaseQueueSurface surface = SourceBaseQueueSurface.all}) =>
      AppRoute(AppRouteKind.queue, {'surface': surface.name});
  static AppRoute generationProcessing({
    required String sourceFileId,
    required String kind,
    required String label,
    required String surface,
    required String mode,
    Map<String, String> options = const {},
  }) =>
      AppRoute(AppRouteKind.generationProcessing, {
        'sourceFileId': sourceFileId,
        'kind': kind,
        'label': label,
        'surface': surface,
        'mode': mode,
        ...options.map((k, v) => MapEntry('opt_$k', v)),
      });
  static AppRoute result({required String jobId}) =>
      AppRoute(AppRouteKind.result, {'jobId': jobId});
  static AppRoute studyOutput({required String outputId}) =>
      AppRoute(AppRouteKind.studyOutput, {'outputId': outputId});

  // SourceLab
  static const examMorning = AppRoute(AppRouteKind.examMorning);
  static const clinical = AppRoute(AppRouteKind.clinical);
  static const plan = AppRoute(AppRouteKind.plan);
  static const podcast = AppRoute(AppRouteKind.podcast);
  static const infographic = AppRoute(AppRouteKind.infographic);
  static const mindMap = AppRoute(AppRouteKind.mindMap);

  // Profile
  static const store = AppRoute(AppRouteKind.store);
  static const settings = AppRoute(AppRouteKind.settings);
  static AppRoute profileMenu(String destination) =>
      AppRoute(AppRouteKind.profileMenu, {'destination': destination});

  Map<String, String> get generationOptions => {
        for (final e in params.entries)
          if (e.key.startsWith('opt_')) e.key.substring(4): e.value,
      };

  @override
  bool operator ==(Object other) =>
      other is AppRoute &&
      other.kind == kind &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(params.entries
      .map((e) => Object.hash(e.key, e.value))
      .toList()
    ..sort()));
}

enum SourcePickerDestinationKind { baseForceHome, sourceLabHome, route }

class SourcePickerDestination {
  const SourcePickerDestination._(this.kind, [this.route]);

  final SourcePickerDestinationKind kind;
  final AppRoute? route;

  static const baseForceHome = SourcePickerDestination._(
      SourcePickerDestinationKind.baseForceHome);
  static const sourceLabHome = SourcePickerDestination._(
      SourcePickerDestinationKind.sourceLabHome);
  static SourcePickerDestination toRoute(AppRoute route) =>
      SourcePickerDestination._(SourcePickerDestinationKind.route, route);
}

/// Port of AppRouter: tab selection plus a push-style navigation path.
class AppRouter extends ChangeNotifier {
  AppRouter._();

  static final AppRouter shared = AppRouter._();

  List<AppRoute> path = [];
  AppRoute selectedTab = AppRoute.drive;
  SourcePickerDestination? sourcePickerDestination;

  bool get canPop => path.isNotEmpty;

  void navigate(AppRoute route) {
    path = [...path, route];
    notifyListeners();
  }

  void pop() {
    if (path.isEmpty) return;
    path = path.sublist(0, path.length - 1);
    notifyListeners();
  }

  void popToRoot() {
    path = [];
    notifyListeners();
  }

  void replace(AppRoute route) {
    path = [route];
    notifyListeners();
  }

  void replaceCurrent(AppRoute route) {
    if (path.isEmpty) {
      path = [route];
    } else {
      path = [...path.sublist(0, path.length - 1), route];
    }
    notifyListeners();
  }

  void switchTab(AppRoute tab) {
    selectedTab = rootTab(tab);
    path = [];
    notifyListeners();
  }

  void reset(AppRoute route) {
    path = [];
    selectedTab = rootTab(route);
    sourcePickerDestination = null;
    notifyListeners();
  }

  void beginSourceSelection(
      {AppRoute? from, required SourcePickerDestination destination}) {
    if (from != null) {
      selectedTab = rootTab(from);
      path = [];
    }
    sourcePickerDestination = destination;
    path = [...path, AppRoute.sourcePicker];
    notifyListeners();
  }

  void completeSourceSelection() {
    final destination = sourcePickerDestination;
    sourcePickerDestination = null;

    switch (destination?.kind) {
      case SourcePickerDestinationKind.baseForceHome:
      case SourcePickerDestinationKind.sourceLabHome:
        switchTab(AppRoute.baseForce);
      case SourcePickerDestinationKind.route:
        final route = destination!.route!;
        final tab = rootTab(route);
        selectedTab = tab;
        path = route == tab ? [] : [route];
        notifyListeners();
      case null:
        if (canPop) {
          pop();
        } else {
          switchTab(AppRoute.baseForce);
        }
    }
  }

  AppRoute rootTab(AppRoute route) {
    switch (route.kind) {
      case AppRouteKind.drive:
      case AppRouteKind.courseDetail:
      case AppRouteKind.folder:
      case AppRouteKind.fileDetail:
      case AppRouteKind.uploads:
      case AppRouteKind.collections:
      case AppRouteKind.search:
        return AppRoute.drive;
      case AppRouteKind.baseForce:
      case AppRouteKind.sourcePicker:
      case AppRouteKind.flashcardFactory:
      case AppRouteKind.questionFactory:
      case AppRouteKind.summaryFactory:
      case AppRouteKind.algorithmFactory:
      case AppRouteKind.comparisonFactory:
      case AppRouteKind.queue:
      case AppRouteKind.generationProcessing:
      case AppRouteKind.result:
      case AppRouteKind.studyOutput:
      // SourceLab tools live inside the unified "Üret" (baseForce) tab.
      case AppRouteKind.sourceLab:
      case AppRouteKind.examMorning:
      case AppRouteKind.clinical:
      case AppRouteKind.plan:
      case AppRouteKind.podcast:
      case AppRouteKind.infographic:
      case AppRouteKind.mindMap:
        return AppRoute.baseForce;
      case AppRouteKind.centralAI:
        return AppRoute.centralAI;
      case AppRouteKind.profile:
      case AppRouteKind.store:
      case AppRouteKind.settings:
      case AppRouteKind.profileMenu:
        return AppRoute.profile;
      case AppRouteKind.login:
      case AppRouteKind.register:
      case AppRouteKind.verifyEmail:
      case AppRouteKind.forgotPassword:
      case AppRouteKind.resetPassword:
        return AppRoute.drive;
    }
  }
}
