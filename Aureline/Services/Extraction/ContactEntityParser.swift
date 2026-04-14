import Foundation
import NaturalLanguage

struct DetectedContactEntity: Sendable, Equatable {
    enum Kind: String, Sendable {
        case personName
        case emailAddress
        case phoneNumber
        case link
    }

    let sourceText: String
    let normalizedValue: String?
    let kind: Kind
    let range: NSRange
    let confidence: Double
}

struct ContactEntityParser: Sendable {
    func parse(in text: String) -> [DetectedContactEntity] {
        let structuredEntities = parseStructuredContacts(in: text)
        let nameEntities = parseNames(in: text, excluding: structuredEntities.map(\.range))
        return deduplicated(structuredEntities + nameEntities)
    }

    private func parseStructuredContacts(in text: String) -> [DetectedContactEntity] {
        let types = NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        var entities: [DetectedContactEntity] = []
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let detector = try? NSDataDetector(types: types) {
            entities.append(contentsOf: detector.matches(in: text, options: [], range: fullRange).compactMap { result in
                guard let range = Range(result.range, in: text) else { return nil }
                let sourceText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sourceText.isEmpty else { return nil }

                if let phoneNumber = result.phoneNumber {
                    return DetectedContactEntity(
                        sourceText: sourceText,
                        normalizedValue: phoneNumber,
                        kind: .phoneNumber,
                        range: result.range,
                        confidence: 0.95
                    )
                }

                if let url = result.url {
                    let absolute = url.absoluteString
                    if absolute.lowercased().hasPrefix("mailto:") || sourceText.contains("@") {
                        let normalized = absolute.replacingOccurrences(of: "mailto:", with: "")
                        return DetectedContactEntity(
                            sourceText: sourceText,
                            normalizedValue: normalized,
                            kind: .emailAddress,
                            range: result.range,
                            confidence: 0.95
                        )
                    }

                    return DetectedContactEntity(
                        sourceText: sourceText,
                        normalizedValue: absolute,
                        kind: .link,
                        range: result.range,
                        confidence: 0.9
                    )
                }

                return nil
            })
        }

        entities.append(contentsOf: regexEntities(
            pattern: #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            in: text,
            kind: .emailAddress,
            confidence: 0.92
        ) { $0.lowercased() })

        entities.append(contentsOf: regexEntities(
            pattern: #"\+?\d[\d\-\s().]{6,}\d"#,
            in: text,
            kind: .phoneNumber,
            confidence: 0.92
        ) { $0 })

        return entities
    }

    private func parseNames(in text: String, excluding excludedRanges: [NSRange]) -> [DetectedContactEntity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var entities: [DetectedContactEntity] = []
        let textRange = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: textRange, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            guard tag == .personalName else { return true }

            let nsRange = NSRange(range, in: text)
            guard excludedRanges.allSatisfy({ !rangesIntersect($0, nsRange) }) else { return true }

            let sourceText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = normalizePersonName(sourceText)
            guard normalizedName.count > 1, isLikelyPersonName(normalizedName) else { return true }

            entities.append(
                DetectedContactEntity(
                    sourceText: normalizedName,
                    normalizedValue: normalizedName,
                    kind: .personName,
                    range: nsRange,
                    confidence: 0.72
                )
            )
            return true
        }

        entities.append(contentsOf: parseActionCueFallbackNames(in: text))

        return entities
    }

    private func parseActionCueFallbackNames(in text: String) -> [DetectedContactEntity] {
        let pattern = #"\b(?:call|email|text|meet|ask|remind|follow up with|check with|send to)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: fullRange).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else {
                return nil
            }

            let name = normalizePersonName(String(text[range]))
            guard name.count > 1, isLikelyPersonName(name) else { return nil }
            return DetectedContactEntity(
                sourceText: name,
                normalizedValue: name,
                kind: .personName,
                range: match.range(at: 1),
                confidence: 0.68
            )
        }
    }

    private func regexEntities(
        pattern: String,
        in text: String,
        kind: DetectedContactEntity.Kind,
        confidence: Double,
        normalizer: (String) -> String
    ) -> [DetectedContactEntity] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let sourceText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sourceText.isEmpty else { return nil }

            return DetectedContactEntity(
                sourceText: sourceText,
                normalizedValue: normalizer(sourceText),
                kind: kind,
                range: match.range,
                confidence: confidence
            )
        }
    }

    private func deduplicated(_ entities: [DetectedContactEntity]) -> [DetectedContactEntity] {
        var seen: Set<String> = []
        return entities
            .sorted { $0.range.location < $1.range.location }
            .filter { entity in
                let key = "\(entity.kind.rawValue)|\((entity.normalizedValue ?? entity.sourceText).lowercased())"
                return seen.insert(key).inserted
            }
    }

    private func normalizePersonName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(?:(?:call|email|text|meet|ask|remind)\s+|follow up with\s+|check with\s+|send to\s+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return trimmed
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let normalized = regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "")
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isLikelyPersonName(_ value: String) -> Bool {
        let words = value.split(separator: " ")
        guard !words.isEmpty else { return false }

        return words.allSatisfy { word in
            guard let first = word.first else { return false }
            return first.isUppercase && word.dropFirst().allSatisfy { $0.isLetter || $0 == "'" || $0 == "-" }
        }
    }
}

private func rangesIntersect(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
    NSIntersectionRange(lhs, rhs).length > 0
}
