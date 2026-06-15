import 'dart:convert';
import 'dart:typed_data';

enum SBUploadPhase {
  idle,
  selecting,
  extracting,
  uploading,
  completing,
  success,
  error;

  String get message {
    switch (this) {
      case SBUploadPhase.idle:
        return "Yükleme beklemede.";
      case SBUploadPhase.selecting:
        return "Dosya seçiliyor...";
      case SBUploadPhase.extracting:
        return "Metin çıkarılıyor...";
      case SBUploadPhase.uploading:
        return "Dosya güvenli şekilde yükleniyor.";
      case SBUploadPhase.completing:
        return "Kaynak Drive alanına ekleniyor.";
      case SBUploadPhase.success:
        return "Dosya Drive alanına eklendi.";
      case SBUploadPhase.error:
        return "Yükleme tamamlanamadı. Tekrar deneyebilirsin.";
    }
  }
}

enum DriveFileKind {
  pdf,
  pptx,
  docx,
  ppt,
  doc,
  zip;

  static DriveFileKind fromString(String value) {
    return DriveFileKind.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => DriveFileKind.pdf,
    );
  }
}

enum DriveItemStatus {
  completed,
  processing,
  uploading,
  failed,
  draft;

  static DriveItemStatus fromString(String value) {
    return DriveItemStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => DriveItemStatus.draft,
    );
  }
}

enum GenerationJobPhase {
  queued,
  running,
  completed,
  failed;

  static GenerationJobPhase fromRawStatus(String rawStatus) {
    final normalized = rawStatus
        .trim()
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .toLowerCase();

    switch (normalized) {
      case "completed":
      case "complete":
      case "ready":
      case "succeeded":
      case "success":
      case "done":
      case "finished":
      case "processed":
      case "generated":
        return GenerationJobPhase.completed;
      case "failed":
      case "error":
      case "errored":
      case "cancelled":
      case "canceled":
      case "timeout":
      case "timed_out":
      case "expired":
        return GenerationJobPhase.failed;
      case "queued":
      case "pending":
      case "draft":
      case "created":
      case "scheduled":
      case "waiting":
        return GenerationJobPhase.queued;
      default:
        return GenerationJobPhase.running;
    }
  }

  bool get isActive =>
      this == GenerationJobPhase.queued || this == GenerationJobPhase.running;

  DriveItemStatus get driveStatus {
    switch (this) {
      case GenerationJobPhase.completed:
        return DriveItemStatus.completed;
      case GenerationJobPhase.failed:
        return DriveItemStatus.failed;
      case GenerationJobPhase.queued:
        return DriveItemStatus.draft;
      case GenerationJobPhase.running:
        return DriveItemStatus.processing;
    }
  }
}

enum GeneratedKind {
  flashcard,
  question,
  summary,
  examMorningSummary,
  algorithm,
  comparison,
  clinicalScenario,
  learningPlan,
  podcast,
  table,
  infographic,
  mindMap;

  static GeneratedKind fromString(String value) {
    final normalized = value.trim().replaceAll('-', '_').replaceAll(' ', '_').toLowerCase();
    switch (normalized) {
      case "flashcard": return GeneratedKind.flashcard;
      case "question":
      case "quiz":
        return GeneratedKind.question;
      case "summary": return GeneratedKind.summary;
      case "exam_morning_summary": return GeneratedKind.examMorningSummary;
      case "algorithm": return GeneratedKind.algorithm;
      case "comparison": return GeneratedKind.comparison;
      case "clinical_scenario": return GeneratedKind.clinicalScenario;
      case "learning_plan": return GeneratedKind.learningPlan;
      case "podcast": return GeneratedKind.podcast;
      case "table": return GeneratedKind.table;
      case "infographic": return GeneratedKind.infographic;
      case "mindmap":
      case "mind_map":
        return GeneratedKind.mindMap;
      default: return GeneratedKind.summary;
    }
  }

