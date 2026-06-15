import XCTest
import Supabase
@testable import SourceBaseBackend

final class DriveTests: XCTestCase {
    private func string(_ value: AnyJSON?) -> String? {
        guard case .string(let string) = value else { return nil }
        return string
    }

    // MARK: - Models

    func testDriveWorkspaceDataEmpty() {
        let workspace = DriveWorkspaceData.empty
        XCTAssertTrue(workspace.courses.isEmpty)
        XCTAssertTrue(workspace.recentFiles.isEmpty)
        XCTAssertNil(workspace.primaryCourse)
    }

    func testUploadDraftToJSON() {
        let draft = DriveUploadDraft(
            fileName: "test.pdf",
            contentType: "application/pdf",
            sizeBytes: 1024,
            courseId: "course-1",
            sectionId: "section-1"
        )
        let json = draft.toJSON()
        XCTAssertEqual(json["fileName"], "test.pdf")
        XCTAssertEqual(json["courseId"], "course-1")
    }

    func testUploadSessionPayloadKeepsSizeAsInteger() {
        let draft = DriveUploadDraft(
            fileName: "test.pdf",
            contentType: "application/pdf",
            sizeBytes: 1024,
            courseId: "course-1",
            sectionId: "section-1"
        )

        let payload = DriveAPI.uploadSessionPayload(for: draft)
        guard case .integer(let sizeBytes) = payload["sizeBytes"] else {
            return XCTFail("sizeBytes must be sent as a JSON integer.")
        }

        XCTAssertEqual(sizeBytes, 1024)
        XCTAssertEqual(string(payload["ocr_required_when_sparse"]), "true")
        XCTAssertTrue(string(payload["ocr_policy"])?.contains("low_text_density") == true)
        XCTAssertTrue(string(payload["large_document_extraction_policy"])?.contains("not_first_pages_only") == true)
    }

