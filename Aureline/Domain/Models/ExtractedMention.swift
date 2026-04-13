import Foundation
import SwiftData

enum ExtractedMentionKind: String {
    case date
    case contact
    case other
}

@Model
final class ExtractedMention {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var displayText: String
    var normalizedValue: String?
    var confidence: Double
    var memo: VoiceMemo?

    init(
        id: UUID = UUID(),
        kind: ExtractedMentionKind,
        displayText: String,
        normalizedValue: String? = nil,
        confidence: Double = 0.5,
        memo: VoiceMemo? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.displayText = displayText
        self.normalizedValue = normalizedValue
        self.confidence = confidence
        self.memo = memo
    }
}

extension ExtractedMention {
    var kind: ExtractedMentionKind {
        get { ExtractedMentionKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}