  String get rawValue {
    switch (this) {
      case GeneratedKind.flashcard: return "flashcard";
      case GeneratedKind.question: return "question";
      case GeneratedKind.summary: return "summary";
      case GeneratedKind.examMorningSummary: return "exam_morning_summary";
      case GeneratedKind.algorithm: return "algorithm";
      case GeneratedKind.comparison: return "comparison";
      case GeneratedKind.clinicalScenario: return "clinical_scenario";
      case GeneratedKind.learningPlan: return "learning_plan";
      case GeneratedKind.podcast: return "podcast";
      case GeneratedKind.table: return "table";
      case GeneratedKind.infographic: return "infographic";
      case GeneratedKind.mindMap: return "mindMap";
    }
  }

  String? get jobType {
    switch (this) {
      case GeneratedKind.flashcard: return "flashcard";
      case GeneratedKind.question: return "quiz";
      case GeneratedKind.summary: return "summary";
      case GeneratedKind.examMorningSummary: return "exam_morning_summary";
      case GeneratedKind.algorithm: return "algorithm";
      case GeneratedKind.comparison:
      case GeneratedKind.table:
        return "comparison";
      case GeneratedKind.clinicalScenario: return "clinical_scenario";
      case GeneratedKind.learningPlan: return "learning_plan";
      case GeneratedKind.podcast: return "podcast";
      case GeneratedKind.infographic: return "infographic";
      case GeneratedKind.mindMap: return "mind_map";
    }
  }

  int? get defaultCount {
    switch (this) {
      case GeneratedKind.flashcard: return 20;
      case GeneratedKind.question: return 10;
      case GeneratedKind.clinicalScenario:
      case GeneratedKind.examMorningSummary:
      case GeneratedKind.learningPlan:
      case GeneratedKind.mindMap:
        return 1;
      default: return null;
    }
  }

  String get titleLabel {
    switch (this) {
      case GeneratedKind.flashcard: return "Flashcard Seti";
      case GeneratedKind.question: return "Soru Seti";
      case GeneratedKind.summary: return "Özet";
      case GeneratedKind.examMorningSummary: return "Sınav Sabahı Özeti";
      case GeneratedKind.algorithm: return "Algoritma";
      case GeneratedKind.comparison: return "Karşılaştırma";
      case GeneratedKind.clinicalScenario: return "Klinik Senaryo";
      case GeneratedKind.learningPlan: return "Öğrenme Planı";
      case GeneratedKind.podcast: return "Podcast";
      case GeneratedKind.table: return "Tablo";
      case GeneratedKind.infographic: return "İnfografik";
      case GeneratedKind.mindMap: return "Zihin Haritası";
    }
  }
}

class ExtractionMetadata {
  final int charCount;
  final int wordCount;
  final DateTime extractedAt;

  ExtractionMetadata({
    required this.charCount,
    required this.wordCount,
    required this.extractedAt,
  });

