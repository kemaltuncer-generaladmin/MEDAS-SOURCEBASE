import Foundation
import Supabase

public struct ExtractionMetadata: Sendable, Codable {
    public let charCount: Int
    public let wordCount: Int
    public let extractedAt: Date

    public init(charCount: Int, wordCount: Int, extractedAt: Date) {
        self.charCount = charCount
        self.wordCount = wordCount
        self.extractedAt = extractedAt
    }
}

// MARK: - Enums

public enum DriveFileKind: String, Codable, Sendable, CaseIterable {
    case pdf, pptx, docx, ppt, doc, zip
}

public enum DriveItemStatus: String, Codable, Sendable {
    case completed, processing, uploading, failed, draft
}

public enum GenerationJobPhase: String, Codable, Sendable, Equatable {
    case queued, running, completed, failed

    public init(rawStatus: String) {
        let normalized = rawStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()

        switch normalized {
        case "completed", "complete", "ready", "succeeded", "success", "done", "finished", "processed", "generated":
            self = .completed
        case "failed", "error", "errored", "cancelled", "canceled", "timeout", "timed_out", "expired":
            self = .failed
        case "queued", "pending", "draft", "created", "scheduled", "waiting":
            self = .queued
        case "running", "processing", "in_progress", "inprogress", "started", "working", "generating":
            self = .running
        default:
            self = .running
        }
    }

    public var isActive: Bool {
        self == .queued || self == .running
    }

    public var driveStatus: DriveItemStatus {
        switch self {
        case .completed: return .completed
        case .failed: return .failed
        case .queued: return .draft
        case .running: return .processing
        }
    }
}

public enum GeneratedKind: String, Codable, Sendable, CaseIterable {
    case flashcard, question, summary, algorithm, comparison
    case examMorningSummary = "exam_morning_summary"
    case clinicalScenario = "clinical_scenario"
    case learningPlan = "learning_plan"
    case podcast, table, infographic
    case mindMap = "mindMap"

    public var jobType: String? {
        switch self {
        case .flashcard: return "flashcard"
        case .question: return "quiz"
        case .summary: return "summary"
        case .examMorningSummary: return "exam_morning_summary"
        case .algorithm: return "algorithm"
        case .comparison, .table: return "comparison"
        case .clinicalScenario: return "clinical_scenario"
        case .learningPlan: return "learning_plan"
        case .podcast: return "podcast"
        case .infographic: return "infographic"
        case .mindMap: return "mind_map"
        }
    }

    public var defaultCount: Int? {
        switch self {
        case .flashcard: return 20
        case .question: return 10
        case .clinicalScenario, .examMorningSummary, .learningPlan, .mindMap: return 1
        default: return nil
        }
    }

    public var titleLabel: String {
        switch self {
        case .flashcard: return "Flashcard Seti"
        case .question: return "Soru Seti"
        case .summary: return "Özet"
        case .examMorningSummary: return "Sınav Sabahı Özeti"
        case .algorithm: return "Algoritma"
        case .comparison: return "Karşılaştırma"
        case .clinicalScenario: return "Klinik Senaryo"
        case .learningPlan: return "Öğrenme Planı"
        case .podcast: return "Podcast"
        case .table: return "Tablo"
        case .infographic: return "İnfografik"
        case .mindMap: return "Zihin Haritası"
        }
    }
}

// MARK: - Data Models

public struct DriveWorkspaceData: Codable, Sendable {
    public let courses: [DriveCourse]
    public let recentFiles: [DriveFile]
    public let uploads: [UploadTask]
    public let collections: [CollectionBundle]

    public init(
        courses: [DriveCourse],
        recentFiles: [DriveFile],
        uploads: [UploadTask],
        collections: [CollectionBundle]
    ) {
        self.courses = courses
        self.recentFiles = recentFiles
        self.uploads = uploads
        self.collections = collections
    }

    public static let empty = DriveWorkspaceData(
        courses: [], recentFiles: [], uploads: [], collections: []
    )

    public var primaryCourse: DriveCourse? {
        courses.first
    }

    public var primarySection: DriveSection? {
        primaryCourse?.sections.first
    }

    public var primaryFile: DriveFile? {
        primarySection?.files.first
    }
}

