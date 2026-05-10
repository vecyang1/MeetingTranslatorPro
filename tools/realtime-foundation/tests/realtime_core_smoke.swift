import Foundation

@main
struct RealtimeCoreSmoke {
    static func main() {
        let router = RealtimeModelRouter()
        let transcription = router.route(
            showTranslations: false,
            sameLanguage: false,
            wantsTranslatedAudio: false,
            wantsAgent: false
        )
        precondition(transcription.mode == .transcription)
        precondition(transcription.model == OpenAIRealtimeModel.realtimeWhisper.rawValue)

        let hiddenTranslation = router.route(
            showTranslations: false,
            sameLanguage: false,
            wantsTranslatedAudio: true,
            wantsAgent: false
        )
        precondition(hiddenTranslation.mode == .transcription)

        let translation = router.route(
            showTranslations: true,
            sameLanguage: false,
            wantsTranslatedAudio: true,
            wantsAgent: false
        )
        precondition(translation.mode == .translation)
        precondition(translation.model == OpenAIRealtimeModel.realtimeTranslate.rawValue)

        let reducer = RealtimeEventReducer()
        let source = TranscriptionEntry.AudioSource.microphone
        if let first = reducer.reduce(
            .partialTranscript(source: source, itemID: "item_1", text: "Hello", timestamp: Date())
        ) {
            precondition(first.text == "Hello")
            precondition(first.isFinal == false)
        } else {
            fatalError("expected partial event")
        }

        if let second = reducer.reduce(
            .partialTranscript(source: source, itemID: "item_1", text: " world", timestamp: Date())
        ) {
            precondition(second.text == "Hello world")
        } else {
            fatalError("expected accumulated partial event")
        }

        if let final = reducer.reduce(
            .finalTranscript(source: source, itemID: "item_1", text: "", language: "en", timestamp: Date())
        ) {
            precondition(final.text == "Hello world")
            precondition(final.isFinal)
            precondition(final.language == "en")
        } else {
            fatalError("expected final event")
        }

        let pcm16 = Data((0..<160).flatMap { sample -> [UInt8] in
            let value = Int16(sample)
            return [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
        })
        let upsampled = AudioResampler.resamplePCM16Mono(pcm16, fromSampleRate: 16_000, toSampleRate: 24_000)
        precondition(upsampled.count == 240 * 2)

        print("realtime core smoke ok")
    }
}
