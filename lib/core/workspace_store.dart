import 'dart:async';

import 'package:flutter/foundation.dart';

import 'drive_repository.dart';
import '../models/models.dart';
import '../models/study_models.dart';
import 'sourcebase_api_client.dart';

enum SBGenerationStatus { queued, running, completed, failed }

class SBWorkspaceGenerationJob {
  SBWorkspaceGenerationJob({
    required this.id,
    required this.sourceFileId,
    required this.sourceTitle,
    required this.kind,
    required this.status,
    required this.progress,
    this.output,
    this.outputId,
    this.failureMessage,
  });

  final String id;
  final String sourceFileId;
  final String sourceTitle;
  final GeneratedKind kind;
  SBGenerationStatus status;
  double progress;
  GeneratedOutput? output;
  String? outputId;
  String? failureMessage;

  bool get isActive =>
      status == SBGenerationStatus.queued ||
      status == SBGenerationStatus.running;
}

/// Live SourceBase workspace store backed by the SourceBase Edge Function.
class WorkspaceStore extends ChangeNotifier {
  WorkspaceStore._();

  static final WorkspaceStore shared = WorkspaceStore._();
  final DriveRepository _repository = DriveRepository();

  DriveWorkspaceData workspace = DriveWorkspaceData.empty;
  bool isLoading = false;
  bool isBusy = false;
  String? errorMessage;
  String? toastMessage;
  SBUploadPhase uploadPhase = SBUploadPhase.idle;
  String? selectedCourseId;
  String? selectedSectionId;
  String? selectedFileId;
  Set<String> selectedSourceIds = {};
  List<SBWorkspaceGenerationJob> generationJobs = [];
  DriveDestination? currentUploadDestination;
  SBStorageStatus storageStatus = SBStorageStatus.empty;

  bool _loadedOnce = false;

  bool get hasLoadedWorkspace => _loadedOnce;

  // MARK: - Computed

  List<DriveFile> get allFiles => [
    for (final course in workspace.courses)
      for (final section in course.sections) ...section.files,
  ];

  List<DriveFile> get readyFiles =>
      allFiles.where((f) => f.status == DriveItemStatus.completed).toList();

  List<DriveFile> get selectedReadyFiles =>
      readyFiles.where((f) => selectedSourceIds.contains(f.id)).toList();

  int get totalGeneratedOutputCount =>
      allFiles.fold(0, (sum, f) => sum + f.generated.length);

  List<({DriveFile file, GeneratedOutput output})> get latestGeneratedPairs => [
    for (final f in allFiles)
      if (f.generated.isNotEmpty) (file: f, output: f.generated.first),
  ];

  ({DriveFile file, GeneratedOutput output})? get quickContinueOutput =>
      latestGeneratedPairs.isNotEmpty ? latestGeneratedPairs.first : null;

  DriveFile? get quickContinueReadyFile {
    for (final f in readyFiles) {
      if (selectedSourceIds.contains(f.id)) return f;
    }
    final selected = file(selectedFileId);
    if (selected != null && isReadyForGeneration(selected)) return selected;
    return readyFiles.isNotEmpty ? readyFiles.first : null;
  }

  String get momentumFocusTitle =>
      quickContinueOutput?.file.courseTitle ??
      quickContinueReadyFile?.courseTitle ??
      workspace.primaryCourse?.title ??
      'Hazır kaynak bekleniyor';

  // MARK: - Loading

