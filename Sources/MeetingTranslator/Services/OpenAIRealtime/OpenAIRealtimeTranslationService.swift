import Foundation

final class OpenAIRealtimeTranslationService: OpenAIRealtimeWebSocketService, @unchecked Sendable {
    private let model = OpenAIRealtimeModel.realtimeTranslate.rawValue
    private var currentTurnID = "translation-\(UUID().uuidString)"

    override var sessionMode: RealtimeRouteMode { .translation }

    func connect(targetLanguageCode: String) async throws {
        guard let url = URL(string: "wss://api.openai.com/v1/realtime/translations?model=\(model)") else {
            throw OpenAIRealtimeError.invalidURL
        }
        onEvent?(.sessionStateChanged(source: source, state: .connecting))
        try await super.connect(url: url)
        sendJSON([
            "type": "session.update",
            "session": [
                "audio": [
                    "output": [
                        "language": targetLanguageCode
                    ]
                ]
            ]
        ])
    }

    @discardableResult
    func sendAudio(_ pcm16kData: Data) -> Bool {
        let pcm24k = AudioResampler.resamplePCM16Mono(pcm16kData, fromSampleRate: 16_000, toSampleRate: 24_000)
        let duration = Double(pcm16kData.count) / (16_000.0 * 2.0)
        return sendAudioAppend(type: "session.input_audio_buffer.append", pcm24kData: pcm24k, durationSeconds: duration)
    }

    override func processServerEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }
        let itemID = (event["item_id"] as? String) ?? currentTurnID
        switch type {
        case "session.updated":
            markSessionReady()
        case "session.input_transcript.delta":
            if let delta = event["delta"] as? String, !delta.isEmpty {
                onEvent?(.partialTranscript(source: source, itemID: itemID, text: delta, timestamp: Date()))
            }
        case "session.input_transcript.done", "session.input_transcript.completed":
            let transcript = event["transcript"] as? String ?? event["text"] as? String ?? ""
            onEvent?(.finalTranscript(source: source, itemID: itemID, text: transcript, language: nil, timestamp: Date()))
        case "session.output_transcript.delta":
            if let delta = event["delta"] as? String, !delta.isEmpty {
                onEvent?(.partialTranslation(source: source, itemID: itemID, text: delta, timestamp: Date()))
            }
        case "session.output_transcript.done", "session.output_transcript.completed":
            let text = event["transcript"] as? String ?? event["text"] as? String ?? ""
            onEvent?(.finalTranslation(source: source, itemID: itemID, text: text, language: nil, timestamp: Date()))
            rotateTurnIDIfFallbackID(itemID)
        case "session.output_audio.delta":
            if let delta = event["delta"] as? String, let data = Data(base64Encoded: delta) {
                onEvent?(.translatedAudioChunk(source: source, itemID: itemID, data: data, timestamp: Date()))
            }
        case "session.output_audio.done":
            rotateTurnIDIfFallbackID(itemID)
        case "error":
            let message = ((event["error"] as? [String: Any])?["message"] as? String) ?? "OpenAI Realtime translation error."
            emitRecoverableError(message, action: "Use Legacy OpenAI")
        default:
            break
        }
    }

    private func rotateTurnIDIfFallbackID(_ itemID: String) {
        guard itemID == currentTurnID else { return }
        currentTurnID = "translation-\(UUID().uuidString)"
    }
}
