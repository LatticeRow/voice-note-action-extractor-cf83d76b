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

    var statusSummary: String {
        if extractionStatus == .completed {
            return "Ready to review"
        }
        if transcriptionStatus == .completed {
            return "Transcribed"
        }
        if lastProcessingError != nil {
            return "Needs attention"
        }
        return "Awaiting review"
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
