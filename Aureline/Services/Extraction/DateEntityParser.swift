import Foundation

struct DetectedDateEntity: Sendable, Equatable {
    let sourceText: String
    let date: Date
    let includesTime: Bool
    let range: NSRange
    let confidence: Double
}

struct DateEntityParser: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func parse(in text: String, referenceDate: Date) -> [DetectedDateEntity] {
        var entities: [DetectedDateEntity] = []
        var claimedRanges: [NSRange] = []

        for entity in parseRelativeEntities(in: text, referenceDate: referenceDate) {
            entities.append(entity)
            claimedRanges.append(entity.range)
        }

        let types = NSTextCheckingResult.CheckingType.date.rawValue
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let detector = try? NSDataDetector(types: types) {
            detector.enumerateMatches(in: text, options: [], range: fullRange) { result, _, _ in
                guard let result, let date = result.date else { return }
                guard claimedRanges.allSatisfy({ !$0.intersects(result.range) }) else { return }
                guard let range = Range(result.range, in: text) else { return }

                let sourceText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sourceText.isEmpty else { return }

                entities.append(
                    DetectedDateEntity(
                        sourceText: sourceText,
                        date: date,
                        includesTime: includesTime(in: result),
                        range: result.range,
                        confidence: 0.9
                    )
                )
                claimedRanges.append(result.range)
            }
        }

        for entity in parseAbsoluteFallbacks(in: text) where claimedRanges.allSatisfy({ !$0.intersects(entity.range) }) {
            entities.append(entity)
            claimedRanges.append(entity.range)
        }

        return entities.sorted { $0.range.location < $1.range.location }
    }

    private func parseRelativeEntities(in text: String, referenceDate: Date) -> [DetectedDateEntity] {
        var entities: [DetectedDateEntity] = []
        var claimedRanges: [NSRange] = []

        for weekday in Self.weekdayPatterns {
            let matches = parseMatches(of: weekday.pattern, in: text, builder: { sourceText in
                guard let date = nextWeekdayDate(named: weekday.day, referenceDate: referenceDate) else {
                    return nil
                }

                return DetectedDateEntity(
                    sourceText: sourceText,
                    date: date,
                    includesTime: false,
                    range: placeholderRange,
                    confidence: weekday.confidence
                )
            })

            for match in matches where claimedRanges.allSatisfy({ !$0.intersects(match.range) }) {
                entities.append(match)
                claimedRanges.append(match.range)
            }
        }

        for match in parseMatches(of: #"\btoday\b"#, in: text, builder: { sourceText in
            let date = calendar.startOfDay(for: referenceDate)
            return DetectedDateEntity(
                sourceText: sourceText,
                date: date,
                includesTime: false,
                range: placeholderRange,
                confidence: 0.82
            )
        }) where claimedRanges.allSatisfy({ !$0.intersects(match.range) }) {
            entities.append(match)
            claimedRanges.append(match.range)
        }

        for match in parseMatches(of: #"\btomorrow\b"#, in: text, builder: { sourceText in
            guard let date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) else {
                return nil
            }

            return DetectedDateEntity(
                sourceText: sourceText,
                date: date,
                includesTime: false,
                range: placeholderRange,
                confidence: 0.86
            )
        }) where claimedRanges.allSatisfy({ !$0.intersects(match.range) }) {
            entities.append(match)
            claimedRanges.append(match.range)
        }

        return deduplicated(entities)
    }

    private func parseMatches(
        of pattern: String,
        in text: String,
        builder: (_ sourceText: String) -> DetectedDateEntity?
    ) -> [DetectedDateEntity] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let sourceText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard var entity = builder(sourceText) else { return nil }
            entity = DetectedDateEntity(
                sourceText: entity.sourceText,
                date: entity.date,
                includesTime: entity.includesTime,
                range: match.range,
                confidence: entity.confidence
            )
            return entity
        }
    }

    private func nextWeekdayDate(named day: String, referenceDate: Date) -> Date? {
        guard let weekday = Self.weekdayNumbers[day.lowercased()] else { return nil }
        return calendar.nextDate(
            after: referenceDate,
            matching: DateComponents(hour: 9, minute: 0, weekday: weekday),
            matchingPolicy: .nextTime,
            direction: .forward
        )
    }

    private func deduplicated(_ entities: [DetectedDateEntity]) -> [DetectedDateEntity] {
        var seen: Set<String> = []
        return entities
            .sorted { $0.range.location < $1.range.location }
            .filter { entity in
                let key = "\(entity.sourceText.lowercased())|\(entity.date.timeIntervalSinceReferenceDate)"
                return seen.insert(key).inserted
            }
    }

    private func includesTime(in result: NSTextCheckingResult) -> Bool {
        guard let date = result.date else { return false }
        let components = calendar.dateComponents(in: calendar.timeZone, from: date)
        return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
    }

    private func parseAbsoluteFallbacks(in text: String) -> [DetectedDateEntity] {
        let pattern = #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}(?:\s+at\s+\d{1,2}(?::\d{2})?\s*(?:AM|PM))?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let sourceText = String(text[range])

            let parsedDate = Self.absoluteDateTimeFormatter.date(from: sourceText)
                ?? Self.absoluteDateFormatter.date(from: sourceText)
            guard let parsedDate else { return nil }

            return DetectedDateEntity(
                sourceText: sourceText,
                date: parsedDate,
                includesTime: sourceText.lowercased().contains(" at "),
                range: match.range,
                confidence: 0.88
            )
        }
    }

    private static let weekdayNumbers: [String: Int] = [
        "sunday": 1,
        "monday": 2,
        "tuesday": 3,
        "wednesday": 4,
        "thursday": 5,
        "friday": 6,
        "saturday": 7,
    ]

    private static let weekdayPatterns: [(pattern: String, day: String, confidence: Double)] = [
        (#"\bnext\s+monday\b"#, "monday", 0.84),
        (#"\bnext\s+tuesday\b"#, "tuesday", 0.84),
        (#"\bnext\s+wednesday\b"#, "wednesday", 0.84),
        (#"\bnext\s+thursday\b"#, "thursday", 0.84),
        (#"\bnext\s+friday\b"#, "friday", 0.84),
        (#"\bnext\s+saturday\b"#, "saturday", 0.84),
        (#"\bnext\s+sunday\b"#, "sunday", 0.84),
        (#"\bbefore\s+monday\b"#, "monday", 0.78),
        (#"\bbefore\s+tuesday\b"#, "tuesday", 0.78),
        (#"\bbefore\s+wednesday\b"#, "wednesday", 0.78),
        (#"\bbefore\s+thursday\b"#, "thursday", 0.78),
        (#"\bbefore\s+friday\b"#, "friday", 0.78),
        (#"\bbefore\s+saturday\b"#, "saturday", 0.78),
        (#"\bbefore\s+sunday\b"#, "sunday", 0.78),
        (#"\bmonday\b"#, "monday", 0.74),
        (#"\btuesday\b"#, "tuesday", 0.74),
        (#"\bwednesday\b"#, "wednesday", 0.74),
        (#"\bthursday\b"#, "thursday", 0.74),
        (#"\bfriday\b"#, "friday", 0.74),
        (#"\bsaturday\b"#, "saturday", 0.74),
        (#"\bsunday\b"#, "sunday", 0.74),
    ]

    private let placeholderRange = NSRange(location: 0, length: 0)

    private static let absoluteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let absoluteDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMMM d, yyyy 'at' h a"
        return formatter
    }()
}

private extension NSRange {
    func intersects(_ other: NSRange) -> Bool {
        NSIntersectionRange(self, other).length > 0
    }
}
