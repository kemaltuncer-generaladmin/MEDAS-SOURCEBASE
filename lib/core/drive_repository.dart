import 'dart:convert';
import 'dart:math';

import '../models/generated_content_parser.dart';
import '../models/models.dart';
import '../models/study_models.dart';
import 'sourcebase_api_client.dart';

class DriveRepository {
  DriveRepository({SourceBaseApiClient? api})
      : api = api ?? SourceBaseApiClient.shared;

  final SourceBaseApiClient api;

  Future<DriveWorkspaceData> loadWorkspace() async {
    final response = await api.invoke('drive_bootstrap');
    final data = _map(response['data']);
    final courseRows = _rows(data['courses']);
    final sectionRows = _rows(data['sections']);
    final fileRows = _rows(data['files']);
    final outputRows =
        _rows(data['generatedOutputs'] ?? data['generated_outputs']);
    final uploadRows =
        _rows(data['uploads'] ?? data['uploadTasks'] ?? data['upload_tasks']);

    final courses = courseRows.isEmpty && fileRows.isNotEmpty
        ? [
            DriveCourse(
              id: 'uncategorized',
              title: 'Drive',
              iconName: 'folder',
              iconColorHex: '#0A5BFF',
              iconBackgroundHex: '#EDF4FF',
              status: DriveItemStatus.completed,
              sections: [
                DriveSection(
                  id: 'uncategorized-section',
                  title: 'Kaynaklar',
                  status: DriveItemStatus.completed,
                  files: [
                    for (final row in fileRows)
                      _fileFromRow(
                        row,
                        courseTitle: _string(row, ['course_title']) ?? 'Drive',
                        sectionTitle:
                            _string(row, ['section_title']) ?? 'Kaynaklar',
                        outputRows: outputRows,
                      ),
                  ],
                  savedOutputs: const [],
                  iconName: 'folder',
                  iconColorHex: '#0A5BFF',
                ),
              ],
              updatedLabel: 'Bugün',
              description: 'Drive kaynakların burada listelenir.',
            )
          ]
        : [
            for (final row in courseRows)
              _courseFromRow(
                row,
                sectionRows: sectionRows,
                fileRows: fileRows,
                outputRows: outputRows,
              ),
          ];

    final allFiles = [
      for (final course in courses)
        for (final section in course.sections) ...section.files,
    ];
    final recentFiles = allFiles.take(5).toList();
    final collections = [
      for (final file in allFiles)
        if (file.generated.isNotEmpty)
          CollectionBundle(
            file: file,
            outputs: file.generated,
            subject: file.courseTitle,
            previewKind: file.generated.first.kind,
          ),
    ];

    return DriveWorkspaceData(
      courses: courses,
      recentFiles: recentFiles,
      uploads: [
        for (final row in uploadRows)
          _uploadTaskFromRow(row, allFiles: allFiles, outputRows: outputRows),
      ],
      collections: collections,
    );
  }

  Future<SBStorageStatus> storageStatus() async {
    final response = await api.invoke('get_storage_status');
    return SBStorageStatus.fromJson(_map(response['data']));
  }

  Future<DriveCourse> createCourse(
    String title, {
    String? iconName,
    String? colorHex,
  }) async {
    final payload = <String, dynamic>{'title': title};
    if (iconName?.trim().isNotEmpty == true) payload['iconName'] = iconName;
    if (colorHex?.trim().isNotEmpty == true) payload['colorHex'] = colorHex;
    final response = await api.invoke('create_course', payload: payload);
    return _courseFromRow(_requiredRow(response, 'Ders oluşturulamadı.'));
  }

  Future<DriveSection> createSection({
    required String courseId,
    required String title,
    String? iconName,
    String? colorHex,
  }) async {
    final payload = <String, dynamic>{
      'courseId': courseId,
      'title': title,
    };
    if (iconName?.trim().isNotEmpty == true) payload['iconName'] = iconName;
    if (colorHex?.trim().isNotEmpty == true) payload['colorHex'] = colorHex;
    final response = await api.invoke('create_section', payload: payload);
    return _sectionFromRow(_requiredRow(response, 'Bölüm oluşturulamadı.'));
  }

  Future<DriveCourse> renameCourse({
    required String courseId,
    required String title,
  }) async {
    final response = await api.invoke('rename_course', payload: {
      'courseId': courseId,
      'title': title,
    });
    return _courseFromRow(_requiredRow(response, 'Ders yeniden adlandırılamadı.'));
  }

  Future<DriveSection> renameSection({
    required String sectionId,
    required String title,
  }) async {
    final response = await api.invoke('rename_section', payload: {
      'sectionId': sectionId,
      'title': title,
    });
    return _sectionFromRow(
      _requiredRow(response, 'Bölüm yeniden adlandırılamadı.'),
    );
  }

