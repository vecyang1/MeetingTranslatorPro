import Foundation

@MainActor
final class OpenAIRealtimeCoordinator {
    private let router = RealtimeModelRouter()
    private let reducer = RealtimeEventReducer()
    private var transcriptionServices: [TranscriptionEntry.AudioSource: OpenAIRealtimeTranscriptionService] = [:]
    private var translationServices: [TranscriptionEntry.AudioSource: OpenAIRealtimeTranslationService] = [:]
    private var agentServices: [TranscriptionEntry.AudioSource: OpenAIRealtimeAgentService] = [:]

    private(set) var activeMode: RealtimeRouteMode?

    var onEvent: ((RealtimeAppEvent) -> Void)?

    func updateAPIKey(_ key: String) {
        transcriptionServices.values.forEach { $0.updateAPIKey(key) }
        translationServices.values.forEach { $0.updateAPIKey(key) }
        agentServices.values.forEach { $0.updateAPIKey(key) }
    }

    func start(
        apiKey: String,
        sources: [TranscriptionEntry.AudioSource],
        showTranslations: Bool,
        sameLanguage: Bool,
        targetLanguageCode: String,
        languageHint: String?,
        latencyPreset: RealtimeCaptionLatencyPreset,
        reasoningEffort: RealtimeReasoningEffort
    ) async throws -> RealtimeRouteDecision {
        stop()
        reducer.reset()

        let decision = router.route(
            showTranslations: showTranslations,
            sameLanguage: sameLanguage,
            wantsTranslatedAudio: showTranslations,
            wantsAgent: false
        )
        activeMode = decision.mode

        for source in sources {
            switch decision.mode {
            case .translation:
                guard decision.shouldStartTranslationSession else { continue }
                let service = OpenAIRealtimeTranslationService(apiKey: apiKey, source: source)
                wire(service)
                translationServices[source] = service
                try await service.connect(targetLanguageCode: targetLanguageCode)
            case .transcription:
                let service = OpenAIRealtimeTranscriptionService(apiKey: apiKey, source: source)
                wire(service)
                transcriptionServices[source] = service
                try await service.connect(languageHint: languageHint, latencyPreset: latencyPreset)
            case .agent:
                let service = OpenAIRealtimeAgentService(apiKey: apiKey, source: source)
                wire(service)
                agentServices[source] = service
                try await service.connect(
                    targetLanguageCode: targetLanguageCode,
                    shouldTranslate: showTranslations && !sameLanguage && languageHint != nil,
                    reasoningEffort: reasoningEffort
                )
            }
        }

        return decision
    }

    func stop() {
        transcriptionServices.values.forEach { $0.disconnect() }
        translationServices.values.forEach { $0.disconnect() }
        agentServices.values.forEach { $0.disconnect() }
        transcriptionServices.removeAll()
        translationServices.removeAll()
        agentServices.removeAll()
        activeMode = nil
        reducer.reset()
    }

    func sendAudio(_ data: Data, source: TranscriptionEntry.AudioSource) -> Bool {
        switch activeMode {
        case .translation:
            return translationServices[source]?.sendAudio(data) ?? false
        case .transcription:
            return transcriptionServices[source]?.sendAudio(data) ?? false
        case .agent:
            return agentServices[source]?.sendAudio(data) ?? false
        case .none:
            return false
        }
    }

    func reduce(_ event: RealtimeAppEvent) -> RealtimeReducedEntry? {
        reducer.reduce(event)
    }

    func expirePartials(olderThan maxAge: TimeInterval) -> [RealtimeReducedEntry] {
        reducer.expirePartials(olderThan: maxAge)
    }

    private func wire(_ service: OpenAIRealtimeWebSocketService) {
        service.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.onEvent?(event)
            }
        }
    }
}
