import Foundation
import SwiftData

@MainActor
struct VoiceMemoRepository {
    let modelContext: ModelContext

    @discardableResult
    func createPlaceholderMemo(source: MemoSource) -> VoiceMemo {
        let title: String
        let duration: Double

        switch source {
        case .recorded:
            title = "Project follow-up"
            duration = 78
        case .imported:
            title = "Client estimate"
            duration = 52
        }

        let memo = VoiceMemo(
            title: title,
            source: source,
            audioRelativePath: "placeholder/\(UUID().uuidString).m4a",
            originalFilename: source == .imported ? "sample-\(UUID().uuidString.prefix(6)).m4a" : nil,
            durationSeconds: duration
        )
        memo.transcriptText = nil
        memo.lastProcessingError = nil
        modelContext.insert(memo)
        persist("Unable to save the new note.", memo: memo)

        if source == .recorded {
            memo.localeIdentifier = Locale.current.identifier
        }

        memo.touch()
        persist("Unable to update the new note.", memo: memo)
        return memo
    }

    func addPlaceholderTranscript(to memo: VoiceMemo) {
        clearSegments(for: memo)

        let transcript: String
        let segmentOne: String
        let segmentTwo: String

        switch memo.source {
        case .recorded:
            transcript = "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday."
            segmentOne = "Call Jordan tomorrow about the lighting quote."
            segmentTwo = "Send the revised site plan before Friday."
        case .imported:
            transcript = "Email Priya the updated estimate next Tuesday. Confirm the install window for 9 AM."
            segmentOne = "Email Priya the updated estimate next Tuesday."
            segmentTwo = "Confirm the install window for 9 AM."
        }

        memo.transcriptText = transcript
        memo.transcriptionStatus = .completed
        memo.lastProcessingError = nil
        memo.touch()

        let firstSegment = TranscriptSegment(startSeconds: 0, durationSeconds: memo.durationSeconds / 2, text: segmentOne, memo: memo)
        let secondSegment = TranscriptSegment(startSeconds: memo.durationSeconds / 2, durationSeconds: memo.durationSeconds / 2, text: segmentTwo, memo: memo)
        memo.transcriptSegments.append(firstSegment)
        memo.transcriptSegments.append(secondSegment)

        persist("Unable to save transcript changes.", memo: memo)
    }

    func addPlaceholderExtraction(to memo: VoiceMemo) {
        if memo.transcriptText == nil {
            addPlaceholderTranscript(to: memo)
        }

        clearActionItems(for: memo)
        clearMentions(for: memo)

        let firstAction: ExtractedActionItem
        let secondAction: ExtractedActionItem
        let dateMention: ExtractedMention
        let contactMention: ExtractedMention

        switch memo.source {
        case .recorded:
            firstAction = ExtractedActionItem(
                rawText: "Call Jordan tomorrow about the lighting quote.",
                normalizedText: "Call Jordan about the lighting quote.",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                contactName: "Jordan",
                contactMethod: "Phone",
                confidence: 0.89,
                memo: memo
            )
            secondAction = ExtractedActionItem(
                rawText: "Send the revised site plan before Friday.",
                normalizedText: "Send the revised site plan.",
                dueDate: Calendar.current.nextDate(after: .now, matching: DateComponents(weekday: 6), matchingPolicy: .nextTime),
                contactName: nil,
                contactMethod: "Email",
                confidence: 0.82,
                memo: memo
            )
            dateMention = ExtractedMention(kind: .date, displayText: "tomorrow", normalizedValue: "Next day", confidence: 0.91, memo: memo)
            contactMention = ExtractedMention(kind: .contact, displayText: "Jordan", normalizedValue: "Jordan", confidence: 0.84, memo: memo)
        case .imported:
            firstAction = ExtractedActionItem(
                rawText: "Email Priya the updated estimate next Tuesday.",
                normalizedText: "Email Priya the updated estimate.",
                dueDate: Calendar.current.nextDate(after: .now, matching: DateComponents(weekday: 3), matchingPolicy: .nextTime),
                contactName: "Priya",
                contactMethod: "Email",
                confidence: 0.94,
                memo: memo
            )
            secondAction = ExtractedActionItem(
                rawText: "Confirm the install window for 9 AM.",
                normalizedText: "Confirm the install window.",
                dueDate: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now),
                contactName: nil,
                contactMethod: "Phone",
                confidence: 0.78,
                memo: memo
            )
            dateMention = ExtractedMention(kind: .date, displayText: "next Tuesday", normalizedValue: "Next Tuesday", confidence: 0.88, memo: memo)
            contactMention = ExtractedMention(kind: .contact, displayText: "Priya", normalizedValue: "Priya", confidence: 0.93, memo: memo)
        }

        memo.actionItems.append(firstAction)
        memo.actionItems.append(secondAction)
        memo.mentions.append(dateMention)
        memo.mentions.append(contactMention)
        memo.extractionStatus = .completed
        memo.touch()

        persist("Unable to save review items.", memo: memo)
    }

    private func clearSegments(for memo: VoiceMemo) {
        for segment in memo.transcriptSegments {
            modelContext.delete(segment)
        }
        memo.transcriptSegments.removeAll()
    }

    private func clearActionItems(for memo: VoiceMemo) {
        for actionItem in memo.actionItems {
            modelContext.delete(actionItem)
        }
        memo.actionItems.removeAll()
    }

    private func clearMentions(for memo: VoiceMemo) {
        for mention in memo.mentions {
            modelContext.delete(mention)
        }
        memo.mentions.removeAll()
    }

    private func persist(_ errorMessage: String, memo: VoiceMemo?) {
        do {
            try modelContext.save()
        } catch {
            memo?.lastProcessingError = errorMessage
            assertionFailure("\(errorMessage) \(error.localizedDescription)")
        }
    }
}