  Future<void> deleteCourse(String courseId) async {
    await api.invoke('delete_course', payload: {'courseId': courseId});
  }

  Future<void> deleteSection(String sectionId) async {
    await api.invoke('delete_section', payload: {'sectionId': sectionId});
  }

  Future<DriveFile?> renameFile({
    required String fileId,
    required String title,
    String courseTitle = '',
    String sectionTitle = '',
  }) async {
    final response = await api.invoke('rename_file', payload: {
      'fileId': fileId,
      'title': title,
    });
    final row = _dataRow(response);
    if (row == null || row.isEmpty) return null;
    return _fileFromRow(
      row,
      courseTitle: _string(row, ['course_title']) ?? courseTitle,
      sectionTitle: _string(row, ['section_title']) ?? sectionTitle,
      outputRows: const [],
    );
  }

  Future<void> moveFiles(
    List<String> fileIds, {
    required String courseId,
    required String sectionId,
  }) async {
    if (fileIds.isEmpty) return;
    await api.invoke('move_files', payload: {
      'fileIds': fileIds,
      'courseId': courseId,
      'sectionId': sectionId,
    });
  }

  Future<void> saveGeneratedOutput({
    required String outputId,
    required String courseId,
    required String sectionId,
  }) async {
    await api.invoke('move_generated_output', payload: {
      'outputId': outputId,
      'courseId': courseId,
      'sectionId': sectionId,
    });
  }

  Future<void> deleteFiles(List<String> fileIds) async {
    if (fileIds.isEmpty) return;
    await api.invoke('delete_files', payload: {'fileIds': fileIds});
  }

  Future<void> retryFileProcessing(String fileId) async {
    await api.invoke('retry_file_processing', payload: {'fileId': fileId});
  }

  Future<void> addToCollection({
    required String fileId,
    String? outputId,
    String? collection,
  }) async {
    final payload = <String, dynamic>{'fileIds': [fileId]};
    if (outputId?.trim().isNotEmpty == true) payload['outputId'] = outputId;
    if (collection?.trim().isNotEmpty == true) payload['collection'] = collection;
    await api.invoke('add_to_collection', payload: payload);
  }

  Future<StorageUploadSession> createUploadSession({
    required PickedDriveFile file,
    required DriveDestination destination,
  }) async {
    final response = await api.invoke('create_upload_session', payload: {
      'fileName': file.name,
      'contentType': file.contentType,
      'sizeBytes': file.sizeBytes,
      'courseId': destination.courseId,
      'sectionId': destination.sectionId,
      ..._documentProcessingPolicy(file.name, file.contentType),
    });
    final session = StorageUploadSession.fromJson(_map(response['data']));
    if (!session.isUsable) {
      throw SourceBaseApiException(
        'Yükleme bağlantısı alınamadı. Tekrar deneyebilirsin.',
      );
    }
    return session;
  }

  Future<DriveFile> completeUpload({
    required PickedDriveFile file,
    required StorageUploadSession session,
    required DriveDestination destination,
  }) async {
    final response = await api.invoke('complete_upload', payload: {
      'objectName': session.objectName,
      'courseId': destination.courseId,
      'sectionId': destination.sectionId,
      'fileName': file.name,
      'contentType': file.contentType,
      'sizeBytes': file.sizeBytes,
      ..._documentProcessingPolicy(file.name, file.contentType),
    });
    final row = _requiredRow(response, 'Yüklenen dosya kaydı alınamadı.');
    final uploaded = _fileFromRow(
      row,
      courseTitle: destination.courseTitle,
      sectionTitle: destination.sectionTitle,
      outputRows: const [],
    );
    if (uploaded.status == DriveItemStatus.failed) {
      throw SourceBaseApiException(
        uploaded.statusMessage ??
            'Dosya yüklendi ancak işleme kuyruğuna alınamadı.',
      );
    }
    return uploaded;
  }

