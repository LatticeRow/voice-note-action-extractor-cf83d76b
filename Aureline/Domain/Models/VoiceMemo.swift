import Foundation
import SwiftData

@Model
final class VoiceMemo {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var sourceRaw: String
    var audioRelativePath: String
    var originalFilename: String?
    var durationSeconds: Double
    var localeIdentifier: String?
    var transcriptText: String?
    var transcriptionStatusRaw: String
    var extractionStatusRaw: String
    var lastProcessingError: String?

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.memo)
    var transcriptSegments: [TranscriptSegment]

    @Relationship(deleteRule: .cascade, inverse: \ExtractedActionItem.memo)
    var actionItems: [ExtractedActionItem]

    @Relationship(deleteRule: .cascade, inverse: \ExtractedMention.memo)
    var mentions: [ExtractedMention]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String,
        source: MemoSource,
        audioRelativePath: String,
        originalFilename: String? = nil,
        durationSeconds: Double = 0,
        localeIdentifier: String? = Locale.current.identifier,
        transcriptText: String? = nil,
        transcriptionStatus: ProcessingStatus = .notStarted,
        extractionStatus: ProcessingStatus = .notStarted,
        lastProcessingError: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.sourceRaw = source.rawValue
        self.audioRelativePath = audioRelativePath
        self.originalFilename = originalFilename
        self.durationSeconds = durationSeconds
        self.localeIdentifier = localeIdentifier
        self.transcriptText = transcriptText
        self.transcriptionStatusRaw = transcriptionStatus.rawValue
        self.extractionStatusRaw = extractionStatus.rawValue
        self.lastProcessingError = lastProcessingError
        self.transcriptSegments = []
        self.actionItems = []
        self.mentions = []
    }
}

extension VoiceMemo {
    var source: MemoSource {
        get { MemoSource(rawValue: sourceRaw) ?? .recorded }
        set { sourceRaw = newValue.rawValue }
    }

    var transcriptionStatus: ProcessingStatus {
        get { ProcessingStatus(rawValue: transcriptionStatusRaw) ?? .notStarted }
        set { transcriptionStatusRaw = newValue.rawValue }
    }

    var extractionStatus: ProcessingStatus {
        get { ProcessingStatus(rawValue: extractionStatusRaw) ?? .notStarted }
        set { extractionStatusRaw = newValue.rawValue }
    }

    var durationText: String {
        Self.durationFormatter.string(from: durationSeconds) ?? "0:00"
    }

    var sortedTranscriptSegments: [TranscriptSegment] {
        transcriptSegments.sorted {
            if $0.startSeconds == $1.startSeconds {
                return $0.text < $1.text
            }
            return $0.startSeconds < $1.startSeconds
        }
    }

    var sortedActionItems: [ExtractedActionItem] {
        actionItems.sorted { lhs, rhs in
            if lhs.isSelectedForExport != rhs.isSelectedForExport {
                return lhs.isSelectedForExport && !rhs.isSelectedForExport
            }
            if lhs.confidence == rhs.confidence {
                return lhs.normalizedText.localizedCaseInsensitiveCompare(rhs.normalizedText) == .orderedAscending
            }
            return lhs.confidence > rhs.confidence
        }
    }

    var sortedMentions: [ExtractedMention] {
        mentions.sorted { lhs, rhs in
            if lhs.kindRaw == rhs.kindRaw {
                return lhs.displayText.localizedCaseInsensitiveCompare(rhs.displayText) == .orderedAscending
            }
            return lhs.kindRaw < rhs.kindRaw
        }
    }

    var selectedActionCount: Int {
        actionItems.filter(\.isSelectedForExport).count
    }

    var transcriptPreview: String {
        let text = (transcriptText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return statusSummary
        }

        if text.count <= 120 {
            return text
        }

        let index = text.index(text.startIndex, offsetBy: 120)
        return "\(text[..<index])."
    }

    var statusSummary: String {
        if lastProcessingError != nil || transcriptionStatus == .failed || extractionStatus == .failed {
            return "Needs attention"
        }
        if extractionStatus == .processing {
            return "Reviewing"
        }
        if extractionStatus == .completed {
            return "Ready to review"
        }
        if transcriptionStatus == .processing {
            return "Transcribing"
        }
        if transcriptionStatus == .completed {
            return "Transcribed"
        }
        return "Awaiting review"
    }

    var reviewSummary: String {
        if extractionStatus == .completed {
            if actionItems.isEmpty, mentions.isEmpty {
                return "No items found"
            }

            var parts: [String] = []
            if !actionItems.isEmpty {
                parts.append("\(actionItems.count) \(actionItems.count == 1 ? "task" : "tasks")")
            }
            if !mentions.isEmpty {
                parts.append("\(mentions.count) \(mentions.count == 1 ? "mention" : "mentions")")
            }
            return parts.joined(separator: " • ")
        }

        return extractionStatus.title
    }

    func touch() {
        updatedAt = .now
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
