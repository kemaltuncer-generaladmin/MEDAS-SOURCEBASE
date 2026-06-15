import Foundation
import Supabase

public struct RepositoryError: Error, Sendable {
    public let message: String
}

enum DriveFileMapping {
    static func kind(from row: [String: AnyJSON]) -> DriveFileKind {
        let candidates = [
            row.stringValue(for: "file_type"),
            row.stringValue(for: "mime_type"),
            row.stringValue(for: "content_type"),
            row.stringValue(for: "original_filename"),
            row.stringValue(for: "file_name"),
            row.stringValue(for: "filename"),
            row.stringValue(for: "title")
        ].compactMap { $0 }

        for candidate in candidates {
            if let kind = kind(from: candidate) { return kind }
        }
        return .docx
    }

    static func kind(from text: String) -> DriveFileKind? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "pdf", "application/pdf":
            return .pdf
        case "ppt", "application/vnd.ms-powerpoint":
            return .ppt
        case "pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return .pptx
        case "doc", "application/msword":
            return .doc
        case "docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return .docx
        case "zip", "application/zip", "application/x-zip-compressed":
            return .zip
        default:
            let ext = DriveUploadService.normalizedExtension(normalized)
            if !ext.isEmpty, ext != normalized {
                return kind(from: ext)
            }
            return nil
        }
    }

    static func pageLabel(
        kind: DriveFileKind,
        status: DriveItemStatus,
        pageCount: Int,
        slideCount: Int
    ) -> String {
        if kind == .ppt || kind == .pptx {
            let count = slideCount > 0 ? slideCount : pageCount
            if count > 0 { return "\(count) slayt" }
            switch status {
            case .completed: return "Slayt bilgisi yok"
            case .processing: return "Slaytlar işleniyor"
            case .uploading: return "Yükleniyor"
            case .failed: return "Slaytlar okunamadı"
            case .draft: return "Beklemede"
            }
        }

        if pageCount > 0 { return "\(pageCount) sayfa" }
        switch status {
        case .completed: return "Sayfa bilgisi yok"
        case .processing: return "İşleniyor"
        case .uploading: return "Yükleniyor"
        case .failed: return "İşlenemedi"
        case .draft: return "Beklemede"
        }
    }

    static func statusMessage(
        row: [String: AnyJSON],
        kind: DriveFileKind,
        status: DriveItemStatus,
        sizeBytes: Int
    ) -> String? {
        if status == .completed { return "Kaynak üretime hazır." }
        if sizeBytes <= 0 { return "Dosya boş görünüyor. 0 KB dosyalar kaynak olarak kullanılamaz." }
        if status == .processing {
            if kind == .ppt || kind == .pptx {
                return "Slayt metinleri çıkarılıyor. İşlem tamamlanınca üretim için kullanılabilir."
            }
            return "Dosya metni çıkarılıyor. İşlem tamamlanınca üretim için kullanılabilir."
        }
        if status == .uploading { return "Yükleme devam ediyor. Tamamlanmadan üretim başlatılamaz." }
        if status == .draft { return "Kaynak henüz üretime hazır değil." }
        guard status == .failed else { return nil }

        let metadata = row["metadata"]?.dictValue ?? [:]
        let code = firstText(
            metadata,
            keys: ["extractionErrorCode", "extraction_error_code", "errorCode", "error_code", "parseErrorCode", "parse_error_code"]
        ).uppercased()
        let message = firstText(
            metadata,
            keys: ["extractionError", "extraction_error", "errorMessage", "error_message", "parseError", "parse_error", "reason"]
        )
        let lower = "\(code) \(message)".lowercased()

        if lower.contains("encrypt") || lower.contains("password") || lower.contains("protected")
            || lower.contains("şifre") || lower.contains("sifre") || lower.contains("parola") {
            if kind == .pdf {
                return "Bu PDF şifreli görünüyor. Şifre korumasını kaldırıp tekrar yükleyebilirsin."
            }
            return "Bu dosya şifreli görünüyor. Korumasını kaldırıp tekrar yükleyebilirsin."
        }
        if lower.contains("corrupt") || lower.contains("damaged") || lower.contains("malformed")
            || lower.contains("bozuk") || lower.contains("okunamıyor") || lower.contains("unreadable") {
            return "Dosya bozuk ya da okunamıyor. Dosyayı yeniden kaydedip tekrar yükleyebilirsin."
        }
        if lower.contains("scanned") || lower.contains("ocr") || lower.contains("no text")
            || lower.contains("taranmış") || lower.contains("taranmis") || lower.contains("metin bulunamad") {
            return "Bu PDF taranmış/görsel tabanlı görünüyor. Metin çıkarılamadı; OCR desteği gerekir."
        }
        if kind == .ppt || lower.contains("file_type_limited_support") && lower.contains("ppt") {
            return "Eski PPT dosyaları sınırlı desteklenir. Dosyayı PPTX olarak kaydedip tekrar yükleyebilirsin."
        }
        if kind == .doc || lower.contains("file_type_limited_support") && lower.contains("doc") {
            return "Eski DOC dosyaları sınırlı desteklenir. Dosyayı DOCX olarak kaydedip tekrar yükleyebilirsin."
        }
        if lower.contains("file_text_empty") {
            return "Dosyadan okunabilir metin çıkarılamadı. İçeriği kontrol edip tekrar yükleyebilirsin."
        }
        if lower.contains("file_type_unsupported") {
            return "Bu dosya türü desteklenmiyor. \(DriveUploadService.supportedExtensionsDisplay) yükleyebilirsin."
        }
        if lower.contains("file_object_missing") {
            return "Yüklenen dosya depolama alanında bulunamadı. Tekrar yükleyebilirsin."
        }
        if lower.contains("file_object_empty") {
            return "Yüklenen dosya boş görünüyor. Dolu bir dosya yükleyebilirsin."
        }
        if !message.isEmpty { return message }
        return "Dosya işlenemedi. Dosyayı kontrol edip tekrar yükleyebilirsin."
    }

    private static func firstText(_ row: [String: AnyJSON], keys: [String]) -> String {
        for key in keys {
            if let value = row.stringValue(for: key), !value.isEmpty { return value }
        }
        return ""
    }
}

