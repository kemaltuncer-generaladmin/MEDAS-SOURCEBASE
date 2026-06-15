import Foundation

// MARK: - Systematic study document
//
// Every AI output type is parsed into ONE canonical document of typed blocks.
// Both the SwiftUI study screen and the native PDF exporter render this same
// document, so the on-screen template and the exported PDF can never drift
// apart ("sistematik iste → sistematiğe göre oturt → PDF de aynı sistematiğe
// göre"). Per-kind distinctiveness comes from the block composition + accent /
// icon resolved in the iOS layer (which owns the design tokens). This file is
// pure data: no SwiftUI, no colors.

/// Semantic emphasis for a list block. The iOS layer maps each style to a
/// design-token color + icon; the PDF maps it to a colored callout.
public enum SBCalloutStyle: String, Sendable, Equatable, Codable {
    case plain        // neutral bullet list
    case mustKnow     // high-yield, must-know
    case redFlag      // danger / critical
    case tip          // clinical / exam tip
    case confused     // commonly confused
    case objective    // learning objective
}

public struct SBDecisionNode: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let yes: String
    public let no: String
    public let substeps: [String]

    public init(id: String = UUID().uuidString, title: String, detail: String = "", yes: String = "", no: String = "", substeps: [String] = []) {
        self.id = id
        self.title = title
        self.detail = detail
        self.yes = yes
        self.no = no
        self.substeps = substeps
    }
}

public struct SBKeyValue: Identifiable, Sendable, Equatable {
    public let id: String
    public let key: String
    public let value: String

    public init(id: String = UUID().uuidString, key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

public struct SBQAPair: Identifiable, Sendable, Equatable {
    public let id: String
    public let question: String
    public let answer: String
    public let explanation: String

    public init(id: String = UUID().uuidString, question: String, answer: String, explanation: String = "") {
        self.id = id
        self.question = question
        self.answer = answer
        self.explanation = explanation
    }
}

public struct SBTimelineEntry: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let meta: String          // e.g. "30 dk", "Gün 1"
    public let items: [String]

    public init(id: String = UUID().uuidString, title: String, meta: String = "", items: [String]) {
        self.id = id
        self.title = title
        self.meta = meta
        self.items = items
    }
}

public struct SBMindBranch: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let children: [String]
    public let tags: [String]

    public init(id: String = UUID().uuidString, label: String, children: [String], tags: [String] = []) {
        self.id = id
        self.label = label
        self.children = children
        self.tags = tags
    }
}

/// One renderable block. `id` makes it usable directly in SwiftUI `ForEach`.
public enum SBStudyBlock: Identifiable, Sendable, Equatable {
    case paragraph(id: String, text: String)
    case calloutList(id: String, title: String, items: [String], style: SBCalloutStyle)
    case steps(id: String, title: String, items: [String])
    case decisions(id: String, title: String, nodes: [SBDecisionNode])
    case table(id: String, title: String, table: SBStudyTable)
    case keyValues(id: String, title: String, pairs: [SBKeyValue])
    case qa(id: String, title: String, pairs: [SBQAPair])
    case timeline(id: String, title: String, entries: [SBTimelineEntry])
    case mindBranches(id: String, title: String, branches: [SBMindBranch])
    case cards(id: String, cards: [SBFlashcard])
    case quiz(id: String, questions: [SBQlinikQuestion])
    case image(id: String, url: URL?, caption: String)
    case audio(id: String, url: URL?, segments: [SBPodcastSegment])

    public var id: String {
        switch self {
        case let .paragraph(id, _),
             let .calloutList(id, _, _, _),
             let .steps(id, _, _),
             let .decisions(id, _, _),
             let .table(id, _, _),
             let .keyValues(id, _, _),
             let .qa(id, _, _),
             let .timeline(id, _, _),
             let .mindBranches(id, _, _),
             let .cards(id, _),
             let .quiz(id, _),
             let .image(id, _, _),
             let .audio(id, _, _):
            return id
        }
    }
}

/// The full systematic document for one generated output.
public struct SBStudyDocument: Sendable, Equatable {
    public let kind: GeneratedKind
    public let title: String
    public let subtitle: String
    public let summary: String
    public let blocks: [SBStudyBlock]

    public init(kind: GeneratedKind, title: String, subtitle: String = "", summary: String = "", blocks: [SBStudyBlock]) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.blocks = blocks
    }

    /// True when the document has no meaningful body (only a placeholder).
    public var isEffectivelyEmpty: Bool {
        blocks.isEmpty && summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
