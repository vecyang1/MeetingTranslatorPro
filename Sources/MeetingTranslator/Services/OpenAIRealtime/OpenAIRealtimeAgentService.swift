import Foundation

final class OpenAIRealtimeAgentService: OpenAIRealtimeWebSocketService, @unchecked Sendable {
    private let model = OpenAIRealtimeModel.realtimeAgent.rawValue

    override var sessionMode: RealtimeRouteMode { .agent }

    func connect(
        targetLanguageCode: String,
        shouldTranslate: Bool,
        reasoningEffort: RealtimeReasoningEffort
    ) async throws {
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
            throw OpenAIRealtimeError.invalidURL
        }
        onEvent?(.sessionStateChanged(source: source, state: .connecting))
        try await super.connect(url: url)
        sendSessionUpdate(
            targetLanguageCode: targetLanguageCode,
            shouldTranslate: shouldTranslate,
            reasoningEffort: reasoningEffort
        )
    }

    @discardableResult
    func sendAudio(_ pcm16kData: Data) -> Bool {
        let pcm24k = AudioResampler.resamplePCM16Mono(pcm16kData, fromSampleRate: 16_000, toSampleRate: 24_000)
        let duration = Double(pcm16kData.count) / (16_000.0 * 2.0)
        return sendAudioAppend(type: "input_audio_buffer.append", pcm24kData: pcm24k, durationSeconds: duration)
    }

    private func sendSessionUpdate(
        targetLanguageCode: String,
        shouldTranslate: Bool,
        reasoningEffort: RealtimeReasoningEffort
    ) {
        let outputInstruction = shouldTranslate
            ? "Output only the best faithful \(targetLanguageCode) translation of the speaker's latest speech."
            : "Output only the faithful transcript of the speaker's latest speech in the original language."

        sendJSON([
            "type": "session.update",
            "session": [
                "type": "realtime",
                "output_modalities": ["text"],
                "reasoning": ["effort": reasoningEffort.rawValue],
                "max_output_tokens": 600,
                "instructions": """
                You are the live caption engine inside Meeting Translator Pro.
                \(outputInstruction)
                Never answer the speaker. Never summarize. Never explain. Never add labels, prefixes, markdown, timestamps, apologies, or commentary.
                Preserve names, numbers, product terms, and code words as spoken.
                If the audio is silence or unclear, output nothing.
                """,
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "turn_detection": [
                            "type": "server_vad",
                            "threshold": 0.5,
                            "prefix_padding_ms": 300,
                            "silence_duration_ms": 700,
                            "create_response": true,
                            "interrupt_response": false
                        ]
                    ]
                ]
            ]
        ])
    }

    override func processServerEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }
        let itemID = event["item_id"] as? String ?? event["response_id"] as? String ?? "agent-\(UUID().uuidString)"
        switch type {
        case "session.updated":
            markSessionReady()
        case "response.output_text.delta", "response.text.delta", "response.output_audio_transcript.delta", "response.audio_transcript.delta":
            if let delta = event["delta"] as? String, !delta.isEmpty {
                onEvent?(.partialTranscript(source: source, itemID: itemID, text: delta, timestamp: Date()))
            }
        case "response.output_text.done", "response.text.done":
            let text = event["text"] as? String ?? ""
            onEvent?(.finalTranscript(source: source, itemID: itemID, text: text, language: nil, timestamp: Date()))
        case "response.output_audio_transcript.done", "response.audio_transcript.done":
            let transcript = event["transcript"] as? String ?? ""
            onEvent?(.finalTranscript(source: source, itemID: itemID, text: transcript, language: nil, timestamp: Date()))
        case "response.output_item.done", "response.done":
            let segments = Self.finalTranscriptSegments(from: event, fallbackItemID: itemID)
            for segment in segments where !segment.text.isEmpty {
                onEvent?(.finalTranscript(source: source, itemID: segment.itemID, text: segment.text, language: nil, timestamp: Date()))
            }
        case "error":
            let message = ((event["error"] as? [String: Any])?["message"] as? String) ?? "OpenAI Realtime assistant error."
            emitRecoverableError(message, action: "Retry")
        default:
            break
        }
    }

    static func finalTranscriptSegments(
        from event: [String: Any],
        fallbackItemID: String
    ) -> [(itemID: String, text: String)] {
        if let item = event["item"] as? [String: Any],
           let text = extractText(fromItem: item) {
            let itemID = item["id"] as? String ?? event["item_id"] as? String ?? fallbackItemID
            return [(itemID: itemID, text: text)]
        }
        if let response = event["response"] as? [String: Any],
           let output = response["output"] as? [[String: Any]] {
            return output.compactMap { item in
                guard let text = extractText(fromItem: item) else { return nil }
                let itemID = item["id"] as? String
                    ?? item["item_id"] as? String
                    ?? event["item_id"] as? String
                    ?? response["id"] as? String
                    ?? fallbackItemID
                return (itemID: itemID, text: text)
            }
        }
        return []
    }

    private static func extractText(fromItem item: [String: Any]) -> String? {
        if let content = item["content"] as? [[String: Any]] {
            let chunks = content.compactMap { part -> String? in
                if let text = part["text"] as? String { return text }
                if let transcript = part["transcript"] as? String { return transcript }
                return nil
            }
            let text = chunks.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        if let text = item["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
