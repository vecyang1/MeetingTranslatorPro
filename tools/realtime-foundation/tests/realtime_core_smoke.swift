import Foundation

@main
struct RealtimeCoreSmoke {
    static func main() {
        let router = RealtimeModelRouter()
        let transcription = router.route(
            showTranslations: false,
            sameLanguage: false,
            hasPinnedSourceLanguage: false,
            wantsInterpreterSession: false,
            wantsAgent: false
        )
        precondition(transcription.mode == .transcription)
        precondition(transcription.model == OpenAIRealtimeModel.realtimeWhisper.rawValue)
        precondition(transcription.endpointPath == "/v1/realtime")
        precondition(!transcription.shouldStartTranslationSession)

        let hiddenTranslation = router.route(
            showTranslations: false,
            sameLanguage: false,
            hasPinnedSourceLanguage: true,
            wantsInterpreterSession: true,
            wantsAgent: false
        )
        precondition(hiddenTranslation.mode == .transcription)
        precondition(hiddenTranslation.model == OpenAIRealtimeModel.realtimeWhisper.rawValue)
        precondition(!hiddenTranslation.shouldStartTranslationSession)

        let textTranslationOnly = router.route(
            showTranslations: true,
            sameLanguage: false,
            hasPinnedSourceLanguage: true,
            wantsInterpreterSession: false,
            wantsAgent: false
        )
        precondition(textTranslationOnly.mode == .transcription)
        precondition(textTranslationOnly.model == OpenAIRealtimeModel.realtimeWhisper.rawValue)
        precondition(!textTranslationOnly.shouldStartTranslationSession)

        let sameLanguage = router.route(
            showTranslations: true,
            sameLanguage: true,
            hasPinnedSourceLanguage: true,
            wantsInterpreterSession: true,
            wantsAgent: false
        )
        precondition(sameLanguage.mode == .transcription)
        precondition(sameLanguage.model == OpenAIRealtimeModel.realtimeWhisper.rawValue)
        precondition(!sameLanguage.shouldStartTranslationSession)

        let autoDetectInterpreter = router.route(
            showTranslations: true,
            sameLanguage: false,
            hasPinnedSourceLanguage: false,
            wantsInterpreterSession: true,
            wantsAgent: false
        )
        precondition(autoDetectInterpreter.mode == .transcription)
        precondition(autoDetectInterpreter.model == OpenAIRealtimeModel.realtimeWhisper.rawValue)
        precondition(!autoDetectInterpreter.shouldStartTranslationSession)
        precondition(!autoDetectInterpreter.shouldStartSourceCaptionSession)

        let translation = router.route(
            showTranslations: true,
            sameLanguage: false,
            hasPinnedSourceLanguage: true,
            wantsInterpreterSession: true,
            wantsAgent: false
        )
        precondition(translation.mode == .translation)
        precondition(translation.model == OpenAIRealtimeModel.realtimeTranslate.rawValue)
        precondition(translation.shouldStartTranslationSession)
        precondition(translation.shouldStartSourceCaptionSession)

        let agent = router.route(
            showTranslations: true,
            sameLanguage: false,
            hasPinnedSourceLanguage: true,
            wantsInterpreterSession: true,
            wantsAgent: true
        )
        precondition(agent.mode == .agent)
        precondition(agent.model == OpenAIRealtimeModel.realtimeAgent.rawValue)
        precondition(!agent.shouldStartTranslationSession)
        precondition(!agent.shouldStartSourceCaptionSession)

        precondition(RealtimePricing.whisperPerMinuteUSD == 0.017)
        precondition(RealtimePricing.translatePerMinuteUSD == 0.034)
        precondition(RealtimePricing.whisperCost(audioDurationSeconds: 60) == 0.017)
        precondition(RealtimePricing.translateCost(audioDurationSeconds: 60) == 0.034)
        precondition(RealtimePricing.whisperCost(audioDurationSeconds: 3600) == 1.02)
        precondition(RealtimePricing.translateCost(audioDurationSeconds: 3600) == 2.04)
        let realtime2BidirectionalHour = RealtimePricing.realtime2Cost(
            inputAudioDurationSeconds: 3600,
            outputAudioDurationSeconds: 3600
        )
        precondition(abs(realtime2BidirectionalHour - 5.76) < 0.000001)
        precondition(RealtimeConnectionRecoveryPolicy.isRecoverableNetworkError(
            "A TLS error caused the secure connection to fail. 0: 13"
        ))
        precondition(RealtimeConnectionRecoveryPolicy.isRecoverableNetworkError(
            "A TLS error caused the secure connection to fail. 0:13"
        ))
        precondition(RealtimeConnectionRecoveryPolicy.shouldRetry(
            message: "Realtime connection dropped.",
            attemptsUsed: 0
        ))
        precondition(!RealtimeConnectionRecoveryPolicy.shouldRetry(
            message: "A TLS error caused the secure connection to fail. 0: 13",
            attemptsUsed: RealtimeConnectionRecoveryPolicy.maxAttempts
        ))
        precondition(!RealtimeConnectionRecoveryPolicy.isRecoverableNetworkError(
            "401 unauthorized: invalid API key"
        ))
        precondition(
            RealtimeConnectionRecoveryPolicy.retryDelayNanoseconds(forAttempt: 2)
                > RealtimeConnectionRecoveryPolicy.retryDelayNanoseconds(forAttempt: 1)
        )

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

        let sidecarReducer = RealtimeEventReducer()
        _ = sidecarReducer.reduce(
            .partialTranscript(source: source, itemID: "whisper_sidecar", text: "Good", timestamp: Date())
        )
        if let attachedTranslation = sidecarReducer.reduce(
            .partialTranslation(source: source, itemID: "translate_sidecar", text: "好", timestamp: Date())
        ) {
            precondition(attachedTranslation.itemID == "whisper_sidecar")
            precondition(attachedTranslation.text == "Good")
            precondition(attachedTranslation.translatedText == "好")
            precondition(attachedTranslation.isTranslationOnly)
        } else {
            fatalError("expected attached sidecar translation")
        }
        _ = sidecarReducer.reduce(
            .finalTranscript(source: source, itemID: "whisper_sidecar", text: "Good morning", language: "en", timestamp: Date())
        )
        if let finalAttachedTranslation = sidecarReducer.reduce(
            .finalTranslation(source: source, itemID: "translate_sidecar", text: "早上好", language: "zh", timestamp: Date())
        ) {
            precondition(finalAttachedTranslation.itemID == "whisper_sidecar")
            precondition(finalAttachedTranslation.translatedText == "早上好")
            precondition(finalAttachedTranslation.isFinal)
            precondition(finalAttachedTranslation.isTranslationOnly)
        } else {
            fatalError("expected final attached sidecar translation")
        }

        var choppedEntries: [TranscriptionEntry] = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "不知道为什么我要为什么表达但是就是很麻烦。",
                detectedLanguage: "zh",
                source: .microphone,
                speakerLabel: "You",
                realtimeItemID: "chunk_1"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 2),
                originalText: "就是",
                detectedLanguage: "zh",
                source: .microphone,
                speakerLabel: "You",
                realtimeItemID: "chunk_2"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 8),
                originalText: "在千万人的时间中时间五点达到荒野里。",
                detectedLanguage: "zh",
                source: .microphone,
                speakerLabel: "You",
                realtimeItemID: "chunk_3"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 14),
                originalText: "没有就走一步。",
                detectedLanguage: "zh",
                source: .microphone,
                speakerLabel: "You",
                realtimeItemID: "chunk_4"
            )
        ]
        let stitched = RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &choppedEntries,
            source: .microphone,
            mode: .transcription,
            baseMaxDuration: 8.0,
            baseMaxCharacters: 240
        )
        precondition(choppedEntries.count == 1)
        precondition(choppedEntries[0].originalText == "不知道为什么我要为什么表达但是就是很麻烦。就是在千万人的时间中时间五点达到荒野里。没有就走一步。")
        precondition(stitched == choppedEntries[0].originalText)

        var languageDriftEntries: [TranscriptionEntry] = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 20),
                originalText: "就成怎么遇见的？你们有没有什么别的哇好说",
                detectedLanguage: "zh",
                source: .microphone,
                speakerLabel: "You",
                realtimeItemID: "chunk_5"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 21),
                originalText: "我说一句你也在这儿。",
                detectedLanguage: "zh",
                source: .microphone,
                speakerLabel: "You",
                realtimeItemID: "chunk_6"
            )
        ]
        _ = RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &languageDriftEntries,
            source: .microphone,
            mode: .transcription,
            baseMaxDuration: 8.0,
            baseMaxCharacters: 240
        )
        precondition(languageDriftEntries.count == 1)
        precondition(languageDriftEntries[0].originalText == "就成怎么遇见的？你们有没有什么别的哇好说我说一句你也在这儿。")

        var translationModeEntries = languageDriftEntries
        let translationModeStitch = RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &translationModeEntries,
            source: .microphone,
            mode: .translation,
            baseMaxDuration: 8.0,
            baseMaxCharacters: 240
        )
        precondition(translationModeStitch == nil)
        precondition(translationModeEntries.count == 1)

        precondition(RealtimeUtteranceMerger.shouldDropUnstableShortFragment("啊", language: "zh"))
        precondition(RealtimeUtteranceMerger.shouldDropUnstableShortFragment("Give me a wipe.", language: "en"))
        precondition(RealtimeUtteranceMerger.shouldDropUnstableShortFragment("あります", language: "ja"))
        precondition(!RealtimeUtteranceMerger.shouldDropUnstableShortFragment("没有就走一步。", language: "zh"))

        let outputFirstReducer = RealtimeEventReducer()
        if let outputFirstTranslation = outputFirstReducer.reduce(
            .partialTranslation(source: source, itemID: "translate_output_first", text: "早", timestamp: Date())
        ) {
            precondition(outputFirstTranslation.itemID == "translate_output_first")
            precondition(outputFirstTranslation.text.isEmpty)
            precondition(outputFirstTranslation.translatedText == "早")
        } else {
            fatalError("expected output-first translation")
        }
        _ = outputFirstReducer.reduce(
            .partialTranscript(source: source, itemID: "whisper_output_late", text: "Good", timestamp: Date())
        )
        if let reboundTranslation = outputFirstReducer.reduce(
            .partialTranslation(source: source, itemID: "translate_output_first", text: "上好", timestamp: Date())
        ) {
            precondition(reboundTranslation.itemID == "whisper_output_late")
            precondition(reboundTranslation.text == "Good")
            precondition(reboundTranslation.translatedText == "早上好")
            precondition(reboundTranslation.supersededItemIDs == ["translate_output_first"])
        } else {
            fatalError("expected output-first translation to rebind to source caption")
        }

        precondition(
            RealtimeSessionState.connected(.transcription)
                .presented(activeMode: .translation)
                .userMessage == "Realtime translation active"
        )
        precondition(
            RealtimeSessionState.connected(.translation)
                .presented(activeMode: .translation)
                == .connected(.translation)
        )

        let transcriptionService = OpenAIRealtimeTranscriptionService(apiKey: "test-key", source: source)
        var transcriptionFallbackIDs: [String] = []
        transcriptionService.onEvent = { event in
            switch event {
            case .partialTranscript(_, let itemID, _, _),
                 .finalTranscript(_, let itemID, _, _, _):
                transcriptionFallbackIDs.append(itemID)
            default:
                break
            }
        }
        transcriptionService.processServerEvent([
            "type": "conversation.item.input_audio_transcription.delta",
            "delta": "Live"
        ])
        transcriptionService.processServerEvent([
            "type": "conversation.item.input_audio_transcription.delta",
            "delta": " captions"
        ])
        transcriptionService.processServerEvent([
            "type": "conversation.item.input_audio_transcription.completed",
            "transcript": "Live captions",
            "language": "en"
        ])
        transcriptionService.processServerEvent([
            "type": "conversation.item.input_audio_transcription.delta",
            "delta": "Next turn"
        ])
        precondition(transcriptionFallbackIDs.count == 4)
        precondition(Set(transcriptionFallbackIDs.prefix(3)).count == 1)
        precondition(transcriptionFallbackIDs[3] != transcriptionFallbackIDs[0])

        let coordinator = OpenAIRealtimeCoordinator()
        precondition(coordinator.activeMode == nil)
        let fanoutBeforeStart = coordinator.sendAudio(Data([1, 2, 3, 4]), source: source)
        precondition(!fanoutBeforeStart.sentToPrimary)
        precondition(!fanoutBeforeStart.sentToSourceCaption)
        precondition(!fanoutBeforeStart.accepted)

        let translationService = OpenAIRealtimeTranslationService(apiKey: "test-key", source: source)
        var translationEvents: [RealtimeAppEvent] = []
        translationService.onEvent = { event in
            translationEvents.append(event)
        }
        translationService.processServerEvent([
            "type": "session.input_transcript.delta",
            "delta": "Good"
        ])
        translationService.processServerEvent([
            "type": "session.output_transcript.delta",
            "delta": "好"
        ])
        translationService.processServerEvent([
            "type": "session.input_transcript.done",
            "transcript": "Good morning"
        ])
        translationService.processServerEvent([
            "type": "session.output_transcript.done",
            "transcript": "早上好"
        ])
        translationService.processServerEvent([
            "type": "session.output_audio.delta",
            "delta": Data([1, 2, 3]).base64EncodedString()
        ])
        precondition(translationEvents.count == 4)
        var translationItemIDs: [String] = []
        var sawInputDelta = false
        var sawOutputDelta = false
        var sawInputFinal = false
        var sawOutputFinal = false
        for event in translationEvents {
            switch event {
            case .partialTranscript(_, let itemID, let text, _):
                translationItemIDs.append(itemID)
                sawInputDelta = text == "Good"
            case .partialTranslation(_, let itemID, let text, _):
                translationItemIDs.append(itemID)
                sawOutputDelta = text == "好"
            case .finalTranscript(_, let itemID, let text, _, _):
                translationItemIDs.append(itemID)
                sawInputFinal = text == "Good morning"
            case .finalTranslation(_, let itemID, let text, _, _):
                translationItemIDs.append(itemID)
                sawOutputFinal = text == "早上好"
            default:
                fatalError("unexpected translation event")
            }
        }
        precondition(Set(translationItemIDs).count == 1)
        precondition(sawInputDelta && sawOutputDelta && sawInputFinal && sawOutputFinal)

        let playbackTranslationService = OpenAIRealtimeTranslationService(
            apiKey: "test-key",
            source: source,
            translatedAudioPlaybackEnabled: true
        )
        var playbackAudioEventCount = 0
        playbackTranslationService.onEvent = { event in
            if case .translatedAudioChunk(_, _, let data, _) = event {
                playbackAudioEventCount += 1
                precondition(data == Data([4, 5, 6]))
            }
        }
        playbackTranslationService.processServerEvent([
            "type": "session.output_audio.delta",
            "delta": Data([4, 5, 6]).base64EncodedString()
        ])
        precondition(playbackAudioEventCount == 1)

        let staleFinalReducer = RealtimeEventReducer()
        _ = staleFinalReducer.reduce(
            .partialTranscript(
                source: source,
                itemID: "item_stale_final",
                text: "并且呢它还支持语音输入",
                timestamp: Date()
            )
        )
        if let staleFinal = staleFinalReducer.reduce(
            .finalTranscript(
                source: source,
                itemID: "item_stale_final",
                text: "并且呢它还支持",
                language: "zh",
                timestamp: Date()
            )
        ) {
            precondition(staleFinal.text == "并且呢它还支持语音输入")
            precondition(staleFinal.isFinal)
            precondition(staleFinal.language == "zh")
        } else {
            fatalError("expected stale final event")
        }

        let correctedFinalReducer = RealtimeEventReducer()
        _ = correctedFinalReducer.reduce(
            .partialTranscript(source: source, itemID: "item_corrected_final", text: "I scream", timestamp: Date())
        )
        if let correctedFinal = correctedFinalReducer.reduce(
            .finalTranscript(
                source: source,
                itemID: "item_corrected_final",
                text: "ice cream",
                language: "en",
                timestamp: Date()
            )
        ) {
            precondition(correctedFinal.text == "ice cream")
        } else {
            fatalError("expected corrected final event")
        }

        let pcm16 = Data((0..<160).flatMap { sample -> [UInt8] in
            let value = Int16(sample)
            return [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
        })
        let upsampled = AudioResampler.resamplePCM16Mono(pcm16, fromSampleRate: 16_000, toSampleRate: 24_000)
        precondition(upsampled.count == 240 * 2)

        precondition(RealtimeCaptionLatencyPreset.aggressive.realtimeCaptureChunkDuration < RealtimeCaptionLatencyPreset.balanced.realtimeCaptureChunkDuration)
        precondition(RealtimeCaptionLatencyPreset.balanced.realtimeCaptureChunkDuration == 1.4)
        precondition(RealtimeCaptionLatencyPreset.accuracy.realtimeCaptureChunkDuration == 2.4)

        let tailBytes = Int(0.3 * 16_000 * 2)
        var boundaryContext = RealtimeAudioBoundaryContext(overlapSeconds: 0.3)
        let firstMicChunk = Data(repeating: 1, count: 16_000 * 2)
        let secondMicChunk = Data(repeating: 2, count: 16_000 * 2)
        let firstSystemChunk = Data(repeating: 3, count: 16_000 * 2)
        precondition(boundaryContext.contextualizedAudio(firstMicChunk, source: .microphone) == firstMicChunk)
        precondition(
            boundaryContext.contextualizedAudio(secondMicChunk, source: .microphone)
                == Data(firstMicChunk.suffix(tailBytes)) + secondMicChunk
        )
        precondition(boundaryContext.contextualizedAudio(firstSystemChunk, source: .system) == firstSystemChunk)
        boundaryContext.reset(source: .microphone)
        precondition(boundaryContext.contextualizedAudio(secondMicChunk, source: .microphone) == secondMicChunk)
        precondition(
            boundaryContext.contextualizedAudio(firstMicChunk, source: .system)
                == Data(firstSystemChunk.suffix(tailBytes)) + firstMicChunk
        )
        boundaryContext.reset()
        precondition(boundaryContext.contextualizedAudio(secondMicChunk, source: .microphone) == secondMicChunk)

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
        precondition(
            RealtimeUtteranceMerger.mergedTextSequence([
                "系统音频验证开始",
                "验证开始这里只有第",
                "这里只有第电脑声音",
                "电脑声音没有麦克",
                "没有麦克完整稳定的字幕"
            ]) == "系统音频验证开始这里只有第电脑声音没有麦克完整稳定的字幕"
        )
        precondition(
            RealtimeUtteranceMerger.hasNoNewContent(
                previous: "You have a meeting soon. Scan their site",
                next: "Scan their site"
            )
        )
        precondition(!RealtimeUtteranceMerger.hasNoNewContent(previous: "website", next: "site"))
        let tailDuplicatePrevious = TranscriptionEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            originalText: "You have a meeting soon. Scan their site",
            detectedLanguage: "en",
            source: .system,
            realtimeItemID: "rt_tail_1"
        )
        precondition(RealtimeUtteranceMerger.canDropNoNewContent(
            previous: tailDuplicatePrevious,
            nextText: "Scan their site",
            nextLanguage: "en",
            nextSource: .system,
            nextTimestamp: Date(timeIntervalSince1970: 1.0),
            maxDuration: 8,
            maxCharacters: 240
        ))
        precondition(RealtimeUtteranceMerger.canDropNoNewContent(
            previous: TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "one readable caption without repeating the final words though",
                detectedLanguage: "en",
                source: .system,
                realtimeItemID: "rt_tail_slow"
            ),
            nextText: "though",
            nextLanguage: "en",
            nextSource: .system,
            nextTimestamp: Date(timeIntervalSince1970: 8.0),
            maxDuration: 12,
            maxCharacters: 480
        ))
        precondition(!RealtimeUtteranceMerger.canDropNoNewContent(
            previous: tailDuplicatePrevious,
            nextText: "Scan their site",
            nextLanguage: "zh",
            nextSource: .system,
            nextTimestamp: Date(timeIntervalSince1970: 1.0),
            maxDuration: 8,
            maxCharacters: 240
        ))
        precondition(!RealtimeUtteranceMerger.canDropNoNewContent(
            previous: TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "website",
                detectedLanguage: "en",
                source: .system,
                realtimeItemID: "rt_tail_subword"
            ),
            nextText: "site",
            nextLanguage: "en",
            nextSource: .system,
            nextTimestamp: Date(timeIntervalSince1970: 1.0),
            maxDuration: 8,
            maxCharacters: 240
        ))
        precondition(!RealtimeUtteranceMerger.canDropNoNewContent(
            previous: tailDuplicatePrevious,
            nextText: "Scan their site",
            nextLanguage: "en",
            nextSource: .system,
            nextTimestamp: Date(timeIntervalSince1970: 12.0),
            maxDuration: 8,
            maxCharacters: 240
        ))
        precondition(!RealtimeUtteranceMerger.canDropNoNewContent(
            previous: TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "same phrase",
                detectedLanguage: "en",
                source: .system,
                realtimeItemID: "rt_repeat_1"
            ),
            nextText: "same phrase",
            nextLanguage: "en",
            nextSource: .system,
            nextTimestamp: Date(timeIntervalSince1970: 1.0),
            maxDuration: 8,
            maxCharacters: 240
        ))
        var adjacentSystemEntries = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "系统音频验证开始",
                detectedLanguage: "zh",
                source: .system,
                realtimeItemID: "rt_sys_1"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 1),
                originalText: "验证开始这里只有第",
                detectedLanguage: "zh",
                source: .system,
                realtimeItemID: "rt_sys_2"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 2),
                originalText: "这里只有第电脑声音",
                detectedLanguage: "zh",
                source: .system,
                realtimeItemID: "rt_sys_3"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 3),
                originalText: "电脑声音没有麦克",
                detectedLanguage: "zh",
                source: .system,
                realtimeItemID: "rt_sys_4"
            )
        ]
        let agentLatest = RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &adjacentSystemEntries,
            source: .system,
            mode: .agent,
            baseMaxDuration: 8,
            baseMaxCharacters: 240
        )
        precondition(agentLatest == "系统音频验证开始这里只有第电脑声音没有麦克")
        precondition(adjacentSystemEntries.count == 1)
        precondition(adjacentSystemEntries[0].originalText == "系统音频验证开始这里只有第电脑声音没有麦克")

        var rollingMicEntries = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "这个世界上本来没有路",
                detectedLanguage: "zh",
                source: .microphone,
                realtimeItemID: "rt_roll_1"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 7),
                originalText: "没有路，走的人多了",
                detectedLanguage: "zh",
                source: .microphone,
                realtimeItemID: "rt_roll_2"
            )
        ]
        _ = RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &rollingMicEntries,
            source: .microphone,
            mode: .transcription,
            baseMaxDuration: 8,
            baseMaxCharacters: 240
        )
        rollingMicEntries.append(
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 14),
                originalText: "走的人多了也就有了路。",
                detectedLanguage: "zh",
                source: .microphone,
                realtimeItemID: "rt_roll_3"
            )
        )
        let rollingMicLatest = RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &rollingMicEntries,
            source: .microphone,
            mode: .transcription,
            baseMaxDuration: 8,
            baseMaxCharacters: 240
        )
        precondition(rollingMicLatest == "这个世界上本来没有路，走的人多了也就有了路。")
        precondition(rollingMicEntries.count == 1)
        precondition(rollingMicEntries[0].originalText == "这个世界上本来没有路，走的人多了也就有了路。")

        var appMergeEntry = TranscriptionEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            originalText: "这个世界上本来没有路",
            detectedLanguage: "zh",
            source: .microphone,
            realtimeItemID: "rt_app_roll_1"
        )
        let appSecondMergeTime = Date(timeIntervalSince1970: 7)
        let appSecondMerged = RealtimeUtteranceMerger.mergedText(
            previous: appMergeEntry.originalText,
            next: "没有路，走的人多了"
        )
        precondition(appSecondMerged == "这个世界上本来没有路，走的人多了")
        RealtimeUtteranceMerger.applyMergedFinal(
            to: &appMergeEntry,
            originalText: appSecondMerged!,
            translatedText: nil,
            detectedLanguage: "zh",
            speakerLabel: "You",
            isTranslating: false,
            mergedAt: appSecondMergeTime
        )
        precondition(appMergeEntry.realtimeLastMergedAt == appSecondMergeTime)
        precondition(RealtimeUtteranceMerger.canMerge(
            previous: appMergeEntry,
            nextText: "走的人多了也就有了路。",
            nextLanguage: "zh",
            nextSource: .microphone,
            nextTimestamp: Date(timeIntervalSince1970: 14),
            maxDuration: 8,
            maxCharacters: 240
        ))

        precondition(SpeakerRecognitionMode.off.isEnabled == false)
        precondition(SpeakerRecognitionMode.delayedDiarization.isEnabled)

        var diarizationEntries = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 10),
                originalText: "Remote speaker one final text.",
                detectedLanguage: "en",
                source: .system,
                speakerLabel: "Speaker (English)",
                isDraft: false,
                realtimeItemID: "diarized_row_1"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 20),
                originalText: "Remote speaker two final text.",
                detectedLanguage: "en",
                source: .system,
                speakerLabel: "Speaker (English)",
                isDraft: false,
                realtimeItemID: "diarized_row_2"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 30),
                originalText: "A live draft must not be relabeled yet.",
                detectedLanguage: "en",
                source: .system,
                speakerLabel: "Speaker (English)",
                isDraft: true,
                realtimeItemID: "draft_row"
            )
        ]
        let diarizationUpdates = SpeakerDiarizationMatcher.apply(
            segments: [
                DiarizedSpeechSegment(
                    speakerID: "speaker_1",
                    speakerDisplayName: "Speaker 1",
                    start: 9.6,
                    end: 12.2,
                    text: "Remote speaker one final text.",
                    confidence: 0.91
                ),
                DiarizedSpeechSegment(
                    speakerID: "speaker_2",
                    speakerDisplayName: "Speaker 2",
                    start: 19.7,
                    end: 22.0,
                    text: "Remote speaker two final text.",
                    confidence: 0.87
                ),
                DiarizedSpeechSegment(
                    speakerID: "speaker_3",
                    speakerDisplayName: "Speaker 3",
                    start: 29.8,
                    end: 31.0,
                    text: "A live draft must not be relabeled yet.",
                    confidence: 0.93
                )
            ],
            to: &diarizationEntries
        )
        precondition(diarizationUpdates == 2)
        precondition(diarizationEntries[0].speakerLabel == "Speaker 1")
        precondition(diarizationEntries[0].speakerID == "speaker_1")
        precondition(diarizationEntries[0].speakerSource == .diarization)
        precondition(diarizationEntries[0].originalText == "Remote speaker one final text.")
        precondition(diarizationEntries[1].speakerLabel == "Speaker 2")
        precondition(diarizationEntries[2].speakerLabel == "Speaker (English)")

        var ambiguousEntries = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 40),
                originalText: "same text",
                detectedLanguage: "en",
                source: .system,
                isDraft: false
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 40.2),
                originalText: "same text",
                detectedLanguage: "en",
                source: .system,
                isDraft: false
            )
        ]
        let ambiguousUpdates = SpeakerDiarizationMatcher.apply(
            segments: [
                DiarizedSpeechSegment(
                    speakerID: "speaker_ambiguous",
                    speakerDisplayName: "Speaker 4",
                    start: 39.9,
                    end: 40.5,
                    text: "same text",
                    confidence: 0.75
                )
            ],
            to: &ambiguousEntries
        )
        precondition(ambiguousUpdates == 0)
        precondition(ambiguousEntries.allSatisfy { $0.speakerSource == nil })

        let beforeFailure = ambiguousEntries
        precondition(SpeakerDiarizationMatcher.apply(segments: [], to: &ambiguousEntries) == 0)
        precondition(ambiguousEntries == beforeFailure)

        let speakerFields = SpeakerDiarizationRequestBuilder.fields(knownSpeakers: [
            KnownSpeakerReference(name: "Ada", audioDataURL: "data:audio/wav;base64,AAAA"),
            KnownSpeakerReference(name: "Grace", audioDataURL: "data:audio/wav;base64,BBBB")
        ])
        precondition(speakerFields.contains { $0.0 == "model" && $0.1 == "gpt-4o-transcribe-diarize" })
        precondition(speakerFields.contains { $0.0 == "response_format" && $0.1 == "diarized_json" })
        precondition(speakerFields.contains { $0.0 == "chunking_strategy" && $0.1 == "auto" })
        precondition(speakerFields.filter { $0.0 == "known_speaker_names[]" }.map(\.1) == ["Ada", "Grace"])
        precondition(
            speakerFields.filter { $0.0 == "known_speaker_references[]" }.map(\.1)
                == ["data:audio/wav;base64,AAAA", "data:audio/wav;base64,BBBB"]
        )

        var interleavedEntries = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "系统音频验证开始",
                detectedLanguage: "zh",
                source: .system,
                realtimeItemID: "rt_sys_interleaved_1"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0.5),
                originalText: "interleaved mic row",
                detectedLanguage: "en",
                source: .microphone,
                realtimeItemID: "rt_mic_interleaved"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 1),
                originalText: "验证开始这里只有第",
                detectedLanguage: "zh",
                source: .system,
                realtimeItemID: "rt_sys_interleaved_2"
            )
        ]
        let interleavedLatest = RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &interleavedEntries,
            source: .system,
            mode: .agent,
            baseMaxDuration: 8,
            baseMaxCharacters: 240
        )
        precondition(interleavedLatest == "验证开始这里只有第")
        precondition(interleavedEntries.count == 3)
        precondition(interleavedEntries[0].originalText == "系统音频验证开始")
        precondition(interleavedEntries[1].source == .microphone)
        precondition(interleavedEntries[2].originalText == "验证开始这里只有第")

        var translationEntries = [
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 0),
                originalText: "hello world",
                detectedLanguage: "en",
                source: .system,
                realtimeItemID: "rt_trans_1"
            ),
            TranscriptionEntry(
                timestamp: Date(timeIntervalSince1970: 1),
                originalText: "world again",
                detectedLanguage: "en",
                source: .system,
                realtimeItemID: "rt_trans_2"
            )
        ]
        let beforeTranslationConsolidation = translationEntries
        precondition(RealtimeUtteranceMerger.consolidateFinalEntries(
            entries: &translationEntries,
            source: .system,
            mode: .translation,
            baseMaxDuration: 8,
            baseMaxCharacters: 240
        ) == nil)
        precondition(translationEntries == beforeTranslationConsolidation)

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
        precondition(
            OpenAIRealtimeAgentService.eventItemID(
                from: outputItemDone,
                type: "response.output_item.done"
            ) == "msg_007"
        )
        precondition(outputItemSegments.count == 1)
        precondition(outputItemSegments[0].itemID == "msg_007")
        precondition(outputItemSegments[0].text == "Realtime nested final")

        let incompleteOutputItemDone: [String: Any] = [
            "type": "response.output_item.done",
            "item": [
                "id": "msg_incomplete_item",
                "status": "incomplete",
                "content": [
                    ["type": "output_text", "text": "truncated final"]
                ]
            ]
        ]
        precondition(OpenAIRealtimeAgentService.finalTranscriptSegments(
            from: incompleteOutputItemDone,
            fallbackItemID: "response_ignored"
        ).isEmpty)

        let responseDone: [String: Any] = [
            "type": "response.done",
            "response": [
                "id": "resp_ignored",
                "status": "completed",
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
        precondition(
            OpenAIRealtimeAgentService.eventItemID(
                from: responseDone,
                type: "response.done"
            ) == "msg_008"
        )
        precondition(responseDoneSegments.map(\.itemID) == ["msg_008", "msg_009"])
        precondition(responseDoneSegments.map(\.text) == ["First final item", "Second final item"])

        let incompleteResponseDone: [String: Any] = [
            "type": "response.done",
            "response": [
                "id": "resp_incomplete",
                "status": "incomplete",
                "output": [
                    [
                        "id": "msg_incomplete",
                        "content": [
                            ["type": "output_text", "text": "truncated response"]
                        ]
                    ]
                ]
            ]
        ]
        precondition(OpenAIRealtimeAgentService.finalTranscriptSegments(
            from: incompleteResponseDone,
            fallbackItemID: "response_ignored"
        ).isEmpty)

        print("realtime core smoke ok")
    }
}
