import Foundation

struct RealtimeModelRouter {
    func route(
        showTranslations: Bool,
        sameLanguage: Bool,
        wantsTranslatedAudio: Bool,
        wantsAgent: Bool
    ) -> RealtimeRouteDecision {
        if wantsAgent {
            return RealtimeRouteDecision(
                mode: .agent,
                model: OpenAIRealtimeModel.realtimeAgent.rawValue,
                endpointPath: "/v1/realtime",
                reason: "Voice assistant/tool workflow requested.",
                shouldStartTranslationSession: false
            )
        }

        guard showTranslations, !sameLanguage, wantsTranslatedAudio else {
            return RealtimeRouteDecision(
                mode: .transcription,
                model: OpenAIRealtimeModel.realtimeWhisper.rawValue,
                endpointPath: "/v1/realtime",
                reason: "Captions-only route because translation is hidden, same-language, or translated audio is off.",
                shouldStartTranslationSession: false
            )
        }

        return RealtimeRouteDecision(
            mode: .translation,
            model: OpenAIRealtimeModel.realtimeTranslate.rawValue,
            endpointPath: "/v1/realtime/translations",
            reason: "Translation is visible and source differs from target.",
            shouldStartTranslationSession: true
        )
    }
}
