import Foundation

struct SyntheticRealtimeTimeline {
    private let reducer = RealtimeEventReducer()
    private(set) var entries: [TranscriptionEntry] = []
    private(set) var firstPartialOffset: TimeInterval?
    private(set) var translatedAudioChunkCount = 0
    private let start = Date()

    mutating func apply(_ event: RealtimeAppEvent) {
        if case .translatedAudioChunk = event {
            translatedAudioChunkCount += 1
            return
        }
        guard let reduced = reducer.reduce(event) else { return }
        if reduced.isFinal {
            confirm(reduced)
        } else {
            upsertPartial(reduced)
        }
    }

    private mutating func upsertPartial(_ reduced: RealtimeReducedEntry) {
        if reduced.isTranslationOnly {
            upsertTranslation(reduced, isFinal: false)
            return
        }
        let text = reduced.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let detectedLanguage = reduced.language ?? detectLanguage(text)
        if firstPartialOffset == nil {
            firstPartialOffset = reduced.timestamp.timeIntervalSince(start)
        }
        if let index = entries.firstIndex(where: { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }) {
            entries[index].originalText = text
            entries[index].detectedLanguage = detectedLanguage
            entries[index].isDraft = true
            return
        }
        entries.append(
            TranscriptionEntry(
                timestamp: reduced.timestamp,
                originalText: text,
                detectedLanguage: detectedLanguage,
                source: reduced.source,
                speakerLabel: speakerLabel(source: reduced.source, language: detectedLanguage),
                isDraft: true,
                realtimeItemID: reduced.itemID
            )
        )
    }

    private mutating func confirm(_ reduced: RealtimeReducedEntry) {
        if reduced.isTranslationOnly {
            upsertTranslation(reduced, isFinal: true)
            return
        }
        let text = reduced.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let index = entries.firstIndex(where: { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }) {
            entries[index].originalText = text
            entries[index].detectedLanguage = reduced.language ?? entries[index].detectedLanguage
            entries[index].speakerLabel = speakerLabel(source: reduced.source, language: reduced.language)
            entries[index].isDraft = false
            return
        }
        entries.append(
            TranscriptionEntry(
                timestamp: reduced.timestamp,
                originalText: text,
                detectedLanguage: reduced.language ?? "unknown",
                source: reduced.source,
                speakerLabel: speakerLabel(source: reduced.source, language: reduced.language),
                isDraft: false,
                realtimeItemID: reduced.itemID
            )
        )
    }

