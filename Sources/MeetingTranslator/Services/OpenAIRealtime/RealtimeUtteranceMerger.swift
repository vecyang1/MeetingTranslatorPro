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

    static func hasNoNewContent(previous: String, next: String) -> Bool {
        let lhs = previous.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = next.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lhs.isEmpty, rhs.count >= 4 else { return false }
        if lhs.caseInsensitiveCompare(rhs) == .orderedSame { return true }
        guard lhs.lowercased().hasSuffix(rhs.lowercased()) else { return false }
        return hasSafeTailDuplicateBoundary(previous: lhs, suffix: rhs)
    }

    static func canDropNoNewContent(
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

        let lhs = previous.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = nextText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lhs.isEmpty, !rhs.isEmpty, lhs.caseInsensitiveCompare(rhs) != .orderedSame else {
            return false
        }

        let elapsed = nextTimestamp.timeIntervalSince(previous.timestamp)
        guard elapsed >= 0, elapsed <= maxDuration else { return false }
        guard previous.originalText.count + rhs.count <= maxCharacters else { return false }

        let previousLanguage = previous.detectedLanguage?.lowercased()
        let incomingLanguage = nextLanguage?.lowercased()
        if let previousLanguage, let incomingLanguage, previousLanguage != incomingLanguage {
            return false
        }

        return hasNoNewContent(previous: lhs, next: rhs)
    }

    static func consolidateFinalEntries(
        entries: inout [TranscriptionEntry],
        source: TranscriptionEntry.AudioSource,
        mode: RealtimeRouteMode?,
        baseMaxDuration: TimeInterval,
        baseMaxCharacters: Int
    ) -> String? {
        guard mode != .translation else { return nil }

        let maxMergeDuration = source == .system ? baseMaxDuration * 1.5 : baseMaxDuration
        let maxMergeCharacters = source == .system ? baseMaxCharacters * 2 : baseMaxCharacters
        var index = 1
        var latestText: String?

        while index < entries.count {
            let current = entries[index]
            guard current.source == source,
                  current.realtimeItemID != nil,
                  !current.isDraft else {
                index += 1
                continue
            }

            latestText = current.originalText
            let previousIndex = entries.index(before: index)
            let previous = entries[previousIndex]
            guard previous.source == source,
                  previous.realtimeItemID != nil,
                  !previous.isDraft else {
                index += 1
                continue
            }

            if canDropNoNewContent(
                previous: previous,
                nextText: current.originalText,
                nextLanguage: current.detectedLanguage,
                nextSource: source,
                nextTimestamp: current.timestamp,
                maxDuration: maxMergeDuration,
                maxCharacters: maxMergeCharacters
            ) {
                entries.remove(at: index)
                latestText = previous.originalText
                continue
            }

            guard canMerge(
                previous: previous,
                nextText: current.originalText,
                nextLanguage: current.detectedLanguage,
                nextSource: source,
                nextTimestamp: current.timestamp,
                maxDuration: maxMergeDuration,
                maxCharacters: maxMergeCharacters
            ), let merged = mergedTextSequence([previous.originalText, current.originalText]) else {
                index += 1
                continue
            }

            entries[previousIndex].originalText = merged
            entries[previousIndex].translatedText = mergedOptionalText(
                previous: previous.translatedText,
                next: current.translatedText
            )
            entries[previousIndex].detectedLanguage = previous.detectedLanguage ?? current.detectedLanguage
            entries[previousIndex].speakerLabel = previous.speakerLabel?.isEmpty == false
                ? previous.speakerLabel
                : current.speakerLabel
            entries[previousIndex].isTranslating = previous.isTranslating || current.isTranslating
            entries.remove(at: index)
            latestText = merged
        }

        return latestText
    }

    static func mergedTextSequence(_ texts: [String]) -> String? {
        let chunks = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard var merged = chunks.first else { return nil }
        for chunk in chunks.dropFirst() {
            guard let next = mergedText(previous: merged, next: chunk) else {
                continue
            }
            merged = next
        }
        return merged
    }

    private static func mergedOptionalText(previous: String?, next: String?) -> String? {
        guard let next, !next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return previous
        }
        guard let previous, !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return next
        }
        return mergedTextSequence([previous, next]) ?? "\(previous)\n\(next)"
    }

    private static func hasSafeTailDuplicateBoundary(previous: String, suffix: String) -> Bool {
        let left = Array(previous.lowercased())
        let right = Array(suffix.lowercased())
        guard !right.isEmpty, right.count <= left.count else { return false }
        if right.allSatisfy(isCJK) { return true }
        let start = left.count - right.count
        return start == 0 || isBoundary(left[start - 1])
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
