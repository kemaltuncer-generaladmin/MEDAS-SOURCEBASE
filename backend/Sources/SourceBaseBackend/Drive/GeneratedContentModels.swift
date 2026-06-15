import Foundation
import Supabase

public struct SBFlashcard: Identifiable, Sendable, Equatable {
    public let id: String
    public let front: String
    public let back: String
    public let explanation: String
    public let difficulty: String
    public let hint: String

    public init(
        id: String = UUID().uuidString,
        front: String,
        back: String,
        explanation: String = "",
        difficulty: String = "",
        hint: String = ""
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.explanation = explanation
        self.difficulty = difficulty
        self.hint = hint
    }
}

public struct SBQlinikQuestion: Identifiable, Sendable, Equatable {
    public let id: String
    public let subject: String
    public let topic: String
    public let difficulty: String
    public let text: String
    public let options: [String]
    public let correctIndex: Int
    public let explanation: String
    public let optionRationales: [String]
    public let tags: [String]
    public let isUserGenerated: Bool

    public init(
        id: String = UUID().uuidString,
        subject: String,
        topic: String,
        difficulty: String,
        text: String,
        options: [String],
        correctIndex: Int,
        explanation: String,
        optionRationales: [String] = [],
        tags: [String] = [],
        isUserGenerated: Bool = true
    ) {
        self.id = id
        self.subject = subject
        self.topic = topic
        self.difficulty = difficulty
        self.text = text
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.optionRationales = optionRationales
        self.tags = tags
        self.isUserGenerated = isUserGenerated
    }

