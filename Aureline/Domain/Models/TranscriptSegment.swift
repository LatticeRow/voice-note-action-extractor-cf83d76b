import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    @Attribute(.unique) var id: UUID
    var startSeconds: Double
    var durationSeconds: Double
    var text: String
    var memo: VoiceMemo?

    init(
        id: UUID = UUID(),
        startSeconds: Double,
        durationSeconds: Double,
        text: String,
        memo: VoiceMemo? = nil
    ) {
        self.id = id
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
        self.text = text
        self.memo = memo
    }
}
