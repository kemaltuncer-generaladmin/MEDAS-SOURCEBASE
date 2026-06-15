import Foundation
import Supabase

public struct DriveAPIError: Error, Sendable, LocalizedError, CustomStringConvertible {
    public let message: String
    public let code: String?
    public let status: Int?

    public init(message: String, code: String? = nil, status: Int? = nil) {
        self.message = message
        self.code = code
        self.status = status
    }

    public var isUnauthorized: Bool {
        status == 401 || code == "UNAUTHORIZED" || code == "AUTH_NOT_CONFIGURED"
    }

    public var errorDescription: String? { message }

    public var description: String {
        var parts = [message]
        if let code { parts.append("code=\(code)") }
        if let status { parts.append("status=\(status)") }
        return parts.joined(separator: " ")
    }
}

public struct DriveAPI: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Core invoke

    public func invoke(
        _ action: String,
        payload: [String: AnyJSON] = [:],
        timeoutSeconds: UInt64 = 90
    ) async throws -> [String: AnyJSON] {
        let body = AnyJSON.object([
            "action": .string(action),
            "payload": .object(payload)
        ])

        do {
            let data: [String: AnyJSON] = try await withDriveAPITimeout(seconds: timeoutSeconds) {
                try await client.functions.invoke(
                    "sourcebase",
                    options: FunctionInvokeOptions(body: body)
                )
            }

            if let ok = data["ok"], case .bool(false) = ok {
                let errorInfo = data["error"]
                var message = "SourceBase request failed."
                var code: String?
                var status: Int?

                if case .object(let errorDict) = errorInfo {
                    message = errorDict["message"]?.stringValue ?? "SourceBase request failed."
                    code = errorDict["code"]?.stringValue
                    status = errorDict["status"].flatMap { v -> Int? in
                        if case .integer(let i) = v { return i }
                        return Int(v.stringValue ?? "")
                    }
                }

                SBLog.drive.error("edge action failed action=\(action, privacy: .public) code=\(code ?? "none", privacy: .public) status=\(status ?? 0, privacy: .public)")
                throw DriveAPIError(message: message, code: code, status: status)
            }

            return data
        } catch let error as DriveAPIError {
            throw error
        } catch FunctionsError.httpError(let status, let data) {
            SBLog.drive.error("edge http error action=\(action, privacy: .public) status=\(status, privacy: .public)")
            throw Self.httpError(status: status, data: data)
        } catch {
            SBLog.drive.error("edge invoke threw action=\(action, privacy: .public) error=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    static func httpError(status: Int, data: Data) -> DriveAPIError {
        let fallback = HTTPURLResponse.localizedString(forStatusCode: status)
        guard !data.isEmpty else {
            return DriveAPIError(message: fallback, code: nil, status: status)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let errorDict = json["error"] as? [String: Any]
            let source = errorDict ?? json
            let message = source["message"] as? String
                ?? json["message"] as? String
                ?? fallback
            let code = source["code"] as? String
                ?? json["code"] as? String
            let parsedStatus = source["status"] as? Int
                ?? json["status"] as? Int
                ?? status
            return DriveAPIError(message: message, code: code, status: parsedStatus)
        }

        let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return DriveAPIError(message: body?.isEmpty == false ? body! : fallback, code: nil, status: status)
    }

    // MARK: - Upload

    public func createUploadSession(_ draft: DriveUploadDraft) async throws -> StorageUploadSession {
        let payload = Self.uploadSessionPayload(for: draft)
        let response = try await invoke("create_upload_session", payload: payload)
        guard case .object(let dataDict) = response["data"] else {
            throw DriveAPIError(message: "Upload session response is empty.", code: nil, status: nil)
        }
        let jsonData = try JSONEncoder().encode(dataDict)
        return try JSONDecoder().decode(StorageUploadSession.self, from: jsonData)
    }

    static func uploadSessionPayload(for draft: DriveUploadDraft) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileName": .string(draft.fileName),
            "contentType": .string(draft.contentType),
            "sizeBytes": .integer(draft.sizeBytes),
            "courseId": .string(draft.courseId),
            "sectionId": .string(draft.sectionId)
        ]
        payload.merge(documentProcessingPolicy(fileName: draft.fileName, contentType: draft.contentType)) { current, _ in current }
        return payload
    }

    public func completeUpload(
        objectName: String,
        courseId: String,
        sectionId: String,
        fileName: String,
        contentType: String,
        sizeBytes: Int,
        extractedText: String? = nil,
        pageCount: Int? = nil,
        extractionMetadata: ExtractionMetadata? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.completeUploadPayload(
            objectName: objectName,
            courseId: courseId,
            sectionId: sectionId,
            fileName: fileName,
            contentType: contentType,
            sizeBytes: sizeBytes,
            extractedText: extractedText,
            pageCount: pageCount,
            extractionMetadata: extractionMetadata
        )
        return try await invoke("complete_upload", payload: payload)
    }

    static func completeUploadPayload(
        objectName: String,
        courseId: String,
        sectionId: String,
        fileName: String,
        contentType: String,
        sizeBytes: Int,
        extractedText: String? = nil,
        pageCount: Int? = nil,
        extractionMetadata: ExtractionMetadata? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "objectName": .string(objectName),
            "courseId": .string(courseId),
            "sectionId": .string(sectionId),
            "fileName": .string(fileName),
            "contentType": .string(contentType),
            "sizeBytes": .integer(sizeBytes)
        ]
        if let extractedText {
            payload["extractedText"] = .string(extractedText)
        }
        if let pageCount {
            payload["pageCount"] = .integer(pageCount)
        }
        if let metadata = extractionMetadata {
            payload["extractionMetadata"] = .object([
                "charCount": .integer(metadata.charCount),
                "wordCount": .integer(metadata.wordCount),
                "extractedAt": .string(ISO8601DateFormatter().string(from: metadata.extractedAt))
            ])
        }
        payload.merge(Self.documentProcessingPolicy(fileName: fileName, contentType: contentType)) { current, _ in current }
        return payload
    }

    private static func documentProcessingPolicy(fileName: String, contentType: String) -> [String: AnyJSON] {
        let normalized = "\(fileName) \(contentType)".lowercased()
        let isDocument = [
            ".pdf", "application/pdf",
            ".ppt", ".pptx", "presentation",
            ".doc", ".docx", "wordprocessing", "msword"
        ].contains { normalized.contains($0) }
        guard isDocument else { return [:] }

        let extraction = "extract_all_pages_slides_and_doc_sections_preserve_page_numbers_headings_tables_figures"
        let ocr = "run_ocr_when_pdf_or_slide_page_is_scanned_image_based_or_low_text_density"
        let readiness = "do_not_mark_ready_until_text_or_ocr_text_is_available_or_explicit_failure_is_returned"
        return [
            "extractionPolicy": .string(extraction),
            "extraction_policy": .string(extraction),
            "ocrPolicy": .string(ocr),
            "ocr_policy": .string(ocr),
            "ocrRequiredWhenSparse": .string("true"),
            "ocr_required_when_sparse": .string("true"),
            "ocrLanguageHints": .string("tr,en,medical"),
            "ocr_language_hints": .string("tr,en,medical"),
            "documentReadinessPolicy": .string(readiness),
            "document_readiness_policy": .string(readiness),
            "largeDocumentExtractionPolicy": .string("chunk_extract_then_index_full_document_not_first_pages_only"),
            "large_document_extraction_policy": .string("chunk_extract_then_index_full_document_not_first_pages_only")
        ]
    }

    public func runtimeConfig() async throws -> [String: AnyJSON] {
        try await invoke("runtime_config")
    }

    // MARK: - Course

    public func createCourse(
        _ title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["title": .string(title)]
        if let iconName, !iconName.isEmpty { payload["iconName"] = .string(iconName) }
        if let colorHex, !colorHex.isEmpty { payload["colorHex"] = .string(colorHex) }
        return try await invoke("create_course", payload: payload)
    }

    public func createSection(
        courseId: String,
        title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "courseId": .string(courseId),
            "title": .string(title)
        ]
        if let iconName, !iconName.isEmpty { payload["iconName"] = .string(iconName) }
        if let colorHex, !colorHex.isEmpty { payload["colorHex"] = .string(colorHex) }
        return try await invoke("create_section", payload: payload)
    }

    public func renameCourse(courseId: String, title: String) async throws -> [String: AnyJSON] {
        try await invoke("rename_course", payload: [
            "courseId": .string(courseId),
            "title": .string(title)
        ])
    }

    public func renameSection(sectionId: String, title: String) async throws -> [String: AnyJSON] {
        try await invoke("rename_section", payload: [
            "sectionId": .string(sectionId),
            "title": .string(title)
        ])
    }

    public func deleteCourse(_ courseId: String) async throws -> [String: AnyJSON] {
        try await invoke("delete_course", payload: ["courseId": .string(courseId)])
    }

    public func deleteSection(_ sectionId: String) async throws -> [String: AnyJSON] {
        try await invoke("delete_section", payload: ["sectionId": .string(sectionId)])
    }

    // MARK: - File Actions

    public func renameFile(fileId: String, title: String) async throws -> [String: AnyJSON] {
        try await invoke("rename_file", payload: [
            "fileId": .string(fileId),
            "title": .string(title)
        ])
    }

    public func moveFiles(fileIds: [String], courseId: String, sectionId: String) async throws -> [String: AnyJSON] {
        try await invoke("move_files", payload: [
            "fileIds": .array(fileIds.map { .string($0) }),
            "courseId": .string(courseId),
            "sectionId": .string(sectionId)
        ])
    }

    public func moveGeneratedOutput(outputId: String, courseId: String, sectionId: String) async throws -> [String: AnyJSON] {
        try await invoke("move_generated_output", payload: [
            "outputId": .string(outputId),
            "courseId": .string(courseId),
            "sectionId": .string(sectionId)
        ])
    }

    public func deleteFiles(_ fileIds: [String]) async throws -> [String: AnyJSON] {
        try await invoke("delete_files", payload: [
            "fileIds": .array(fileIds.map { .string($0) })
        ])
    }

    public func retryFileProcessing(_ fileId: String) async throws -> [String: AnyJSON] {
        try await invoke("retry_file_processing", payload: ["fileId": .string(fileId)])
    }

    public func addToCollection(fileId: String, outputId: String? = nil, collection: String? = nil) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileIds": .array([.string(fileId)])
        ]
        if let outputId, !outputId.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["outputId"] = .string(outputId.trimmingCharacters(in: .whitespaces))
        }
        if let collection, !collection.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["collection"] = .string(collection.trimmingCharacters(in: .whitespaces))
        }
        return try await invoke("add_to_collection", payload: payload)
    }

    // MARK: - Generated Outputs

    public func createGeneratedOutput(
        fileId: String,
        kind: GeneratedKind,
        itemCount: Int? = nil,
        jobId: String? = nil
    ) async throws -> [String: AnyJSON] {
        try await createGeneratedOutputByKind(
            fileId: fileId,
            kind: kind.rawValue,
            itemCount: itemCount,
            jobId: jobId
        )
    }

    public func createGeneratedOutputByKind(
        fileId: String,
        kind: String,
        itemCount: Int? = nil,
        jobId: String? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileId": .string(fileId),
            "kind": .string(kind)
        ]
        if let itemCount {
            payload["itemCount"] = .integer(itemCount)
        }
        if let jobId, !jobId.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["jobId"] = .string(jobId.trimmingCharacters(in: .whitespaces))
        }
        return try await invoke("create_generated_output", payload: payload)
    }

    // MARK: - Generation Jobs

    public func createGenerationJob(
        fileId: String,
        jobType: String,
        sourceIds: [String]? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.generationJobPayload(
            fileId: fileId,
            jobType: jobType,
            sourceIds: sourceIds,
            count: count,
            qualityTier: qualityTier,
            options: options
        )
        return try await invoke("create_generation_job", payload: payload)
    }

    static func generationJobPayload(
        fileId: String,
        jobType: String,
        sourceIds: [String]? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileId": .string(fileId),
            "jobType": .string(jobType)
        ]
        if let sourceIds, !sourceIds.isEmpty {
            payload["sourceIds"] = .array(sourceIds.map { .string($0) })
        }
        if let count {
            payload["count"] = .integer(count)
        }

        for (key, value) in premiumGenerationOptions(
            jobType: jobType,
            qualityTier: qualityTier,
            options: options
        ) {
            payload[key] = .string(value)
        }

        return payload
    }

    private static func premiumGenerationOptions(
        jobType: String,
        qualityTier: String?,
        options: [String: String]?
    ) -> [String: String] {
        var enriched = cleanGenerationOptions(options)
        let requestedTier = firstNonEmpty(
            qualityTier,
            enriched["qualityTier"],
            enriched["quality_tier"]
        )
        let tier = normalizedGenerationQualityTier(requestedTier)
        let economy = tier == "economy"
        let standard = tier == "standard"
        let profile: String = {
            if economy { return "sourcebase_premium_efficient_generation_v3" }
            if standard { return "sourcebase_premium_balanced_generation_v3" }
            return "sourcebase_premium_plus_generation_v3"
        }()

        enriched["qualityTier"] = tier
        enriched["quality_tier"] = tier
        enriched["generationQualityProfile"] = profile
        enriched["generation_quality_profile"] = profile
        enriched["generationSchemaVersion"] = profile
        enriched["generation_schema_version"] = profile

        let modelPolicy = premiumModelPolicy(for: jobType, tier: tier)
        let minimumDepth = premiumMinimumDepth(for: jobType, tier: tier)
        let lengthPolicy = premiumOutputLengthPolicy(for: jobType, tier: tier)

        enriched["modelPolicy"] = modelPolicy
        enriched["model_policy"] = modelPolicy
        enriched["minimumDepth"] = minimumDepth
        enriched["minimum_depth"] = minimumDepth
        enriched["outputLengthPolicy"] = lengthPolicy
        enriched["output_length_policy"] = lengthPolicy

        enriched["qualityGate"] = "reject_thin_generic_single_paragraph_or_source_detached_output"
        enriched["quality_gate"] = "reject_thin_generic_single_paragraph_or_source_detached_output"
        enriched["reasoningPolicy"] = "source_grounded_clinical_reasoning_before_final_answer"
        enriched["reasoning_policy"] = "source_grounded_clinical_reasoning_before_final_answer"
        enriched["sourceGroundingPolicy"] = "strict_source_grounded_mark_source_gap_no_fabrication"
        enriched["source_grounding_policy"] = "strict_source_grounded_mark_source_gap_no_fabrication"
        enriched["sourceReadPolicy"] = "read_full_extracted_document_not_first_excerpt"
        enriched["source_read_policy"] = "read_full_extracted_document_not_first_excerpt"
        enriched["sourceCoveragePolicy"] = premiumSourceCoveragePolicy(for: jobType)
        enriched["source_coverage_policy"] = premiumSourceCoveragePolicy(for: jobType)
        enriched["sourceChunkPolicy"] = "adaptive_full_document_chunk_map_reduce_for_long_sources"
        enriched["source_chunk_policy"] = "adaptive_full_document_chunk_map_reduce_for_long_sources"
        enriched["largeSourcePolicy"] = "10_pages_read_all_200_pages_chunk_index_all_sections_then_synthesize"
        enriched["large_source_policy"] = "10_pages_read_all_200_pages_chunk_index_all_sections_then_synthesize"
        enriched["ocrPolicy"] = "use_ocr_text_for_scanned_pdf_or_low_text_density_slide_pages_before_generation"
        enriched["ocr_policy"] = "use_ocr_text_for_scanned_pdf_or_low_text_density_slide_pages_before_generation"
        enriched["modelRouterPolicy"] = premiumModelRouterPolicy(for: jobType)
        enriched["model_router_policy"] = premiumModelRouterPolicy(for: jobType)
        enriched["preferredModelTier"] = premiumPreferredModelTier(for: jobType, tier: tier)
        enriched["preferred_model_tier"] = premiumPreferredModelTier(for: jobType, tier: tier)
        enriched["modelUpgradeAllowed"] = "true"
        enriched["model_upgrade_allowed"] = "true"
        enriched["pedagogyPolicy"] = "high_yield_active_recall_misconception_first"
        enriched["pedagogy_policy"] = "high_yield_active_recall_misconception_first"
        enriched["learningSciencePolicy"] = premiumLearningSciencePolicy(for: jobType)
        enriched["learning_science_policy"] = premiumLearningSciencePolicy(for: jobType)
        enriched["retrievalPracticePolicy"] = "force_commit_before_answer_with_self_check_or_questions"
        enriched["retrieval_practice_policy"] = "force_commit_before_answer_with_self_check_or_questions"
        enriched["spacedReviewPolicy"] = "include_today_24h_72h_7d_review_prompts_when_applicable"
        enriched["spaced_review_policy"] = "include_today_24h_72h_7d_review_prompts_when_applicable"
        enriched["clinicalReasoningPolicy"] = "problem_representation_differential_justification_red_flags_and_management_frame"
        enriched["clinical_reasoning_policy"] = "problem_representation_differential_justification_red_flags_and_management_frame"
        enriched["studentOutcomeContract"] = premiumStudentOutcomeContract(for: jobType)
        enriched["student_outcome_contract"] = premiumStudentOutcomeContract(for: jobType)
        enriched["antiCrutchPolicy"] = "do_not_skip_reasoning_do_not_spoonfeed_final_answer_without_check_step"
        enriched["anti_crutch_policy"] = "do_not_skip_reasoning_do_not_spoonfeed_final_answer_without_check_step"
        enriched["clinicalSafetyPolicy"] = "educational_not_diagnostic_warn_on_uncertain_or_unsafe_claims"
        enriched["clinical_safety_policy"] = "educational_not_diagnostic_warn_on_uncertain_or_unsafe_claims"
        enriched["languagePolicy"] = "clear_turkish_medical_student_level_no_filler"
        enriched["language_policy"] = "clear_turkish_medical_student_level_no_filler"
        enriched["structurePolicy"] = premiumStructurePolicy(for: jobType)
        enriched["structure_policy"] = premiumStructurePolicy(for: jobType)
        enriched["mustInclude"] = premiumMustInclude(for: jobType)
        enriched["must_include"] = premiumMustInclude(for: jobType)
        enriched["qualityChecklist"] = premiumQualityChecklist(for: jobType)
        enriched["quality_checklist"] = premiumQualityChecklist(for: jobType)
        enriched["studyWorkspaceSchema"] = premiumStudyWorkspaceSchema(for: jobType)
        enriched["study_workspace_schema"] = premiumStudyWorkspaceSchema(for: jobType)
        enriched["renderingContract"] = premiumRenderingContract(for: jobType)
        enriched["rendering_contract"] = premiumRenderingContract(for: jobType)
        if enriched["outputContract"] == nil {
            enriched["outputContract"] = premiumOutputContract(for: jobType)
        }
        if enriched["output_contract"] == nil {
            enriched["output_contract"] = enriched["outputContract"] ?? premiumOutputContract(for: jobType)
        }
        enriched["resultRouteContract"] = "create_or_reuse_generated_output_then_route_to_study_output"
        enriched["result_route_contract"] = "create_or_reuse_generated_output_then_route_to_study_output"
        enriched["ctaContract"] = "primary_cta_opens_typed_study_output_secondary_cta_returns_to_source_or_queue"
        enriched["cta_contract"] = "primary_cta_opens_typed_study_output_secondary_cta_returns_to_source_or_queue"
        enriched["finalQualityReview"] = "verify_not_plain_text_verify_schema_fields_verify_source_grounding_verify_mobile_renderability"
        enriched["final_quality_review"] = "verify_not_plain_text_verify_schema_fields_verify_source_grounding_verify_mobile_renderability"
        enriched["thinOutputRecovery"] = "if_output_is_short_or_generic_expand_before_returning"
        enriched["thin_output_recovery"] = "if_output_is_short_or_generic_expand_before_returning"
        enriched["reviewBeforeReturn"] = "true"
        enriched["review_before_return"] = "true"

        switch normalizedGenerationJobType(jobType) {
        case "podcast":
            enriched["audioAssetRequired"] = enriched["audioAssetRequired"] ?? "true"
            enriched["audio_asset_required"] = enriched["audio_asset_required"] ?? "true"
            enriched["audioFormat"] = enriched["audioFormat"] ?? "m4a_or_mp3_exportable"
            enriched["audio_format"] = enriched["audio_format"] ?? "m4a_or_mp3_exportable"
        case "infographic":
            let imageModel = premiumImageModel(for: tier)
            let imageQuality = premiumImageQuality(for: tier)
            enriched["visualAssetRequired"] = enriched["visualAssetRequired"] ?? "true"
            enriched["visual_asset_required"] = enriched["visual_asset_required"] ?? "true"
            enriched["assetFallbackPolicy"] = enriched["assetFallbackPolicy"] ?? "structured_text_blocks_when_image_unavailable"
            enriched["asset_fallback_policy"] = enriched["asset_fallback_policy"] ?? "structured_text_blocks_when_image_unavailable"
            enriched["imageModelPolicy"] = imageModel
            enriched["image_model_policy"] = imageModel
            enriched["gptImageModel"] = imageModel
            enriched["gpt_image_model"] = imageModel
            enriched["openaiImageModel"] = imageModel
            enriched["openai_image_model"] = imageModel
            enriched["imageQuality"] = imageQuality
            enriched["image_quality"] = imageQuality
            enriched["visualReadabilityPolicy"] = enriched["visualReadabilityPolicy"] ?? "large_clear_labels_mobile_readable_no_tiny_text"
            enriched["visual_readability_policy"] = enriched["visual_readability_policy"] ?? "large_clear_labels_mobile_readable_no_tiny_text"
        default:
            break
        }

        if enriched["backendQualityBrief"] == nil {
            enriched["backendQualityBrief"] = premiumBackendBrief(for: jobType)
        }
        if enriched["backend_quality_brief"] == nil {
            enriched["backend_quality_brief"] = premiumBackendBrief(for: jobType)
        }

        return enriched
    }

    private static func cleanGenerationOptions(_ options: [String: String]?) -> [String: String] {
        guard let options else { return [:] }
        return options.reduce(into: [String: String]()) { partial, pair in
            let key = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return }
            partial[key] = value
        }
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func normalizedGenerationQualityTier(_ rawValue: String?) -> String {
        let value = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if value.contains("economy")
            || value.contains("economic")
            || value.contains("ekonomik")
            || value.contains("ucuz")
            || value.contains("cost_saver") {
            return "economy"
        }
        if value.contains("standard")
            || value.contains("standart") {
            return "standard"
        }
        return "premium"
    }

    private static func premiumImageModel(for tier: String) -> String {
        switch tier {
        case "economy":
            return "gpt-image-1-mini"
        case "standard":
            return "gpt-image-1.5"
        default:
            return "gpt-image-2"
        }
    }

    private static func premiumImageQuality(for tier: String) -> String {
        switch tier {
        case "economy":
            return "low"
        case "standard":
            return "standard"
        default:
            return "premium"
        }
    }

    private static func premiumModelPolicy(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            return premiumEfficientModelPolicy(for: jobType)
        }
        if tier == "standard" {
            return premiumBalancedModelPolicy(for: jobType)
        }
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "premium_latest_long_context_assessment_quality_first"
        case "clinical_scenario":
            return "premium_latest_long_context_clinical_reasoning_first"
        case "infographic":
            return "premium_latest_long_context_visual_quality_first"
        case "podcast":
            return "premium_latest_long_context_longform_learning_quality"
        case "flashcard":
            return "premium_latest_long_context_active_recall_quality_first"
        case "comparison", "table":
            return "premium_latest_long_context_matrix_reasoning_first"
        case "summary", "exam_morning_summary":
            return "premium_latest_long_context_summary_synthesis_first"
        case "learning_plan":
            return "premium_latest_long_context_adaptive_study_planning"
        default:
            return "premium_latest_long_context_structured_reasoning_first"
        }
    }

    private static func premiumEfficientModelPolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "premium_efficient_long_context_assessment_quality_first"
        case "clinical_scenario":
            return "premium_efficient_long_context_clinical_reasoning_first"
        case "infographic":
            return "premium_efficient_long_context_visual_quality_first"
        case "podcast":
            return "premium_efficient_long_context_longform_learning_quality"
        case "flashcard":
            return "premium_efficient_long_context_active_recall_quality_first"
        case "comparison", "table":
            return "premium_efficient_long_context_matrix_reasoning_first"
        case "summary", "exam_morning_summary":
            return "premium_efficient_long_context_summary_synthesis_first"
        case "learning_plan":
            return "premium_efficient_long_context_adaptive_study_planning"
        default:
            return "premium_efficient_long_context_structured_reasoning_first"
        }
    }

    private static func premiumBalancedModelPolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "premium_balanced_long_context_assessment_quality_first"
        case "clinical_scenario":
            return "premium_balanced_long_context_clinical_reasoning_first"
        case "infographic":
            return "premium_balanced_long_context_visual_quality_first"
        case "podcast":
            return "premium_balanced_long_context_longform_learning_quality"
        case "flashcard":
            return "premium_balanced_long_context_active_recall_quality_first"
        case "comparison", "table":
            return "premium_balanced_long_context_matrix_reasoning_first"
        case "summary", "exam_morning_summary":
            return "premium_balanced_long_context_summary_synthesis_first"
        case "learning_plan":
            return "premium_balanced_long_context_adaptive_study_planning"
        default:
            return "premium_balanced_long_context_structured_reasoning_first"
        }
    }

    private static func premiumSourceCoveragePolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "comparison", "table":
            return "all_selected_sources_all_sections_tables_middle_end_and_conclusions"
        case "quiz", "question":
            return "all_testable_objectives_tables_figures_common_misconceptions_and_edge_cases"
        case "flashcard":
            return "all_core_concepts_definitions_mechanisms_tables_figures_and_common_mistakes"
        case "algorithm":
            return "all_decision_points_thresholds_exceptions_red_flags_and_actions"
        case "clinical_scenario":
            return "full_case_relevant_source_findings_labs_decisions_differential_and_safety_limits"
        case "podcast":
            return "full_source_episode_arc_beginning_middle_end_tables_and_recap"
        case "infographic":
            return "full_source_visual_hierarchy_warnings_main_message_and_text_fallback"
        case "learning_plan":
            return "full_source_objectives_weak_points_sessions_reviews_and_gap_closure"
        case "mind_map":
            return "full_source_branches_cross_links_confusions_and_clinical_ties"
        default:
            return "full_source_beginning_middle_end_headings_tables_conclusions_red_flags_and_self_check"
        }
    }

    private static func premiumModelRouterPolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "comparison", "table", "clinical_scenario", "podcast", "infographic":
            return "route_large_or_sparse_sources_to_long_context_high_reasoning_model"
        default:
            return "route_to_long_context_reasoning_when_source_or_quality_requires_it"
        }
    }

    private static func premiumPreferredModelTier(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            return "latest_premium_efficient_long_context"
        }
        if tier == "standard" {
            return "latest_premium_balanced_long_context"
        }
        switch normalizedGenerationJobType(jobType) {
        case "comparison", "table", "clinical_scenario", "podcast", "infographic":
            return "latest_premium_high_reasoning_long_context"
        default:
            return "latest_premium_reasoning_long_context"
        }
    }

    private static func premiumMinimumDepth(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            switch normalizedGenerationJobType(jobType) {
            case "comparison", "table":
                return "efficient_full_source_matrix_deep"
            case "clinical_scenario":
                return "efficient_clinical_deep_with_differential"
            case "quiz", "question":
                return "efficient_assessment_deep_with_distractor_rationales"
            case "infographic":
                return "efficient_visual_detailed_with_text_fallback"
            case "podcast":
                return "efficient_longform_deep_segmented"
            default:
                return "premium_efficient_deep_with_gap_analysis"
            }
        }
        if tier == "standard" {
            switch normalizedGenerationJobType(jobType) {
            case "comparison", "table":
                return "balanced_full_source_matrix_deep"
            case "clinical_scenario":
                return "balanced_clinical_deep_with_differential"
            case "quiz", "question":
                return "balanced_assessment_deep_with_distractor_rationales"
            case "infographic":
                return "balanced_visual_detailed_with_text_fallback"
            case "podcast":
                return "balanced_longform_deep_segmented"
            default:
                return "premium_balanced_deep"
            }
        }
        switch normalizedGenerationJobType(jobType) {
        case "clinical_scenario":
            return "clinical_deep_with_differential"
        case "quiz", "question":
            return "assessment_deep_with_distractor_rationales"
        case "infographic":
            return "visual_detailed_with_text_fallback"
        case "podcast":
            return "longform_deep_segmented"
        case "comparison", "table":
            return "full_source_matrix_deep"
        default:
            return "premium_deep"
        }
    }

    private static func premiumOutputLengthPolicy(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            switch normalizedGenerationJobType(jobType) {
            case "flashcard", "quiz", "question":
                return "complete_set_compact_explanations_not_short"
            case "podcast":
                return "compact_longform_complete_not_padded"
            default:
                return "compact_structured_but_complete"
            }
        }
        if tier == "standard" {
            switch normalizedGenerationJobType(jobType) {
            case "flashcard", "quiz", "question":
                return "complete_set_balanced_explanations_not_short"
            case "podcast":
                return "balanced_longform_complete_not_padded"
            default:
                return "balanced_comprehensive_structured_not_short"
            }
        }
        switch normalizedGenerationJobType(jobType) {
        case "podcast":
            return "longform_comprehensive_not_padded"
        case "flashcard", "quiz", "question":
            return "complete_set_not_short"
        default:
            return "comprehensive_structured_not_short"
        }
    }

    private static func premiumStructurePolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "atomic_cards_grouped_by_concept_with_hint_and_common_mistake"
        case "quiz", "question":
            return "five_choice_questions_hidden_answer_rationales_and_traps"
        case "summary", "exam_morning_summary":
            return "scan_ready_sections_tables_red_flags_and_quick_check"
        case "algorithm":
            return "mobile_decision_nodes_with_red_flags_and_exit_actions"
        case "comparison", "table":
            return "full_source_same_criteria_matrix_with_source_coverage_refs_distinguishing_clues_and_exam_traps"
        case "clinical_scenario":
            return "case_stem_findings_differential_decision_points_feedback"
        case "learning_plan":
            return "time_blocks_spaced_repetition_measurement_and_gap_closure"
        case "podcast":
            return "episode_segments_spoken_script_recap_and_recall_prompts"
        case "infographic":
            return "visual_blocks_main_message_warnings_source_note_text_fallback"
        case "mind_map":
            return "central_concept_branches_links_confusions_and_clinical_ties"
        default:
            return "clear_sections_key_takeaways_and_recovery_prompts"
        }
    }

    private static func premiumMustInclude(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "front,back,hint,explanation,common_mistake,concept_group"
        case "quiz", "question":
            return "5_options,single_correct_answer,wrong_option_rationales,source_grounded_explanation,qlinik_candidate_schema"
        case "summary", "exam_morning_summary":
            return "high_yield_points,common_confusions,red_flags,mini_table,final_self_check"
        case "algorithm":
            return "entry_criteria,decision_nodes,yes_no_or_step_flow,warning_points,exit_actions"
        case "comparison", "table":
            return "source_coverage,minimum_8_aligned_criteria_or_source_gap,source_refs,distinguishing_clues,clinical_exam_traps,short_takeaway"
        case "clinical_scenario":
            return "patient_snapshot,critical_findings,differential_diagnosis,decision_points,teaching_feedback"
        case "learning_plan":
            return "time_blocks,spaced_review,mini_assessment,gap_closure_tasks"
        case "podcast":
            return "segments,spoken_script,key_repeats,recap,source_limits"
        case "infographic":
            return "main_message,at_least_5_blocks,warnings,source_note,structured_text_fallback"
        case "mind_map":
            return "central_concept,at_least_4_branches,child_nodes,confusions,cross_links"
        default:
            return "source_summary,key_points,misconceptions,next_action"
        }
    }

    private static func premiumQualityChecklist(for jobType: String) -> String {
        let common = "source_grounded;no_hallucination;not_generic;clinically_safe;mobile_scannable;active_recall;spaced_review_prompt;source_gap_visible"
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "\(common);5_options;answer_hidden_until_solution;all_distractors_explained"
        case "flashcard":
            return "\(common);atomic_cards;active_recall;common_mistake_per_cluster"
        case "clinical_scenario":
            return "\(common);differential_reasoning;red_flags;feedback"
        case "infographic":
            return "\(common);visual_or_text_fallback;at_least_5_blocks"
        case "comparison", "table":
            return "\(common);full_source_read;minimum_8_criteria_or_gap;source_refs;not_intro_only"
        default:
            return "\(common);full_source_read;enough_depth_for_paid_output"
        }
    }

    private static func premiumBackendBrief(for jobType: String) -> String {
        "Produce a premium SourceBase output for \(normalizedGenerationJobType(jobType)): read the full extracted document, never rely only on the intro or first excerpt, use OCR text for scanned or low-text-density pages, and for long decks/documents chunk-map-reduce across beginning, middle, end, tables, figures, headings, and conclusions. Route to a long-context reasoning model when the source is large or the first pass is thin. Identify gaps and likely misconceptions, stay strictly grounded in the source, mark missing evidence instead of inventing, and return typed JSON blocks for the interactive study workspace. Every output must help a medical student actively retrieve, review later, and connect facts to clinical reasoning: include recall prompts, common traps, review timing, source gaps, and when relevant problem representation, differential diagnosis, diagnostic justification, red flags, and management framing. Expand the result before returning if it feels thin, generic, single-paragraph, or impossible to render as visual study cards."
    }

    private static func premiumLearningSciencePolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "retrieval_practice_atomic_cards_spaced_review_common_mistake_feedback"
        case "quiz", "question":
            return "test_enhanced_learning_five_choice_commitment_rationales_error_correction"
        case "clinical_scenario":
            return "case_based_clinical_reasoning_problem_representation_differential_justification_feedback"
        case "learning_plan":
            return "spaced_practice_interleaving_retrieval_checkpoints_gap_closure"
        case "podcast":
            return "dual_coding_audio_recap_retrieval_pauses_and_later_review_prompts"
        case "infographic", "mind_map":
            return "dual_coding_visual_hierarchy_active_recall_and_common_confusion_links"
        default:
            return "spaced_practice_retrieval_practice_interleaving_elaboration_dual_coding_concrete_examples"
        }
    }

    private static func premiumStudentOutcomeContract(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "student_can_cover_answer_recall_explain_common_mistake_and_schedule_next_review"
        case "quiz", "question":
            return "student_commits_to_answer_receives_rationale_reviews_wrong_options_and_knows_weak_topic"
        case "clinical_scenario":
            return "student_forms_problem_representation_lists_differential_justifies_top_diagnosis_and_names_red_flags"
        case "learning_plan":
            return "student_knows_what_to_do_today_next_24h_72h_7d_and_how_to_measure_progress"
        case "comparison", "table":
            return "student_can_distinguish_entities_by_same_criteria_exam_traps_source_refs_and_red_flags"
        case "algorithm":
            return "student_can_enter_from_symptom_or_finding_follow_decisions_and_stop_at_red_flags"
        case "podcast":
            return "student_can_list_key_points_after_listening_answer_recall_prompts_and_export_audio"
        case "infographic":
            return "student_can_scan_main_message_warnings_blocks_and_quick_check_without_plain_text_dump"
        case "mind_map":
            return "student_can_explain_central_concept_branches_cross_links_and_common_confusions"
        default:
            return "student_can_study_actively_review_later_identify_gaps_and_verify_source_grounding"
        }
    }

    private static func premiumStudyWorkspaceSchema(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "cards[{front,back,hint,explanation,difficulty,concept_group,common_mistake}],summary,source_gaps"
        case "quiz", "question":
            return "questions[{text,options[5],correct_index,explanation,option_rationales[5],topic,difficulty,tags}],summary,source_gaps"
        case "summary", "exam_morning_summary":
            return "summary,high_yield_points,must_know,commonly_confused,red_flags,mini_table{headers,rows},clinicalDecisionFlow,self_check,next_review_prompts,source_gaps"
        case "algorithm":
            return "starting_point,decision_nodes[{title,detail,yes,no,substeps}],action_steps,critical_thresholds,red_flags,exam_tips,source_gaps"
        case "comparison", "table":
            return "title,summary,source_coverage,headers,criteria,rows[{criterion,values,distinguishing_tip,exam_trap,source_refs}],distinguishing_tips,clinical_notes,commonly_confused,red_flags,short_takeaway,source_gaps"
        case "clinical_scenario":
            return "patientInfo,chiefComplaint,caseStem,physicalExam,labsImaging,problemRepresentation,findings,differentialDiagnosis,diagnosticJustification,decision_nodes,questions,red_flags,teachingPoints,examTips"
        case "learning_plan":
            return "duration,sessions[{title,estimatedMinutes,activities}],startToday,dailyGoals,checklist,reviewDays,next_review_prompts,weakPoints,objectives,questionFlashcardSuggestions"
        case "podcast":
            return "title,durationLabel,audio_url_optional,segments[{title,text,durationLabel}],recap,active_recall_prompts,source_limits"
        case "infographic":
            return "title,main_message,image_url_optional,sections[{heading,bullets}],warnings,red_flags,source_note,quick_check"
        case "mind_map":
            return "centralTopic,summary,branches[{label,children,tags}],criticalConnections,commonly_confused,clinicalTusTips,source_gaps"
        default:
            return "summary,sections,high_yield_points,red_flags,self_check,source_gaps"
        }
    }

    private static func premiumRenderingContract(for jobType: String) -> String {
        "Return structured JSON for SourceBase interactive study surfaces, not plain prose. The app renders Learn, Flow, and Check layers; include enough typed fields to populate visual cards, tables, timelines, decision nodes, and active-recall controls for \(normalizedGenerationJobType(jobType)). Shallow first-excerpt answers, underfilled cards, and generic two-row tables must be expanded or rejected before return."
    }

    private static func premiumOutputContract(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "Return cards[{front,back,hint,explanation,difficulty,concept_group,common_mistake}], summary, source_gaps. Minimum 20 atomic cards unless source is genuinely smaller and source_gaps explains why."
        case "quiz", "question":
            return "Return questions[{text,options[5],correct_index,explanation,option_rationales[5],topic,difficulty,tags}], summary, source_gaps. Every distractor must be plausible and explained."
        case "summary", "exam_morning_summary":
            return "Return summary, high_yield_points, must_know, commonly_confused, red_flags, mini_table{headers,rows}, clinicalDecisionFlow, self_check, next_review_prompts, source_gaps. Never return a single paragraph only."
        case "algorithm":
            return "Return starting_point, decision_nodes[{title,detail,yes,no,substeps}], action_steps, critical_thresholds, red_flags, exam_tips, notes, source_gaps."
        case "comparison", "table":
            return "Return title, summary, source_coverage, headers, rows[{criterion,values,distinguishing_tip,exam_trap,source_refs}], distinguishing_tips, clinical_notes, commonly_confused, red_flags, short_takeaway, source_gaps. At least 8 aligned criteria or explain the source gap."
        case "clinical_scenario":
            return "Return patientInfo, chiefComplaint, caseStem, physicalExam, labsImaging, problemRepresentation, findings, differentialDiagnosis, diagnosticJustification, decision_nodes, questions, red_flags, teachingPoints, examTips."
        case "learning_plan":
            return "Return duration, sessions[{title,estimatedMinutes,activities}], startToday, dailyGoals, checklist, reviewDays, next_review_prompts, weakPoints, objectives, questionFlashcardSuggestions."
        case "podcast":
            return "Return title, durationLabel, audio_url when available, segments[{title,text,durationLabel}], recap, active_recall_prompts, source_limits. If audio is delayed, full transcript is still required."
        case "infographic":
            return "Return title, main_message, image_url when available, sections[{heading,bullets}], warnings, red_flags, source_note, quick_check. If image fails, structured text blocks are required."
        case "mind_map":
            return "Return centralTopic, summary, branches[{label,children,tags}], criticalConnections, commonly_confused, clinicalTusTips, source_gaps."
        default:
            return "Return structured SourceBase study JSON with summary, typed sections, active recall, source gaps, and no plain prose only."
        }
    }

    private static func normalizedGenerationJobType(_ jobType: String) -> String {
        jobType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
    }

    public func getJobStatus(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("get_job_status", payload: ["jobId": .string(jobId)])
    }

    public func processGenerationJob(_ jobId: String) async throws -> [String: AnyJSON] {
        // The server processes generation synchronously inside this call and the
        // edge worker stays alive up to ~5 min. Keep the connection open well past
        // any realistic generation (text/image/podcast-TTS) so the worker is never
        // killed for idleness mid-generation and we receive the real result.
        try await invoke("process_generation_job", payload: ["jobId": .string(jobId)], timeoutSeconds: 320)
    }

    public func getGeneratedContent(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("get_generated_content", payload: ["jobId": .string(jobId)])
    }

    public func estimateGenerationCost(
        jobType: String,
        sourceTextLength: Int? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.estimateGenerationCostPayload(
            jobType: jobType,
            sourceTextLength: sourceTextLength,
            count: count,
            qualityTier: qualityTier,
            options: options
        )
        return try await invoke("estimate_generation_cost", payload: payload)
    }

    static func estimateGenerationCostPayload(
        jobType: String,
        sourceTextLength: Int? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["jobType": .string(jobType)]
        if let sourceTextLength {
            payload["sourceTextLength"] = .integer(sourceTextLength)
        }
        if let count {
            payload["count"] = .integer(count)
        }

        for (key, value) in premiumGenerationOptions(
            jobType: jobType,
            qualityTier: qualityTier,
            options: options
        ) {
            payload[key] = .string(value)
        }

        return payload
    }

    public func listUserJobs(limit: Int? = nil) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [:]
        if let limit {
            payload["limit"] = .integer(limit)
        }
        return try await invoke("list_user_jobs", payload: payload)
    }

    public func cancelJob(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("cancel_job", payload: ["jobId": .string(jobId)])
    }

    public func retryJob(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("retry_job", payload: ["jobId": .string(jobId)])
    }

    public func purchaseMedasiCoin(
        productCode: String,
        successURL: String,
        cancelURL: String
    ) async throws -> [String: AnyJSON] {
        try await invoke("purchase_medasicoin", payload: [
            "product_code": .string(productCode),
            "success_url": .string(successURL),
            "cancel_url": .string(cancelURL)
        ])
    }

    /// Redeem a verified StoreKit 2 transaction on the backend.
    /// Returns the updated wallet balance in MC.
    public func redeemAppStorePurchase(
        transactionId: String,
        productId: String,
        jws: String
    ) async throws -> Double {
        let response = try await invoke("redeem_appstore_purchase", payload: [
            "transactionId": .string(transactionId),
            "productId": .string(productId),
            "jws": .string(jws)
        ])
        // Extract wallet_balance from response data
        if case .object(let data) = response["data"],
           let balanceValue = data["wallet_balance"] {
            switch balanceValue {
            case .double(let d): return d
            case .integer(let i): return Double(i)
            case .string(let s): return Double(s) ?? 0
            default: break
            }
        }
        return 0
    }

    // MARK: - Storage quota / subscriptions

    /// Current storage usage + effective quota (free 25 GB + active subscriptions).
    public func storageStatus() async throws -> SBStorageStatus {
        let response = try await invoke("get_storage_status", payload: [:])
        return Self.parseStorageStatus(response["data"])
    }

    /// Redeem a verified StoreKit 2 storage subscription; returns the updated quota.
    public func redeemStorageSubscription(jws: String) async throws -> SBStorageStatus {
        let response = try await invoke("redeem_storage_subscription", payload: [
            "jws": .string(jws)
        ])
        return Self.parseStorageStatus(response["data"])
    }

    private static func parseStorageStatus(_ data: AnyJSON?) -> SBStorageStatus {
        guard let dict = data?.dictValue else { return .empty }
        func bytes(_ key: String) -> Int {
            if let i = dict[key]?.intValue { return i }
            if let d = dict[key]?.doubleValue { return Int(d) }
            return 0
        }
        let plans = (dict["plans"]?.arrayValue ?? []).compactMap { item -> SBStoragePlan? in
            guard let row = item.dictValue else { return nil }
            let code = row["product_code"]?.stringValue ?? ""
            guard !code.isEmpty else { return nil }
            let bonus = row["bonus_bytes"]?.intValue ?? row["bonus_bytes"]?.doubleValue.map(Int.init) ?? 0
            return SBStoragePlan(productCode: code, bonusBytes: bonus, expiresAt: row["expires_at"]?.stringValue)
        }
        let base = bytes("baseBytes")
        let bonus = bytes("bonusBytes")
        let total = bytes("totalBytes")
        return SBStorageStatus(
            usedBytes: bytes("usedBytes"),
            baseBytes: base,
            bonusBytes: bonus,
            totalBytes: total > 0 ? total : base + bonus,
            plans: plans
        )
    }

    // MARK: - Study Sessions

    public func sourcebaseQuestionSession(outputId: String) async throws -> [String: AnyJSON] {
        try await invoke("sourcebase_question_session", payload: [
            "outputId": .string(outputId)
        ])
    }

    public func submitSourcebaseQuestionAnswer(
        outputId: String,
        questionId: String,
        selectedIndex: Int,
        elapsedSeconds: Int? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.questionAnswerPayload(
            outputId: outputId,
            questionId: questionId,
            selectedIndex: selectedIndex,
            elapsedSeconds: elapsedSeconds
        )
        return try await invoke("submit_sourcebase_question_answer", payload: payload)
    }

    public static func questionAnswerPayload(
        outputId: String,
        questionId: String,
        selectedIndex: Int,
        elapsedSeconds: Int? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "outputId": .string(outputId),
            "questionId": .string(questionId),
            "selectedIndex": .integer(selectedIndex)
        ]
        if let elapsedSeconds {
            payload["elapsedSeconds"] = .integer(elapsedSeconds)
        }
        return payload
    }

    // MARK: - Generated Assets

    public func generatedAssetURL(assetPath: String, outputId: String? = nil) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["assetPath": .string(assetPath)]
        if let outputId, !outputId.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["outputId"] = .string(outputId)
        }
        return try await invoke("get_generated_asset_url", payload: payload)
    }

    // MARK: - Profile Assets & Support

    public func createProfileAvatarUploadSession(
        fileName: String,
        contentType: String,
        sizeBytes: Int
    ) async throws -> StorageUploadSession {
        let response = try await invoke(
            "create_profile_avatar_upload_session",
            payload: Self.profileAvatarUploadPayload(
                fileName: fileName,
                contentType: contentType,
                sizeBytes: sizeBytes
            )
        )
        guard case .object(let dataDict) = response["data"] else {
            throw DriveAPIError(message: "Avatar upload session response is empty.", code: nil, status: nil)
        }
        let jsonData = try JSONEncoder().encode(dataDict)
        return try JSONDecoder().decode(StorageUploadSession.self, from: jsonData)
    }

    public static func profileAvatarUploadPayload(
        fileName: String,
        contentType: String,
        sizeBytes: Int
    ) -> [String: AnyJSON] {
        [
            "fileName": .string(fileName),
            "contentType": .string(contentType),
            "sizeBytes": .integer(sizeBytes)
        ]
    }

    public func completeProfileAvatarUpload(objectName: String) async throws -> [String: AnyJSON] {
        try await invoke("complete_profile_avatar_upload", payload: [
            "objectName": .string(objectName)
        ])
    }

    public func submitSupportForm(
        topic: String,
        email: String,
        message: String
    ) async throws -> [String: AnyJSON] {
        try await invoke("submit_support_form", payload: Self.supportFormPayload(
            topic: topic,
            email: email,
            message: message
        ))
    }

    public static func supportFormPayload(
        topic: String,
        email: String,
        message: String
    ) -> [String: AnyJSON] {
        [
            "topic": .string(topic.trimmingCharacters(in: .whitespacesAndNewlines)),
            "email": .string(email.trimmingCharacters(in: .whitespacesAndNewlines)),
            "message": .string(message.trimmingCharacters(in: .whitespacesAndNewlines))
        ]
    }

    // MARK: - Central AI

    public func centralAiChat(
        _ message: String,
        context: String? = nil,
        fileIds: [String]? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["message": .string(message)]

        if let context, !context.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["context"] = .string(context.trimmingCharacters(in: .whitespaces))
        }
        if let fileIds {
            let clean = Array(Set(fileIds
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            ))
            if !clean.isEmpty {
                payload["fileIds"] = .array(clean.map { .string($0) })
            }
        }

        return try await invoke("central_ai_chat", payload: payload)
    }

    public func requestAccountDeletion() async throws -> [String: AnyJSON] {
        try await invoke("request_account_deletion")
    }
}

private struct DriveAPITimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        "SourceBase request timed out."
    }
}

private func withDriveAPITimeout<T: Sendable>(
    seconds: UInt64 = 90,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            throw DriveAPITimeoutError()
        }
        guard let result = try await group.next() else {
            throw DriveAPITimeoutError()
        }
        group.cancelAll()
        return result
    }
}