  Future<GenerationJobSnapshot> createGenerationJob({
    required DriveFile file,
    required GeneratedKind kind,
    List<String>? sourceIds,
    Map<String, String>? options,
  }) async {
    final jobType = kind.jobType;
    if (jobType == null) {
      throw SourceBaseApiException(
        '${kind.titleLabel} için backend job type henüz aktif değil.',
      );
    }
    final enriched = _generationOptions(jobType, options);
    final payload = <String, dynamic>{
      'fileId': file.id,
      'jobType': jobType,
      ...enriched,
    };
    final count = int.tryParse(enriched['count'] ?? '') ?? kind.defaultCount;
    if (count != null) payload['count'] = count;
    final cleanSourceIds = (sourceIds ?? const [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (cleanSourceIds.isNotEmpty) payload['sourceIds'] = cleanSourceIds;

    final response = await api.invoke('create_generation_job', payload: payload);
    final data = _map(response['data']);
    final jobId = _string(data, ['jobId', 'job_id', 'id']) ?? '';
    if (jobId.trim().isEmpty) {
      throw SourceBaseApiException('Üretim işi başlatılamadı.');
    }
    return _generationJobFromRow({
      ...data,
      'id': jobId,
      'source_file_id': file.id,
      'source_title': file.title,
      'job_type': jobType,
    });
  }

  Future<void> processGenerationJob(String jobId) async {
    await api.invoke(
      'process_generation_job',
      payload: {'jobId': jobId},
      timeout: const Duration(seconds: 320),
    );
  }

  Future<GenerationJobSnapshot> getJobStatus(String jobId) async {
    final response = await api.invoke('get_job_status', payload: {'jobId': jobId});
    return _generationJobFromRow(_map(response['data']));
  }

  Future<Map<String, dynamic>?> generatedContentIfReady(String jobId) async {
    final status = await getJobStatus(jobId);
    if (status.phase == GenerationJobPhase.failed) {
      throw SourceBaseApiException(status.errorMessage ?? 'Üretim başarısız.');
    }
    if (status.phase != GenerationJobPhase.completed) return null;
    final response =
        await api.invoke('get_generated_content', payload: {'jobId': jobId});
    final content = _generatedContentPayload(response);
    if (content == null) {
      throw SourceBaseApiException('Üretim tamamlandı ancak içerik alınamadı.');
    }
    return content;
  }

  Future<GeneratedOutput?> finalizeGenerationJob({
    required DriveFile file,
    required GeneratedKind kind,
    required String jobId,
  }) async {
    final content = await generatedContentIfReady(jobId);
    if (content == null) return null;
    final response = await api.invoke('create_generated_output', payload: {
      'fileId': file.id,
      'kind': kind.rawValue,
      'itemCount': _contentItemCount(content),
      'jobId': jobId,
    });
    final row = _requiredRow(response, 'Üretilen içerik kaydı alınamadı.');
    return _outputFromRow(row, contentOverride: content);
  }

  Future<List<GenerationJobSnapshot>> listUserJobs({int limit = 50}) async {
    final response = await api.invoke('list_user_jobs', payload: {'limit': limit});
    final data = response['data'];
    final rows = data is List
        ? _rows(data)
        : _rows(_map(data)['jobs'] ?? _map(data)['rows']);
    return [for (final row in rows) _generationJobFromRow(row)];
  }

  Future<void> cancelJob(String jobId) async {
    await api.invoke('cancel_job', payload: {'jobId': jobId});
  }

  Future<void> retryJob(String jobId) async {
    await api.invoke('retry_job', payload: {'jobId': jobId});
  }

  Future<List<SBQuestionPrompt>> loadQuestionSession(String outputId) async {
    final response =
        await api.invoke('sourcebase_question_session', payload: {'outputId': outputId});
    return GeneratedContentParser.questionPrompts(response);
  }

  Future<SBQuestionAnswerFeedback> submitQuestionAnswer({
    required String outputId,
    required String questionId,
    required int selectedIndex,
  }) async {
    final response = await api.invoke('submit_sourcebase_question_answer', payload: {
      'outputId': outputId,
      'questionId': questionId,
      'selectedIndex': selectedIndex,
    });
    return GeneratedContentParser.questionAnswerFeedback(
      response,
      questionId,
      selectedIndex,
    );
  }

  Future<String> centralAiChat(
    String message, {
    String? context,
    List<String> fileIds = const [],
  }) async {
    final payload = <String, dynamic>{'message': message};
    if (context?.trim().isNotEmpty == true) payload['context'] = context!.trim();
    final cleanFileIds =
        fileIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleanFileIds.isNotEmpty) payload['fileIds'] = cleanFileIds;
    final response = await api.invoke(
      'central_ai_chat',
      payload: payload,
      timeout: const Duration(seconds: 120),
    );
    final data = _map(response['data']);
    return _string(data, ['message', 'reply', 'content']) ??
        'Yanıt alınamadı.';
  }

  Future<void> submitSupportForm({
    required String topic,
    required String email,
    required String message,
  }) async {
    await api.invoke('submit_support_form', payload: {
      'topic': topic,
      'email': email,
      'message': message,
    });
  }

  Future<void> requestAccountDeletion() async {
    await api.invoke('request_account_deletion');
  }

  Future<Map<String, dynamic>> purchaseMedasiCoin({
    required String productCode,
  }) async {
    final response = await api.invoke('purchase_medasicoin', payload: {
      'product_code': productCode,
      'success_url': '${api.config.publicUrl}/store/success',
      'cancel_url': '${api.config.publicUrl}/store/cancel',
    });
    return _map(response['data']);
  }

  DriveCourse _courseFromRow(
    Map<String, dynamic> row, {
    List<Map<String, dynamic>> sectionRows = const [],
    List<Map<String, dynamic>> fileRows = const [],
    List<Map<String, dynamic>> outputRows = const [],
  }) {
    final id = _string(row, ['id']) ?? '';
    final title = _string(row, ['title']) ?? 'Yeni Ders';
    final metadata = _metadata(row);
    final colorHex = _string(metadata, ['colorHex', 'color_hex']) ?? '#0A5BFF';
    return DriveCourse(
      id: id,
      title: title,
      iconName: _string(row, ['icon_name', 'iconName']) ?? 'book.closed',
      iconColorHex: colorHex,
      iconBackgroundHex: colorHex,
      status: _statusFromText(_string(row, ['status']) ?? 'active'),
      sections: [
        for (final section in sectionRows)
          if (_string(section, ['course_id', 'courseId']) == id)
            _sectionFromRow(
              section,
              fileRows: fileRows,
              courseTitle: title,
              outputRows: outputRows,
            ),
      ],
      updatedLabel: 'Son güncelleme ${_dateLabel(_string(row, [
            'updated_at',
            'updatedAt',
            'created_at',
            'createdAt',
          ]) ?? '')}',
      description: _string(metadata, ['description']) ??
          '$title dersine ait tüm içerikler, bölümler halinde düzenlenmiştir.',
    );
  }

  DriveSection _sectionFromRow(
    Map<String, dynamic> row, {
    List<Map<String, dynamic>> fileRows = const [],
    String? courseTitle,
    List<Map<String, dynamic>> outputRows = const [],
  }) {
    final id = _string(row, ['id']) ?? '';
    final title = _string(row, ['title']) ?? 'Yeni Bölüm';
    final metadata = _metadata(row);
    return DriveSection(
      id: id,
      title: title,
      status: _statusFromText(_string(row, ['status']) ?? 'active'),
      files: [
        for (final file in fileRows)
          if (_string(file, ['section_id', 'sectionId']) == id)
            _fileFromRow(
              file,
              courseTitle: courseTitle ?? _string(file, ['course_title']) ?? '',
              sectionTitle: title,
              outputRows: outputRows,
            ),
      ],
      savedOutputs: [
        for (final output in outputRows)
          if (_string(output, ['section_id', 'sectionId']) == id)
            _outputFromRow(output),
      ],
      iconName: _string(metadata, ['iconName', 'icon_name']) ?? 'folder',
      iconColorHex:
          _string(metadata, ['colorHex', 'color_hex']) ?? '#0A5BFF',
    );
  }

  DriveFile _fileFromRow(
    Map<String, dynamic> row, {
    required String courseTitle,
    required String sectionTitle,
    required List<Map<String, dynamic>> outputRows,
  }) {
    final id = _string(row, ['id']) ?? '';
    final kind = _kindFromRow(row);
    final status = _fileStatusFromRow(row);
    final sizeBytes = _int(row, ['size_bytes', 'sizeBytes']) ?? 0;
    return DriveFile(
      id: id,
      title: _string(row, ['title', 'original_filename', 'file_name']) ?? '',
      kind: kind,
      sizeLabel: _sizeLabel(sizeBytes),
      pageLabel: _pageLabel(
        kind,
        status,
        _int(row, ['page_count', 'pageCount', 'pages', 'total_pages']) ?? 0,
        _int(row, ['slide_count', 'slideCount', 'slides', 'total_slides']) ?? 0,
      ),
      updatedLabel: _dateLabel(_string(row, [
            'updated_at',
            'updatedAt',
            'created_at',
            'createdAt',
          ]) ?? ''),
      courseTitle: courseTitle,
      sectionTitle: sectionTitle,
      status: status,
      statusMessage: _fileStatusMessage(row, kind, status, sizeBytes),
      tag: _string(row, ['tag']),
      featured: false,
      selected: false,
      generated: [
        for (final output in outputRows)
          if (_string(output, ['source_file_id', 'sourceFileId']) == id)
            _outputFromRow(output),
      ],
    );
  }

  GeneratedOutput _outputFromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? contentOverride,
  }) {
    final rawType = _string(row, ['output_type', 'kind', 'raw_type']) ?? '';
    final kind = GeneratedKind.fromString(rawType);
    final metadata = _metadata(row);
    final content = contentOverride ?? _contentMap(metadata['content'] ?? row['content']);
    final itemCount = _int(row, ['item_count', 'itemCount']) ?? 0;
    final status = _string(row, ['status']) ?? 'ready';
    return GeneratedOutput(
      id: _string(row, ['id']) ?? '',
      sourceFileId: _string(row, ['source_file_id', 'sourceFileId']) ?? '',
      kind: kind,
      rawType: rawType,
      title: _string(row, ['title']) ?? kind.titleLabel,
      detail: _outputDetail(rawType, status, itemCount, content),
      content: content,
      contentText: _contentText(content),
      updatedLabel: _dateLabel(_string(row, [
            'updated_at',
            'updatedAt',
            'created_at',
            'createdAt',
          ]) ?? ''),
      status: status,
      itemCount: itemCount,
      jobId: _string(metadata, ['jobId', 'job_id']) ??
          _string(row, ['job_id', 'jobId']),
    );
  }

  UploadTask _uploadTaskFromRow(
    Map<String, dynamic> row, {
    required List<DriveFile> allFiles,
    required List<Map<String, dynamic>> outputRows,
  }) {
    final fileRow = _map(row['file']).isEmpty ? row : _map(row['file']);
    final fileId = _string(fileRow, ['id', 'file_id', 'fileId']) ??
        _string(row, ['file_id', 'fileId']) ??
        '';
    DriveFile? existing;
    for (final file in allFiles) {
      if (file.id == fileId) {
        existing = file;
        break;
      }
    }
    final file = existing ??
        _fileFromRow(
          fileRow,
          courseTitle:
              _string(fileRow, ['course_title']) ?? _string(row, ['course_title']) ?? 'Drive',
          sectionTitle: _string(fileRow, ['section_title']) ??
              _string(row, ['section_title']) ??
              'Kaynaklar',
          outputRows: outputRows,
        );
    final status = _statusFromText(
      _string(row, ['status', 'ai_status']) ??
          _string(fileRow, ['ai_status', 'status']) ??
          file.status.name,
    );
    return UploadTask(
      file: file,
      status: status,
      progress: _normalizedProgress(
        _double(row, ['progress', 'processing_progress', 'upload_progress']),
        status,
      ),
      errorLabel: _string(row, [
            'errorLabel',
            'error_label',
            'errorMessage',
            'error_message',
          ]) ??
          file.statusMessage,
    );
  }

  GenerationJobSnapshot _generationJobFromRow(Map<String, dynamic> row) {
    final id = _string(row, ['id', 'jobId', 'job_id']) ?? '';
    final outputId =
        _string(row, ['outputId', 'output_id', 'generatedOutputId', 'generated_output_id']);
    final rawStatus = _string(row, ['status']) ?? 'queued';
    final rawPhase = GenerationJobPhase.fromRawStatus(rawStatus);
    final phase = outputId?.trim().isNotEmpty == true &&
            rawPhase != GenerationJobPhase.failed
        ? GenerationJobPhase.completed
        : rawPhase;
    return GenerationJobSnapshot(
      id: id,
      sourceFileId: _string(row, ['sourceFileId', 'source_file_id', 'fileId', 'file_id']) ?? '',
      sourceTitle: _string(row, ['sourceTitle', 'source_title', 'fileTitle', 'file_title']) ??
          'Drive kaynağı',
      kind: GeneratedKind.fromString(
        _string(row, ['jobType', 'job_type', 'output_type', 'kind']) ?? 'summary',
      ),
      status: phase.name,
      progress: _normalizedProgress(
        _double(row, ['progress']),
        phase.driveStatus,
      ),
      errorMessage: _string(row, ['errorMessage', 'error_message']),
      outputId: outputId,
      jobId: _string(row, ['jobId', 'job_id']) ?? id,
    );
  }

  Map<String, dynamic>? _generatedContentPayload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      final dict = Map<String, dynamic>.from(data);
      return _contentMap(dict['content'] ??
          dict['result'] ??
          dict['output'] ??
          dict['generatedContent'] ??
          dict['generated_content']);
    }
    return _contentMap(response['content'] ?? response['result'] ?? response['output']);
  }

  Map<String, dynamic>? _contentMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {'text': value};
      } catch (_) {
        return {'text': value};
      }
    }
    return {'value': value};
  }

  Map<String, dynamic>? _dataRow(Map<String, dynamic> response) {
    final data = _map(response['data']);
    if (data['row'] is Map) return _map(data['row']);
    if (data['id'] != null) return data;
    return null;
  }

  Map<String, dynamic> _requiredRow(Map<String, dynamic> response, String message) {
    final row = _dataRow(response);
    if (row == null || row.isEmpty) throw SourceBaseApiException(message);
    return row;
  }

  Map<String, dynamic> _metadata(Map<String, dynamic> row) {
    final metadata = row['metadata'];
    if (metadata is Map) return Map<String, dynamic>.from(metadata);
    if (metadata is String && metadata.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  String? _string(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  int? _int(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _double(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  DriveItemStatus _statusFromText(String text) {
    final normalized = text.trim().replaceAll('-', '_').toLowerCase();
    switch (normalized) {
      case 'completed':
      case 'complete':
      case 'uploaded':
      case 'ready':
      case 'active':
      case 'succeeded':
      case 'success':
      case 'done':
      case 'finished':
      case 'processed':
        return DriveItemStatus.completed;
      case 'processing':
      case 'pending':
      case 'running':
      case 'in_progress':
      case 'started':
      case 'working':
      case 'generating':
        return DriveItemStatus.processing;
      case 'uploading':
        return DriveItemStatus.uploading;
      case 'draft':
      case 'queued':
      case 'created':
      case 'scheduled':
      case 'waiting':
        return DriveItemStatus.draft;
      default:
        return DriveItemStatus.failed;
    }
  }

  DriveItemStatus _fileStatusFromRow(Map<String, dynamic> row) {
    if ((_int(row, ['size_bytes', 'sizeBytes']) ?? 0) <= 0) {
      return DriveItemStatus.failed;
    }
    final aiStatus = _string(row, ['ai_status', 'aiStatus']);
    if (aiStatus != null) return _statusFromText(aiStatus);
    final storageStatus = _string(row, ['status']) ?? '';
    if (storageStatus.toLowerCase() == 'uploaded') {
      return DriveItemStatus.processing;
    }
    return _statusFromText(storageStatus);
  }

  DriveFileKind _kindFromRow(Map<String, dynamic> row) {
    final candidates = [
      _string(row, ['file_type']),
      _string(row, ['mime_type', 'content_type']),
      _string(row, ['original_filename', 'file_name', 'filename', 'title']),
    ].whereType<String>();
    for (final candidate in candidates) {
      final kind = _kindFromText(candidate);
      if (kind != null) return kind;
    }
    return DriveFileKind.docx;
  }

  DriveFileKind? _kindFromText(String text) {
    final normalized = text.trim().toLowerCase();
    switch (normalized) {
      case 'pdf':
      case 'application/pdf':
        return DriveFileKind.pdf;
      case 'ppt':
      case 'application/vnd.ms-powerpoint':
        return DriveFileKind.ppt;
      case 'pptx':
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return DriveFileKind.pptx;
      case 'doc':
      case 'application/msword':
        return DriveFileKind.doc;
      case 'docx':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return DriveFileKind.docx;
      case 'zip':
      case 'application/zip':
      case 'application/x-zip-compressed':
        return DriveFileKind.zip;
    }
    final match = RegExp(r'\.([a-z0-9]+)$').firstMatch(normalized);
    if (match != null) return _kindFromText(match.group(1)!);
    return null;
  }

  String _pageLabel(
    DriveFileKind kind,
    DriveItemStatus status,
    int pageCount,
    int slideCount,
  ) {
    if (kind == DriveFileKind.ppt || kind == DriveFileKind.pptx) {
      final count = slideCount > 0 ? slideCount : pageCount;
      if (count > 0) return '$count slayt';
      return switch (status) {
        DriveItemStatus.completed => 'Slayt bilgisi yok',
        DriveItemStatus.processing => 'Slaytlar işleniyor',
        DriveItemStatus.uploading => 'Yükleniyor',
        DriveItemStatus.failed => 'Slaytlar okunamadı',
        DriveItemStatus.draft => 'Beklemede',
      };
    }
    if (pageCount > 0) return '$pageCount sayfa';
    return switch (status) {
      DriveItemStatus.completed => 'Sayfa bilgisi yok',
      DriveItemStatus.processing => 'İşleniyor',
      DriveItemStatus.uploading => 'Yükleniyor',
      DriveItemStatus.failed => 'İşlenemedi',
      DriveItemStatus.draft => 'Beklemede',
    };
  }

  String? _fileStatusMessage(
    Map<String, dynamic> row,
    DriveFileKind kind,
    DriveItemStatus status,
    int sizeBytes,
  ) {
    if (status == DriveItemStatus.completed) return 'Kaynak üretime hazır.';
    if (sizeBytes <= 0) {
      return 'Dosya boş görünüyor. 0 KB dosyalar kaynak olarak kullanılamaz.';
    }
    if (status == DriveItemStatus.processing) {
      return kind == DriveFileKind.ppt || kind == DriveFileKind.pptx
          ? 'Slayt metinleri çıkarılıyor. İşlem tamamlanınca üretim için kullanılabilir.'
          : 'Dosya metni çıkarılıyor. İşlem tamamlanınca üretim için kullanılabilir.';
    }
    if (status == DriveItemStatus.uploading) {
      return 'Yükleme devam ediyor. Tamamlanmadan üretim başlatılamaz.';
    }
    if (status == DriveItemStatus.draft) {
      return 'Kaynak henüz üretime hazır değil.';
    }
    final metadata = _metadata(row);
    final message = _string(metadata, [
      'extractionError',
      'extraction_error',
      'errorMessage',
      'error_message',
      'parseError',
      'parse_error',
      'reason',
    ]);
    final code = _string(metadata, [
      'extractionErrorCode',
      'extraction_error_code',
      'errorCode',
      'error_code',
    ]);
    final lower = '${code ?? ''} ${message ?? ''}'.toLowerCase();
    if (lower.contains('encrypt') ||
        lower.contains('password') ||
        lower.contains('protected') ||
        lower.contains('şifre') ||
        lower.contains('sifre') ||
        lower.contains('parola')) {
      return 'Bu dosya şifreli görünüyor. Korumasını kaldırıp tekrar yükleyebilirsin.';
    }
    if (lower.contains('corrupt') ||
        lower.contains('damaged') ||
        lower.contains('bozuk') ||
        lower.contains('unreadable')) {
      return 'Dosya bozuk ya da okunamıyor. Dosyayı yeniden kaydedip tekrar yükleyebilirsin.';
    }
    if (lower.contains('scanned') ||
        lower.contains('ocr') ||
        lower.contains('no text') ||
        lower.contains('taran') ||
        lower.contains('metin bulunamad')) {
      return 'Bu PDF taranmış/görsel tabanlı görünüyor. Metin çıkarılamadı; OCR desteği gerekir.';
    }
    if (message?.isNotEmpty == true) return message;
    return 'Dosya işlenemedi. Dosyayı kontrol edip tekrar yükleyebilirsin.';
  }

  double _normalizedProgress(double? raw, DriveItemStatus status) {
    if (raw != null) {
      final progress = raw > 1 ? raw / 100 : raw;
      return min(max(progress, 0), 1);
    }
    return switch (status) {
      DriveItemStatus.completed => 1,
      DriveItemStatus.failed => 1,
      DriveItemStatus.uploading => 0.35,
      DriveItemStatus.processing => 0.65,
      DriveItemStatus.draft => 0.05,
    };
  }

  String _sizeLabel(int bytes) {
    if (bytes <= 0) return '-';
    final mb = bytes / (1024.0 * 1024.0);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${max(1, bytes ~/ 1024)} KB';
  }

  String _dateLabel(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? 'Bugün' : raw;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    if (date == today) return 'Bugün';
    if (date == today.subtract(const Duration(days: 1))) return 'Dün';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _outputDetail(
    String rawType,
    String status,
    int itemCount,
    Map<String, dynamic>? content,
  ) {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus == 'failed' || normalizedStatus == 'error') {
      return 'Üretim tamamlanamadı';
    }
    final preview = _contentPreview(content);
    if (itemCount > 0 && preview.isNotEmpty) return '$itemCount öğe • $preview';
    if (itemCount > 0) return '$itemCount öğe';
    if (preview.isNotEmpty) return preview;
    if (normalizedStatus == 'ready' || normalizedStatus == 'completed') {
      return 'Sonuç oluşturuldu';
    }
    return 'Sonuç oluşturuldu ancak bu görünüm henüz desteklenmiyor.';
  }

  String? _contentText(Map<String, dynamic>? content) {
    if (content == null) return null;
    final text = _readableContent(content).trim();
    return text.isEmpty ? null : text;
  }

  String _contentPreview(Map<String, dynamic>? content) {
    final text = _readableContent(content)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return '';
    return text.length > 120 ? '${text.substring(0, 120)}...' : text;
  }

  String _readableContent(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return value.map(_readableContent).where((e) => e.trim().isNotEmpty).join('\n');
    }
    if (value is Map) {
      return value.entries
          .map((entry) {
            final child = _readableContent(entry.value).trim();
            if (child.isEmpty) return '';
            return '${_label(entry.key.toString())}: $child';
          })
          .where((e) => e.isNotEmpty)
          .join('\n');
    }
    return value.toString();
  }

  String _label(String key) {
    final replacements = {
      'fullText': 'Metin',
      'must_know': 'Mutlaka Bil',
      'commonly_confused': 'Sık Karışanlar',
      'clinical_tus_tips': 'Klinik İpuçları',
      'self_check': 'Kontrol',
      'front': 'Ön',
      'back': 'Arka',
    };
    return replacements[key] ??
        key.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  int _contentItemCount(Map<String, dynamic> content) {
    for (final key in [
      'cards',
      'flashcards',
      'questions',
      'items',
      'sections',
      'steps',
      'branches',
      'segments',
      'days',
    ]) {
      final value = content[key];
      if (value is List && value.isNotEmpty) return value.length;
    }
    return 1;
  }

  Map<String, String> _documentProcessingPolicy(String fileName, String contentType) {
    final normalized = '$fileName $contentType'.toLowerCase();
    final isDocument = [
      '.pdf',
      'application/pdf',
      '.ppt',
      '.pptx',
      'presentation',
      '.doc',
      '.docx',
      'wordprocessing',
      'msword',
    ].any(normalized.contains);
    if (!isDocument) return const {};
    const extraction =
        'extract_all_pages_slides_and_doc_sections_preserve_page_numbers_headings_tables_figures';
    const ocr =
        'run_ocr_when_pdf_or_slide_page_is_scanned_image_based_or_low_text_density';
    const readiness =
        'do_not_mark_ready_until_text_or_ocr_text_is_available_or_explicit_failure_is_returned';
    return const {
      'extractionPolicy': extraction,
      'extraction_policy': extraction,
      'ocrPolicy': ocr,
      'ocr_policy': ocr,
      'ocrRequiredWhenSparse': 'true',
      'ocr_required_when_sparse': 'true',
      'ocrLanguageHints': 'tr,en,medical',
      'ocr_language_hints': 'tr,en,medical',
      'documentReadinessPolicy': readiness,
      'document_readiness_policy': readiness,
      'largeDocumentExtractionPolicy':
          'chunk_extract_then_index_full_document_not_first_pages_only',
      'large_document_extraction_policy':
          'chunk_extract_then_index_full_document_not_first_pages_only',
    };
  }

  Map<String, String> _generationOptions(
    String jobType,
    Map<String, String>? options,
  ) {
    final clean = <String, String>{};
    for (final entry in (options ?? const <String, String>{}).entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isNotEmpty && value.isNotEmpty) clean[key] = value;
    }
    final requestedTier =
        clean['qualityTier'] ?? clean['quality_tier'] ?? 'premium';
    final tier = _normalizeQualityTier(requestedTier);
    clean['qualityTier'] = tier;
    clean['quality_tier'] = tier;
    clean['generationQualityProfile'] =
        tier == 'economy'
            ? 'sourcebase_premium_efficient_generation_v3'
            : tier == 'standard'
                ? 'sourcebase_premium_balanced_generation_v3'
                : 'sourcebase_premium_plus_generation_v3';
    clean['generation_quality_profile'] = clean['generationQualityProfile']!;
    clean['sourceGroundingPolicy'] =
        'strict_source_grounded_mark_source_gap_no_fabrication';
    clean['source_grounding_policy'] = clean['sourceGroundingPolicy']!;
    clean['sourceReadPolicy'] = 'read_full_extracted_document_not_first_excerpt';
    clean['source_read_policy'] = clean['sourceReadPolicy']!;
    clean['sourceChunkPolicy'] =
        'adaptive_full_document_chunk_map_reduce_for_long_sources';
    clean['source_chunk_policy'] = clean['sourceChunkPolicy']!;
    clean['clinicalSafetyPolicy'] =
        'educational_not_diagnostic_warn_on_uncertain_or_unsafe_claims';
    clean['clinical_safety_policy'] = clean['clinicalSafetyPolicy']!;
    clean['languagePolicy'] = 'clear_turkish_medical_student_level_no_filler';
    clean['language_policy'] = clean['languagePolicy']!;
    clean['resultRouteContract'] =
        'create_or_reuse_generated_output_then_route_to_study_output';
    clean['result_route_contract'] = clean['resultRouteContract']!;
    clean['finalQualityReview'] =
        'verify_not_plain_text_verify_schema_fields_verify_source_grounding_verify_mobile_renderability';
    clean['final_quality_review'] = clean['finalQualityReview']!;
    if (jobType == 'podcast') {
      clean['audioAssetRequired'] = clean['audioAssetRequired'] ?? 'true';
      clean['audio_asset_required'] = clean['audio_asset_required'] ?? 'true';
    }
    if (jobType == 'infographic') {
      clean['visualAssetRequired'] = clean['visualAssetRequired'] ?? 'true';
      clean['visual_asset_required'] = clean['visual_asset_required'] ?? 'true';
    }
    return clean;
  }

  String _normalizeQualityTier(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('economy') ||
        lower.contains('economic') ||
        lower.contains('ekonomik') ||
        lower.contains('ucuz')) {
      return 'economy';
    }
    if (lower.contains('standard') || lower.contains('standart')) {
      return 'standard';
    }
    return 'premium';
  }
}
