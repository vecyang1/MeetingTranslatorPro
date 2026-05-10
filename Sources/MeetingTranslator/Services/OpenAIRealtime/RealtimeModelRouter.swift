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

        if showTranslations, !sameLanguage, wantsTranslatedAudio {
            return RealtimeRouteDecision(
                mode: .translation,
                model: OpenAIRealtimeModel.realtimeTranslate.rawValue,
                endpointPath: "/v1/realtime/translations",
                reason: "Live translated-audio route because translation is visible and source differs from target.",
                shouldStartTranslationSession: true
            )
        }

        return RealtimeRouteDecision(
            mode: .agent,
            model: OpenAIRealtimeModel.realtimeAgent.rawValue,
            endpointPath: "/v1/realtime",
            reason: "Default live captions route uses GPT Realtime 2 for lower-latency dialog understanding.",
            shouldStartTranslationSession: false
        )
    }
}
