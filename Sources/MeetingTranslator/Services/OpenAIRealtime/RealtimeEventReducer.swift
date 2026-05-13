import Foundation

final class RealtimeEventReducer {
    private var pending: [String: RealtimePendingItem] = [:]
    private var sourceCaptionItemIDs: [TranscriptionEntry.AudioSource: String] = [:]
    private var translationToSourceCaptionItemIDs: [String: String] = [:]

    func reset() {
        pending.removeAll()
        sourceCaptionItemIDs.removeAll()
        translationToSourceCaptionItemIDs.removeAll()
    }

    func reduce(_ event: RealtimeAppEvent) -> RealtimeReducedEntry? {
        switch event {
        case .partialTranscript(let source, let itemID, let text, let timestamp):
            sourceCaptionItemIDs[source] = itemID
            let item = updateItem(source: source, itemID: itemID, timestamp: timestamp) { current in
                current.transcript += text
            }
            return reducedEntry(from: item, isFinal: false, isTranslationOnly: false)

        case .finalTranscript(let source, let itemID, let text, let language, let timestamp):
            sourceCaptionItemIDs[source] = itemID
            let item = updateItem(source: source, itemID: itemID, timestamp: timestamp) { current in
                let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let draftText = current.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if finalText.isEmpty {
                    current.transcript = draftText
                } else if !draftText.isEmpty,
                          draftText.caseInsensitiveCompare(finalText) != .orderedSame,
                          draftText.lowercased().hasPrefix(finalText.lowercased()) {
                    current.transcript = draftText
                } else {
                    current.transcript = finalText
                }
                current.language = language
            }
            pending.removeValue(forKey: key(source: source, itemID: itemID))
            return reducedEntry(from: item, isFinal: true, isTranslationOnly: false)

        case .partialTranslation(let source, let itemID, let text, let timestamp):
            let mapKey = translationMapKey(source: source, itemID: itemID)
            let targetItemID = sourceCaptionItemIDs[source] ?? translationToSourceCaptionItemIDs[mapKey] ?? itemID
            var supersededItemIDs: [String] = []
            if let previousTarget = translationToSourceCaptionItemIDs[mapKey],
               previousTarget != targetItemID {
                if moveTranslation(
                    source: source,
                    previousItemID: previousTarget,
                    targetItemID: targetItemID
                ) {
                    supersededItemIDs.append(previousTarget)
                }
            }
            translationToSourceCaptionItemIDs[mapKey] = targetItemID
            let item = updateItem(source: source, itemID: targetItemID, timestamp: timestamp) { current in
                current.translation = (current.translation ?? "") + text
            }
            return reducedEntry(
                from: item,
                isFinal: false,
                isTranslationOnly: true,
                supersededItemIDs: supersededItemIDs
            )

        case .finalTranslation(let source, let itemID, let text, let language, let timestamp):
            let mapKey = translationMapKey(source: source, itemID: itemID)
            let targetItemID = sourceCaptionItemIDs[source] ?? translationToSourceCaptionItemIDs[mapKey] ?? itemID
            var supersededItemIDs: [String] = []
            if let previousTarget = translationToSourceCaptionItemIDs[mapKey],
               previousTarget != targetItemID {
                if moveTranslation(
                    source: source,
                    previousItemID: previousTarget,
                    targetItemID: targetItemID
                ) {
                    supersededItemIDs.append(previousTarget)
                }
            }
            translationToSourceCaptionItemIDs[mapKey] = targetItemID
            let item = updateItem(source: source, itemID: targetItemID, timestamp: timestamp) { current in
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    current.translation = current.translation?.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    current.translation = text
                }
                current.language = language
            }
            return reducedEntry(
                from: item,
                isFinal: true,
                isTranslationOnly: true,
                supersededItemIDs: supersededItemIDs
            )

        case .translatedAudioChunk,
             .translatedAudioDone,
             .translatedAudioFormatUnsupported,
             .sessionStateChanged,
             .usageUpdated,
             .audioQueued,
             .recoverableError:
            return nil
        }
    }

    func expirePartials(olderThan maxAge: TimeInterval, now: Date = Date()) -> [RealtimeReducedEntry] {
        let expired = pending.values.filter { now.timeIntervalSince($0.lastUpdated) > maxAge }
        for item in expired {
            pending.removeValue(forKey: key(source: item.source, itemID: item.itemID))
        }
        return expired.map { reducedEntry(from: $0, isFinal: true, isTranslationOnly: false) }
    }

    private func updateItem(
        source: TranscriptionEntry.AudioSource,
        itemID: String,
        timestamp: Date,
        apply: (inout RealtimePendingItem) -> Void
    ) -> RealtimePendingItem {
        let mapKey = key(source: source, itemID: itemID)
        var item = pending[mapKey] ?? RealtimePendingItem(
            source: source,
            itemID: itemID,
            transcript: "",
            translation: nil,
            language: nil,
            timestamp: timestamp,
            lastUpdated: timestamp
        )
        apply(&item)
        item.lastUpdated = timestamp
        pending[mapKey] = item
        return item
    }

    private func reducedEntry(
        from item: RealtimePendingItem,
        isFinal: Bool,
        isTranslationOnly: Bool,
        supersededItemIDs: [String] = []
    ) -> RealtimeReducedEntry {
        RealtimeReducedEntry(
            source: item.source,
            itemID: item.itemID,
            text: item.transcript,
            translatedText: item.translation,
            language: item.language,
            timestamp: item.timestamp,
            isFinal: isFinal,
            isTranslationOnly: isTranslationOnly,
            supersededItemIDs: supersededItemIDs
        )
    }

    private func key(source: TranscriptionEntry.AudioSource, itemID: String) -> String {
        "\(source.rawValue):\(itemID)"
    }

    private func moveTranslation(
        source: TranscriptionEntry.AudioSource,
        previousItemID: String,
        targetItemID: String
    ) -> Bool {
        let previousKey = key(source: source, itemID: previousItemID)
        let targetKey = key(source: source, itemID: targetItemID)
        guard var previousItem = pending[previousKey],
              let previousTranslation = previousItem.translation,
              !previousTranslation.isEmpty else { return false }
        var targetItem = pending[targetKey] ?? RealtimePendingItem(
            source: source,
            itemID: targetItemID,
            transcript: "",
            translation: nil,
            language: nil,
            timestamp: previousItem.timestamp,
            lastUpdated: previousItem.lastUpdated
        )
        targetItem.translation = (targetItem.translation ?? "") + previousTranslation
        targetItem.lastUpdated = max(targetItem.lastUpdated, previousItem.lastUpdated)
        pending[targetKey] = targetItem
        previousItem.translation = nil
        if previousItem.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pending.removeValue(forKey: previousKey)
        } else {
            pending[previousKey] = previousItem
        }
        return true
    }

    private func translationMapKey(source: TranscriptionEntry.AudioSource, itemID: String) -> String {
        "\(source.rawValue):translation:\(itemID)"
    }
}