    func testDriveAPIHTTPErrorParsesEdgeErrorBody() throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "ok": false,
            "error": [
                "code": "INVALID_UPLOAD",
                "message": "Dosya yükleme isteği geçersiz.",
                "status": 400
            ]
        ])

        let error = DriveAPI.httpError(status: 400, data: body)
        XCTAssertEqual(error.message, "Dosya yükleme isteği geçersiz.")
        XCTAssertEqual(error.code, "INVALID_UPLOAD")
        XCTAssertEqual(error.status, 400)
    }

    func testStorageUploadSessionUsable() {
        let session = StorageUploadSession(
            uploadURL: "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            objectName: "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            bucket: "medasistorage",
            headers: [:],
            expiresAt: Date().addingTimeInterval(300)
        )
        XCTAssertTrue(session.isUsable)
    }

    func testStorageUploadSessionNotUsable() {
        let session = StorageUploadSession(
            uploadURL: "",
            objectName: "",
            bucket: "",
            headers: [:],
            expiresAt: Date()
        )
        XCTAssertFalse(session.isUsable)
    }

    func testStorageUploadSessionNearExpiryNotUsable() {
        let session = StorageUploadSession(
            uploadURL: "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            objectName: "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            bucket: "medasistorage",
            headers: [:],
            expiresAt: Date().addingTimeInterval(10)
        )
        XCTAssertFalse(session.isUsable)
    }

    func testCompleteUploadPayloadIncludesClientExtractionContract() {
        let extractedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let payload = DriveAPI.completeUploadPayload(
            objectName: "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            courseId: "course-1",
            sectionId: "section-1",
            fileName: "test.pdf",
            contentType: "application/pdf",
            sizeBytes: 2_048,
            extractedText: "Sayfa 1\nKlinik kaynak metni",
            pageCount: 12,
            extractionMetadata: ExtractionMetadata(
                charCount: 27,
                wordCount: 5,
                extractedAt: extractedAt
            )
        )

        XCTAssertEqual(string(payload["extractedText"]), "Sayfa 1\nKlinik kaynak metni")
        guard case .integer(let pageCount) = payload["pageCount"] else {
            return XCTFail("pageCount must be sent as an integer.")
        }
        XCTAssertEqual(pageCount, 12)
        guard case .object(let metadata) = payload["extractionMetadata"] else {
            return XCTFail("extractionMetadata must be sent as an object.")
        }
        guard case .integer(let charCount) = metadata["charCount"],
              case .integer(let wordCount) = metadata["wordCount"] else {
            return XCTFail("Client extraction counts must be JSON integers.")
        }
        XCTAssertEqual(charCount, 27)
        XCTAssertEqual(wordCount, 5)
        XCTAssertEqual(string(metadata["extractedAt"]), ISO8601DateFormatter().string(from: extractedAt))
        XCTAssertEqual(string(payload["ocr_required_when_sparse"]), "true")
    }

    func testStorageUploadSessionDecodesFractionalSecondExpiry() throws {
        // Deno's `new Date().toISOString()` always includes milliseconds.
        let future = ISO8601DateFormatter()
        future.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiry = future.string(from: Date().addingTimeInterval(300))

        let json = try JSONSerialization.data(withJSONObject: [
            "uploadUrl": "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            "objectName": "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            "bucket": "medasistorage",
            "headers": [:],
            "expiresAt": expiry
        ])

        let session = try JSONDecoder().decode(StorageUploadSession.self, from: json)
        XCTAssertTrue(session.isUsable, "Fractional-second ISO8601 expiry must parse, not fall back to distantPast.")
    }

    func testStorageUploadSessionDecodesNumericEpochExpiry() throws {
        let epoch = Date().addingTimeInterval(300).timeIntervalSince1970
        let json = try JSONSerialization.data(withJSONObject: [
            "uploadUrl": "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            "objectName": "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            "bucket": "medasistorage",
            "headers": [:],
            "expiresAt": epoch
        ])

        let session = try JSONDecoder().decode(StorageUploadSession.self, from: json)
        XCTAssertTrue(session.isUsable)
    }

    func testDriveDestinationRequiresCourseAndSection() {
        XCTAssertTrue(DriveDestination(
            courseId: "course-1",
            sectionId: "section-1",
            courseTitle: "Anatomi",
            sectionTitle: "Kas"
        ).isUsable)

        XCTAssertFalse(DriveDestination(
            courseId: "course-1",
            sectionId: "",
            courseTitle: "Anatomi",
            sectionTitle: ""
        ).isUsable)
    }

    func testPickedDriveFileCanBeURLBacked() throws {
        let url = URL(fileURLWithPath: "/tmp/sourcebase-test.pdf")
        let file = PickedDriveFile(
            name: "sourcebase-test.pdf",
            contentType: "application/pdf",
            sizeBytes: 42,
            fileURL: url
        )

        XCTAssertTrue(file.hasSupportedExtension)
        XCTAssertTrue(file.hasReadableContent)
        XCTAssertNil(file.data)
        XCTAssertEqual(file.fileURL, url)
    }

    func testPickedDriveFileSupportedExtensions() {
        for name in ["document.pdf", "deck.pptx", "legacy.PPT", "notes.docx", "legacy.DOC"] {
            let file = PickedDriveFile(
                name: name,
                contentType: DriveUploadService.contentTypeFor(name),
                sizeBytes: 100,
                data: Data([1, 2, 3])
            )
            XCTAssertTrue(file.hasSupportedExtension, "\(name) should be accepted by extension.")
            XCTAssertTrue(file.hasReadableContent)
        }
    }

    func testPickedDriveFileUnsupportedExtension() {
        let file = PickedDriveFile(
            name: "image.png",
            contentType: "image/png",
            sizeBytes: 100,
            data: Data()
        )
        XCTAssertFalse(file.hasSupportedExtension)
        XCTAssertFalse(file.hasReadableContent)
    }

    // MARK: - Enums

    func testGeneratedKindJobType() {
        XCTAssertEqual(GeneratedKind.flashcard.jobType, "flashcard")
        XCTAssertEqual(GeneratedKind.question.jobType, "quiz")
        XCTAssertEqual(GeneratedKind.summary.jobType, "summary")
        XCTAssertEqual(GeneratedKind.examMorningSummary.jobType, "exam_morning_summary")
        XCTAssertEqual(GeneratedKind.clinicalScenario.jobType, "clinical_scenario")
        XCTAssertEqual(GeneratedKind.learningPlan.jobType, "learning_plan")
        XCTAssertEqual(GeneratedKind.podcast.jobType, "podcast")
        XCTAssertEqual(GeneratedKind.infographic.jobType, "infographic")
        XCTAssertEqual(GeneratedKind.mindMap.jobType, "mind_map")
    }

    func testGeneratedKindDefaultCount() {
        XCTAssertEqual(GeneratedKind.flashcard.defaultCount, 20)
        XCTAssertEqual(GeneratedKind.question.defaultCount, 10)
        XCTAssertNil(GeneratedKind.summary.defaultCount)
    }

    func testGenerationJobPayloadAddsPremiumQualityContract() {
        let payload = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "quiz",
            sourceIds: ["file-1", "file-2"],
            count: 10,
            qualityTier: "standard",
            options: [
                " modelPolicy ": "balanced_default",
                "schema": "qlinik_public_review_v1",
                "blank": "   "
            ]
        )

        XCTAssertEqual(string(payload["quality_tier"]), "standard")
        XCTAssertEqual(string(payload["qualityTier"]), "standard")
        XCTAssertEqual(string(payload["modelPolicy"]), "premium_balanced_long_context_assessment_quality_first")
        XCTAssertEqual(string(payload["sourceReadPolicy"]), "read_full_extracted_document_not_first_excerpt")
        XCTAssertEqual(string(payload["preferred_model_tier"]), "latest_premium_balanced_long_context")
        XCTAssertTrue(string(payload["ocrPolicy"])?.contains("low_text_density") == true)
        XCTAssertEqual(string(payload["minimum_depth"]), "balanced_assessment_deep_with_distractor_rationales")
        XCTAssertEqual(string(payload["outputLengthPolicy"]), "complete_set_balanced_explanations_not_short")
        XCTAssertEqual(string(payload["schema"]), "qlinik_public_review_v1")
        XCTAssertNil(payload["blank"])
        XCTAssertTrue(string(payload["qualityChecklist"])?.contains("all_distractors_explained") == true)
        XCTAssertTrue(string(payload["must_include"])?.contains("wrong_option_rationales") == true)
        XCTAssertTrue(string(payload["studyWorkspaceSchema"])?.contains("option_rationales") == true)
        XCTAssertTrue(string(payload["renderingContract"])?.contains("interactive study surfaces") == true)

        guard case .array(let sourceIds) = payload["sourceIds"] else {
            return XCTFail("sourceIds must remain part of the generation job payload.")
        }
        XCTAssertEqual(sourceIds.compactMap { string($0) }, ["file-1", "file-2"])
    }

    func testInfographicGenerationPayloadMapsQualityToGptImageModels() {
        let economy = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "infographic",
            qualityTier: "economy"
        )
        let standard = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "infographic",
            qualityTier: "standard"
        )
        let premium = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "infographic",
            qualityTier: "premium"
        )

        XCTAssertEqual(string(economy["qualityTier"]), "economy")
        XCTAssertEqual(string(economy["gptImageModel"]), "gpt-image-1-mini")
        XCTAssertEqual(string(economy["image_quality"]), "low")
        XCTAssertEqual(string(standard["quality_tier"]), "standard")
        XCTAssertEqual(string(standard["imageModelPolicy"]), "gpt-image-1.5")
        XCTAssertEqual(string(standard["openai_image_model"]), "gpt-image-1.5")
        XCTAssertEqual(string(standard["imageQuality"]), "standard")
        XCTAssertEqual(string(premium["qualityTier"]), "premium")
        XCTAssertEqual(string(premium["image_model_policy"]), "gpt-image-2")
        XCTAssertEqual(string(premium["gpt_image_model"]), "gpt-image-2")
        XCTAssertEqual(string(premium["imageQuality"]), "premium")
        XCTAssertEqual(string(premium["assetFallbackPolicy"]), "structured_text_blocks_when_image_unavailable")
    }

    func testEstimateGenerationCostPayloadUsesSamePremiumQualityContract() {
        let payload = DriveAPI.estimateGenerationCostPayload(
            jobType: "summary",
            sourceTextLength: 2400,
            count: nil,
            qualityTier: nil,
            options: ["quality_tier": "standard"]
        )

        XCTAssertEqual(string(payload["quality_tier"]), "standard")
        XCTAssertEqual(string(payload["model_policy"]), "premium_balanced_long_context_summary_synthesis_first")
        XCTAssertEqual(string(payload["modelUpgradeAllowed"]), "true")
        XCTAssertTrue(string(payload["source_coverage_policy"])?.contains("full_source") == true)
        XCTAssertTrue(string(payload["backendQualityBrief"])?.contains("first excerpt") == true)
        XCTAssertEqual(string(payload["minimumDepth"]), "premium_balanced_deep")
        XCTAssertTrue(string(payload["study_workspace_schema"])?.contains("mini_table") == true)
        XCTAssertTrue(string(payload["rendering_contract"])?.contains("Learn, Flow, and Check") == true)
        guard case .integer(let sourceTextLength) = payload["sourceTextLength"] else {
            return XCTFail("sourceTextLength must remain an integer for cost estimation.")
        }
        XCTAssertEqual(sourceTextLength, 2400)
    }

    func testComparisonGenerationPayloadRequiresFullSourceMatrix() {
        let payload = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "comparison",
            sourceIds: ["file-1", "file-2"],
            qualityTier: nil,
            options: nil
        )

        XCTAssertEqual(string(payload["model_policy"]), "premium_latest_long_context_matrix_reasoning_first")
        XCTAssertEqual(string(payload["preferredModelTier"]), "latest_premium_high_reasoning_long_context")
        XCTAssertTrue(string(payload["structurePolicy"])?.contains("full_source_same_criteria_matrix") == true)
        XCTAssertTrue(string(payload["must_include"])?.contains("minimum_8_aligned_criteria") == true)
        XCTAssertTrue(string(payload["studyWorkspaceSchema"])?.contains("source_refs") == true)
        XCTAssertTrue(string(payload["qualityChecklist"])?.contains("not_intro_only") == true)
    }

    func testGenerationJobPayloadKeepsExplicitEconomyButRaisesQualityFloor() {
        let payload = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "flashcard",
            count: 20,
            qualityTier: "economy",
            options: nil
        )

        XCTAssertEqual(string(payload["quality_tier"]), "economy")
        XCTAssertEqual(string(payload["modelPolicy"]), "premium_efficient_long_context_active_recall_quality_first")
        XCTAssertEqual(string(payload["minimumDepth"]), "premium_efficient_deep_with_gap_analysis")
        XCTAssertEqual(string(payload["preferredModelTier"]), "latest_premium_efficient_long_context")
        XCTAssertEqual(string(payload["generationQualityProfile"]), "sourcebase_premium_efficient_generation_v3")
        XCTAssertEqual(string(payload["qualityGate"]), "reject_thin_generic_single_paragraph_or_source_detached_output")
    }

    func testGenerationJobPayloadPreservesOutputContractAndMediaAssetRequirements() {
        let podcast = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "podcast",
            options: [
                "outputContract": "custom typed podcast contract",
                "audioAssetRequired": "true"
            ]
        )
        let infographic = DriveAPI.generationJobPayload(
            fileId: "file-2",
            jobType: "infographic",
            options: [
                "output_contract": "custom typed infographic contract"
            ]
        )

        XCTAssertEqual(string(podcast["outputContract"]), "custom typed podcast contract")
        XCTAssertEqual(string(podcast["output_contract"]), "custom typed podcast contract")
        XCTAssertEqual(string(podcast["audioAssetRequired"]), "true")
        XCTAssertEqual(string(podcast["audio_format"]), "m4a_or_mp3_exportable")
        XCTAssertEqual(string(podcast["resultRouteContract"]), "create_or_reuse_generated_output_then_route_to_study_output")
        XCTAssertEqual(string(podcast["retrievalPracticePolicy"]), "force_commit_before_answer_with_self_check_or_questions")
        XCTAssertEqual(string(podcast["spaced_review_policy"]), "include_today_24h_72h_7d_review_prompts_when_applicable")
        XCTAssertTrue(string(podcast["learningSciencePolicy"])?.contains("dual_coding_audio") == true)
        XCTAssertTrue(string(podcast["studentOutcomeContract"])?.contains("export_audio") == true)
        XCTAssertTrue(string(podcast["finalQualityReview"])?.contains("verify_not_plain_text") == true)

        XCTAssertEqual(string(infographic["output_contract"]), "custom typed infographic contract")
        XCTAssertEqual(string(infographic["visualAssetRequired"]), "true")
        XCTAssertEqual(string(infographic["assetFallbackPolicy"]), "structured_text_blocks_when_image_unavailable")
        XCTAssertTrue(string(infographic["learning_science_policy"])?.contains("dual_coding_visual") == true)
        XCTAssertTrue(string(infographic["student_outcome_contract"])?.contains("quick_check") == true)
        XCTAssertTrue(string(infographic["cta_contract"])?.contains("primary_cta_opens_typed_study_output") == true)
    }

    func testInfographicParserFlattensSectionsAndIgnoresRelativeImagePath() {
        let content: AnyJSON = .object([
            "title": .string("Hipertansiyon İnfografiği"),
            "imageUrl": .string("generated/infographic.png"),
            "sections": .array([
                .object([
                    "heading": .string("Ana mesaj"),
                    "bullets": .array([
                        .string("Kan basıncı ölçümünü doğru manşonla doğrula."),
                        .string("Risk faktörlerini aynı vizitte sınıflandır.")
                    ])
                ]),
                .object([
                    "title": .string("Uyarılar"),
                    "items": .array([
                        .string("Acil bulguda gecikmeden ileri değerlendirme gerekir.")
                    ])
                ])
            ])
        ])

        let infographic = GeneratedContentParser.infographic(
            from: content,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(infographic.title, "Hipertansiyon İnfografiği")
        XCTAssertNil(infographic.imageURL, "Relative asset paths should not be handed to AsyncImage as remote URLs.")
        XCTAssertEqual(infographic.blocks.count, 3)
        XCTAssertTrue(infographic.blocks.contains("Ana mesaj: Kan basıncı ölçümünü doğru manşonla doğrula."))
        XCTAssertTrue(infographic.blocks.contains("Uyarılar: Acil bulguda gecikmeden ileri değerlendirme gerekir."))
    }

    func testInfographicParserAcceptsNestedPublicImageURL() {
        let content: AnyJSON = .object([
            "headline": .string("Görsel Özet"),
            "image": .object([
                "publicUrl": .string("https://cdn.example.com/sourcebase/infographic.png")
            ]),
            "blocks": .array([.string("Kısa klinik not")])
        ])

        let infographic = GeneratedContentParser.infographic(
            from: content,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(infographic.imageURL?.absoluteString, "https://cdn.example.com/sourcebase/infographic.png")
        XCTAssertEqual(infographic.blocks, ["Kısa klinik not"])
    }

    func testInfographicParserAcceptsMarkdownAndAssetArrayImageURLs() {
        let markdownContent: AnyJSON = .object([
            "title": .string("Klinik Görsel"),
            "visual": .string("![infografik](https://cdn.example.com/sourcebase/clinical-info.webp)"),
            "quick_check": .array([.string("Kırmızı bayrağı görmeden cevaba geçme.")])
        ])
        let arrayContent: AnyJSON = .object([
            "title": .string("Klinik Görsel"),
            "assets": .array([
                .object([
                    "cdn_url": .string("https://assets.example.com/generated/clinical-info.png")
                ])
            ]),
            "blocks": .array([.string("Ana mesajı 20 saniyede tara.")])
        ])

        let markdown = GeneratedContentParser.infographic(
            from: markdownContent,
            fallbackTitle: "Fallback"
        )
        let array = GeneratedContentParser.infographic(
            from: arrayContent,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(markdown.imageURL?.absoluteString, "https://cdn.example.com/sourcebase/clinical-info.webp")
        XCTAssertEqual(markdown.blocks, ["Kırmızı bayrağı görmeden cevaba geçme."])
        XCTAssertEqual(array.imageURL?.absoluteString, "https://assets.example.com/generated/clinical-info.png")
        XCTAssertEqual(array.blocks, ["Ana mesajı 20 saniyede tara."])
    }

    func testMediaParsersExposePrivateGeneratedAssetPaths() {
        let infographicContent: AnyJSON = .object([
            "title": .string("Klinik Görsel"),
            "image": .object([
                "storageObjectName": .string("sourcebase/users/user-1/generated/infographics/job-1.png"),
                "storageUrl": .string("s3://medasistorage/sourcebase/users/user-1/generated/infographics/job-1.png")
            ]),
            "blocks": .array([.string("Ana mesajı görselde göster.")])
        ])
        let podcastContent: AnyJSON = .object([
            "title": .string("Klinik Podcast"),
            "audio": .object([
                "storageObjectName": .string("sourcebase/users/user-1/generated/podcasts/job-1.m4a"),
                "storageUrl": .string("s3://medasistorage/sourcebase/users/user-1/generated/podcasts/job-1.m4a")
            ]),
            "segments": .array([.string("Kalp yetmezliği anlatımı.")])
        ])

        let infographic = GeneratedContentParser.infographic(
            from: infographicContent,
            fallbackTitle: "Fallback"
        )
        let podcast = GeneratedContentParser.podcast(
            from: podcastContent,
            fallbackTitle: "Fallback"
        )
        let ignored = GeneratedContentParser.infographic(
            from: .object(["assetPath": .string("generated/missing.png")]),
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(infographic.assetPath, "sourcebase/users/user-1/generated/infographics/job-1.png")
        XCTAssertEqual(podcast.assetPath, "sourcebase/users/user-1/generated/podcasts/job-1.m4a")
        XCTAssertNil(podcast.audioURL)
        XCTAssertNil(ignored.assetPath)
    }

    func testFlashcardParserHidesClozeMarkup() {
        let content: AnyJSON = .object([
            "cards": .array([
                .object([
                    "front": .string("Beta bloker {{c1::kalp hızını azaltır::ipucu}}"),
                    "back": .string("Yanıt: {{c2::kontraktilite azalır}}"),
                    "hint": .string("{{c3::sempatik tonus}}")
                ])
            ])
        ])

        let card = GeneratedContentParser.flashcards(from: content).first

        XCTAssertEqual(card?.front, "Beta bloker kalp hızını azaltır")
        XCTAssertEqual(card?.back, "Yanıt: kontraktilite azalır")
        XCTAssertEqual(card?.hint, "sempatik tonus")
    }

    func testInfographicDocumentDoesNotCreateEmptyImageBlockWithoutRemoteURL() {
        let content: AnyJSON = .object([
            "title": .string("Metin İnfografik"),
            "assetPath": .string("generated/missing.png"),
            "blocks": .array([.string("Birinci blok"), .string("İkinci blok")])
        ])

        let document = GeneratedContentParser.document(
            for: .infographic,
            from: content,
            fallbackTitle: "Fallback",
            fallbackText: nil
        )

        XCTAssertFalse(document.blocks.contains { block in
            if case .image = block { return true }
            return false
        })
        XCTAssertTrue(document.blocks.contains { block in
            if case let .calloutList(_, title, items, _) = block {
                return title == "Öne Çıkanlar" && items == ["Birinci blok", "İkinci blok"]
            }
            return false
        })
    }

    func testQlinikQuestionParserRequiresFiveChoices() {
        let content: AnyJSON = .object([
            "questions": .array([
                .object([
                    "id": .string("q1"),
                    "subject": .string("Dahiliye"),
                    "topic": .string("Kardiyoloji"),
                    "difficulty": .string("medium"),
                    "text": .string("En olası tanı hangisidir?"),
                    "options": .array([
                        .string("A seçeneği"),
                        .string("B seçeneği"),
                        .string("C seçeneği"),
                        .string("D seçeneği"),
                        .string("E seçeneği")
                    ]),
                    "correct_index": .integer(2),
                    "explanation": .string("Klinik bulgular C seçeneğini destekler."),
                    "option_rationales": .array([
                        .string("A dışlanır"),
                        .string("B dışlanır"),
                        .string("C doğru"),
                        .string("D dışlanır"),
                        .string("E dışlanır")
                    ])
                ])
            ])
        ])

        let questions = GeneratedContentParser.questions(from: content)
        XCTAssertEqual(questions.count, 1)
        XCTAssertTrue(questions[0].isQlinikCompatibleFiveChoice)
    }

    func testQlinikQuestionParserAcceptsAnswerIndexAliases() {
        let content: AnyJSON = .object([
            "questions": .array([
                .object([
                    "text": .string("Hangi yaklaşım doğrudur?"),
                    "options": .array([
                        .string("A"),
                        .string("B"),
                        .string("C"),
                        .string("D"),
                        .string("E")
                    ]),
                    "correctAnswerIndex": .integer(3),
                    "explanation": .string("D doğru cevaptır.")
                ])
            ])
        ])

        let questions = GeneratedContentParser.questions(from: content)
        XCTAssertEqual(questions.first?.correctIndex, 3)
        XCTAssertTrue(questions.first?.isQlinikCompatibleFiveChoice == true)
    }

    func testQlinikQuestionParserRejectsNonFiveChoiceSetForCompatibility() {
        let output = GeneratedOutput(
            id: "out-1",
            sourceFileId: "file-1",
            kind: .question,
            rawType: "question",
            title: "Soru",
            detail: "1 öğe",
            content: .object([
                "questions": .array([
                    .object([
                        "text": .string("Eksik seçenekli soru"),
                        "options": .array([.string("A"), .string("B"), .string("C"), .string("D")]),
                        "correctIndex": .integer(0),
                        "explanation": .string("Açıklama")
                    ])
                ])
            ]),
            updatedLabel: "Bugün",
            status: "ready",
            itemCount: 1,
            jobId: "job-1"
        )

        XCTAssertEqual(output.qlinikQuestions.count, 1)
        XCTAssertTrue(output.qlinikCompatibleQuestions.isEmpty)
    }

    func testQuestionAnswerPayloadDoesNotSendCorrectAnswer() {
        let payload = DriveAPI.questionAnswerPayload(
            outputId: "out-1",
            questionId: "q1",
            selectedIndex: 3,
            elapsedSeconds: 12
        )

        XCTAssertNotNil(payload["selectedIndex"])
        XCTAssertNil(payload["correctIndex"])
        XCTAssertNil(payload["correct_index"])
    }

    func testQuestionSessionParserBuildsPublicPromptWithoutAnswer() {
        let response: [String: AnyJSON] = [
            "data": .object([
                "questions": .array([
                    .object([
                        "id": .string("q1"),
                        "subject": .string("Dahiliye"),
                        "topic": .string("Kardiyoloji"),
                        "text": .string("En olası tanı hangisidir?"),
                        "options": .array([.string("A"), .string("B"), .string("C"), .string("D"), .string("E")]),
                        "correct_index": .integer(2),
                        "explanation": .string("Bu alan public prompt modeline alınmaz.")
                    ])
                ])
            ])
        ]

        let prompts = GeneratedContentParser.questionPrompts(from: response)
        XCTAssertEqual(prompts.count, 1)
        XCTAssertTrue(prompts[0].isFiveChoice)
        XCTAssertEqual(prompts[0].id, "q1")
        XCTAssertEqual(prompts[0].options.count, 5)
    }

    func testQuestionAnswerFeedbackParsesAfterSubmit() {
        let response: [String: AnyJSON] = [
            "data": .object([
                "questionId": .string("q1"),
                "selectedIndex": .integer(1),
                "isCorrect": .bool(false),
                "correctIndex": .integer(3),
                "explanation": .string("D doğru cevaptır."),
                "optionRationales": .array([.string("A değil"), .string("B değil")])
            ])
        ]

        let feedback = GeneratedContentParser.questionAnswerFeedback(
            from: response,
            fallbackQuestionId: "fallback",
            selectedIndex: 1
        )

        XCTAssertEqual(feedback.questionId, "q1")
        XCTAssertFalse(feedback.isCorrect)
        XCTAssertEqual(feedback.correctIndex, 3)
        XCTAssertEqual(feedback.explanation, "D doğru cevaptır.")
    }

    func testQuestionAnswerFeedbackAcceptsCorrectAnswerIndexAlias() {
        let response: [String: AnyJSON] = [
            "data": .object([
                "question_id": .string("q2"),
                "selected_index": .integer(2),
                "is_correct": .bool(true),
                "correct_answer_index": .integer(2),
                "explanation": .string("C doğru cevaptır.")
            ])
        ]

        let feedback = GeneratedContentParser.questionAnswerFeedback(
            from: response,
            fallbackQuestionId: "fallback",
            selectedIndex: 0
        )

        XCTAssertEqual(feedback.questionId, "q2")
        XCTAssertEqual(feedback.selectedIndex, 2)
        XCTAssertEqual(feedback.correctIndex, 2)
        XCTAssertTrue(feedback.isCorrect)
    }

    func testGeneratedOutputReadyStatusIsCaseInsensitive() {
        let output = GeneratedOutput(
            id: "out-ready",
            sourceFileId: "file-1",
            kind: .summary,
            rawType: "SUMMARY",
            title: "Özet",
            detail: "Hazır",
            updatedLabel: "Bugün",
            status: "SUCCEEDED",
            itemCount: 1,
            jobId: "job-1"
        )

        XCTAssertTrue(output.isReady)
    }

    func testGeneratedKindTitleLabel() {
        XCTAssertEqual(GeneratedKind.flashcard.titleLabel, "Flashcard Seti")
        XCTAssertEqual(GeneratedKind.question.titleLabel, "Soru Seti")
        XCTAssertEqual(GeneratedKind.summary.titleLabel, "Özet")
        XCTAssertEqual(GeneratedKind.examMorningSummary.titleLabel, "Sınav Sabahı Özeti")
        XCTAssertEqual(GeneratedKind.algorithm.titleLabel, "Algoritma")
        XCTAssertEqual(GeneratedKind.comparison.titleLabel, "Karşılaştırma")
        XCTAssertEqual(GeneratedKind.clinicalScenario.titleLabel, "Klinik Senaryo")
        XCTAssertEqual(GeneratedKind.learningPlan.titleLabel, "Öğrenme Planı")
        XCTAssertEqual(GeneratedKind.podcast.titleLabel, "Podcast")
        XCTAssertEqual(GeneratedKind.table.titleLabel, "Tablo")
        XCTAssertEqual(GeneratedKind.infographic.titleLabel, "İnfografik")
        XCTAssertEqual(GeneratedKind.mindMap.titleLabel, "Zihin Haritası")
    }

    func testDriveFileKindAllCases() {
        let all = DriveFileKind.allCases
        XCTAssertTrue(all.contains(.pdf))
        XCTAssertTrue(all.contains(.pptx))
        XCTAssertTrue(all.contains(.docx))
        XCTAssertTrue(all.contains(.ppt))
        XCTAssertTrue(all.contains(.doc))
        XCTAssertTrue(all.contains(.zip))
    }

    func testGeneratedKindAllCases() {
        let all = GeneratedKind.allCases
        XCTAssertEqual(all.count, 12)
    }

    // MARK: - Upload Service

    func testContentTypeForExtensions() {
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.pdf"), "application/pdf")
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.ppt"), "application/vnd.ms-powerpoint")
        XCTAssertEqual(
            DriveUploadService.contentTypeFor("file.pptx"),
            "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        )
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.doc"), "application/msword")
        XCTAssertEqual(
            DriveUploadService.contentTypeFor("file.docx"),
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.unknown"), "application/octet-stream")
    }

    func testProfileAvatarUploadPayloadKeepsSizeAsInteger() {
        let payload = DriveAPI.profileAvatarUploadPayload(
            fileName: "avatar.jpg",
            contentType: "image/jpeg",
            sizeBytes: 2048
        )
        guard case .integer(let sizeBytes) = payload["sizeBytes"] else {
            return XCTFail("sizeBytes must be sent as a JSON integer.")
        }
        XCTAssertEqual(sizeBytes, 2048)
    }

    func testSupportFormPayloadTrimsFields() {
        let payload = DriveAPI.supportFormPayload(
            topic: "  Ödeme  ",
            email: "  user@example.com  ",
            message: "  Merhaba destek  "
        )
        XCTAssertEqual(stringPayloadValue(payload["topic"]), "Ödeme")
        XCTAssertEqual(stringPayloadValue(payload["email"]), "user@example.com")
        XCTAssertEqual(stringPayloadValue(payload["message"]), "Merhaba destek")
    }

    func testAllowedExtensions() {
        XCTAssertEqual(DriveUploadService.allowedExtensions, ["pdf", "pptx", "docx", "ppt", "doc"])
        XCTAssertEqual(DriveUploadService.supportedExtensionsDisplay, "PDF, PPTX, DOCX, PPT veya DOC")
    }

    func testSupportedFileNameValidationUsesRealExtension() {
        XCTAssertTrue(DriveUploadService.isSupportedFileName("Ders Notu.PPT"))
        XCTAssertTrue(DriveUploadService.isSupportedFileName("Kardiyoloji.v2.docx"))
        XCTAssertFalse(DriveUploadService.isSupportedFileName("pptx.png"))
    }

    func testDriveFileMappingKeepsLegacyPPTDistinctFromPPTX() {
        XCTAssertEqual(DriveFileMapping.kind(from: "application/vnd.ms-powerpoint"), .ppt)
        XCTAssertEqual(DriveFileMapping.kind(from: "slides.PPT"), .ppt)
        XCTAssertEqual(DriveFileMapping.kind(from: "slides.pptx"), .pptx)
        XCTAssertEqual(DriveFileMapping.kind(from: [
            "original_filename": .string("komite-slayt.PPT")
        ]), .ppt)
    }

    func testDriveFileMappingUsesSlideLabelsForPresentations() {
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .pptx, status: .completed, pageCount: 0, slideCount: 42),
            "42 slayt"
        )
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .pptx, status: .completed, pageCount: 12, slideCount: 0),
            "12 slayt"
        )
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .ppt, status: .failed, pageCount: 0, slideCount: 0),
            "Slaytlar okunamadı"
        )
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .pdf, status: .completed, pageCount: 9, slideCount: 0),
            "9 sayfa"
        )
    }

    func testDriveFileMappingExplainsExtractionFailures() {
        let encryptedPDF: [String: AnyJSON] = [
            "metadata": .object(["error_code": .string("FILE_ENCRYPTED_PDF")])
        ]
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: encryptedPDF, kind: .pdf, status: .failed, sizeBytes: 10),
            "Bu PDF şifreli görünüyor. Şifre korumasını kaldırıp tekrar yükleyebilirsin."
        )

        let corruptFile: [String: AnyJSON] = [
            "metadata": .object(["parseError": .string("corrupt package")])
        ]
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: corruptFile, kind: .docx, status: .failed, sizeBytes: 10),
            "Dosya bozuk ya da okunamıyor. Dosyayı yeniden kaydedip tekrar yükleyebilirsin."
        )

        let scannedPDF: [String: AnyJSON] = [
            "metadata": .object(["extractionErrorCode": .string("FILE_SCANNED_PDF_OCR_REQUIRED")])
        ]
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: scannedPDF, kind: .pdf, status: .failed, sizeBytes: 10),
            "Bu PDF taranmış/görsel tabanlı görünüyor. Metin çıkarılamadı; OCR desteği gerekir."
        )

        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: [:], kind: .ppt, status: .failed, sizeBytes: 10),
            "Eski PPT dosyaları sınırlı desteklenir. Dosyayı PPTX olarak kaydedip tekrar yükleyebilirsin."
        )
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: [:], kind: .doc, status: .failed, sizeBytes: 10),
            "Eski DOC dosyaları sınırlı desteklenir. Dosyayı DOCX olarak kaydedip tekrar yükleyebilirsin."
        )
    }

    func testMaxSizeBytes() {
        XCTAssertEqual(DriveUploadService.maxSizeBytes, 25 * 1024 * 1024)
    }

    // MARK: - API Error

    func testDriveAPIErrorUnauthorized() {
        let error = DriveAPIError(message: "Unauthorized", code: "UNAUTHORIZED", status: 401)
        XCTAssertTrue(error.isUnauthorized)
    }

    func testDriveAPIErrorNotUnauthorized() {
        let error = DriveAPIError(message: "Bad request", code: "BAD_REQUEST", status: 400)
        XCTAssertFalse(error.isUnauthorized)
    }

    // MARK: - Repository Error

    func testRepositoryError() {
        let error = RepositoryError(message: "Test error message")
        XCTAssertEqual(error.message, "Test error message")
    }

    private func stringPayloadValue(_ value: AnyJSON?) -> String? {
        guard case .string(let string) = value else { return nil }
        return string
    }

    // MARK: - Profile

    func testProfileSnapshotEmpty() {
        let snapshot = ProfileSnapshot.empty
        XCTAssertTrue(snapshot.displayName.isEmpty)
        XCTAssertNil(snapshot.walletBalance)
        XCTAssertEqual(snapshot.courseCount, 0)
    }
}