    public var isQlinikCompatibleFiveChoice: Bool {
        options.count == 5
            && correctIndex >= 0
            && correctIndex < options.count
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public struct SBQuestionPrompt: Identifiable, Sendable, Equatable {
    public let id: String
    public let subject: String
    public let topic: String
    public let difficulty: String
    public let text: String
    public let options: [String]
    public let tags: [String]

    public init(
        id: String,
        subject: String = "Kullanıcı Kaynağı",
        topic: String = "SourceBase",
        difficulty: String = "medium",
        text: String,
        options: [String],
        tags: [String] = []
    ) {
        self.id = id
        self.subject = subject
        self.topic = topic
        self.difficulty = difficulty
        self.text = text
        self.options = options
        self.tags = tags
    }

    public var isFiveChoice: Bool {
        options.count == 5
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public struct SBQuestionAnswerFeedback: Sendable, Equatable {
    public let questionId: String
    public let selectedIndex: Int
    public let isCorrect: Bool
    public let correctIndex: Int?
    public let explanation: String
    public let optionRationales: [String]

    public init(
        questionId: String,
        selectedIndex: Int,
        isCorrect: Bool,
        correctIndex: Int? = nil,
        explanation: String = "",
        optionRationales: [String] = []
    ) {
        self.questionId = questionId
        self.selectedIndex = selectedIndex
        self.isCorrect = isCorrect
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.optionRationales = optionRationales
    }
}

public struct SBStudySection: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let items: [String]

    public init(id: String = UUID().uuidString, title: String, items: [String]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct SBStudyTable: Sendable, Equatable {
    public let headers: [String]
    public let rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}

public struct SBStudyTemplateContent: Sendable, Equatable {
    public let title: String
    public let summary: String
    public let sections: [SBStudySection]
    public let table: SBStudyTable?

    public init(title: String, summary: String = "", sections: [SBStudySection], table: SBStudyTable? = nil) {
        self.title = title
        self.summary = summary
        self.sections = sections
        self.table = table
    }
}

public struct SBPodcastSegment: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let text: String
    public let durationLabel: String

    public init(id: String = UUID().uuidString, title: String, text: String, durationLabel: String = "") {
        self.id = id
        self.title = title
        self.text = text
        self.durationLabel = durationLabel
    }
}

public struct SBPodcastContent: Sendable, Equatable {
    public let title: String
    public let durationLabel: String
    public let audioURL: URL?
    public let assetPath: String?
    public let segments: [SBPodcastSegment]

    public init(title: String, durationLabel: String = "", audioURL: URL? = nil, assetPath: String? = nil, segments: [SBPodcastSegment]) {
        self.title = title
        self.durationLabel = durationLabel
        self.audioURL = audioURL
        self.assetPath = assetPath
        self.segments = segments
    }
}

public struct SBInfographicContent: Sendable, Equatable {
    public let title: String
    public let imageURL: URL?
    public let assetPath: String?
    public let blocks: [String]

    public init(title: String, imageURL: URL? = nil, assetPath: String? = nil, blocks: [String]) {
        self.title = title
        self.imageURL = imageURL
        self.assetPath = assetPath
        self.blocks = blocks
    }
}

public extension GeneratedOutput {
    var flashcards: [SBFlashcard] {
        GeneratedContentParser.flashcards(from: content, fallbackText: contentText)
    }

    var qlinikQuestions: [SBQlinikQuestion] {
        GeneratedContentParser.questions(from: content)
    }

    var qlinikCompatibleQuestions: [SBQlinikQuestion] {
        let questions = qlinikQuestions
        guard !questions.isEmpty,
              questions.allSatisfy(\.isQlinikCompatibleFiveChoice) else { return [] }
        return questions
    }

    var studyTemplateContent: SBStudyTemplateContent {
        GeneratedContentParser.studyTemplate(from: content, fallbackTitle: title, fallbackText: contentText)
    }

    var podcastContent: SBPodcastContent {
        GeneratedContentParser.podcast(from: content, fallbackTitle: title, fallbackText: contentText)
    }

    var infographicContent: SBInfographicContent {
        GeneratedContentParser.infographic(from: content, fallbackTitle: title, fallbackText: contentText)
    }

    /// Canonical systematic document used by BOTH the study screen and the PDF.
    var studyDocument: SBStudyDocument {
        GeneratedContentParser.document(
            for: kind,
            from: content,
            fallbackTitle: title,
            fallbackText: contentText
        )
    }
}

public enum GeneratedContentParser {
    public static func questionPrompts(from response: [String: AnyJSON]) -> [SBQuestionPrompt] {
        let root = objectPayload(from: response)
        let rawQuestions = array(in: root, keys: ["questions", "items"]) ?? arrayValue(root)
        return rawQuestions?.enumerated().compactMap { index, value -> SBQuestionPrompt? in
            guard let dict = objectValue(value) else { return nil }
            let text = firstString(dict, keys: ["text", "question", "stem"])
            let options = stringArray(dict["options"])
            guard !text.isEmpty, options.count == 5 else { return nil }
            return SBQuestionPrompt(
                id: firstString(dict, keys: ["id", "questionId", "question_id"]).nilIfEmpty ?? "question-\(index)",
                subject: firstString(dict, keys: ["subject"]).nilIfEmpty ?? "Kullanıcı Kaynağı",
                topic: firstString(dict, keys: ["topic"]).nilIfEmpty ?? "SourceBase",
                difficulty: normalizedDifficulty(firstString(dict, keys: ["difficulty"])),
                text: text,
                options: options,
                tags: stringArray(dict["tags"])
            )
        } ?? []
    }

    public static func questionAnswerFeedback(from response: [String: AnyJSON], fallbackQuestionId: String, selectedIndex: Int) -> SBQuestionAnswerFeedback {
        let root = objectValue(objectPayload(from: response)) ?? response
        let isCorrect = boolValue(root["isCorrect"] ?? root["is_correct"] ?? root["correct"]) ?? false
        let correctIndex = firstInt(root, keys: ["correctIndex", "correct_index", "correctAnswerIndex", "correct_answer_index", "answerIndex", "answer_index"])
        return SBQuestionAnswerFeedback(
            questionId: firstString(root, keys: ["questionId", "question_id", "id"]).nilIfEmpty ?? fallbackQuestionId,
            selectedIndex: intValue(root["selectedIndex"] ?? root["selected_index"]) ?? selectedIndex,
            isCorrect: isCorrect,
            correctIndex: correctIndex,
            explanation: firstString(root, keys: ["explanation", "rationale"]),
            optionRationales: stringArray(root["optionRationales"] ?? root["option_rationales"])
        )
    }

    public static func flashcards(from content: AnyJSON?, fallbackText: String? = nil) -> [SBFlashcard] {
        let rawCards = array(in: content, keys: ["cards", "flashcards"]) ?? arrayValue(content)
        let cards = rawCards?.enumerated().compactMap { index, value -> SBFlashcard? in
            guard let dict = objectValue(value) else {
                let text = cleanFlashcardText(stringValue(value))
                return text.isEmpty ? nil : SBFlashcard(id: "card-\(index)", front: text, back: "")
            }
            let front = cleanFlashcardText(firstString(dict, keys: ["front", "question", "prompt", "term", "title"]))
            let back = cleanFlashcardText(firstString(dict, keys: ["back", "answer", "definition", "text"]))
            guard !front.isEmpty || !back.isEmpty else { return nil }
            return SBFlashcard(
                id: firstString(dict, keys: ["id"]).nilIfEmpty ?? "card-\(index)",
                front: front.isEmpty ? "Kart \(index + 1)" : front,
                back: back,
                explanation: cleanFlashcardText(firstString(dict, keys: ["explanation", "rationale", "note"])),
                difficulty: firstString(dict, keys: ["difficulty"]),
                hint: cleanFlashcardText(firstString(dict, keys: ["hint", "ipucu"]))
            )
        } ?? []

        if !cards.isEmpty { return cards }
        let fallback = cleanFlashcardText(fallbackText ?? "")
        guard !fallback.isEmpty else { return [] }
        return [SBFlashcard(front: fallback.components(separatedBy: "\n").first ?? "Kart", back: fallback)]
    }

    public static func questions(from content: AnyJSON?) -> [SBQlinikQuestion] {
        let rawQuestions = array(in: content, keys: ["questions", "items"]) ?? arrayValue(content)
        return rawQuestions?.enumerated().compactMap { index, value -> SBQlinikQuestion? in
            guard let dict = objectValue(value) else { return nil }
            let options = stringArray(dict["options"])
            let rationales = stringArray(dict["option_rationales"] ?? dict["optionRationales"])
            let text = firstString(dict, keys: ["text", "question", "stem"])
            guard !text.isEmpty, !options.isEmpty else { return nil }
            return SBQlinikQuestion(
                id: firstString(dict, keys: ["id"]).nilIfEmpty ?? "question-\(index)",
                subject: firstString(dict, keys: ["subject"]).nilIfEmpty ?? "Kullanıcı Kaynağı",
                topic: firstString(dict, keys: ["topic"]).nilIfEmpty ?? "SourceBase",
                difficulty: normalizedDifficulty(firstString(dict, keys: ["difficulty"])),
                text: text,
                options: options,
                correctIndex: firstInt(dict, keys: ["correct_index", "correctIndex", "correctAnswerIndex", "correct_answer_index", "answerIndex", "answer_index", "correctOptionIndex", "correct_option_index"]) ?? -1,
                explanation: firstString(dict, keys: ["explanation", "rationale"]),
                optionRationales: rationales,
                tags: stringArray(dict["tags"]),
                isUserGenerated: boolValue(dict["is_user_generated"] ?? dict["isUserGenerated"]) ?? true
            )
        } ?? []
    }

    public static func studyTemplate(
        from content: AnyJSON?,
        fallbackTitle: String,
        fallbackText: String? = nil
    ) -> SBStudyTemplateContent {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "name"]).nilIfEmpty } ?? fallbackTitle
        let summary = dict.map { firstString($0, keys: ["summary", "description", "overview"]) } ?? ""
        var sections: [SBStudySection] = []

        if let dict {
            let keys = [
                "must_know", "commonly_confused", "clinical_tus_tips", "red_flags",
                "self_check", "decision_nodes", "branches", "thresholds", "action_steps",
                "distinguishing_tips", "clinical_notes", "steps", "nodes", "sections",
                "teachingPoints", "teaching_points", "objectives", "learningObjectives",
                "learning_objectives", "days", "tasks", "redFlags", "clinicalTips",
                "clinical_tips", "highYieldPoints", "high_yield_points", "pitfalls",
                "keyTakeaways", "key_takeaways"
            ]
            for key in keys {
                let items = sectionItems(dict[key])
                if !items.isEmpty {
                    sections.append(SBStudySection(title: label(for: key), items: items))
                }
            }
        }

        if sections.isEmpty {
            let fallbackItems = (fallbackText ?? "")
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            sections.append(SBStudySection(title: "Çalışma Notları", items: fallbackItems.isEmpty ? ["Bu çalışma ekranı için kaynak içeriği henüz hazırlanmadı."] : fallbackItems))
        }

        return SBStudyTemplateContent(
            title: title,
            summary: summary,
            sections: sections,
            table: table(from: dict)
        )
    }

    public static func podcast(from content: AnyJSON?, fallbackTitle: String, fallbackText: String? = nil) -> SBPodcastContent {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "name"]).nilIfEmpty } ?? fallbackTitle
        let duration = dict.map { firstString($0, keys: ["duration", "durationLabel", "duration_label"]) } ?? ""
        let audioText = dict.map {
            firstString(
                $0,
                keys: [
                    "audio_url", "audioUrl", "audioFileUrl", "audio_file_url",
                    "mp3_url", "mp3Url", "m4a_url", "m4aUrl",
                    "storageUrl", "storage_url", "publicUrl", "public_url",
                    "assetUrl", "asset_url", "url"
                ]
            )
        } ?? ""
        let segmentsRaw = dict.flatMap { array(in: .object($0), keys: ["segments", "chapters"]) } ?? []
        let segments = segmentsRaw.enumerated().compactMap { index, value -> SBPodcastSegment? in
            guard let item = objectValue(value) else {
                let text = stringValue(value)
                return text.isEmpty ? nil : SBPodcastSegment(id: "segment-\(index)", title: "Bölüm \(index + 1)", text: text)
            }
            let text = firstString(item, keys: ["text", "script", "body", "content"])
            guard !text.isEmpty else { return nil }
            return SBPodcastSegment(
                id: firstString(item, keys: ["id"]).nilIfEmpty ?? "segment-\(index)",
                title: firstString(item, keys: ["title", "heading"]).nilIfEmpty ?? "Bölüm \(index + 1)",
                text: text,
                durationLabel: firstString(item, keys: ["duration", "durationLabel", "duration_label"])
            )
        }
        let fallback = fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return SBPodcastContent(
            title: title,
            durationLabel: duration,
            audioURL: absoluteRemoteURL(from: audioText),
            assetPath: dict.flatMap(podcastAssetPath),
            segments: segments.isEmpty && !fallback.isEmpty
                ? [SBPodcastSegment(title: "Transkript", text: fallback)]
                : segments
        )
    }

    public static func infographic(from content: AnyJSON?, fallbackTitle: String, fallbackText: String? = nil) -> SBInfographicContent {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "headline"]).nilIfEmpty } ?? fallbackTitle
        return SBInfographicContent(
            title: title,
            imageURL: dict.flatMap(infographicImageURL),
            assetPath: dict.flatMap(infographicAssetPath),
            blocks: dict.map { infographicBlocks(from: $0, fallbackText: fallbackText) }
                ?? fallbackLines(fallbackText)
        )
    }

    // MARK: - Systematic document builder

    /// Build the canonical per-kind document. Maps each output type's real JSON
    /// fields (see edge fn `ai-generation-provider.ts`) into typed blocks. Reuses the lenient
    /// helpers below so partial / legacy payloads still render.
    public static func document(
        for kind: GeneratedKind,
        from content: AnyJSON?,
        fallbackTitle: String,
        fallbackText: String?
    ) -> SBStudyDocument {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "name", "headline", "centralTopic"]).nilIfEmpty } ?? fallbackTitle
        var blocks: [SBStudyBlock] = []
        var summary = dict.map { firstString($0, keys: ["summary", "overview", "description", "fullText"]) } ?? ""

        func callout(_ t: String, _ key: String, _ style: SBCalloutStyle) {
            let items = sectionItems(dict?[key])
            if !items.isEmpty { blocks.append(.calloutList(id: "\(kind.rawValue)-\(key)", title: t, items: items, style: style)) }
        }
        func calloutAny(_ t: String, keys: [String], style: SBCalloutStyle, id: String) {
            guard let dict else { return }
            let items = keys.lazy.map { sectionItems(dict[$0]) }.first { !$0.isEmpty } ?? []
            if !items.isEmpty { blocks.append(.calloutList(id: "\(kind.rawValue)-\(id)", title: t, items: items, style: style)) }
        }
        func steps(_ t: String, _ key: String) {
            let items = sectionItems(dict?[key])
            if !items.isEmpty { blocks.append(.steps(id: "\(kind.rawValue)-\(key)", title: t, items: items)) }
        }

        switch kind {
        case .flashcard:
            let cards = flashcards(from: content, fallbackText: fallbackText)
            if !cards.isEmpty { blocks.append(.cards(id: "cards", cards: cards)) }
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .question:
            let qs = questions(from: content)
            if !qs.isEmpty { blocks.append(.quiz(id: "quiz", questions: qs)) }
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .summary:
            callout("Ana Konular", "mainTopics", .plain)
            callout("Yüksek Verimli Noktalar", "high_yield_points", .mustKnow)
            callout("Yüksek Verimli Noktalar", "highYieldPoints", .mustKnow)
            callout("Önemli Maddeler", "bulletPoints", .mustKnow)
            callout("Mutlaka Bil", "mustKnow", .mustKnow)
            callout("Mutlaka Bil", "must_know", .mustKnow)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Sık Karışanlar", "commonlyConfused", .confused)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            if let t = table(from: dict) { blocks.append(.table(id: "mini_table", title: "Mini Tablo", table: t)) }
            steps("Klinik Karar Akışı", "clinicalDecisionFlow")
            steps("Klinik Karar Akışı", "clinical_decision_flow")
            callout("Sınav Tuzakları", "examTraps", .tip)
            callout("Sınav Tuzakları", "exam_traps", .tip)
            callout("Anahtar Terimler", "keyTerms", .tip)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)
            let sc = qaPairs(dict?["self_check"] ?? dict?["quick_check"])
            if !sc.isEmpty { blocks.append(.qa(id: "self_check", title: "Kendini Kontrol Et", pairs: sc)) }

        case .examMorningSummary:
            callout("Mutlaka Bil", "must_know", .mustKnow)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            callout("Klinik / TUS İpuçları", "clinical_tus_tips", .tip)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            steps("Algoritma Akışı", "algorithm_flow")
            if let t = table(from: dict) { blocks.append(.table(id: "mini_table", title: "Hızlı Tablo", table: t)) }
            let sc = qaPairs(dict?["self_check"])
            if !sc.isEmpty { blocks.append(.qa(id: "self_check", title: "Kendini Kontrol Et", pairs: sc)) }
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .algorithm:
            if let start = dict.flatMap({ firstString($0, keys: ["starting_point", "startingPoint", "entry", "entry_point", "entryPoint"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "start", text: "Başlangıç: \(start)"))
            }
            let nodes = decisionNodes(dict?["decision_nodes"] ?? dict?["decisionNodes"] ?? dict?["nodes"])
            if !nodes.isEmpty { blocks.append(.decisions(id: "decision_nodes", title: "Karar Düğümleri", nodes: nodes)) }
            let actionItems = sectionItems(dict?["action_steps"] ?? dict?["actionSteps"] ?? dict?["steps"])
            if !actionItems.isEmpty { blocks.append(.steps(id: "algorithm-actions", title: "Eylem Adımları", items: actionItems)) }
            callout("Akış Dalları", "branches", .plain)
            callout("Kritik Eşikler", "critical_thresholds", .mustKnow)
            callout("Kritik Eşikler", "criticalThresholds", .mustKnow)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            callout("Sınav İpuçları", "exam_tips", .tip)
            callout("Sınav İpuçları", "examTips", .tip)
            callout("Notlar", "notes", .plain)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)
            callout("Kaynakta Eksik Kalanlar", "sourceGaps", .redFlag)

        case .comparison, .table:
            if let t = comparisonTable(from: dict) ?? table(from: dict) {
                blocks.append(.table(id: "comparison", title: "Karşılaştırma", table: t))
            }
            callout("Ayırt Edici İpuçları", "distinguishing_tips", .tip)
            callout("Klinik Notlar", "clinical_notes", .plain)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kısa Sonuç", "short_takeaway", .mustKnow)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .clinicalScenario:
            let kv = [
                ("Hasta", dict.map { firstString($0, keys: ["patientInfo", "patient_info", "patient", "patientSnapshot", "patient_snapshot"]) } ?? ""),
                ("Başvuru Şikayeti", dict.map { firstString($0, keys: ["chiefComplaint", "chief_complaint", "complaint"]) } ?? ""),
                ("Karar Noktası", dict.map { firstString($0, keys: ["decisionPoint", "decision_point"]) } ?? "")
            ].filter { !$0.1.isEmpty }.map { SBKeyValue(key: $0.0, value: $0.1) }
            if !kv.isEmpty { blocks.append(.keyValues(id: "patient", title: "Vaka Bilgisi", pairs: kv)) }
            if let stem = dict.flatMap({ firstString($0, keys: ["caseStem", "case_stem", "history", "case", "scenario"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "stem", text: stem))
            }
            callout("Fizik Muayene", "physicalExam", .plain)
            callout("Fizik Muayene", "physical_exam", .plain)
            callout("Lab / Görüntüleme", "labsImaging", .plain)
            callout("Lab / Görüntüleme", "labs_imaging", .plain)
            callout("Bulgular", "findings", .mustKnow)
            callout("Problem Temsili", "problemRepresentation", .mustKnow)
            callout("Problem Temsili", "problem_representation", .mustKnow)
            callout("Ayırıcı Tanı", "differentialDiagnosis", .confused)
            callout("Ayırıcı Tanı", "differential_diagnosis", .confused)
            callout("Tanısal Gerekçe", "diagnosticJustification", .tip)
            callout("Tanısal Gerekçe", "diagnostic_justification", .tip)
            let nodes = decisionNodes(dict?["decision_nodes"] ?? dict?["decisionNodes"])
            if !nodes.isEmpty { blocks.append(.decisions(id: "clinical_decision_nodes", title: "Karar Noktaları", nodes: nodes)) }
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            let qa = qaPairs(dict?["questions"])
            if !qa.isEmpty { blocks.append(.qa(id: "questions", title: "Sorular", pairs: qa)) }
            callout("Öğrenme Hedefleri", "learningObjective", .objective)
            callout("Öğrenme Hedefleri", "learning_objective", .objective)
            callout("Öğretim Noktaları", "teachingPoints", .tip)
            callout("Öğretim Noktaları", "teaching_points", .tip)
            callout("Sınav İpuçları", "examTips", .tip)
            callout("Sınav İpuçları", "exam_tips", .tip)

        case .learningPlan:
            if let dur = dict.flatMap({ firstString($0, keys: ["duration"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "duration", text: "Süre: \(dur)"))
            }
            let sessions = timelineEntries(dict?["sessions"] ?? dict?["study_sessions"] ?? dict?["studySessions"])
            if !sessions.isEmpty { blocks.append(.timeline(id: "sessions", title: "Çalışma Oturumları", entries: sessions)) }
            callout("Bugün Başla", "startToday", .mustKnow)
            callout("Bugün Başla", "start_today", .mustKnow)
            callout("Günlük Hedefler", "dailyGoals", .objective)
            callout("Günlük Hedefler", "daily_goals", .objective)
            steps("Yapılacaklar", "checklist")
            callout("Tekrar Günleri", "reviewDays", .plain)
            callout("Tekrar Günleri", "review_days", .plain)
            callout("Zayıf Noktalar", "weakPoints", .redFlag)
            callout("Zayıf Noktalar", "weak_points", .redFlag)
            callout("Hedefler", "objectives", .objective)
            callout("Soru / Flashcard Önerileri", "questionFlashcardSuggestions", .tip)
            callout("Soru / Flashcard Önerileri", "question_flashcard_suggestions", .tip)

        case .podcast:
            let p = podcast(from: content, fallbackTitle: title, fallbackText: fallbackText)
            blocks.append(.audio(id: "audio", url: p.audioURL, segments: p.segments))
            callout("Kısa Özet", "recap", .mustKnow)
            callout("Aktif Hatırlama", "active_recall_prompts", .tip)
            callout("Kaynak Sınırları", "source_limits", .redFlag)
            if summary.isEmpty { summary = p.durationLabel }

        case .infographic:
            let info = infographic(from: content, fallbackTitle: title, fallbackText: fallbackText)
            if let imageURL = info.imageURL {
                blocks.append(.image(id: "image", url: imageURL, caption: info.title))
            }
            callout("Ana Mesaj", "main_message", .mustKnow)
            callout("Ana Mesaj", "mainMessage", .mustKnow)
            // Section bullets (heading + bullets[]) become callout lists.
            let sectionStartCount = blocks.count
            if let sections = array(in: content, keys: ["sections"]) {
                for (i, value) in sections.enumerated() {
                    guard let obj = objectValue(value) else { continue }
                    let heading = firstString(obj, keys: ["heading", "title"]).nilIfEmpty ?? "Bölüm \(i + 1)"
                    let bullets = sectionItems(obj["bullets"] ?? obj["items"])
                    if !bullets.isEmpty { blocks.append(.calloutList(id: "info-\(i)", title: heading, items: bullets, style: .plain)) }
                }
            }
            if blocks.count == sectionStartCount, !info.blocks.isEmpty {
                blocks.append(.calloutList(id: "info-blocks", title: "Öne Çıkanlar", items: info.blocks, style: .plain))
            }
            callout("Uyarılar", "warnings", .redFlag)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            callout("Kaynak Notu", "source_note", .plain)
            callout("Kaynak Notu", "sourceNote", .plain)
            let quickCheck = qaPairs(dict?["quick_check"])
            if !quickCheck.isEmpty {
                blocks.append(.qa(id: "quick_check", title: "Hızlı Kontrol", pairs: quickCheck))
            } else {
                calloutAny(
                    "Hızlı Kontrol",
                    keys: ["quick_check", "quickCheck", "self_check", "selfCheck"],
                    style: .objective,
                    id: "quick-check"
                )
            }

        case .mindMap:
            if let center = dict.flatMap({ firstString($0, keys: ["centralTopic", "central_topic", "topic"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "center", text: "Merkez Konu: \(center)"))
            }
            let branches = mindBranches(dict?["branches"])
            if !branches.isEmpty { blocks.append(.mindBranches(id: "branches", title: "Dallar", branches: branches)) }
            callout("Kritik Bağlantılar", "criticalConnections", .mustKnow)
            callout("Kritik Bağlantılar", "critical_connections", .mustKnow)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            callout("Klinik / TUS İpuçları", "clinicalTusTips", .tip)
            callout("Klinik / TUS İpuçları", "clinical_tus_tips", .tip)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)
        }

        calloutAny(
            "Sonraki Tekrar",
            keys: ["next_review_prompts", "nextReviewPrompts", "review_prompts", "reviewPrompts", "spaced_review_prompts", "spacedReviewPrompts"],
            style: .objective,
            id: "next-review"
        )

        if blocks.isEmpty {
            let fallback = fallbackDocumentParts(for: kind, fallbackText: fallbackText)
            if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                summary = fallback.summary
            }
            blocks.append(contentsOf: fallback.blocks)
        }

        // Universal fallback: never show an empty screen.
        if blocks.isEmpty && summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let template = studyTemplate(from: content, fallbackTitle: fallbackTitle, fallbackText: fallbackText)
            summary = template.summary
            for s in template.sections where !s.items.isEmpty {
                blocks.append(.calloutList(id: s.id, title: s.title, items: s.items, style: .plain))
            }
            if let t = template.table { blocks.append(.table(id: "fallback-table", title: "Tablo", table: t)) }
        }

        let subtitle = dict.flatMap { firstString($0, keys: ["duration", "patientInfo", "sourceName", "infographic_type"]).nilIfEmpty } ?? ""
        return SBStudyDocument(kind: kind, title: title, subtitle: subtitle, summary: summary, blocks: blocks)
    }

    private static func decisionNodes(_ value: AnyJSON?) -> [SBDecisionNode] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else { return nil }
            let title = firstString(d, keys: ["title", "label", "question", "node"])
            guard !title.isEmpty else { return nil }
            return SBDecisionNode(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "node-\(index)",
                title: title,
                detail: firstString(d, keys: ["description", "detail", "meaning"]),
                yes: firstString(d, keys: ["yes", "ifYes", "evet"]),
                no: firstString(d, keys: ["no", "ifNo", "hayir", "hayır"]),
                substeps: stringArray(d["substeps"] ?? d["subSteps"])
            )
        }
    }

    private static func qaPairs(_ value: AnyJSON?) -> [SBQAPair] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else {
                let text = stringValue(item)
                return text.isEmpty ? nil : SBQAPair(question: text, answer: "")
            }
            let q = firstString(d, keys: ["question", "q", "prompt"])
            guard !q.isEmpty else { return nil }
            return SBQAPair(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "qa-\(index)",
                question: q,
                answer: firstString(d, keys: ["answer", "a", "response"]),
                explanation: firstString(d, keys: ["explanation", "rationale", "detail"])
            )
        }
    }

    private static func timelineEntries(_ value: AnyJSON?) -> [SBTimelineEntry] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else {
                let text = stringValue(item)
                return text.isEmpty ? nil : SBTimelineEntry(title: text, items: [])
            }
            let title = firstString(d, keys: ["title", "day", "label", "name"]).nilIfEmpty ?? "Oturum \(index + 1)"
            let minutes = firstInt(d, keys: ["estimatedMinutes", "minutes", "estimated_minutes"])
            let meta = minutes.map { "\($0) dk" } ?? firstString(d, keys: ["duration", "meta"])
            return SBTimelineEntry(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "session-\(index)",
                title: title,
                meta: meta,
                items: stringArray(d["activities"] ?? d["tasks"] ?? d["items"])
            )
        }
    }

    private static func mindBranches(_ value: AnyJSON?) -> [SBMindBranch] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else { return nil }
            let label = firstString(d, keys: ["label", "title", "name", "topic"])
            guard !label.isEmpty else { return nil }
            return SBMindBranch(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "branch-\(index)",
                label: label,
                children: stringArray(d["children"] ?? d["subbranches"] ?? d["sub_branches"] ?? d["items"]),
                tags: stringArray(d["tags"])
            )
        }
    }

    private static func podcastAssetPath(from dict: [String: AnyJSON]) -> String? {
        for key in [
            "audio", "asset", "media", "file", "output",
            "audios", "assets", "mediaAssets", "media_assets",
            "files", "outputs", "generatedAudio", "generated_audio"
        ] {
            if let path = generatedAssetPath(from: dict[key]) { return path }
        }

        return generatedAssetPath(
            from: firstString(
                dict,
                keys: [
                    "storageObjectName", "storage_object_name",
                    "objectName", "object_name",
                    "assetPath", "asset_path",
                    "storagePath", "storage_path",
                    "storageUrl", "storage_url",
                    "path"
                ]
            )
        )
    }

    private static func cleanFlashcardText(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        if let regex = try? NSRegularExpression(pattern: #"\{\{c\d+::(.*?)(?:::[^{}]*)?\}\}"#) {
            let nsText = cleaned as NSString
            let matches = regex.matches(in: cleaned, range: NSRange(location: 0, length: nsText.length))
            if !matches.isEmpty {
                var mutable = cleaned
                for match in matches.reversed() {
                    guard match.numberOfRanges > 1,
                          match.range(at: 1).location != NSNotFound,
                          let whole = Range(match.range(at: 0), in: mutable),
                          let inner = Range(match.range(at: 1), in: mutable) else { continue }
                    mutable.replaceSubrange(whole, with: String(mutable[inner]))
                }
                cleaned = mutable
            }
        }

        return cleaned
            .replacingOccurrences(of: #"\{\{c\d+::"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "}}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func infographicImageURL(from dict: [String: AnyJSON]) -> URL? {
        let direct = firstString(
            dict,
            keys: [
                "image_url", "imageUrl", "storageUrl", "storage_url",
                "publicUrl", "public_url", "assetUrl", "asset_url",
                "cdnUrl", "cdn_url", "secureUrl", "secure_url",
                "signedUrl", "signed_url", "downloadUrl", "download_url",
                "fileUrl", "file_url", "mediaUrl", "media_url", "url"
            ]
        )
        if let url = remoteImageURL(from: direct) { return url }
        for key in [
            "image", "asset", "visual", "media", "file", "output",
            "images", "assets", "visuals", "mediaAssets", "media_assets",
            "files", "outputs", "generatedImages", "generated_images"
        ] {
            if let url = remoteImageURL(from: dict[key]) { return url }
        }
        return nil
    }

    private static func infographicAssetPath(from dict: [String: AnyJSON]) -> String? {
        for key in [
            "image", "asset", "visual", "media", "file", "output",
            "images", "assets", "visuals", "mediaAssets", "media_assets",
            "files", "outputs", "generatedImages", "generated_images"
        ] {
            if let path = generatedAssetPath(from: dict[key]) { return path }
        }

        return generatedAssetPath(
            from: firstString(
                dict,
                keys: [
                    "storageObjectName", "storage_object_name",
                    "objectName", "object_name",
                    "assetPath", "asset_path",
                    "storagePath", "storage_path",
                    "storageUrl", "storage_url",
                    "path"
                ]
            )
        )
    }

    private static func remoteImageURL(from value: AnyJSON?) -> URL? {
        if let array = arrayValue(value) {
            for item in array {
                if let url = remoteImageURL(from: item) { return url }
            }
            return nil
        }
        if let dict = objectValue(value) {
            let direct = firstString(
                dict,
                keys: [
                    "url", "src", "image_url", "imageUrl", "storageUrl",
                    "storage_url", "publicUrl", "public_url", "assetUrl", "asset_url",
                    "cdnUrl", "cdn_url", "secureUrl", "secure_url",
                    "signedUrl", "signed_url", "downloadUrl", "download_url",
                    "fileUrl", "file_url", "mediaUrl", "media_url"
                ]
            )
            if let url = remoteImageURL(from: direct) { return url }

            for key in dict.keys.sorted() {
                let normalized = key.lowercased()
                guard normalized.contains("image")
                    || normalized.contains("asset")
                    || normalized.contains("visual")
                    || normalized.contains("media")
                    || normalized.contains("url") else { continue }
                if let url = remoteImageURL(from: dict[key]) { return url }
            }
            return nil
        }
        return remoteImageURL(from: stringValue(value))
    }

    private static func generatedAssetPath(from value: AnyJSON?) -> String? {
        if let array = arrayValue(value) {
            for item in array {
                if let path = generatedAssetPath(from: item) { return path }
            }
            return nil
        }

        if let dict = objectValue(value) {
            let direct = firstString(
                dict,
                keys: [
                    "storageObjectName", "storage_object_name",
                    "objectName", "object_name",
                    "assetPath", "asset_path",
                    "storagePath", "storage_path",
                    "storageUrl", "storage_url",
                    "path"
                ]
            )
            if let path = generatedAssetPath(from: direct) { return path }

            for key in dict.keys.sorted() {
                let normalized = key.lowercased()
                guard normalized.contains("storage")
                    || normalized.contains("object")
                    || normalized.contains("asset")
                    || normalized.contains("image")
                    || normalized.contains("path") else { continue }
                if let path = generatedAssetPath(from: dict[key]) { return path }
            }
            return nil
        }

        return generatedAssetPath(from: stringValue(value))
    }

    private static func generatedAssetPath(from raw: String) -> String? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}\"'`"))
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("sourcebase/users/"), trimmed.contains("/generated/") {
            return trimmed
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme != "http",
           scheme != "https" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.hasPrefix("sourcebase/users/"), path.contains("/generated/") {
                return path
            }
        }

        return nil
    }

    private static func remoteImageURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = absoluteRemoteURL(from: trimmed) { return url }
        return embeddedRemoteImageURL(in: trimmed)
    }

    private static func absoluteRemoteURL(from raw: String) -> URL? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}\"'`"))
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    private static func embeddedRemoteImageURL(in text: String) -> URL? {
        let patterns = [
            "!\\[[^\\]]*\\]\\((https?://[^\\s\\)]+)\\)",
            "https?://[^\\s<>\\\"'\\)\\]]+"
        ]
        let nsText = text as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let range = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
                guard range.location != NSNotFound else { continue }
                let candidate = nsText.substring(with: range)
                guard let url = absoluteRemoteURL(from: candidate) else { continue }
                if pattern.hasPrefix("!") || looksLikeImageURL(url) {
                    return url
                }
            }
        }
        return nil
    }

    private static func looksLikeImageURL(_ url: URL) -> Bool {
        let lower = url.absoluteString.lowercased()
        return [".png", ".jpg", ".jpeg", ".webp", ".gif"].contains { lower.contains($0) }
            || lower.contains("image")
            || lower.contains("infographic")
            || lower.contains("asset")
            || lower.contains("cdn")
            || lower.contains("storage")
    }

    private static func infographicBlocks(from dict: [String: AnyJSON], fallbackText: String?) -> [String] {
        var blocks: [String] = []
        for key in [
            "blocks", "sections", "items", "cards", "panels",
            "contentBlocks", "content_blocks", "infoBlocks", "info_blocks",
            "highlights", "facts"
        ] {
            blocks.append(contentsOf: infographicBlockItems(dict[key]))
        }
        if blocks.isEmpty {
            for key in [
                "summary", "overview", "description", "mainMessage", "main_message",
                "message", "warnings", "red_flags", "redFlags", "quick_check",
                "quickCheck", "self_check", "sourceNote", "source_note"
            ] {
                blocks.append(contentsOf: sectionItems(dict[key]))
            }
        }
        if blocks.isEmpty {
            blocks = fallbackLines(fallbackText)
        }
        return uniqueStrings(blocks)
    }

    private static func infographicBlockItems(_ value: AnyJSON?) -> [String] {
        guard let value else { return [] }
        if let array = arrayValue(value) {
            return array.flatMap { item -> [String] in
                guard let dict = objectValue(item) else {
                    let text = stringValue(item).trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? [] : [text]
                }

                let title = firstString(dict, keys: ["heading", "title", "label", "name"])
                let body = firstString(dict, keys: ["text", "body", "content", "detail", "description", "caption", "note"])
                let bullets = sectionItems(
                    dict["bullets"]
                        ?? dict["items"]
                        ?? dict["points"]
                        ?? dict["facts"]
                        ?? dict["warnings"]
                )

                var items: [String] = []
                if !body.isEmpty {
                    items.append(title.isEmpty ? body : "\(title): \(body)")
                }
                if !bullets.isEmpty {
                    items.append(contentsOf: title.isEmpty ? bullets : bullets.map { "\(title): \($0)" })
                }
                if items.isEmpty, !title.isEmpty {
                    items.append(title)
                }
                return items
            }
        }

        if let dict = objectValue(value) {
            return dict.keys.sorted().flatMap { key -> [String] in
                let items = infographicBlockItems(dict[key])
                guard !items.isEmpty else { return [] }
                let title = label(for: key)
                return items.map { item in
                    item.hasPrefix("\(title):") ? item : "\(title): \(item)"
                }
            }
        }

        let text = stringValue(value).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? [] : [text]
    }

    private static func fallbackLines(_ fallbackText: String?) -> [String] {
        let fallback = fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !fallback.isEmpty else { return [] }
        let lines = fallback
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.count > 1 ? lines : [fallback]
    }

    private static func fallbackDocumentParts(for kind: GeneratedKind, fallbackText: String?) -> (summary: String, blocks: [SBStudyBlock]) {
        let items = fallbackLines(fallbackText)
        guard !items.isEmpty else { return ("", []) }
        let summary = items.first ?? ""
        let remaining = Array(items.dropFirst())
        let bodyItems = remaining.isEmpty ? items : remaining

        switch kind {
        case .flashcard:
            return (
                summary,
                [.cards(id: "fallback-cards", cards: [
                    SBFlashcard(front: summary, back: bodyItems.joined(separator: "\n"))
                ])]
            )
        case .question:
            return (
                summary,
                [.calloutList(id: "fallback-question", title: "Soru Taslağı", items: bodyItems, style: .objective)]
            )
        case .summary:
            return (
                summary,
                [.calloutList(id: "fallback-summary", title: "Yüksek Verimli Notlar", items: bodyItems, style: .mustKnow)]
            )
        case .examMorningSummary:
            return (
                summary,
                [.calloutList(id: "fallback-exam-morning", title: "Sınav Sabahı Notları", items: bodyItems, style: .mustKnow)]
            )
        case .algorithm:
            return (
                summary,
                [.steps(id: "fallback-algorithm", title: "Akış Adımları", items: bodyItems)]
            )
        case .comparison, .table:
            let rows = bodyItems.enumerated().map { item in ["Kriter \(item.offset + 1)", item.element] }
            return (
                summary,
                [.table(id: "fallback-comparison", title: "Karşılaştırma", table: SBStudyTable(headers: ["Kriter", "Kaynak Notu"], rows: rows))]
            )
        case .clinicalScenario:
            return (
                summary,
                [
                    .paragraph(id: "fallback-clinical-stem", text: summary),
                    .calloutList(id: "fallback-clinical-points", title: "Klinik Noktalar", items: bodyItems, style: .tip)
                ]
            )
        case .learningPlan:
            return (
                summary,
                [.timeline(id: "fallback-plan", title: "Çalışma Oturumları", entries: bodyItems.enumerated().map { item in
                    SBTimelineEntry(title: "Oturum \(item.offset + 1)", items: [item.element])
                })]
            )
        case .podcast:
            return (
                summary,
                [.audio(id: "fallback-podcast", url: nil, segments: [
                    SBPodcastSegment(title: "Transkript", text: items.joined(separator: "\n"))
                ])]
            )
        case .infographic:
            return (
                summary,
                [.calloutList(id: "fallback-infographic", title: "İnfografik Blokları", items: bodyItems, style: .plain)]
            )
        case .mindMap:
            return (
                summary,
                [.mindBranches(id: "fallback-mind-map", title: "Dallar", branches: [
                    SBMindBranch(label: summary, children: bodyItems)
                ])]
            )
        }
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }

    /// Comparison schema: `rows: [{label, values[]}]` + `headers[]`.
    private static func comparisonTable(from dict: [String: AnyJSON]?) -> SBStudyTable? {
        guard let dict else { return nil }
        let headers = stringArray(dict["headers"] ?? dict["columns"])
        guard let rawRows = arrayValue(dict["rows"]) else { return nil }
        let rows: [[String]] = rawRows.compactMap { row in
            guard let obj = objectValue(row) else { return nil }
            let label = firstString(obj, keys: ["label", "feature", "criterion"])
            let values = stringArray(obj["values"])
            guard !label.isEmpty || !values.isEmpty else { return nil }
            return ([label] + values).filter { !$0.isEmpty }
        }
        guard !rows.isEmpty else { return nil }
        return SBStudyTable(headers: headers, rows: rows)
    }

    private static func table(from dict: [String: AnyJSON]?) -> SBStudyTable? {
        guard let dict else { return nil }
        let nestedTable = objectValue(dict["mini_table"] ?? dict["miniTable"] ?? dict["table"])
        let tableSource = nestedTable ?? dict
        let headers = stringArray(tableSource["headers"] ?? tableSource["columns"])
        guard let rawRows = array(in: .object(tableSource), keys: ["rows", "items"]) else { return nil }
        let rows: [[String]] = rawRows.compactMap { row in
            if let array = arrayValue(row) {
                return array.map { stringValue($0) }.filter { !$0.isEmpty }
            }
            if let object = objectValue(row) {
                if headers.isEmpty {
                    return object.keys.sorted().map { stringValue(object[$0]) }.filter { !$0.isEmpty }
                }
                return headers.map { stringValue(object[$0]) }
            }
            let text = stringValue(row)
            return text.isEmpty ? nil : [text]
        }
        guard !rows.isEmpty else { return nil }
        return SBStudyTable(headers: headers, rows: rows)
    }

    private static func sectionItems(_ value: AnyJSON?) -> [String] {
        guard let value else { return [] }
        if let array = arrayValue(value) {
            return array.flatMap { item -> [String] in
                if let dict = objectValue(item) {
                    let title = firstString(dict, keys: ["title", "label", "criterion", "from", "if"])
                    let body = firstString(dict, keys: ["text", "value", "detail", "description", "then", "to", "tip", "note"])
                    let combined = [title, body].filter { !$0.isEmpty }.joined(separator: ": ")
                    return combined.isEmpty ? [] : [combined]
                }
                let text = stringValue(item)
                return text.isEmpty ? [] : [text]
            }
        }
        if let dict = objectValue(value) {
            return dict.keys.sorted().compactMap { key in
                let text = stringValue(dict[key])
                return text.isEmpty ? nil : "\(label(for: key)): \(text)"
            }
        }
        let text = stringValue(value)
        return text.isEmpty ? [] : [text]
    }

    private static func array(in value: AnyJSON?, keys: [String]) -> [AnyJSON]? {
        guard let dict = objectValue(value) else { return nil }
        for key in keys {
            if let array = arrayValue(dict[key]) { return array }
        }
        return nil
    }

    private static func objectPayload(from response: [String: AnyJSON]) -> AnyJSON? {
        if case .object(let data)? = response["data"] {
            return .object(data)
        }
        return .object(response)
    }

    private static func firstString(_ dict: [String: AnyJSON], keys: [String]) -> String {
        for key in keys {
            let text = stringValue(dict[key]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        return ""
    }

    private static func stringArray(_ value: AnyJSON?) -> [String] {
        guard let array = arrayValue(value) else { return [] }
        return array.map { stringValue($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func objectValue(_ value: AnyJSON?) -> [String: AnyJSON]? {
        guard case .object(let dict) = value else { return nil }
        return dict
    }

    private static func arrayValue(_ value: AnyJSON?) -> [AnyJSON]? {
        guard case .array(let array) = value else { return nil }
        return array
    }

    private static func stringValue(_ value: AnyJSON?) -> String {
        guard let value else { return "" }
        switch value {
        case .string(let string): return string
        case .integer(let int): return String(int)
        case .double(let double): return String(double)
        case .bool(let bool): return bool ? "true" : "false"
        default: return ""
        }
    }

    private static func intValue(_ value: AnyJSON?) -> Int? {
        guard let value else { return nil }
        switch value {
        case .integer(let int): return int
        case .double(let double): return Int(double)
        case .string(let string): return Int(string)
        default: return nil
        }
    }

    private static func firstInt(_ dict: [String: AnyJSON], keys: [String]) -> Int? {
        for key in keys {
            if let int = intValue(dict[key]) { return int }
        }
        return nil
    }

    private static func boolValue(_ value: AnyJSON?) -> Bool? {
        guard let value else { return nil }
        switch value {
        case .bool(let bool): return bool
        case .string(let string): return Bool(string)
        default: return nil
        }
    }

    private static func normalizedDifficulty(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["easy", "kolay"].contains(normalized) { return "easy" }
        if ["hard", "zor", "very hard", "çok zor", "cok zor"].contains(normalized) { return "hard" }
        return "medium"
    }

    private static func label(for key: String) -> String {
        let labels = [
            "must_know": "Mutlaka Bil",
            "commonly_confused": "Sık Karışanlar",
            "clinical_tus_tips": "Klinik İpuçları",
            "red_flags": "Kırmızı Bayraklar",
            "self_check": "Kendini Kontrol Et",
            "decision_nodes": "Karar Düğümleri",
            "branches": "Akış Dalları",
            "thresholds": "Eşikler",
            "action_steps": "Eylem Adımları",
            "distinguishing_tips": "Ayırt Edici İpuçları",
            "clinical_notes": "Klinik Notlar",
            "steps": "Adımlar",
            "nodes": "Düğümler",
            "sections": "Bölümler",
            "teachingPoints": "Öğretici Noktalar",
            "teaching_points": "Öğretici Noktalar",
            "objectives": "Hedefler",
            "learningObjectives": "Öğrenme Hedefleri",
            "learning_objectives": "Öğrenme Hedefleri",
            "days": "Günler",
            "tasks": "Görevler",
            "redFlags": "Kırmızı Bayraklar",
            "clinicalTips": "Klinik İpuçları",
            "clinical_tips": "Klinik İpuçları",
            "highYieldPoints": "Yüksek Verimli Noktalar",
            "high_yield_points": "Yüksek Verimli Noktalar",
            "pitfalls": "Tuzak Noktalar",
            "keyTakeaways": "Ana Çıkarımlar",
            "key_takeaways": "Ana Çıkarımlar"
        ]
        if let label = labels[key] { return label }
        return key
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
