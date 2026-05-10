import Foundation

enum RealtimeUtteranceMerger {
    static func canMerge(
        previous: TranscriptionEntry,
        nextText: String,
        nextLanguage: String?,
        nextSource: TranscriptionEntry.AudioSource,
        nextTimestamp: Date,
        maxDuration: TimeInterval,
        maxCharacters: Int
    ) -> Bool {
        guard previous.realtimeItemID != nil, !previous.isDraft else { return false }
        guard previous.source == nextSource else { return false }
        guard !nextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let elapsed = nextTimestamp.timeIntervalSince(previous.timestamp)
        guard elapsed >= 0, elapsed <= maxDuration else { return false }
        guard previous.originalText.count + nextText.count <= maxCharacters else { return false }

        let previousLanguage = previous.detectedLanguage?.lowercased()
        let incomingLanguage = nextLanguage?.lowercased()
        if let previousLanguage, let incomingLanguage, previousLanguage != incomingLanguage {
            return false
        }

        return mergedText(previous: previous.originalText, next: nextText) != nil
    }

    static func mergedText(previous: String, next: String) -> String? {
        let lhs = previous.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = next.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lhs.isEmpty, !rhs.isEmpty else { return nil }

        if lhs.caseInsensitiveCompare(rhs) == .orderedSame { return nil }
        if lhs.lowercased().hasSuffix(rhs.lowercased()) { return nil }

        let overlap = longestSuffixPrefixOverlap(lhs, rhs)
        let appendStart = rhs.index(rhs.startIndex, offsetBy: overlap)
        let remainder = String(rhs[appendStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else { return nil }

        if shouldInsertSpace(between: lhs, and: remainder) {
            return lhs + " " + remainder
        }
        return lhs + remainder
    }

    private static func longestSuffixPrefixOverlap(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs.lowercased())
        let right = Array(rhs.lowercased())
        let maxLength = min(left.count, right.count, 48)
        guard maxLength > 0 else { return 0 }

        for length in stride(from: maxLength, through: 1, by: -1) {
            if Array(left.suffix(length)) == Array(right.prefix(length)),
               isSafeOverlap(left: left, right: right, length: length) {
                return length
            }
        }
        return 0
    }

    private static func isSafeOverlap(left: [Character], right: [Character], length: Int) -> Bool {
        let overlap = Array(right.prefix(length))
        if overlap.allSatisfy(isCJK) {
            return true
        }

        guard length >= 2 else { return false }
        let leftStart = left.count - length
        let hasBoundaryBeforeOverlap = leftStart == 0 || isBoundary(left[leftStart - 1])
        let hasBoundaryAfterOverlap = length == right.count || isBoundary(right[length])
        return hasBoundaryBeforeOverlap && hasBoundaryAfterOverlap
    }

    private static func shouldInsertSpace(between lhs: String, and rhs: String) -> Bool {
        guard let last = lhs.unicodeScalars.last, let first = rhs.unicodeScalars.first else { return false }
        if last.properties.isWhitespace || first.properties.isWhitespace { return false }
        if isCJK(last) || isCJK(first) { return false }
        if isLeadingPunctuation(first) || isTrailingPunctuation(last) { return false }
        return true
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        return (value >= 0x4E00 && value <= 0x9FFF)
            || (value >= 0x3400 && value <= 0x4DBF)
            || (value >= 0x3040 && value <= 0x30FF)
            || (value >= 0xAC00 && value <= 0xD7AF)
    }

    private static func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(isCJK)
    }

    private static func isBoundary(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else { return false }
        return scalar.properties.isWhitespace || CharacterSet.punctuationCharacters.contains(scalar)
    }

    private static func isLeadingPunctuation(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet(charactersIn: ".,!?;:，。！？；：、)]}").contains(scalar)
    }

    private static func isTrailingPunctuation(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet(charactersIn: "([{").contains(scalar)
    }
}