    private mutating func upsertTranslation(_ reduced: RealtimeReducedEntry, isFinal: Bool) {
        let text = (reduced.translatedText ?? reduced.text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let index = entries.firstIndex(where: { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }) {
            if entries[index].detectedLanguage == nil || entries[index].detectedLanguage == "unknown" {
                entries[index].originalText = text
                entries[index].detectedLanguage = reduced.language ?? entries[index].detectedLanguage
            } else {
                entries[index].translatedText = text
            }
            entries[index].isDraft = !isFinal
            return
        }
        entries.append(
            TranscriptionEntry(
                timestamp: reduced.timestamp,
                originalText: text,
                translatedText: nil,
                detectedLanguage: reduced.language ?? "unknown",
                source: reduced.source,
                speakerLabel: speakerLabel(source: reduced.source, language: reduced.language),
                isDraft: !isFinal,
                realtimeItemID: reduced.itemID
            )
        )
    }

    private func speakerLabel(source: TranscriptionEntry.AudioSource, language: String?) -> String {
        if source == .microphone { return "You" }
        guard let language = language?.lowercased() else { return "Speaker" }
        let languageName = TranscriptionEntry.languageNames[language] ?? language.capitalized
        return "Speaker (\(languageName))"
    }

    private func detectLanguage(_ text: String) -> String {
        LanguageDetector.detect(text)
    }
}

func assertM6Route() {
    let router = RealtimeModelRouter()
    let route = router.route(
        showTranslations: false,
        sameLanguage: false,
        hasPinnedSourceLanguage: false,
        wantsInterpreterSession: false,
        wantsAgent: false
    )
    precondition(route.mode == .transcription)
    precondition(route.model == OpenAIRealtimeModel.realtimeWhisper.rawValue)
    precondition(!route.shouldStartTranslationSession)
}

func assertM7Routes() {
    let router = RealtimeModelRouter()
    let gatedOff = router.route(
        showTranslations: true,
        sameLanguage: false,
        hasPinnedSourceLanguage: true,
        wantsInterpreterSession: false,
        wantsAgent: false
    )
    precondition(gatedOff.mode == .transcription)
    precondition(!gatedOff.shouldStartTranslationSession)

    let autoDetect = router.route(
        showTranslations: true,
        sameLanguage: false,
        hasPinnedSourceLanguage: false,
        wantsInterpreterSession: true,
        wantsAgent: false
    )
    precondition(autoDetect.mode == .transcription)
    precondition(!autoDetect.shouldStartTranslationSession)
    precondition(!autoDetect.shouldStartSourceCaptionSession)

    let translation = router.route(
        showTranslations: true,
        sameLanguage: false,
        hasPinnedSourceLanguage: true,
        wantsInterpreterSession: true,
        wantsAgent: false
    )
    precondition(translation.mode == .translation)
    precondition(translation.model == OpenAIRealtimeModel.realtimeTranslate.rawValue)
    precondition(translation.endpointPath == "/v1/realtime/translations")
    precondition(translation.shouldStartTranslationSession)
    precondition(translation.shouldStartSourceCaptionSession)

    let sameLanguage = router.route(
        showTranslations: true,
        sameLanguage: true,
        hasPinnedSourceLanguage: true,
        wantsInterpreterSession: true,
        wantsAgent: false
    )
    precondition(sameLanguage.mode == .transcription)
    precondition(!sameLanguage.shouldStartTranslationSession)

    let hiddenTranslations = router.route(
        showTranslations: false,
        sameLanguage: false,
        hasPinnedSourceLanguage: true,
        wantsInterpreterSession: true,
        wantsAgent: false
    )
    precondition(hiddenTranslations.mode == .transcription)
    precondition(!hiddenTranslations.shouldStartTranslationSession)
    precondition(!hiddenTranslations.shouldStartSourceCaptionSession)
}

func runSyntheticCaptionE2E(source: TranscriptionEntry.AudioSource) {
    let utteranceDuration: TimeInterval = 5.0
    let start = Date()
    let itemID = "synthetic-\(source.rawValue.lowercased())"
    var timeline = SyntheticRealtimeTimeline()
    let service = OpenAIRealtimeTranscriptionService(apiKey: "test-key", source: source)
    service.onEvent = { timeline.apply($0) }

    service.processServerEvent([
        "type": "conversation.item.input_audio_transcription.delta",
        "item_id": itemID,
        "delta": "Realtime captions"
    ])
    precondition(timeline.firstPartialOffset != nil)
    precondition(timeline.firstPartialOffset! < utteranceDuration)
    precondition(timeline.entries.count == 1)
    precondition(timeline.entries[0].isDraft)
    precondition(timeline.entries[0].source == source)
    if source == .microphone {
        precondition(timeline.entries[0].speakerLabel == "You")
    } else {
        precondition(timeline.entries[0].speakerLabel == "Speaker (English)")
    }

    service.processServerEvent([
        "type": "conversation.item.input_audio_transcription.delta",
        "item_id": itemID,
        "delta": " appear before the final pause"
    ])
    precondition(timeline.entries[0].originalText == "Realtime captions appear before the final pause")
    precondition(timeline.entries[0].isDraft)

    service.processServerEvent([
        "type": "conversation.item.input_audio_transcription.completed",
        "item_id": itemID,
        "transcript": "Realtime captions appear before the final pause.",
        "language": "en"
    ])
    precondition(Date().timeIntervalSince(start) < utteranceDuration)
    precondition(timeline.entries.count == 1)
    precondition(!timeline.entries[0].isDraft)
    precondition(timeline.entries[0].originalText == "Realtime captions appear before the final pause.")
    precondition(timeline.entries[0].detectedLanguage == "en")
    if source == .microphone {
        precondition(timeline.entries[0].speakerLabel == "You")
    } else {
        precondition(timeline.entries[0].speakerLabel == "Speaker (English)")
    }
}

func runSyntheticTranslationE2E(
    source: TranscriptionEntry.AudioSource,
    sourceText: String,
    translationText: String,
    language: String
) {
    let itemID = "translation-\(source.rawValue.lowercased())-\(language)"
    var timeline = SyntheticRealtimeTimeline()
    let service = OpenAIRealtimeTranslationService(apiKey: "test-key", source: source)
    service.onEvent = { timeline.apply($0) }

    service.processServerEvent([
        "type": "session.input_transcript.delta",
        "item_id": itemID,
        "delta": String(sourceText.prefix(4))
    ])
    precondition(timeline.entries.count == 1)
    precondition(timeline.entries[0].isDraft)
    precondition(timeline.entries[0].realtimeItemID == itemID)

    service.processServerEvent([
        "type": "session.output_transcript.delta",
        "item_id": itemID,
        "delta": String(translationText.prefix(2))
    ])
    precondition(timeline.entries[0].translatedText == String(translationText.prefix(2)))

    service.processServerEvent([
        "type": "session.input_transcript.done",
        "item_id": itemID,
        "transcript": sourceText,
        "language": language
    ])
    precondition(timeline.entries[0].originalText == sourceText)
    precondition(timeline.entries[0].detectedLanguage == language)

    service.processServerEvent([
        "type": "session.output_transcript.done",
        "item_id": itemID,
        "transcript": translationText
    ])
    precondition(timeline.entries.count == 1)
    precondition(timeline.entries[0].originalText == sourceText)
    precondition(timeline.entries[0].translatedText == translationText)
    precondition(!timeline.entries[0].isDraft)

    service.processServerEvent([
        "type": "session.output_audio.delta",
        "item_id": itemID,
        "delta": Data([1, 2, 3]).base64EncodedString()
    ])
    precondition(timeline.translatedAudioChunkCount == 0)

    let playbackService = OpenAIRealtimeTranslationService(
        apiKey: "test-key",
        source: source,
        translatedAudioPlaybackEnabled: true
    )
    playbackService.onEvent = { timeline.apply($0) }
    playbackService.processServerEvent([
        "type": "session.output_audio.delta",
        "item_id": itemID,
        "delta": Data([4, 5, 6]).base64EncodedString()
    ])
    precondition(timeline.translatedAudioChunkCount == 1)
}

@main
struct RealtimeAppE2E {
    static func main() {
        assertM6Route()
        assertM7Routes()
        runSyntheticCaptionE2E(source: .microphone)
        runSyntheticCaptionE2E(source: .system)
        runSyntheticTranslationE2E(
            source: .microphone,
            sourceText: "Good morning, this is a synthetic translation test.",
            translationText: "早上好，这是一个合成翻译测试。",
            language: "en"
        )
        runSyntheticTranslationE2E(
            source: .system,
            sourceText: "你好，这是一个合成翻译测试。",
            translationText: "Hello, this is a synthetic translation test.",
            language: "zh"
        )
        print("realtime app e2e ok")
    }
}
