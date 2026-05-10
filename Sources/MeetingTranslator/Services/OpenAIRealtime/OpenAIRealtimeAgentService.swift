import Foundation

final class OpenAIRealtimeAgentService: OpenAIRealtimeWebSocketService {
    private let model = OpenAIRealtimeModel.realtimeAgent.rawValue

    override var sessionMode: RealtimeRouteMode { .agent }

    func connect(reasoningEffort: RealtimeReasoningEffort) async throws {
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
            throw OpenAIRealtimeError.invalidURL
        }
        onEvent?(.sessionStateChanged(source: source, state: .connecting))
        try await super.connect(url: url)
        sendJSON([
            "type": "session.update",
            "session": [
                "type": "realtime",
                "reasoning": ["effort": reasoningEffort.rawValue],
                "instructions": "You are a Meeting Translator Pro assistant. Do not perform app actions without explicit user approval."
            ]
        ])
    }

    override func processServerEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }
        if type == "session.updated" {
            markSessionReady()
        } else if type == "error" {
            let message = ((event["error"] as? [String: Any])?["message"] as? String) ?? "OpenAI Realtime assistant error."
            emitRecoverableError(message, action: "Retry")
        }
    }
}