  Future<void> loadWorkspace({bool force = false}) async {
    if (isLoading && !force) return;
    if (_loadedOnce && !force) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      workspace = await _repository.loadWorkspace();
      try {
        storageStatus = await _repository.storageStatus();
      } catch (_) {
        storageStatus = SBStorageStatus.empty;
      }
      await _syncGenerationQueue(silent: true);
      _loadedOnce = true;
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadWorkspace(force: true);

  Future<void> refreshGenerationQueue() async {
    await _syncGenerationQueue();
  }

  // MARK: - Lookup

  DriveFile? file(String? id) {
    if (id == null) return null;
    for (final f in allFiles) {
      if (f.id == id) return f;
    }
    return null;
  }

  GeneratedOutput? generatedOutput(String? id) {
    if (id == null) return null;
    for (final f in allFiles) {
      for (final o in f.generated) {
        if (o.id == id) return o;
      }
    }
    for (final job in generationJobs) {
      if (job.output?.id == id) return job.output;
    }
    return null;
  }

  DriveCourse? course(String? id) {
    if (id == null) return null;
    for (final c in workspace.courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  DriveSection? section(String? id) {
    if (id == null) return null;
    for (final c in workspace.courses) {
      for (final s in c.sections) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  DriveCourse? courseOfSection(String? sectionId) {
    if (sectionId == null) return null;
    for (final c in workspace.courses) {
      for (final s in c.sections) {
        if (s.id == sectionId) return c;
      }
    }
    return null;
  }

  // MARK: - Selection

  void selectFile(DriveFile file) {
    selectedFileId = file.id;
    if (isReadyForGeneration(file)) {
      selectedSourceIds = {file.id};
    }
    notifyListeners();
  }

  void setSelectedSources(Set<String> ids) {
    selectedSourceIds = ids;
    selectedFileId = ids.isNotEmpty ? ids.first : selectedFileId;
    notifyListeners();
  }

  void toggleSource(DriveFile file) {
    if (selectedSourceIds.contains(file.id)) {
      selectedSourceIds = {...selectedSourceIds}..remove(file.id);
    } else {
      selectedSourceIds = {...selectedSourceIds, file.id};
      selectedFileId = file.id;
    }
    notifyListeners();
  }

  bool isReadyForGeneration(DriveFile file) =>
      file.status == DriveItemStatus.completed;

  // MARK: - Node CRUD

  Future<DriveCourse?> createCourse({
    required String title,
    String description = '',
    String iconName = 'folder',
    String colorHex = '#0A5BFF',
  }) async {
    isBusy = true;
    notifyListeners();
    try {
      final course = await _repository.createCourse(
        title,
        iconName: iconName,
        colorHex: colorHex,
      );
      await refresh();
      toast('Ders oluşturuldu: $title');
      return course;
    } catch (error) {
      errorMessage = _friendlyError(error);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<DriveSection?> createSection({
    required String courseId,
    required String title,
    String iconName = 'folder',
    String colorHex = '#0A5BFF',
  }) async {
    isBusy = true;
    notifyListeners();
    try {
      final section = await _repository.createSection(
        courseId: courseId,
        title: title,
        iconName: iconName,
        colorHex: colorHex,
      );
      await refresh();
      toast('Klasör oluşturuldu: $title');
      return section;
    } catch (error) {
      errorMessage = _friendlyError(error);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> renameCourse(String courseId, {required String title}) async {
    await _runLiveAction(
      () => _repository.renameCourse(courseId: courseId, title: title),
      successMessage: 'Ders adı güncellendi.',
    );
  }

  Future<void> renameSection(String sectionId, {required String title}) async {
    await _runLiveAction(
      () => _repository.renameSection(sectionId: sectionId, title: title),
      successMessage: 'Klasör adı güncellendi.',
    );
  }

  Future<void> deleteCourse(String courseId) async {
    await _runLiveAction(
      () => _repository.deleteCourse(courseId),
      successMessage: 'Ders silindi.',
    );
  }

  Future<void> deleteSection(String sectionId) async {
    await _runLiveAction(
      () => _repository.deleteSection(sectionId),
      successMessage: 'Klasör silindi.',
    );
  }

  Future<void> renameFile(String fileId, {required String title}) async {
    await _runLiveAction(
      () => _repository.renameFile(fileId: fileId, title: title),
      successMessage: 'Dosya adı güncellendi.',
    );
  }

  Future<void> moveFiles(
    List<String> fileIds, {
    String? courseId,
    String? sectionId,
  }) async {
    final targetCourse = course(courseId) ?? workspace.primaryCourse;
    if (targetCourse == null) return;
    final targetSection =
        section(sectionId) ??
        (targetCourse.sections.isNotEmpty ? targetCourse.sections.first : null);
    if (targetSection == null) return;

    await _runLiveAction(
      () => _repository.moveFiles(
        fileIds,
        courseId: targetCourse.id,
        sectionId: targetSection.id,
      ),
      successMessage: 'Dosyalar taşındı.',
    );
  }

  Future<void> saveOutput(
    String outputId, {
    required String courseId,
    required String sectionId,
  }) async {
    await _runLiveAction(
      () => _repository.saveGeneratedOutput(
        outputId: outputId,
        courseId: courseId,
        sectionId: sectionId,
      ),
      successMessage: 'Çalışma Drive alanına kaydedildi.',
    );
  }

  Future<void> deleteFiles(List<String> fileIds) async {
    selectedSourceIds = {...selectedSourceIds}..removeAll(fileIds);
    await _runLiveAction(
      () => _repository.deleteFiles(fileIds),
      successMessage: 'Dosya silindi.',
    );
  }

  Future<void> retryFileProcessing(String fileId) async {
    await _runLiveAction(
      () => _repository.retryFileProcessing(fileId),
      successMessage: 'Dosya yeniden işleme alındı.',
    );
  }

  Future<void> addToCollection({
    required String fileId,
    String? outputId,
    String? collection,
  }) async {
    await _runLiveAction(
      () => _repository.addToCollection(
        fileId: fileId,
        outputId: outputId,
        collection: collection,
      ),
      successMessage: 'Koleksiyona eklendi.',
    );
  }

  // MARK: - Upload

  List<DriveDestination> get availableDestinations => [
    for (final c in workspace.courses)
      for (final s in c.sections)
        DriveDestination(
          courseId: c.id,
          sectionId: s.id,
          courseTitle: c.title,
          sectionTitle: s.title,
        ),
  ];

  DriveDestination? get preferredUploadDestination {
    if (currentUploadDestination != null &&
        currentUploadDestination!.isUsable) {
      return currentUploadDestination;
    }
    final destinations = availableDestinations;
    return destinations.isNotEmpty ? destinations.first : null;
  }

  Future<void> uploadPickedFile(
    PickedDriveFile picked, {
    DriveDestination? destination,
  }) async {
    final dest = destination ?? preferredUploadDestination;
    if (dest == null) {
      errorMessage = 'Önce bir ders ve klasör oluşturmalısın.';
      notifyListeners();
      return;
    }
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      errorMessage = 'Dosya içeriği okunamadı. Lütfen tekrar seç.';
      uploadPhase = SBUploadPhase.error;
      notifyListeners();
      return;
    }

    currentUploadDestination = dest;
    uploadPhase = SBUploadPhase.extracting;
    isBusy = true;
    notifyListeners();
    try {
      final session = await _repository.createUploadSession(
        file: picked,
        destination: dest,
      );

      uploadPhase = SBUploadPhase.uploading;
      notifyListeners();
      await SourceBaseApiClient.shared.uploadToSignedUrl(
        uploadUrl: session.uploadUrl,
        headers: session.headers,
        bytes: bytes,
      );

      uploadPhase = SBUploadPhase.completing;
      notifyListeners();
      await _repository.completeUpload(
        file: picked,
        session: session,
        destination: dest,
      );

      uploadPhase = SBUploadPhase.success;
      await refresh();
      toast('Dosya Drive alanına eklendi.');
    } catch (error) {
      uploadPhase = SBUploadPhase.error;
      errorMessage = _friendlyError(error);
    } finally {
      isBusy = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 2), () {
        if (uploadPhase == SBUploadPhase.success ||
            uploadPhase == SBUploadPhase.error) {
          uploadPhase = SBUploadPhase.idle;
          notifyListeners();
        }
      });
    }
  }

  // MARK: - Generation

  Future<SBWorkspaceGenerationJob?> startGeneration({
    DriveFile? file,
    required GeneratedKind kind,
    Map<String, String>? options,
  }) async {
    final source = file ?? quickContinueReadyFile;
    if (source == null) {
      errorMessage = 'Üretim için hazır bir kaynak seçmelisin.';
      notifyListeners();
      return null;
    }

    try {
      final sourceIds = selectedSourceIds.isNotEmpty
          ? selectedSourceIds.toList()
          : <String>[source.id];
      final snapshot = await _repository.createGenerationJob(
        file: source,
        kind: kind,
        sourceIds: sourceIds,
        options: options,
      );
      final job = _jobFromSnapshot(snapshot);
      generationJobs = [job, ...generationJobs.where((j) => j.id != job.id)];
      notifyListeners();
      unawaited(_processAndTrackJob(job));
      return job;
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
      return null;
    }
  }

  /// Port of `enqueueDriveGeneration`: select sources and start a job.
  Future<SBWorkspaceGenerationJob?> enqueueDriveGeneration({
    required DriveFile file,
    required GeneratedKind kind,
    Set<String>? sourceIds,
    String mode = 'Standart',
  }) async {
    setSelectedSources(sourceIds ?? {file.id});
    selectFile(file);
    return enqueueGeneration(
      file: file,
      kind: kind,
      label: kind.titleLabel,
      surface: 'Üretim',
      mode: mode,
    );
  }

  /// Port of `enqueueGeneration`. The options are forwarded to the backend.
  Future<SBWorkspaceGenerationJob?> enqueueGeneration({
    required DriveFile file,
    required GeneratedKind kind,
    required String label,
    required String surface,
    required String mode,
    Map<String, String> extraOptions = const {},
  }) {
    final options = {
      ...extraOptions,
      'mode': mode,
      'surface': surface,
      'label': label,
    };
    return startGeneration(file: file, kind: kind, options: options);
  }

  SBWorkspaceGenerationJob? job(String? id) {
    if (id == null) return null;
    for (final j in generationJobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  Future<GeneratedOutput?> finalizeGenerationJob(
    SBWorkspaceGenerationJob job,
  ) async {
    if (job.output != null) return job.output;
    final source = file(job.sourceFileId);
    if (source == null) return null;
    try {
      final output = await _repository.finalizeGenerationJob(
        file: source,
        kind: job.kind,
        jobId: job.id,
      );
      if (output != null) {
        job.status = SBGenerationStatus.completed;
        job.output = output;
        job.outputId = output.id;
        workspace = _mapFile(
          job.sourceFileId,
          (f) => _copyFile(f, generated: [output, ...f.generated]),
        );
      }
      return output;
    } catch (error) {
      job.status = SBGenerationStatus.failed;
      job.failureMessage = _friendlyError(error);
      notifyListeners();
      return null;
    }
  }

  Future<void> cancelJob(SBWorkspaceGenerationJob job) async {
    try {
      await _repository.cancelJob(job.id);
      job.status = SBGenerationStatus.failed;
      job.failureMessage = 'Üretim iptal edildi.';
      toast('Üretim iptal edildi.');
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      notifyListeners();
    }
  }

  Future<void> retryJob(SBWorkspaceGenerationJob job) async {
    try {
      await _repository.retryJob(job.id);
      job.status = SBGenerationStatus.queued;
      job.progress = 0;
      job.failureMessage = null;
      notifyListeners();
      unawaited(_processAndTrackJob(job));
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
    }
  }

  // MARK: - Central AI

  Future<String> sendCentralAIMessage(
    String message, {
    List<String> fileIds = const [],
  }) async {
    final context = _centralAIContext(fileIds);
    return _repository.centralAiChat(
      message,
      context: context,
      fileIds: fileIds,
    );
  }

  // MARK: - Question session

  Future<List<SBQuestionPrompt>> loadQuestionSession({
    required String outputId,
  }) async {
    return _repository.loadQuestionSession(outputId);
  }

  Future<SBQuestionAnswerFeedback> submitQuestionAnswer({
    required String outputId,
    required String questionId,
    required int selectedIndex,
  }) async {
    return _repository.submitQuestionAnswer(
      outputId: outputId,
      questionId: questionId,
      selectedIndex: selectedIndex,
    );
  }

  // MARK: - Misc

  Future<bool> requestAccountDeletion() async {
    try {
      await _repository.requestAccountDeletion();
      toast('Hesap silme talebin alındı.');
      return true;
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitSupportForm({
    required String topic,
    required String email,
    required String message,
  }) async {
    try {
      await _repository.submitSupportForm(
        topic: topic,
        email: email,
        message: message,
      );
      toast('Destek talebin iletildi.');
      return true;
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
      return false;
    }
  }

  void toast(String message) {
    toastMessage = message;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      if (toastMessage == message) {
        toastMessage = null;
        notifyListeners();
      }
    });
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _runLiveAction(
    Future<dynamic> Function() action, {
    required String successMessage,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      await refresh();
      toast(successMessage);
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _syncGenerationQueue({bool silent = false}) async {
    try {
      final snapshots = await _repository.listUserJobs();
      final existing = {for (final job in generationJobs) job.id: job};
      generationJobs = [
        for (final snapshot in snapshots)
          _mergeJobSnapshot(snapshot, existing[snapshot.id]),
      ];
    } catch (error) {
      if (!silent) errorMessage = _friendlyError(error);
    } finally {
      if (!silent) notifyListeners();
    }
  }

  Future<void> _processAndTrackJob(SBWorkspaceGenerationJob job) async {
    unawaited(_repository.processGenerationJob(job.id).catchError((_) {}));

    for (var attempt = 0; attempt < 180; attempt += 1) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final snapshot = await _repository.getJobStatus(job.id);
        _applySnapshot(job, snapshot);
        if (job.status == SBGenerationStatus.completed) {
          await finalizeGenerationJob(job);
          await refresh();
          toast('Üretim tamamlandı.');
          return;
        }
        if (job.status == SBGenerationStatus.failed) {
          job.failureMessage ??= snapshot.errorMessage ?? 'Üretim başarısız.';
          notifyListeners();
          return;
        }
      } catch (error) {
        job.status = SBGenerationStatus.failed;
        job.failureMessage = _friendlyError(error);
        notifyListeners();
        return;
      }
    }

    job.status = SBGenerationStatus.failed;
    job.failureMessage =
        'Üretim zaman aşımına uğradı. Kuyruk ekranından tekrar kontrol et.';
    notifyListeners();
  }

  SBWorkspaceGenerationJob _jobFromSnapshot(GenerationJobSnapshot snapshot) {
    return SBWorkspaceGenerationJob(
      id: snapshot.jobId?.isNotEmpty == true ? snapshot.jobId! : snapshot.id,
      sourceFileId: snapshot.sourceFileId,
      sourceTitle: snapshot.sourceTitle,
      kind: snapshot.kind,
      status: _statusFromPhase(snapshot.phase),
      progress: snapshot.progress,
      outputId: snapshot.outputId,
      failureMessage: snapshot.errorMessage,
    );
  }

  SBWorkspaceGenerationJob _mergeJobSnapshot(
    GenerationJobSnapshot snapshot,
    SBWorkspaceGenerationJob? existing,
  ) {
    final job = existing ?? _jobFromSnapshot(snapshot);
    _applySnapshot(job, snapshot);
    return job;
  }

  void _applySnapshot(
    SBWorkspaceGenerationJob job,
    GenerationJobSnapshot snapshot,
  ) {
    job.status = _statusFromPhase(snapshot.phase);
    job.progress = snapshot.progress;
    job.outputId = snapshot.outputId ?? job.outputId;
    job.failureMessage = snapshot.errorMessage ?? job.failureMessage;
  }

  SBGenerationStatus _statusFromPhase(GenerationJobPhase phase) {
    return switch (phase) {
      GenerationJobPhase.queued => SBGenerationStatus.queued,
      GenerationJobPhase.running => SBGenerationStatus.running,
      GenerationJobPhase.completed => SBGenerationStatus.completed,
      GenerationJobPhase.failed => SBGenerationStatus.failed,
    };
  }

  String? _centralAIContext(List<String> fileIds) {
    final selected = fileIds
        .map(file)
        .whereType<DriveFile>()
        .take(6)
        .map(
          (f) =>
              '${f.title} (${f.courseTitle} / ${f.sectionTitle}) - ${f.statusMessage ?? f.pageLabel}',
        )
        .join('\n');
    if (selected.trim().isEmpty) return null;
    return 'Seçili SourceBase kaynakları:\n$selected';
  }

  String _friendlyError(Object error) {
    if (error is SourceBaseApiException) {
      if (error.isUnauthorized) {
        return 'Oturum süresi doldu. Lütfen tekrar giriş yap.';
      }
      return error.message;
    }
    return 'İşlem tamamlanamadı. Lütfen tekrar dene.';
  }

  // MARK: - Copy helpers (models are immutable)

  DriveWorkspaceData _copyWorkspace({
    List<DriveCourse>? courses,
    List<DriveFile>? recentFiles,
    List<UploadTask>? uploads,
    List<CollectionBundle>? collections,
  }) {
    final data = DriveWorkspaceData(
      courses: courses ?? workspace.courses,
      recentFiles: recentFiles ?? workspace.recentFiles,
      uploads: uploads ?? workspace.uploads,
      collections: collections ?? workspace.collections,
    );
    notifyListeners();
    return data;
  }

  DriveCourse _copyCourse(
    DriveCourse c, {
    String? title,
    List<DriveSection>? sections,
  }) => DriveCourse(
    id: c.id,
    title: title ?? c.title,
    iconName: c.iconName,
    iconColorHex: c.iconColorHex,
    iconBackgroundHex: c.iconBackgroundHex,
    status: c.status,
    sections: sections ?? c.sections,
    updatedLabel: c.updatedLabel,
    description: c.description,
  );

  DriveSection _copySection(
    DriveSection s, {
    String? title,
    List<DriveFile>? files,
    List<GeneratedOutput>? savedOutputs,
  }) => DriveSection(
    id: s.id,
    title: title ?? s.title,
    status: s.status,
    files: files ?? s.files,
    savedOutputs: savedOutputs ?? s.savedOutputs,
    iconName: s.iconName,
    iconColorHex: s.iconColorHex,
  );

  DriveFile _copyFile(
    DriveFile f, {
    String? title,
    DriveItemStatus? status,
    List<GeneratedOutput>? generated,
    String? courseTitle,
    String? sectionTitle,
  }) => DriveFile(
    id: f.id,
    title: title ?? f.title,
    kind: f.kind,
    sizeLabel: f.sizeLabel,
    pageLabel: f.pageLabel,
    updatedLabel: f.updatedLabel,
    courseTitle: courseTitle ?? f.courseTitle,
    sectionTitle: sectionTitle ?? f.sectionTitle,
    status: status ?? f.status,
    statusMessage: f.statusMessage,
    tag: f.tag,
    featured: f.featured,
    selected: f.selected,
    generated: generated ?? f.generated,
  );

  DriveWorkspaceData _mapFile(
    String fileId,
    DriveFile Function(DriveFile) transform,
  ) {
    return _copyWorkspace(
      courses: [
        for (final c in workspace.courses)
          _copyCourse(
            c,
            sections: [
              for (final s in c.sections)
                _copySection(
                  s,
                  files: [
                    for (final f in s.files)
                      if (f.id == fileId) transform(f) else f,
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