public struct DriveDestination: Codable, Sendable, Equatable {
    public let courseId: String
    public let sectionId: String
    public let courseTitle: String
    public let sectionTitle: String

    public init(courseId: String, sectionId: String, courseTitle: String, sectionTitle: String) {
        self.courseId = courseId
        self.sectionId = sectionId
        self.courseTitle = courseTitle
        self.sectionTitle = sectionTitle
    }

    public var isUsable: Bool {
        !courseId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sectionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct DriveCourse: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let iconName: String
    public let iconColorHex: String
    public let iconBackgroundHex: String
    public let status: DriveItemStatus
    public let sections: [DriveSection]
    public let updatedLabel: String
    public let description: String

    public var fileCount: Int {
        sections.reduce(0) { $0 + $1.files.count }
    }

    public init(
        id: String,
        title: String,
        iconName: String,
        iconColorHex: String,
        iconBackgroundHex: String,
        status: DriveItemStatus,
        sections: [DriveSection],
        updatedLabel: String,
        description: String
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.iconBackgroundHex = iconBackgroundHex
        self.status = status
        self.sections = sections
        self.updatedLabel = updatedLabel
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case id, title, iconName, iconColorHex, iconBackgroundHex, status, sections, updatedLabel, description
    }
}

public struct DriveSection: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: DriveItemStatus
    public let files: [DriveFile]
    /// Generated study outputs that were explicitly saved INTO this section
    /// ("Bölüme kaydet"). They live alongside `files` and are shown as
    /// first-class, file-like items in the section browser.
    public let savedOutputs: [GeneratedOutput]
    public let iconName: String
    public let iconColorHex: String

    public init(
        id: String,
        title: String,
        status: DriveItemStatus,
        files: [DriveFile],
        savedOutputs: [GeneratedOutput] = [],
        iconName: String = "folder",
        iconColorHex: String = "#0A5BFF"
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.files = files
        self.savedOutputs = savedOutputs
        self.iconName = iconName
        self.iconColorHex = iconColorHex
    }

    enum CodingKeys: String, CodingKey {
        case id, title, status, files, savedOutputs, iconName, iconColorHex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        status = try c.decode(DriveItemStatus.self, forKey: .status)
        files = try c.decode([DriveFile].self, forKey: .files)
        savedOutputs = try c.decodeIfPresent([GeneratedOutput].self, forKey: .savedOutputs) ?? []
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "folder"
        iconColorHex = try c.decodeIfPresent(String.self, forKey: .iconColorHex) ?? "#0A5BFF"
    }
}

public struct DriveFile: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let kind: DriveFileKind
    public let sizeLabel: String
    public let pageLabel: String
    public let updatedLabel: String
    public let courseTitle: String
    public let sectionTitle: String
    public let status: DriveItemStatus
    public let statusMessage: String?
    public let tag: String?
    public let featured: Bool
    public let selected: Bool
    public let generated: [GeneratedOutput]

    public var isReadyForGeneration: Bool {
        status == .completed
    }

    public init(
        id: String,
        title: String,
        kind: DriveFileKind,
        sizeLabel: String,
        pageLabel: String,
        updatedLabel: String,
        courseTitle: String,
        sectionTitle: String,
        status: DriveItemStatus,
        statusMessage: String?,
        tag: String?,
        featured: Bool,
        selected: Bool,
        generated: [GeneratedOutput]
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.sizeLabel = sizeLabel
        self.pageLabel = pageLabel
        self.updatedLabel = updatedLabel
        self.courseTitle = courseTitle
        self.sectionTitle = sectionTitle
        self.status = status
        self.statusMessage = statusMessage
        self.tag = tag
        self.featured = featured
        self.selected = selected
        self.generated = generated
    }

    enum CodingKeys: String, CodingKey {
        case id, title, kind, sizeLabel, pageLabel, updatedLabel
        case courseTitle, sectionTitle, status, statusMessage, tag
        case featured, selected, generated
    }
}

/// One active storage subscription a user has purchased (App Store auto-renewable).
public struct SBStoragePlan: Codable, Sendable, Equatable, Identifiable {
    public let productCode: String
    public let bonusBytes: Int
    public let expiresAt: String?

    public var id: String { productCode + "-" + (expiresAt ?? "") }

