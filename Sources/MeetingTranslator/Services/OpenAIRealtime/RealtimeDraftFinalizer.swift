import Foundation

enum RealtimeDraftFinalizer {
    static func collectRealtimeDraftFinals(
        entries: inout [TranscriptionEntry],
        draftEntryIDs: inout Set<UUID>,
        shouldDropRealtimeDraft: (TranscriptionEntry) -> Bool
    ) -> [RealtimeReducedEntry] {
        var finals: [RealtimeReducedEntry] = []

        entries.removeAll { entry in
            guard entry.isDraft, entry.realtimeItemID != nil else { return false }
            return shouldDropRealtimeDraft(entry)
        }

        for entry in entries where entry.isDraft {
            guard let itemID = entry.realtimeItemID else { continue }
            finals.append(
                RealtimeReducedEntry(
                    source: entry.source,
                    itemID: itemID,
                    text: entry.originalText,
                    translatedText: entry.translatedText,
                    language: entry.detectedLanguage,
                    timestamp: entry.timestamp,
                    isFinal: true,
                    isTranslationOnly: false
                )
            )
        }

        for idx in entries.indices where entries[idx].isDraft && entries[idx].realtimeItemID == nil {
            entries[idx].isDraft = false
        }
        draftEntryIDs.removeAll()
        return finals
    }
}