public struct DriveRepository: Sendable {
    private let api: DriveAPI

    public init(api: DriveAPI) {
        self.api = api
    }

    // MARK: - Workspace

    public func loadWorkspace() async throws -> DriveWorkspaceData {
        let response = try await api.invoke("drive_bootstrap")
        guard case .object(let dataDict) = response["data"] else {
            throw RepositoryError(message: "Drive workspace response is empty.")
        }

        let rawCourses = dataDict["courses"]?.arrayValue ?? []
        let rawSections = dataDict["sections"]?.arrayValue ?? []
        let rawFiles = dataDict["files"]?.arrayValue ?? []
        let rawOutputs = dataDict["generatedOutputs"]?.arrayValue
            ?? dataDict["generated_outputs"]?.arrayValue
            ?? []
        let rawUploads = dataDict["uploads"]?.arrayValue
            ?? dataDict["uploadTasks"]?.arrayValue
            ?? dataDict["upload_tasks"]?.arrayValue
            ?? []

        let courseRows = rawCourses.compactMap { $0.dictValue }
        let sectionRows = rawSections.compactMap { $0.dictValue }
        let fileRows = rawFiles.compactMap { $0.dictValue }
        let outputRows = rawOutputs.compactMap { $0.dictValue }
        let uploadRows = rawUploads.compactMap { $0.dictValue }

        let courses: [DriveCourse]
        if courseRows.isEmpty, !fileRows.isEmpty {
            let files = fileRows.map {
                fileFromRow(
                    $0,
                    courseTitle: $0.stringValue(for: "course_title") ?? "Drive",
                    sectionTitle: $0.stringValue(for: "section_title") ?? "Kaynaklar",
                    allOutputs: outputRows
                )
            }
            courses = [
                DriveCourse(
                    id: "uncategorized",
                    title: "Drive",
                    iconName: "folder",
                    iconColorHex: "#0A5BFF",
                    iconBackgroundHex: "#EDF4FF",
                    status: .completed,
                    sections: [
                        DriveSection(
                            id: "uncategorized-section",
                            title: "Kaynaklar",
                            status: .completed,
                            files: files
                        )
                    ],
                    updatedLabel: "Bugün",
                    description: "Drive kaynakların burada listelenir."
                )
            ]
        } else {
            courses = courseRows.map { courseFromRow($0, allSections: sectionRows, allFiles: fileRows, allOutputs: outputRows) }
        }
        let allFiles = courses.flatMap { $0.sections.flatMap { $0.files } }
        let recent = Array(allFiles.prefix(5))

        let collections = allFiles
            .filter { !$0.generated.isEmpty }
            .map { file in
                CollectionBundle(
                    file: file,
                    outputs: file.generated,
                    subject: file.courseTitle,
                    previewKind: file.generated.first?.kind ?? .summary
                )
            }

        return DriveWorkspaceData(
            courses: courses,
            recentFiles: recent,
            uploads: uploadRows
                .map { uploadTaskFromRow($0, allFiles: allFiles, allOutputs: outputRows) }
                .sorted { $0.file.updatedLabel < $1.file.updatedLabel },
            collections: collections
        )
    }

    // MARK: - Upload

    public func createUploadSession(_ draft: DriveUploadDraft) async throws -> StorageUploadSession {
        let session = try await api.createUploadSession(draft)
        guard session.isUsable else {
            throw RepositoryError(message: "Yükleme bağlantısı alınamadı. Tekrar deneyebilirsin.")
        }
        return session
    }

    public func completeUpload(
        file: PickedDriveFile,
        objectName: String,
        courseId: String,
        sectionId: String,
        courseTitle: String,
        sectionTitle: String,
        extractedText: String? = nil,
        pageCount: Int? = nil,
        extractionMetadata: ExtractionMetadata? = nil
    ) async throws -> DriveFile {
        let response = try await api.completeUpload(
            objectName: objectName,
            courseId: courseId,
            sectionId: sectionId,
            fileName: file.name,
            contentType: file.contentType,
            sizeBytes: file.sizeBytes,
            extractedText: extractedText,
            pageCount: pageCount,
            extractionMetadata: extractionMetadata
        )
        guard let row = requiredDataRow(from: response, message: "Yüklenen dosya kaydı alınamadı.") else {
            throw RepositoryError(message: "Yüklenen dosya kaydı alınamadı.")
        }
        let uploaded = fileFromRow(row, courseTitle: courseTitle, sectionTitle: sectionTitle, allOutputs: [])
        if uploaded.status == .failed {
            throw RepositoryError(message: uploaded.statusMessage ?? "Dosya yüklendi ancak işleme kuyruğuna alınamadı.")
        }
        return uploaded
    }

    // MARK: - Course CRUD