    public init(productCode: String, bonusBytes: Int, expiresAt: String?) {
        self.productCode = productCode
        self.bonusBytes = bonusBytes
        self.expiresAt = expiresAt
    }
}

/// A user's storage usage + quota snapshot. `baseBytes` is the free tier (25 GB);
/// `bonusBytes` is the sum of active storage subscriptions; `totalBytes` is the
/// effective quota enforced server-side at upload time.
public struct SBStorageStatus: Codable, Sendable, Equatable {
    public let usedBytes: Int
    public let baseBytes: Int
    public let bonusBytes: Int
    public let totalBytes: Int
    public let plans: [SBStoragePlan]

    public var availableBytes: Int { max(0, totalBytes - usedBytes) }
    public var usedFraction: Double {
        totalBytes > 0 ? min(1, max(0, Double(usedBytes) / Double(totalBytes))) : 0
    }
    public var isNearlyFull: Bool { usedFraction >= 0.9 }
    /// Used storage exceeds the current quota (e.g. after a subscription expired
    /// or was downgraded). Existing files stay; new uploads are blocked.
    public var isOverQuota: Bool { totalBytes > 0 && usedBytes > totalBytes }

    public init(usedBytes: Int, baseBytes: Int, bonusBytes: Int, totalBytes: Int, plans: [SBStoragePlan]) {
        self.usedBytes = usedBytes
        self.baseBytes = baseBytes
        self.bonusBytes = bonusBytes
        self.totalBytes = totalBytes
        self.plans = plans
    }

    public static let empty = SBStorageStatus(usedBytes: 0, baseBytes: 0, bonusBytes: 0, totalBytes: 0, plans: [])
}

public struct GeneratedOutput: Codable, Identifiable, Sendable {
    public let id: String
    public let sourceFileId: String
    public let kind: GeneratedKind
    public let rawType: String
    public let title: String
    public let detail: String
    public let content: AnyJSON?
    public let contentText: String?
    public let updatedLabel: String
    public let status: String
    public let itemCount: Int
    public let jobId: String?

    public var isReady: Bool {
        GenerationJobPhase(rawStatus: status) == .completed
    }

    public init(
        id: String,
        sourceFileId: String,
        kind: GeneratedKind,
        rawType: String,
        title: String,
        detail: String,
        content: AnyJSON? = nil,
        contentText: String? = nil,
        updatedLabel: String,
        status: String,
        itemCount: Int,
        jobId: String?
    ) {
        self.id = id
        self.sourceFileId = sourceFileId
        self.kind = kind
        self.rawType = rawType
        self.title = title
        self.detail = detail
        self.content = content
        self.contentText = contentText
        self.updatedLabel = updatedLabel
        self.status = status
        self.itemCount = itemCount
        self.jobId = jobId
    }

    enum CodingKeys: String, CodingKey {
        case id, sourceFileId, kind, rawType, title, detail, content, contentText
        case updatedLabel, status, itemCount, jobId
    }
}

public struct UploadTask: Codable, Sendable {
    public let file: DriveFile
    public let status: DriveItemStatus
    public let progress: Double
    public let errorLabel: String?

    public init(
        file: DriveFile,
        status: DriveItemStatus,
        progress: Double,
        errorLabel: String?
    ) {
        self.file = file
        self.status = status
        self.progress = progress
        self.errorLabel = errorLabel
    }

    enum CodingKeys: String, CodingKey {
        case file, status, progress, errorLabel
    }
}

public struct CollectionBundle: Codable, Sendable {
    public let file: DriveFile
    public let outputs: [GeneratedOutput]
    public let subject: String
    public let previewKind: GeneratedKind

    public init(
        file: DriveFile,
        outputs: [GeneratedOutput],
        subject: String,
        previewKind: GeneratedKind
    ) {
        self.file = file
        self.outputs = outputs
        self.subject = subject
        self.previewKind = previewKind
    }

    enum CodingKeys: String, CodingKey {
        case file, outputs, subject, previewKind
    }
}