  factory ExtractionMetadata.fromJson(Map<String, dynamic> json) {
    return ExtractionMetadata(
      charCount: json['charCount'] ?? json['char_count'] ?? 0,
      wordCount: json['wordCount'] ?? json['word_count'] ?? 0,
      extractedAt: DateTime.tryParse(json['extractedAt'] ?? json['extracted_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'charCount': charCount,
        'wordCount': wordCount,
        'extractedAt': extractedAt.toIso8601String(),
      };
}

class DriveWorkspaceData {
  final List<DriveCourse> courses;
  final List<DriveFile> recentFiles;
  final List<UploadTask> uploads;
  final List<CollectionBundle> collections;

  DriveWorkspaceData({
    required this.courses,
    required this.recentFiles,
    required this.uploads,
    required this.collections,
  });

  factory DriveWorkspaceData.fromJson(Map<String, dynamic> json) {
    return DriveWorkspaceData(
      courses: (json['courses'] as List?)?.map((e) => DriveCourse.fromJson(e)).toList() ?? [],
      recentFiles: (json['recentFiles'] as List?)?.map((e) => DriveFile.fromJson(e)).toList() ?? [],
      uploads: (json['uploads'] as List?)?.map((e) => UploadTask.fromJson(e)).toList() ?? [],
      collections: (json['collections'] as List?)?.map((e) => CollectionBundle.fromJson(e)).toList() ?? [],
    );
  }

  static final empty = DriveWorkspaceData(
    courses: [],
    recentFiles: [],
    uploads: [],
    collections: [],
  );

  DriveCourse? get primaryCourse => courses.isNotEmpty ? courses.first : null;
  DriveSection? get primarySection => primaryCourse != null && primaryCourse!.sections.isNotEmpty ? primaryCourse!.sections.first : null;
  DriveFile? get primaryFile => primarySection != null && primarySection!.files.isNotEmpty ? primarySection!.files.first : null;
}

class DriveDestination {
  final String courseId;
  final String sectionId;
  final String courseTitle;
  final String sectionTitle;

  DriveDestination({
    required this.courseId,
    required this.sectionId,
    required this.courseTitle,
    required this.sectionTitle,
  });

  bool get isUsable => courseId.trim().isNotEmpty && sectionId.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriveDestination &&
          runtimeType == other.runtimeType &&
          courseId == other.courseId &&
          sectionId == other.sectionId;

  @override
  int get hashCode => courseId.hashCode ^ sectionId.hashCode;
}

class DriveCourse {
  final String id;
  final String title;
  final String iconName;
  final String iconColorHex;
  final String iconBackgroundHex;
  final DriveItemStatus status;
  final List<DriveSection> sections;
  final String updatedLabel;
  final String description;

  DriveCourse({
    required this.id,
    required this.title,
    required this.iconName,
    required this.iconColorHex,
    required this.iconBackgroundHex,
    required this.status,
    required this.sections,
    required this.updatedLabel,
    required this.description,
  });

  factory DriveCourse.fromJson(Map<String, dynamic> json) {
    return DriveCourse(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      iconName: json['iconName'] ?? json['icon_name'] ?? 'folder',
      iconColorHex: json['iconColorHex'] ?? json['icon_color_hex'] ?? '#0A5BFF',
      iconBackgroundHex: json['iconBackgroundHex'] ?? json['icon_background_hex'] ?? '#EAF3FF',
      status: DriveItemStatus.fromString(json['status'] ?? 'completed'),
      sections: (json['sections'] as List?)?.map((e) => DriveSection.fromJson(e)).toList() ?? [],
      updatedLabel: json['updatedLabel'] ?? json['updated_label'] ?? '',
      description: json['description'] ?? '',
    );
  }

  int get fileCount => sections.fold(0, (sum, item) => sum + item.files.length);
}

class DriveSection {
  final String id;
  final String title;
  final DriveItemStatus status;
  final List<DriveFile> files;
  final List<GeneratedOutput> savedOutputs;
  final String iconName;
  final String iconColorHex;

  DriveSection({
    required this.id,
    required this.title,
    required this.status,
    required this.files,
    required this.savedOutputs,
    required this.iconName,
    required this.iconColorHex,
  });

  factory DriveSection.fromJson(Map<String, dynamic> json) {
    return DriveSection(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      status: DriveItemStatus.fromString(json['status'] ?? 'completed'),
      files: (json['files'] as List?)?.map((e) => DriveFile.fromJson(e)).toList() ?? [],
      savedOutputs: (json['savedOutputs'] as List?)?.map((e) => GeneratedOutput.fromJson(e)).toList() ?? [],
      iconName: json['iconName'] ?? json['icon_name'] ?? 'folder',
      iconColorHex: json['iconColorHex'] ?? json['icon_color_hex'] ?? '#0A5BFF',
    );
  }
}

class DriveFile {
  final String id;
  final String title;
  final DriveFileKind kind;
  final String sizeLabel;
  final String pageLabel;
  final String updatedLabel;
  final String courseTitle;
  final String sectionTitle;
  final DriveItemStatus status;
  final String? statusMessage;
  final String? tag;
  final bool featured;
  final bool selected;
  final List<GeneratedOutput> generated;

  DriveFile({
    required this.id,
    required this.title,
    required this.kind,
    required this.sizeLabel,
    required this.pageLabel,
    required this.updatedLabel,
    required this.courseTitle,
    required this.sectionTitle,
    required this.status,
    this.statusMessage,
    this.tag,
    required this.featured,
    required this.selected,
    required this.generated,
  });

  factory DriveFile.fromJson(Map<String, dynamic> json) {
    return DriveFile(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      kind: DriveFileKind.fromString(json['kind'] ?? 'pdf'),
      sizeLabel: json['sizeLabel'] ?? json['size_label'] ?? '',
      pageLabel: json['pageLabel'] ?? json['page_label'] ?? '',
      updatedLabel: json['updatedLabel'] ?? json['updated_label'] ?? '',
      courseTitle: json['courseTitle'] ?? json['course_title'] ?? '',
      sectionTitle: json['sectionTitle'] ?? json['section_title'] ?? '',
      status: DriveItemStatus.fromString(json['status'] ?? 'completed'),
      statusMessage: json['statusMessage'] ?? json['status_message'],
      tag: json['tag'],
      featured: json['featured'] ?? false,
      selected: json['selected'] ?? false,
      generated: (json['generated'] as List?)?.map((e) => GeneratedOutput.fromJson(e)).toList() ?? [],
    );
  }

  bool get isReadyForGeneration => status == DriveItemStatus.completed;
}

class GeneratedOutput {
  final String id;
  final String sourceFileId;
  final GeneratedKind kind;
  final String rawType;
  final String title;
  final String detail;
  final Map<String, dynamic>? content;
  final String? contentText;
  final String updatedLabel;
  final String status;
  final int itemCount;
  final String? jobId;

  GeneratedOutput({
    required this.id,
    required this.sourceFileId,
    required this.kind,
    required this.rawType,
    required this.title,
    required this.detail,
    this.content,
    this.contentText,
    required this.updatedLabel,
    required this.status,
    required this.itemCount,
    this.jobId,
  });

  factory GeneratedOutput.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedContent;
    if (json['content'] != null) {
      if (json['content'] is Map) {
        parsedContent = Map<String, dynamic>.from(json['content']);
      } else if (json['content'] is String) {
        try {
          parsedContent = Map<String, dynamic>.from(jsonDecode(json['content']));
        } catch (_) {}
      }
    }
    return GeneratedOutput(
      id: json['id'] ?? '',
      sourceFileId: json['sourceFileId'] ?? json['source_file_id'] ?? '',
      kind: GeneratedKind.fromString(json['kind'] ?? 'summary'),
      rawType: json['rawType'] ?? json['raw_type'] ?? '',
      title: json['title'] ?? '',
      detail: json['detail'] ?? '',
      content: parsedContent,
      contentText: json['contentText'] ?? json['content_text'],
      updatedLabel: json['updatedLabel'] ?? json['updated_label'] ?? '',
      status: json['status'] ?? '',
      itemCount: json['itemCount'] ?? json['item_count'] ?? 0,
      jobId: json['jobId'] ?? json['job_id'],
    );
  }

  bool get isReady => GenerationJobPhase.fromRawStatus(status) == GenerationJobPhase.completed;
}

class UploadTask {
  final DriveFile file;
  final DriveItemStatus status;
  final double progress;
  final String? errorLabel;

  UploadTask({
    required this.file,
    required this.status,
    required this.progress,
    this.errorLabel,
  });

  factory UploadTask.fromJson(Map<String, dynamic> json) {
    return UploadTask(
      file: DriveFile.fromJson(json['file']),
      status: DriveItemStatus.fromString(json['status'] ?? 'completed'),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      errorLabel: json['errorLabel'] ?? json['error_label'],
    );
  }
}

class CollectionBundle {
  final DriveFile file;
  final List<GeneratedOutput> outputs;
  final String subject;
  final GeneratedKind previewKind;

  CollectionBundle({
    required this.file,
    required this.outputs,
    required this.subject,
    required this.previewKind,
  });

  factory CollectionBundle.fromJson(Map<String, dynamic> json) {
    return CollectionBundle(
      file: DriveFile.fromJson(json['file']),
      outputs: (json['outputs'] as List?)?.map((e) => GeneratedOutput.fromJson(e)).toList() ?? [],
      subject: json['subject'] ?? '',
      previewKind: GeneratedKind.fromString(json['previewKind'] ?? json['preview_kind'] ?? 'summary'),
    );
  }
}

class SBStoragePlan {
  final String productCode;
  final int bonusBytes;
  final String? expiresAt;

  SBStoragePlan({
    required this.productCode,
    required this.bonusBytes,
    this.expiresAt,
  });

  factory SBStoragePlan.fromJson(Map<String, dynamic> json) {
    return SBStoragePlan(
      productCode: json['productCode'] ?? json['product_code'] ?? '',
      bonusBytes: json['bonusBytes'] ?? json['bonus_bytes'] ?? 0,
      expiresAt: json['expiresAt'] ?? json['expires_at'],
    );
  }

  String get id => "$productCode-${expiresAt ?? ''}";
}

class SBStorageStatus {
  final int usedBytes;
  final int baseBytes;
  final int bonusBytes;
  final int totalBytes;
  final List<SBStoragePlan> plans;

  SBStorageStatus({
    required this.usedBytes,
    required this.baseBytes,
    required this.bonusBytes,
    required this.totalBytes,
    required this.plans,
  });

  factory SBStorageStatus.fromJson(Map<String, dynamic> json) {
    return SBStorageStatus(
      usedBytes: json['usedBytes'] ?? json['used_bytes'] ?? 0,
      baseBytes: json['baseBytes'] ?? json['base_bytes'] ?? 0,
      bonusBytes: json['bonusBytes'] ?? json['bonus_bytes'] ?? 0,
      totalBytes: json['totalBytes'] ?? json['total_bytes'] ?? 0,
      plans: (json['plans'] as List?)?.map((e) => SBStoragePlan.fromJson(e)).toList() ?? [],
    );
  }

  static final empty = SBStorageStatus(
    usedBytes: 0,
    baseBytes: 0,
    bonusBytes: 0,
    totalBytes: 0,
    plans: [],
  );

  int get availableBytes => (totalBytes - usedBytes) < 0 ? 0 : totalBytes - usedBytes;
  double get usedFraction => totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  bool get isNearlyFull => usedFraction >= 0.9;
  bool get isOverQuota => totalBytes > 0 && usedBytes > totalBytes;
}

class SBGenerationJob {
  final String id;
  final String sourceFileId;
  final String sourceTitle;
  final GeneratedKind kind;
  final String status; // 'queued', 'running', 'completed', 'failed'
  final double progress;
  final GeneratedOutput? output;
  final String? outputId;

  SBGenerationJob({
    required this.id,
    required this.sourceFileId,
    required this.sourceTitle,
    required this.kind,
    required this.status,
    required this.progress,
    this.output,
    this.outputId,
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running';
  bool get isQueued => status == 'queued';
}

class GenerationJobSnapshot {
  final String id;
  final String sourceFileId;
  final String sourceTitle;
  final GeneratedKind kind;
  final String status;
  final double progress;
  final String? errorMessage;
  final String? outputId;
  final String? jobId;

  GenerationJobSnapshot({
    required this.id,
    required this.sourceFileId,
    required this.sourceTitle,
    required this.kind,
    required this.status,
    required this.progress,
    this.errorMessage,
    this.outputId,
    this.jobId,
  });

  GenerationJobPhase get phase => GenerationJobPhase.fromRawStatus(status);
}

class StorageUploadSession {
  final String uploadUrl;
  final String objectName;
  final String bucket;
  final Map<String, String> headers;
  final DateTime expiresAt;

  StorageUploadSession({
    required this.uploadUrl,
    required this.objectName,
    required this.bucket,
    required this.headers,
    required this.expiresAt,
  });

  factory StorageUploadSession.fromJson(Map<String, dynamic> json) {
    final headers = json['headers'] is Map
        ? Map<String, String>.from((json['headers'] as Map)
            .map((key, value) => MapEntry(key.toString(), value.toString())))
        : <String, String>{};
    return StorageUploadSession(
      uploadUrl: json['uploadUrl']?.toString() ??
          json['upload_url']?.toString() ??
          '',
      objectName: json['objectName']?.toString() ??
          json['object_name']?.toString() ??
          '',
      bucket: json['bucket']?.toString() ?? '',
      headers: headers,
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ??
              json['expires_at']?.toString() ??
              '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isUsable =>
      uploadUrl.trim().isNotEmpty &&
      objectName.trim().isNotEmpty &&
      expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 45)));
}

class PickedDriveFile {
  final String name;
  final String path;
  final int sizeBytes;
  final String contentType;
  final Uint8List? bytes;

  PickedDriveFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.contentType,
    this.bytes,
  });

  bool get hasSupportedExtension {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.zip');
  }

  bool get hasReadableContent => sizeBytes > 0;
}
