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
        precondition(transcription.mode == .agent)
        precondition(transcription.model == OpenAIRealtimeModel.realtimeAgent.rawValue)

        let hiddenTranslation = router.route(
            showTranslations: false,
            sameLanguage: false,
            wantsTranslatedAudio: true,
            wantsAgent: false
        )
        precondition(hiddenTranslation.mode == .agent)

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

        precondition(RealtimeCaptionLatencyPreset.aggressive.realtimeCaptureChunkDuration < RealtimeCaptionLatencyPreset.balanced.realtimeCaptureChunkDuration)
        precondition(RealtimeCaptionLatencyPreset.balanced.realtimeCaptureChunkDuration <= 1.0)

        let realtimeID = UUID()
        var draftIDs: Set<UUID> = [UUID()]
        var entries = [
            TranscriptionEntry(
                id: realtimeID,
                originalText: "live partial text",
                detectedLanguage: "en",
                isDraft: true,
                realtimeItemID: "item_live"
            ),
            TranscriptionEntry(
                originalText: "legacy draft text",
                detectedLanguage: "en",
                isDraft: true
            ),
            TranscriptionEntry(
                originalText: "",
                detectedLanguage: "en",
                isDraft: true,
                realtimeItemID: "item_empty"
            )
        ]

        let finals = RealtimeDraftFinalizer.collectRealtimeDraftFinals(entries: &entries, draftEntryIDs: &draftIDs) { entry in
            entry.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        precondition(finals.count == 1)
        precondition(finals.first?.itemID == "item_live")
        precondition(finals.first?.text == "live partial text")
        precondition(entries.contains { $0.id == realtimeID && $0.isDraft && $0.originalText == "live partial text" })
        precondition(entries.contains { $0.realtimeItemID == nil && !$0.isDraft && $0.originalText == "legacy draft text" })
        precondition(!entries.contains { $0.realtimeItemID == "item_empty" })
        precondition(draftIDs.isEmpty)

        let firstRealtimeSegment = TranscriptionEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            originalText: "你好,听得到我",
            detectedLanguage: "zh",
            source: .microphone,
            speakerLabel: "You",
            realtimeItemID: "rt_1"
        )
        precondition(RealtimeUtteranceMerger.canMerge(
            previous: firstRealtimeSegment,
            nextText: "我说话吗?",
            nextLanguage: "zh",
            nextSource: .microphone,
            nextTimestamp: Date(timeIntervalSince1970: 1.2),
            maxDuration: 8,
            maxCharacters: 240
        ))
        precondition(
            RealtimeUtteranceMerger.mergedText(
                previous: firstRealtimeSegment.originalText,
                next: "我说话吗?"
            ) == "你好,听得到我说话吗?"
        )
        precondition(
            RealtimeUtteranceMerger.mergedText(
                previous: "hello real",
                next: "real time captions"
            ) == "hello real time captions"
        )
        precondition(
            RealtimeUtteranceMerger.mergedText(
                previous: "I am",
                next: "meeting now"
            ) == "I am meeting now"
        )
        precondition(
            RealtimeUtteranceMerger.mergedText(
                previous: "what",
                next: "whatever happened"
            ) == "what whatever happened"
        )
        precondition(
            RealtimeUtteranceMerger.mergedText(
                previous: "same phrase",
                next: "same phrase"
            ) == nil
        )
        precondition(!RealtimeUtteranceMerger.canMerge(
            previous: firstRealtimeSegment,
            nextText: "system audio",
            nextLanguage: "en",
            nextSource: .system,
            nextTimestamp: Date(timeIntervalSince1970: 1.2),
            maxDuration: 8,
            maxCharacters: 240
        ))

        let outputItemDone: [String: Any] = [
            "type": "response.output_item.done",
            "item": [
                "id": "msg_007",
                "content": [
                    ["type": "output_text", "text": "Realtime nested final"]
                ]
            ]
        ]
        let outputItemSegments = OpenAIRealtimeAgentService.finalTranscriptSegments(
            from: outputItemDone,
            fallbackItemID: "response_ignored"
        )
        precondition(outputItemSegments.count == 1)
        precondition(outputItemSegments[0].itemID == "msg_007")
        precondition(outputItemSegments[0].text == "Realtime nested final")

        let responseDone: [String: Any] = [
            "type": "response.done",
            "response": [
                "id": "resp_ignored",
                "output": [
                    [
                        "id": "msg_008",
                        "content": [
                            ["type": "output_text", "text": "First final item"]
                        ]
                    ],
                    [
                        "id": "msg_009",
                        "content": [
                            ["type": "output_text", "text": "Second final item"]
                        ]
                    ]
                ]
            ]
        ]
        let responseDoneSegments = OpenAIRealtimeAgentService.finalTranscriptSegments(
            from: responseDone,
            fallbackItemID: "response_ignored"
        )
        precondition(responseDoneSegments.map(\.itemID) == ["msg_008", "msg_009"])
        precondition(responseDoneSegments.map(\.text) == ["First final item", "Second final item"])

        print("realtime core smoke ok")
    }
}