    public func createCourse(
        _ title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> DriveCourse {
        let response = try await api.createCourse(title, iconName: iconName, colorHex: colorHex)
        guard let row = requiredDataRow(from: response, message: "Ders oluşturulamadı.") else {
            throw RepositoryError(message: "Ders oluşturulamadı.")
        }
        return courseFromRow(row, allSections: [], allFiles: [], allOutputs: [])
    }

    public func createSection(
        courseId: String,
        title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> DriveSection {
        let response = try await api.createSection(courseId: courseId, title: title, iconName: iconName, colorHex: colorHex)
        guard let row = requiredDataRow(from: response, message: "Bölüm oluşturulamadı.") else {
            throw RepositoryError(message: "Bölüm oluşturulamadı.")
        }
        return sectionFromRow(row, allFiles: [], courseTitle: nil, allOutputs: [])
    }

    public func renameCourse(courseId: String, title: String) async throws -> DriveCourse {
        let response = try await api.renameCourse(courseId: courseId, title: title)
        guard let row = requiredDataRow(from: response, message: "Ders yeniden adlandırılamadı.") else {
            throw RepositoryError(message: "Ders yeniden adlandırılamadı.")
        }
        return courseFromRow(row, allSections: [], allFiles: [], allOutputs: [])
    }

    public func renameSection(sectionId: String, title: String) async throws -> DriveSection {
        let response = try await api.renameSection(sectionId: sectionId, title: title)
        guard let row = requiredDataRow(from: response, message: "Bölüm yeniden adlandırılamadı.") else {
            throw RepositoryError(message: "Bölüm yeniden adlandırılamadı.")
        }
        return sectionFromRow(row, allFiles: [], courseTitle: nil, allOutputs: [])
    }

    public func deleteCourse(_ courseId: String) async throws {
        _ = try await api.deleteCourse(courseId)
    }

    public func deleteSection(_ sectionId: String) async throws {
        _ = try await api.deleteSection(sectionId)
    }

    // MARK: - File Actions

    public func renameFile(
        fileId: String,
        title: String,
        courseTitle: String = "",
        sectionTitle: String = ""
    ) async throws -> DriveFile? {
        let response = try await api.renameFile(fileId: fileId, title: title)
        guard let row = dataRow(from: response), !row.isEmpty else { return nil }
        return fileFromRow(
            row,
            courseTitle: row.stringValue(for: "course_title") ?? courseTitle,
            sectionTitle: row.stringValue(for: "section_title") ?? sectionTitle,
            allOutputs: []
        )
    }

    public func moveFiles(fileIds: [String], courseId: String, sectionId: String) async throws {
        guard !fileIds.isEmpty else { return }
        _ = try await api.moveFiles(fileIds: fileIds, courseId: courseId, sectionId: sectionId)
    }

    public func moveGeneratedOutput(outputId: String, courseId: String, sectionId: String) async throws {
        guard !outputId.isEmpty else { return }
        _ = try await api.moveGeneratedOutput(outputId: outputId, courseId: courseId, sectionId: sectionId)
    }

    public func deleteFiles(_ fileIds: [String]) async throws {
        guard !fileIds.isEmpty else { return }
        _ = try await api.deleteFiles(fileIds)
    }

    public func retryFileProcessing(_ fileId: String) async throws {
        _ = try await api.retryFileProcessing(fileId)
    }

    public func addToCollection(fileId: String, outputId: String? = nil, collection: String? = nil) async throws {
        _ = try await api.addToCollection(fileId: fileId, outputId: outputId, collection: collection)
    }

    // MARK: - Generation

    public func createGeneratedOutput(
        file: DriveFile,
        kind: GeneratedKind,
        options: [String: String]? = nil,
        sourceIds: [String]? = nil
    ) async throws -> GeneratedOutput {
        var itemCount: Int?
        var jobId: String?
        var generatedContent: AnyJSON?

        if let jobType = kind.jobType {
            let requestedCount = options?["count"].flatMap(Int.init) ?? kind.defaultCount
            let jobResponse = try await api.createGenerationJob(
                fileId: file.id,
                jobType: jobType,
                sourceIds: sourceIds,
                count: requestedCount,
                qualityTier: options?["qualityTier"],
                options: options
            )
            let dataDict = jobResponse["data"]?.dictValue
            jobId = dataDict?["jobId"]?.stringValue
            guard let jid = jobId, !jid.isEmpty else {
                throw RepositoryError(message: "Üretim işi başlatılamadı.")
            }
            try await processGenerationJobWithRecovery(jid)
            guard let content = try await waitForGeneratedContent(jobId: jid) else {
                throw RepositoryError(message: "Üretim tamamlandı ancak içerik alınamadı.")
            }
            generatedContent = content
            itemCount = contentItemCount(content)
        }

        let response = try await api.createGeneratedOutput(
            fileId: file.id,
            kind: kind,
            itemCount: itemCount,
            jobId: jobId
        )
        guard let row = requiredDataRow(from: response, message: "Üretilen içerik kaydı alınamadı.") else {
            throw RepositoryError(message: "Üretilen içerik kaydı alınamadı.")
        }
        return outputFromRow(row, contentOverride: generatedContent)
    }

    public func startGenerationJob(
        file: DriveFile,
        kind: GeneratedKind,
        options: [String: String]? = nil,
        sourceIds: [String]? = nil
    ) async throws -> GenerationJobSnapshot {
        guard let jobType = kind.jobType else {
            throw RepositoryError(message: "\(kind.titleLabel) için backend job type henüz aktif değil.")
        }

        let requestedCount = options?["count"].flatMap(Int.init) ?? kind.defaultCount
        let jobResponse = try await api.createGenerationJob(
            fileId: file.id,
            jobType: jobType,
            sourceIds: sourceIds,
            count: requestedCount,
            qualityTier: options?["qualityTier"],
            options: options
        )
        let dataDict = jobResponse["data"]?.dictValue
        let jobId = dataDict?["jobId"]?.stringValue
            ?? dataDict?["job_id"]?.stringValue
            ?? dataDict?["id"]?.stringValue
        guard let jobId, !jobId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError(message: "Üretim işi başlatılamadı.")
        }

        let rawStatus = dataDict?["status"]?.stringValue ?? "queued"
        let phase = GenerationJobPhase(rawStatus: rawStatus)
        let outputId = dataDict?["outputId"]?.stringValue
            ?? dataDict?["output_id"]?.stringValue
            ?? dataDict?["generatedOutputId"]?.stringValue
            ?? dataDict?["generated_output_id"]?.stringValue

        Task.detached(priority: .userInitiated) { [api] in
            do {
                try await Self.processGenerationJobWithRecovery(jobId, api: api)
            } catch {
                SBLog.drive.error("background generation process failed jobId=\(jobId, privacy: .public) error=\(String(describing: error), privacy: .private)")
            }
        }

        return GenerationJobSnapshot(
            id: jobId,
            sourceFileId: file.id,
            sourceTitle: file.title,
            kind: kind,
            status: phase.rawValue,
            progress: normalizedProgress(dataDict?["progress"]?.doubleValue, phase: phase),
            errorMessage: dataDict?["errorMessage"]?.stringValue ?? dataDict?["error_message"]?.stringValue,
            outputId: outputId,
            jobId: jobId
        )
    }

    public func finalizeGenerationJob(
        file: DriveFile,
        kind: GeneratedKind,
        jobId: String
    ) async throws -> GeneratedOutput? {
        guard let content = try await generatedContentIfReady(jobId: jobId) else {
            return nil
        }

        let response = try await api.createGeneratedOutput(
            fileId: file.id,
            kind: kind,
            itemCount: contentItemCount(content),
            jobId: jobId
        )
        guard let row = requiredDataRow(from: response, message: "Üretilen içerik kaydı alınamadı.") else {
            throw RepositoryError(message: "Üretilen içerik kaydı alınamadı.")
        }
        return outputFromRow(row, contentOverride: content)
    }

    public func generatedContentIfReady(jobId: String) async throws -> AnyJSON? {
        let statusResponse = try await api.getJobStatus(jobId)
        let statusData = statusResponse["data"]?.dictValue
        let status = statusData?["status"]?.stringValue ?? ""
        let phase = GenerationJobPhase(rawStatus: status)

        switch phase {
        case .completed:
            let contentResponse = try await api.getGeneratedContent(jobId)
            guard let content = generatedContentPayload(from: contentResponse) else {
                throw RepositoryError(message: "Üretim tamamlandı ancak içerik alınamadı.")
            }
            return content
        case .failed:
            let message = statusData?["errorMessage"]?.stringValue
                ?? statusData?["error_message"]?.stringValue
                ?? "Üretim başarısız."
            throw RepositoryError(message: message)
        case .queued, .running:
            return nil
        }
    }

    public func createGeneratedOutputByKind(
        fileId: String,
        kind: String,
        itemCount: Int? = nil,
        jobId: String? = nil
    ) async throws -> GeneratedOutput {
        let response = try await api.createGeneratedOutputByKind(
            fileId: fileId,
            kind: kind,
            itemCount: itemCount,
            jobId: jobId
        )
        guard let row = requiredDataRow(from: response, message: "Üretilen içerik kaydı alınamadı.") else {
            throw RepositoryError(message: "Üretilen içerik kaydı alınamadı.")
        }
        return outputFromRow(row)
    }

    public func estimateGenerationCost(
        kind: GeneratedKind,
        sourceTextLength: Int? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) async throws -> [String: AnyJSON] {
        guard let jobType = kind.jobType else {
            throw RepositoryError(message: "\(kind.titleLabel) için backend job type henüz aktif değil.")
        }
        return try await api.estimateGenerationCost(
            jobType: jobType,
            sourceTextLength: sourceTextLength,
            count: count,
            qualityTier: qualityTier,
            options: options
        )
    }

    public func listUserJobs(limit: Int? = nil) async throws -> [GenerationJobSnapshot] {
        let response = try await api.listUserJobs(limit: limit)
        let data = response["data"]?.dictValue
        let rows = response["data"]?.arrayValue
            ?? data?["jobs"]?.arrayValue
            ?? data?["rows"]?.arrayValue
            ?? []
        return rows.compactMap(\.dictValue).map(generationJobFromRow)
    }

    public func cancelJob(_ jobId: String) async throws {
        _ = try await api.cancelJob(jobId)
    }

    public func retryJob(_ jobId: String) async throws {
        _ = try await api.retryJob(jobId)
    }

    public func requestAccountDeletion() async throws {
        _ = try await api.requestAccountDeletion()
    }

    public func purchaseMedasiCoin(
        productCode: String,
        successURL: String,
        cancelURL: String
    ) async throws -> [String: AnyJSON] {
        try await api.purchaseMedasiCoin(
            productCode: productCode,
            successURL: successURL,
            cancelURL: cancelURL
        )
    }

    // MARK: - Private: JSON Mapping Helpers

    private func dataRow(from response: [String: AnyJSON]) -> [String: AnyJSON]? {
        guard let data = response["data"]?.dictValue else { return nil }
        if let row = data["row"]?.dictValue { return row }
        if data["id"] != nil { return data }
        return nil
    }

    private func requiredDataRow(from response: [String: AnyJSON], message: String) -> [String: AnyJSON]? {
        guard let row = dataRow(from: response), !row.isEmpty else { return nil }
        return row
    }

    private func waitForGeneratedContent(jobId: String) async throws -> AnyJSON? {
        let maxAttempts = 150 // 300s (150 x 2s) — matches the edge worker wall-clock so podcast+TTS and large sources finish; timeout still points users to Queue.
        for _ in 0..<maxAttempts {
            let statusResponse = try await api.getJobStatus(jobId)
            let statusData = statusResponse["data"]?.dictValue
            let status = statusData?["status"]?.stringValue ?? ""
            let phase = GenerationJobPhase(rawStatus: status)

            if phase == .completed {
                let contentResponse = try await api.getGeneratedContent(jobId)
                guard let content = generatedContentPayload(from: contentResponse) else {
                    throw RepositoryError(message: "Üretim tamamlandı ancak içerik alınamadı.")
                }
                return content
            }

            if phase == .failed {
                let message = statusData?["errorMessage"]?.stringValue
                    ?? statusData?["error_message"]?.stringValue
                    ?? "Üretim başarısız."
                throw RepositoryError(message: message)
            }

            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw RepositoryError(message: "Üretim zaman aşımına uğradı. Arka planda devam ediyorsa Kuyruk ekranından takip edebilirsin.")
    }

    private func processGenerationJobWithRecovery(_ jobId: String) async throws {
        try await Self.processGenerationJobWithRecovery(jobId, api: api)
    }

    private static func processGenerationJobWithRecovery(_ jobId: String, api: DriveAPI) async throws {
        do {
            _ = try await api.processGenerationJob(jobId)
            return
        } catch {
            // A client-side timeout/disconnect does NOT mean the job failed: the edge
            // worker keeps generating server-side for up to ~5 min. Only a *failed* DB
            // status is a real failure worth retrying — never cancel a job that may
            // still be running (cancelling is what turned recoverable jobs into the
            // "Üretim yarıda kaldı" / cancelled state users were seeing).
            if try await generationJobCanContinue(jobId, api: api) { return }

            for delay in [UInt64(1_500_000_000), UInt64(2_500_000_000)] {
                _ = try? await api.retryJob(jobId)
                try? await Task.sleep(nanoseconds: delay)
                do {
                    _ = try await api.processGenerationJob(jobId)
                    return
                } catch {
                    if try await generationJobCanContinue(jobId, api: api) { return }
                }
            }
            throw RepositoryError(message: "Üretim tamamlanamadı. Kuyruktan tekrar deneyebilirsin.")
        }
    }

    private static func generationJobCanContinue(_ jobId: String, api: DriveAPI) async throws -> Bool {
        let statusResponse = try await api.getJobStatus(jobId)
        let statusData = statusResponse["data"]?.dictValue
        let status = (statusData?["status"]?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return GenerationJobPhase(rawStatus: status) != .failed
    }

    private func generatedContentPayload(from response: [String: AnyJSON]) -> AnyJSON? {
        guard let data = response["data"] else {
            return response["content"] ?? response["result"] ?? response["output"]
        }
        if let dataDict = data.dictValue {
            return dataDict["content"]
                ?? dataDict["result"]
                ?? dataDict["output"]
                ?? dataDict["generatedContent"]
                ?? dataDict["generated_content"]
        }
        return data
    }

    // MARK: - Private: Row Mappers

    private func courseFromRow(
        _ row: [String: AnyJSON],
        allSections: [[String: AnyJSON]],
        allFiles: [[String: AnyJSON]],
        allOutputs: [[String: AnyJSON]] = []
    ) -> DriveCourse {
        let id = row.stringValue(for: "id") ?? ""
        let title = row.stringValue(for: "title") ?? "Yeni Ders"
        let updatedAt = row.stringValue(for: "updated_at") ?? row.stringValue(for: "created_at") ?? ""
        let sections = allSections
            .filter { $0.stringValue(for: "course_id") == id }
            .map { sectionFromRow($0, allFiles: allFiles, courseTitle: title, allOutputs: allOutputs) }

        let iconName = row.stringValue(for: "icon_name") ?? "book.closed"
        let colorHex = metadataText(from: row["metadata"], key: "colorHex") ?? "#0A5BFF"

        return DriveCourse(
            id: id,
            title: title,
            iconName: iconName,
            iconColorHex: colorHex,
            iconBackgroundHex: colorHex,
            status: statusFromText(row.stringValue(for: "status") ?? "active"),
            sections: sections,
            updatedLabel: "Son güncelleme \(dateLabel(updatedAt))",
            description: metadataText(from: row["metadata"], key: "description")
                ?? "\(title) dersine ait tüm içerikler, bölümler halinde düzenlenmiştir."
        )
    }

    private func sectionFromRow(
        _ row: [String: AnyJSON],
        allFiles: [[String: AnyJSON]],
        courseTitle: String?,
        allOutputs: [[String: AnyJSON]] = []
    ) -> DriveSection {
        let id = row.stringValue(for: "id") ?? ""
        let title = row.stringValue(for: "title") ?? "Yeni Bölüm"
        let files = allFiles
            .filter { $0.stringValue(for: "section_id") == id }
            .map { fileFromRow($0, courseTitle: courseTitle ?? "", sectionTitle: title, allOutputs: allOutputs) }

        // Outputs that were explicitly saved into this section ("Bölüme kaydet")
        // surface as first-class, file-like items alongside the section's files.
        let savedOutputs = allOutputs
            .filter { $0.stringValue(for: "section_id") == id }
            .map { outputFromRow($0) }

        let iconName = metadataText(from: row["metadata"], key: "iconName") ?? "folder"
        let colorHex = metadataText(from: row["metadata"], key: "colorHex") ?? "#0A5BFF"

        return DriveSection(
            id: id,
            title: title,
            status: statusFromText(row.stringValue(for: "status") ?? "active"),
            files: files,
            savedOutputs: savedOutputs,
            iconName: iconName,
            iconColorHex: colorHex
        )
    }

    private func fileFromRow(
        _ row: [String: AnyJSON],
        courseTitle: String,
        sectionTitle: String,
        allOutputs: [[String: AnyJSON]]
    ) -> DriveFile {
        let id = row.stringValue(for: "id") ?? ""
        let status = fileStatusFromRow(row)
        let kind = kindFromRow(row)
        let pageCount = firstInt(
            row,
            keys: ["page_count", "pageCount", "pages", "num_pages", "total_pages"]
        ) ?? 0
        let slideCount = firstInt(
            row,
            keys: ["slide_count", "slideCount", "slides", "num_slides", "total_slides"]
        ) ?? 0
        let sizeBytes = row["size_bytes"]?.intValue ?? 0

        return DriveFile(
            id: id,
            title: row.stringValue(for: "title") ?? row.stringValue(for: "original_filename") ?? "",
            kind: kind,
            sizeLabel: sizeLabel(sizeBytes),
            pageLabel: pageLabelForFile(
                kind: kind,
                status: status,
                pageCount: pageCount,
                slideCount: slideCount
            ),
            updatedLabel: dateLabel(row.stringValue(for: "updated_at") ?? row.stringValue(for: "created_at") ?? ""),
            courseTitle: courseTitle,
            sectionTitle: sectionTitle,
            status: status,
            statusMessage: fileStatusMessage(row: row, kind: kind, status: status, sizeBytes: sizeBytes),
            tag: row.stringValue(for: "tag"),
            featured: false,
            selected: false,
            generated: allOutputs
                .filter { $0.stringValue(for: "source_file_id") == id }
                .map { outputFromRow($0) }
        )
    }

    private func outputFromRow(_ row: [String: AnyJSON], contentOverride: AnyJSON? = nil) -> GeneratedOutput {
        let rawType = row.stringValue(for: "output_type") ?? row.stringValue(for: "kind") ?? ""
        let kind = generatedKindFromText(rawType)
        let metadata = row["metadata"]?.dictValue ?? [:]
        let content: AnyJSON? = contentOverride ?? metadata["content"] ?? row["content"]
        let itemCount = row["item_count"]?.intValue ?? 0
        let status = row.stringValue(for: "status") ?? "ready"

        return GeneratedOutput(
            id: row.stringValue(for: "id") ?? "",
            sourceFileId: row.stringValue(for: "source_file_id") ?? "",
            kind: kind,
            rawType: rawType,
            title: row.stringValue(for: "title") ?? kind.titleLabel,
            detail: generatedOutputDetail(rawType: rawType, status: status, itemCount: itemCount, content: content),
            content: content,
            contentText: generatedContentText(content),
            updatedLabel: dateLabel(row.stringValue(for: "updated_at") ?? row.stringValue(for: "created_at") ?? ""),
            status: status,
            itemCount: itemCount,
            jobId: metadata.stringValue(for: "jobId")
                ?? metadata.stringValue(for: "job_id")
                ?? row.stringValue(for: "job_id")
        )
    }

    private func uploadTaskFromRow(
        _ row: [String: AnyJSON],
        allFiles: [DriveFile],
        allOutputs: [[String: AnyJSON]]
    ) -> UploadTask {
        let fileRow = row["file"]?.dictValue ?? row
        let fileId = fileRow.stringValue(for: "id")
            ?? fileRow.stringValue(for: "file_id")
            ?? row.stringValue(for: "file_id")
            ?? row.stringValue(for: "fileId")
            ?? ""
        let existingFile = allFiles.first { $0.id == fileId }
        let file = existingFile ?? fileFromRow(
            fileRow,
            courseTitle: fileRow.stringValue(for: "course_title") ?? row.stringValue(for: "course_title") ?? "Drive",
            sectionTitle: fileRow.stringValue(for: "section_title") ?? row.stringValue(for: "section_title") ?? "Kaynaklar",
            allOutputs: allOutputs
        )
        let statusText = row.stringValue(for: "status")
            ?? row.stringValue(for: "ai_status")
            ?? fileRow.stringValue(for: "ai_status")
            ?? fileRow.stringValue(for: "status")
            ?? file.status.rawValue
        let rawProgress = row["progress"]?.doubleValue
            ?? row["processing_progress"]?.doubleValue
            ?? row["upload_progress"]?.doubleValue
        let status = statusFromText(statusText)
        let progress = normalizedProgress(rawProgress, status: status)
        let errorLabel = row.stringValue(for: "errorLabel")
            ?? row.stringValue(for: "error_label")
            ?? row.stringValue(for: "errorMessage")
            ?? row.stringValue(for: "error_message")
            ?? file.statusMessage

        return UploadTask(file: file, status: status, progress: progress, errorLabel: errorLabel)
    }

    private func generationJobFromRow(_ row: [String: AnyJSON]) -> GenerationJobSnapshot {
        let id = row.stringValue(for: "id")
            ?? row.stringValue(for: "jobId")
            ?? row.stringValue(for: "job_id")
            ?? ""
        let rawKind = row.stringValue(for: "jobType")
            ?? row.stringValue(for: "job_type")
            ?? row.stringValue(for: "output_type")
            ?? row.stringValue(for: "kind")
            ?? "summary"
        let rawStatus = row.stringValue(for: "status") ?? "queued"
        let outputId = row.stringValue(for: "outputId")
            ?? row.stringValue(for: "output_id")
            ?? row.stringValue(for: "generatedOutputId")
            ?? row.stringValue(for: "generated_output_id")
        let rawPhase = GenerationJobPhase(rawStatus: rawStatus)
        let phase: GenerationJobPhase = outputId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && rawPhase != .failed
            ? .completed
            : rawPhase
        return GenerationJobSnapshot(
            id: id,
            sourceFileId: row.stringValue(for: "sourceFileId")
                ?? row.stringValue(for: "source_file_id")
                ?? row.stringValue(for: "fileId")
                ?? row.stringValue(for: "file_id")
                ?? "",
            sourceTitle: row.stringValue(for: "sourceTitle")
                ?? row.stringValue(for: "source_title")
                ?? row.stringValue(for: "fileTitle")
                ?? row.stringValue(for: "file_title")
                ?? "Drive kaynağı",
            kind: generatedKindFromText(rawKind),
            status: phase.rawValue,
            progress: normalizedProgress(row["progress"]?.doubleValue, phase: phase),
            errorMessage: row.stringValue(for: "errorMessage") ?? row.stringValue(for: "error_message"),
            outputId: outputId,
            jobId: row.stringValue(for: "jobId") ?? row.stringValue(for: "job_id") ?? id
        )
    }

    // MARK: - Private: Status & Kind Parsing

    private func statusFromText(_ text: String) -> DriveItemStatus {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "completed", "complete", "uploaded", "ready", "active", "succeeded", "success", "done", "finished", "processed": return .completed
        case "processing", "pending", "running", "in_progress", "in-progress", "started", "working", "generating": return .processing
        case "uploading": return .uploading
        case "failed", "error", "errored", "cancelled", "canceled", "timeout", "timed_out": return .failed
        case "draft", "queued", "created", "scheduled", "waiting": return .draft
        default: return .failed
        }
    }

    private func fileStatusFromRow(_ row: [String: AnyJSON]) -> DriveItemStatus {
        let aiStatus = row.stringValue(for: "ai_status") ?? ""
        let storageStatus = row.stringValue(for: "status") ?? ""
        if row["size_bytes"]?.intValue ?? 0 <= 0 { return .failed }
        if !aiStatus.isEmpty { return statusFromText(aiStatus) }
        if storageStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "uploaded" {
            return .processing
        }
        return statusFromText(storageStatus)
    }

    private func kindFromRow(_ row: [String: AnyJSON]) -> DriveFileKind {
        DriveFileMapping.kind(from: row)
    }

    private func firstInt(_ row: [String: AnyJSON], keys: [String]) -> Int? {
        for key in keys {
            if let value = row[key]?.intValue { return value }
        }
        return nil
    }

    private func normalizedProgress(_ raw: Double?, status: DriveItemStatus) -> Double {
        if let raw {
            if raw > 1 { return min(max(raw / 100, 0), 1) }
            return min(max(raw, 0), 1)
        }
        switch status {
        case .completed: return 1
        case .failed: return 1
        case .uploading: return 0.35
        case .processing: return 0.65
        case .draft: return 0.05
        }
    }

    private func normalizedProgress(_ raw: Double?, phase: GenerationJobPhase) -> Double {
        normalizedProgress(raw, status: phase.driveStatus)
    }

    private func generatedKindFromText(_ text: String) -> GeneratedKind {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        switch normalized {
        case "flashcard", "flashcards": return .flashcard
        case "question", "questions", "quiz": return .question
        case "algorithm": return .algorithm
        case "comparison": return .comparison
        case "table": return .table
        case "podcast", "podcast_summary", "podcastsummary": return .podcast
        case "infographic": return .infographic
        case "mind_map", "mindmap": return .mindMap
        case "exam_morning_summary", "exammorningsummary": return .examMorningSummary
        case "clinical_scenario", "clinicalscenario": return .clinicalScenario
        case "learning_plan", "learningplan": return .learningPlan
        case "summary": return .summary
        default: return .summary
        }
    }

    private func isSupportedGeneratedOutputType(_ rawType: String) -> Bool {
        let normalized = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        return switch normalized {
        case "flashcard", "flashcards", "question", "questions", "quiz",
             "summary", "exam_morning_summary", "exammorningsummary",
             "algorithm", "comparison", "table", "podcast", "podcast_summary",
             "podcastsummary", "infographic", "mind_map", "mindmap",
             "clinical_scenario", "clinicalscenario",
             "learning_plan", "learningplan": true
        default: false
        }
    }

    // MARK: - Private: Labels

    private func dateLabel(_ raw: String) -> String {
        guard let parsed = ISO8601DateFormatter().date(from: raw)
                ?? dateFromFlexible(raw) else {
            return raw.isEmpty ? "Bugün" : raw
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateDay = calendar.startOfDay(for: parsed)

        if dateDay == today { return "Bugün" }
        if dateDay == calendar.date(byAdding: .day, value: -1, to: today) { return "Dün" }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: parsed)
    }

    private func dateFromFlexible(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    private func sizeLabel(_ bytes: Int) -> String {
        if bytes <= 0 { return "-" }
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(bytes / 1024) KB"
    }

    private func pageLabelForFile(
        kind: DriveFileKind,
        status: DriveItemStatus,
        pageCount: Int,
        slideCount: Int
    ) -> String {
        DriveFileMapping.pageLabel(
            kind: kind,
            status: status,
            pageCount: pageCount,
            slideCount: slideCount
        )
    }

    private func fileStatusMessage(
        row: [String: AnyJSON],
        kind: DriveFileKind,
        status: DriveItemStatus,
        sizeBytes: Int
    ) -> String? {
        DriveFileMapping.statusMessage(row: row, kind: kind, status: status, sizeBytes: sizeBytes)
    }

    private func generatedOutputDetail(
        rawType: String,
        status: String,
        itemCount: Int,
        content: AnyJSON?
    ) -> String {
        let normalizedStatus = status.trimmingCharacters(in: .whitespaces).lowercased()
        if normalizedStatus == "failed" || normalizedStatus == "error" {
            return "Üretim tamamlanamadı"
        }
        if !isSupportedGeneratedOutputType(rawType) {
            return "Sonuç oluşturuldu ancak bu görünüm henüz desteklenmiyor."
        }
        let preview = generatedContentPreview(content)
        if itemCount > 0 && !preview.isEmpty { return "\(itemCount) öğe • \(preview)" }
        if itemCount > 0 { return "\(itemCount) öğe" }
        if !preview.isEmpty { return preview }
        if normalizedStatus == "ready" || normalizedStatus == "completed" {
            return "Sonuç oluşturuldu"
        }
        return "Sonuç oluşturuldu ancak bu görünüm henüz desteklenmiyor."
    }

    private func generatedContentPreview(_ content: AnyJSON?) -> String {
        let text = firstGeneratedText(content).replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        if text.isEmpty { return "" }
        return text.count > 120 ? String(text.prefix(120)) + "..." : text
    }

    private func generatedContentText(_ content: AnyJSON?) -> String? {
        guard let content else { return nil }
        let text = readableContent(content)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func readableContent(_ value: AnyJSON, key: String? = nil, depth: Int = 0) -> String {
        switch value {
        case .null:
            return ""
        case .bool(let bool):
            return bool ? "Evet" : "Hayır"
        case .integer(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .string(let string):
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case .array(let array):
            return array
                .map { item in
                    let text = readableContent(item, depth: depth + 1)
                    guard !text.isEmpty else { return "" }
                    if text.contains("\n") || depth > 0 {
                        return "- \(text.replacingOccurrences(of: "\n", with: "\n  "))"
                    }
                    return "- \(text)"
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        case .object(let dict):
            let orderedKeys = orderedContentKeys(dict)
            return orderedKeys
                .map { itemKey in
                    guard let child = dict[itemKey] else { return "" }
                    let text = readableContent(child, key: itemKey, depth: depth + 1)
                    guard !text.isEmpty else { return "" }
                    let label = contentLabel(for: itemKey)
                    if child.arrayValue != nil || child.objectValue != nil {
                        return "\(label)\n\(text)"
                    }
                    return "\(label): \(text)"
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    private func orderedContentKeys(_ dict: [String: AnyJSON]) -> [String] {
        let preferred = [
            "title", "summary", "front", "back", "question", "answer", "explanation",
            "description", "body", "text", "fullText", "cards", "flashcards",
            "questions", "options", "rows", "columns", "sections", "steps",
            "nodes", "branches", "segments", "chapters", "days", "tasks",
            "must_know", "commonly_confused", "clinical_tus_tips", "self_check"
        ]
        var seen = Set<String>()
        var keys: [String] = []
        for key in preferred where dict[key] != nil {
            keys.append(key)
            seen.insert(key)
        }
        keys.append(contentsOf: dict.keys.filter { !seen.contains($0) }.sorted())
        return keys
    }

    private func contentLabel(for key: String) -> String {
        let replacements: [String: String] = [
            "fullText": "Metin",
            "must_know": "Mutlaka Bil",
            "commonly_confused": "Sık Karışanlar",
            "clinical_tus_tips": "Klinik İpuçları",
            "self_check": "Kontrol",
            "front": "Ön",
            "back": "Arka"
        ]
        if let replacement = replacements[key] { return replacement }
        let spaced = key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return spaced
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }

    private func firstGeneratedText(_ value: AnyJSON?) -> String {
        guard let value else { return "" }
        switch value {
        case .string(let s): return s.trimmingCharacters(in: .whitespaces)
        case .array(let arr):
            for item in arr {
                let text = firstGeneratedText(item)
                if !text.isEmpty { return text }
            }
            return ""
        case .object(let dict):
            let primaryKeys = ["title", "front", "question", "summary", "fullText",
                               "answer", "description", "body", "text", "prompt"]
            for key in primaryKeys {
                let text = firstGeneratedText(dict[key])
                if !text.isEmpty { return text }
            }
            let secondaryKeys = ["cards", "flashcards", "questions", "bulletPoints",
                                 "must_know", "commonly_confused", "clinical_tus_tips",
                                 "self_check", "steps", "rows", "segments", "chapters",
                                 "days", "nodes", "branches", "sections"]
            for key in secondaryKeys {
                let text = firstGeneratedText(dict[key])
                if !text.isEmpty { return text }
            }
            return ""
        default:
            return ""
        }
    }

    private func contentItemCount(_ content: AnyJSON?) -> Int {
        guard let content else { return 1 }
        if case .array(let arr) = content { return arr.count }
        if case .object(let dict) = content {
            let countKeys = ["cards", "flashcards", "questions", "bulletPoints",
                             "must_know", "commonly_confused", "clinical_tus_tips",
                             "self_check", "steps", "rows", "segments", "chapters",
                             "days", "nodes", "branches", "sections",
                             "teachingPoints", "objectives", "sessions"]
            for key in countKeys {
                if let val = dict[key], case .array(let arr) = val, !arr.isEmpty {
                    return arr.count
                }
            }
        }
        return 1
    }

    private func metadataText(from raw: AnyJSON?, key: String) -> String? {
        guard case .object(let dict) = raw else { return nil }
        return dict[key]?.stringValue
    }
}

// MARK: - AnyJSON Dictionary Helpers

extension [String: AnyJSON] {
    func stringValue(for key: String) -> String? {
        self[key]?.stringValue
    }
}

extension AnyJSON {
    var dictValue: [String: AnyJSON]? {
        if case .object(let d) = self { return d }
        return nil
    }

    var arrayValue: [AnyJSON]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .integer(let v): return v
        case .double(let v): return Int(v)
        case .string(let v): return Int(v)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .integer(let v): return Double(v)
        case .double(let v): return v
        case .string(let v): return Double(v)
        default: return nil
        }
    }
}
