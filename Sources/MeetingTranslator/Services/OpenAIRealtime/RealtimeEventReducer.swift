import Foundation

final class RealtimeEventReducer {
    private var pending: [String: RealtimePendingItem] = [:]

    func reset() {
        pending.removeAll()
    }

    func reduce(_ event: RealtimeAppEvent) -> RealtimeReducedEntry? {
        switch event {
        case .partialTranscript(let source, let itemID, let text, let timestamp):
            let item = updateItem(source: source, itemID: itemID, timestamp: timestamp) { current in
                current.transcript += text
            }
            return reducedEntry(from: item, isFinal: false, isTranslationOnly: false)

        case .finalTranscript(let source, let itemID, let text, let language, let timestamp):
            let item = updateItem(source: source, itemID: itemID, timestamp: timestamp) { current in
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    current.transcript = current.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    current.transcript = text
                }
                current.language = language
            }
            pending.removeValue(forKey: key(source: source, itemID: itemID))
            return reducedEntry(from: item, isFinal: true, isTranslationOnly: false)

        case .partialTranslation(let source, let itemID, let text, let timestamp):
            let item = updateItem(source: source, itemID: itemID, timestamp: timestamp) { current in
                current.translation = (current.translation ?? "") + text
            }
            return reducedEntry(from: item, isFinal: false, isTranslationOnly: true)

        case .finalTranslation(let source, let itemID, let text, let language, let timestamp):
            let item = updateItem(source: source, itemID: itemID, timestamp: timestamp) { current in
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    current.translation = current.translation?.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    current.translation = text
                }
                current.language = language
            }
            return reducedEntry(from: item, isFinal: true, isTranslationOnly: true)

        case .translatedAudioChunk, .sessionStateChanged, .usageUpdated, .audioQueued, .recoverableError:
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
        isTranslationOnly: Bool
    ) -> RealtimeReducedEntry {
        RealtimeReducedEntry(
            source: item.source,
            itemID: item.itemID,
            text: item.transcript,
            translatedText: item.translation,
            language: item.language,
            timestamp: item.timestamp,
            isFinal: isFinal,
            isTranslationOnly: isTranslationOnly
        )
    }

    private func key(source: TranscriptionEntry.AudioSource, itemID: String) -> String {
        "\(source.rawValue):\(itemID)"
    }
}