public struct GenerationJobSnapshot: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let sourceFileId: String
    public let sourceTitle: String
    public let kind: GeneratedKind
    public let status: String
    public let progress: Double
    public let errorMessage: String?
    public let outputId: String?
    public let jobId: String?

    public init(
        id: String,
        sourceFileId: String,
        sourceTitle: String,
        kind: GeneratedKind,
        status: String,
        progress: Double,
        errorMessage: String? = nil,
        outputId: String? = nil,
        jobId: String? = nil
    ) {
        self.id = id
        self.sourceFileId = sourceFileId
        self.sourceTitle = sourceTitle
        self.kind = kind
        self.status = status
        self.progress = progress
        self.errorMessage = errorMessage
        self.outputId = outputId
        self.jobId = jobId
    }
}

public struct DriveUploadDraft: Codable, Sendable {
    public let fileName: String
    public let contentType: String
    public let sizeBytes: Int
    public let courseId: String
    public let sectionId: String

    public init(fileName: String, contentType: String, sizeBytes: Int, courseId: String, sectionId: String) {
        self.fileName = fileName
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.courseId = courseId
        self.sectionId = sectionId
    }

    public func toJSON() -> [String: String] {
        [
            "fileName": fileName,
            "contentType": contentType,
            "sizeBytes": String(sizeBytes),
            "courseId": courseId,
            "sectionId": sectionId
        ]
    }
}

public struct StorageUploadSession: Codable, Sendable {
    public let uploadURL: String
    public let objectName: String
    public let bucket: String
    public let headers: [String: String]
    public let expiresAt: Date

    public init(
        uploadURL: String,
        objectName: String,
        bucket: String,
        headers: [String: String],
        expiresAt: Date
    ) {
        self.uploadURL = uploadURL
        self.objectName = objectName
        self.bucket = bucket
        self.headers = headers
        self.expiresAt = expiresAt
    }

    public var isUsable: Bool {
        !uploadURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !objectName.trimmingCharacters(in: .whitespaces).isEmpty
            && expiresAt.timeIntervalSinceNow > 45
    }

    enum CodingKeys: String, CodingKey {
        case uploadURL = "uploadUrl"
        case objectName
        case bucket
        case headers
        case expiresAt
    }

    /// Dynamic key so we can also look up snake_case aliases (e.g. `upload_url`,
    /// `expires_at`) without force-unwrapping a fixed `CodingKeys` case.
    private struct AnyKey: CodingKey {
        let stringValue: String
        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alt = try decoder.container(keyedBy: AnyKey.self)

        uploadURL = try container.decodeIfPresent(String.self, forKey: .uploadURL)
            ?? alt.decodeIfPresent(String.self, forKey: AnyKey("upload_url"))
            ?? ""

        objectName = try container.decodeIfPresent(String.self, forKey: .objectName)
            ?? alt.decodeIfPresent(String.self, forKey: AnyKey("object_name"))
            ?? ""

        bucket = try container.decodeIfPresent(String.self, forKey: .bucket) ?? ""

        let rawHeaders = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        headers = rawHeaders

        // expiresAt may arrive as an ISO8601 string (with or without fractional
        // seconds, e.g. Deno's `new Date().toISOString()` → "2026-06-04T12:00:00.000Z")
        // or as a numeric epoch. Parse defensively so a valid session is never
        // discarded just because of date formatting.
        // Use `try?` so a numeric value doesn't throw a typeMismatch before the
        // epoch fallback below has a chance to handle it.
        if let dateString = (try? container.decodeIfPresent(String.self, forKey: .expiresAt))
            ?? (try? alt.decodeIfPresent(String.self, forKey: AnyKey("expires_at")))
            ?? nil,
            !dateString.isEmpty {
            expiresAt = Self.parseExpiry(dateString)
        } else if let epoch = (try? container.decodeIfPresent(Double.self, forKey: .expiresAt))
            ?? (try? alt.decodeIfPresent(Double.self, forKey: AnyKey("expires_at")))
            ?? nil {
            // Heuristic: values larger than ~year 2300 in seconds are milliseconds.
            expiresAt = Date(timeIntervalSince1970: epoch > 10_000_000_000 ? epoch / 1000 : epoch)
        } else {
            expiresAt = .distantPast
        }
    }

    static func parseExpiry(_ raw: String) -> Date {
        let dateString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dateString.isEmpty else { return .distantPast }

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = isoWithFractional.date(from: dateString) { return parsed }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let parsed = iso.date(from: dateString) { return parsed }

        // Fall back to plain formats without timezone designators.
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: dateString) { return parsed }
        }

        return .distantPast
    }
}
