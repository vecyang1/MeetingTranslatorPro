import Foundation

struct RealtimeModelRouter {
    func route(
        showTranslations: Bool,
        sameLanguage: Bool,
        hasPinnedSourceLanguage: Bool,
        wantsInterpreterSession: Bool,
        wantsAgent: Bool
    ) -> RealtimeRouteDecision {
        if wantsAgent {
            return RealtimeRouteDecision(
                mode: .agent,
                model: OpenAIRealtimeModel.realtimeAgent.rawValue,
                endpointPath: "/v1/realtime",
                reason: "Voice assistant/tool workflow requested.",
                shouldStartTranslationSession: false,
                shouldStartSourceCaptionSession: false
            )
        }

        if showTranslations, !sameLanguage, hasPinnedSourceLanguage, wantsInterpreterSession {
            return RealtimeRouteDecision(
                mode: .translation,
                model: OpenAIRealtimeModel.realtimeTranslate.rawValue,
                endpointPath: "/v1/realtime/translations",
                reason: "Live interpreter route because translation is visible, source differs from target, and interpreter mode is enabled.",
                shouldStartTranslationSession: true,
                shouldStartSourceCaptionSession: true
            )
        }

        return RealtimeRouteDecision(
            mode: .transcription,
            model: OpenAIRealtimeModel.realtimeWhisper.rawValue,
            endpointPath: "/v1/realtime",
            reason: "Caption-first route uses GPT Realtime Whisper for transcript deltas while speech is still active.",
            shouldStartTranslationSession: false,
            shouldStartSourceCaptionSession: false
        )
    }
}
