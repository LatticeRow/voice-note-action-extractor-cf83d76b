import Foundation
import NaturalLanguage

struct ActionExtractionCandidate: Sendable, Equatable {
    let rawText: String
    let normalizedText: String
    let dueDate: Date?
    let contactName: String?
    let contactMethod: String?
    let confidence: Double
}

struct MentionCandidate: Sendable, Equatable {
    let kind: ExtractedMentionKind
    let displayText: String
    let normalizedValue: String?
    let confidence: Double
}

struct ActionExtractionPayload: Sendable, Equatable {
    let actionItems: [ActionExtractionCandidate]
    let mentions: [MentionCandidate]
}

enum ActionExtractionError: LocalizedError, Sendable, Equatable {
    case missingTranscript

    var errorDescription: String? {
        switch self {
        case .missingTranscript:
            return "Add a transcript before reviewing next steps."
        }
    }
}

struct ActionExtractionService: Sendable {
    private let dateParser: DateEntityParser
    private let contactParser: ContactEntityParser

    init(
        dateParser: DateEntityParser = DateEntityParser(),
        contactParser: ContactEntityParser = ContactEntityParser()
    ) {
        self.dateParser = dateParser
        self.contactParser = contactParser
    }

    func extract(
        from transcriptText: String,
        localeIdentifier _: String?,
        referenceDate: Date
    ) throws -> ActionExtractionPayload {
        let normalizedTranscript = transcriptText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTranscript.isEmpty else {
            throw ActionExtractionError.missingTranscript
        }

        let sentenceMatches = sentenceMatches(in: normalizedTranscript)
        let allDateEntities = dateParser.parse(in: normalizedTranscript, referenceDate: referenceDate)
        let allContactEntities = contactParser.parse(in: normalizedTranscript)

        var actionItems: [ActionExtractionCandidate] = []
        var mentions: [MentionWithLocation] = []

        for match in sentenceMatches {
            let sentenceDates = allDateEntities.filter { match.range.contains($0.range) }
            let sentenceContacts = allContactEntities.filter { match.range.contains($0.range) }
            let score = heuristicScore(for: match.text, dates: sentenceDates, contacts: sentenceContacts)

            if score >= 0.45 {
                actionItems.append(
                    ActionExtractionCandidate(
                        rawText: match.text,
                        normalizedText: normalizeActionText(match.text),
                        dueDate: sentenceDates.first?.date,
                        contactName: preferredContactName(from: sentenceContacts),
                        contactMethod: inferredContactMethod(in: match.text, contacts: sentenceContacts),
                        confidence: min(max(score, 0.46), 0.98)
                    )
                )
            }

            mentions.append(contentsOf: sentenceDates.map {
                MentionWithLocation(
                    candidate: MentionCandidate(
                        kind: .date,
                        displayText: $0.sourceText,
                        normalizedValue: normalizedDateValue(for: $0),
                        confidence: $0.confidence
                    ),
                    location: $0.range.location
                )
            })
            mentions.append(contentsOf: sentenceContacts.map {
                MentionWithLocation(
                    candidate: MentionCandidate(
                        kind: .contact,
                        displayText: $0.sourceText,
                        normalizedValue: $0.normalizedValue,
                        confidence: $0.confidence
                    ),
                    location: $0.range.location
                )
            })
        }

        return ActionExtractionPayload(
            actionItems: actionItems,
            mentions: deduplicateMentions(mentions).map(\.candidate)
        )
    }

    private func sentenceMatches(in text: String) -> [SentenceMatch] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var matches: [SentenceMatch] = []
        let range = text.startIndex..<text.endIndex
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let rawSentence = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawSentence.isEmpty else { return true }

            matches.append(
                SentenceMatch(
                    text: rawSentence,
                    range: NSRange(tokenRange, in: text)
                )
            )
            return true
        }

        return matches
    }

    private func heuristicScore(
        for sentence: String,
        dates: [DetectedDateEntity],
        contacts: [DetectedContactEntity]
    ) -> Double {
        let lowered = sentence.lowercased()
        var score = 0.0

        for cue in Self.actionCues where lowered.contains(cue.phrase) {
            score += cue.weight
        }

        if let firstWord = lowered.split(separator: " ").first, Self.leadingImperatives.contains(String(firstWord)) {
            score += 0.14
        }

        if !dates.isEmpty {
            score += 0.16
        }

        if !contacts.isEmpty {
            score += 0.14
        }

        let wordCount = lowered.split(whereSeparator: \.isWhitespace).count
        if wordCount >= 3 && wordCount <= 18 {
            score += 0.08
        }

        if lowered.contains("?") {
            score -= 0.18
        }

        if lowered.hasPrefix("fyi") || lowered.hasPrefix("by the way") {
            score -= 0.16
        }

        return score
    }

    private func normalizeActionText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[.!?]+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func preferredContactName(from contacts: [DetectedContactEntity]) -> String? {
        if let name = contacts.first(where: { $0.kind == .personName }) {
            return name.sourceText
        }

        return contacts.first?.normalizedValue ?? contacts.first?.sourceText
    }

    private func inferredContactMethod(in sentence: String, contacts: [DetectedContactEntity]) -> String? {
        let lowered = sentence.lowercased()

        if lowered.contains("call") || contacts.contains(where: { $0.kind == .phoneNumber }) {
            return "Phone"
        }

        if lowered.contains("email") || contacts.contains(where: { $0.kind == .emailAddress }) {
            return "Email"
        }

        if lowered.contains("text") {
            return "Text"
        }

        if lowered.contains("send") {
            return "Email"
        }

        return nil
    }

    private func normalizedDateValue(for entity: DetectedDateEntity) -> String {
        if entity.includesTime {
            return Self.dateTimeFormatter.string(from: entity.date)
        }

        return Self.dateFormatter.string(from: entity.date)
    }

    private func deduplicateMentions(_ mentions: [MentionWithLocation]) -> [MentionWithLocation] {
        var seen: Set<String> = []
        return mentions
            .sorted { $0.location < $1.location }
            .filter { mention in
                let key = "\(mention.candidate.kind.rawValue)|\(mention.candidate.displayText.lowercased())|\((mention.candidate.normalizedValue ?? "").lowercased())"
                return seen.insert(key).inserted
            }
    }

    private static let actionCues: [(phrase: String, weight: Double)] = [
        ("follow up", 0.32),
        ("remember to", 0.34),
        ("need to", 0.34),
        ("call", 0.32),
        ("email", 0.32),
        ("text", 0.32),
        ("send", 0.24),
        ("schedule", 0.3),
        ("confirm", 0.22),
        ("review", 0.2),
        ("check", 0.18),
        ("book", 0.22),
    ]

    private static let leadingImperatives: Set<String> = [
        "call",
        "email",
        "send",
        "schedule",
        "confirm",
        "review",
        "check",
        "text",
        "book",
        "remember",
        "need",
    ]

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct SentenceMatch {
    let text: String
    let range: NSRange
}

private struct MentionWithLocation {
    let candidate: MentionCandidate
    let location: Int
}

private extension NSRange {
    func contains(_ other: NSRange) -> Bool {
        location <= other.location && NSMaxRange(self) >= NSMaxRange(other)
    }
}
