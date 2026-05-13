import Foundation

final class OpenAIRealtimeTranscriptionService: OpenAIRealtimeWebSocketService, @unchecked Sendable {
    private let model = OpenAIRealtimeModel.realtimeWhisper.rawValue
    private var currentTurnID = "transcription-\(UUID().uuidString)"
    private var boundaryContext = RealtimeAudioBoundaryContext(overlapSeconds: 0.3)

    override var sessionMode: RealtimeRouteMode { .transcription }

    func connect(languageHint: String?, latencyPreset: RealtimeCaptionLatencyPreset) async throws {
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else {
            throw OpenAIRealtimeError.invalidURL
        }
        onEvent?(.sessionStateChanged(source: source, state: .connecting))
        boundaryContext.reset()
        try await super.connect(url: url)
        sendSessionUpdate(languageHint: languageHint, latencyPreset: latencyPreset)
    }

    @discardableResult
    func sendAudio(_ pcm16kData: Data) -> Bool {
        let contextualPCM16k = boundaryContext.contextualizedAudio(pcm16kData, source: source)
        let pcm24k = AudioResampler.resamplePCM16Mono(contextualPCM16k, fromSampleRate: 16_000, toSampleRate: 24_000)
        let duration = Double(contextualPCM16k.count) / (16_000.0 * 2.0)
        let appended = sendAudioAppend(type: "input_audio_buffer.append", pcm24kData: pcm24k, durationSeconds: duration)
        guard appended else { return false }
        return sendJSON(["type": "input_audio_buffer.commit"])
    }

    func resetAudioBoundaryContext() {
        boundaryContext.reset(source: source)
    }

    func commitAudio() {
        sendJSON(["type": "input_audio_buffer.commit"])
    }

    override func processServerEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }
        let itemID = event["item_id"] as? String ?? currentTurnID
        switch type {
        case "session.updated":
            markSessionReady()
        case "conversation.item.input_audio_transcription.delta":
            if let delta = event["delta"] as? String, !delta.isEmpty {
                onEvent?(.partialTranscript(source: source, itemID: itemID, text: delta, timestamp: Date()))
            }
        case "conversation.item.input_audio_transcription.completed":
            let transcript = event["transcript"] as? String ?? ""
            let language = event["language"] as? String
            onEvent?(.finalTranscript(source: source, itemID: itemID, text: transcript, language: language, timestamp: Date()))
            rotateTurnIDIfFallbackID(itemID)
        case "error":
            let message = ((event["error"] as? [String: Any])?["message"] as? String) ?? "OpenAI Realtime transcription error."
            emitRecoverableError(message, action: "Use Legacy OpenAI")
        default:
            break
        }
    }

    private func sendSessionUpdate(languageHint: String?, latencyPreset _: RealtimeCaptionLatencyPreset) {
        var transcription: [String: Any] = ["model": model]
        if let languageHint, !languageHint.isEmpty {
            transcription["language"] = languageHint
        }
        sendJSON([
            "type": "session.update",
            "session": [
                "type": "transcription",
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "transcription": transcription,
                        "turn_detection": NSNull()
                    ]
                ]
            ]
        ])
    }

    private func rotateTurnIDIfFallbackID(_ itemID: String) {
        guard itemID == currentTurnID else { return }
        currentTurnID = "transcription-\(UUID().uuidString)"
    }
}
