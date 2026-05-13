import Foundation

@main
struct TranslatedAudioOutputSafetySmoke {
    static func main() {
        guard let route = AudioOutputRouteInspector.currentDefaultOutputRoute() else {
            fatalError("expected a default audio output route")
        }

        let confirmedStatus = RealtimeTranslatedAudioOutputSafety.status(
            isMicEnabled: true,
            safeOutputConfirmed: true,
            confirmedRouteFingerprint: route.fingerprint,
            route: route
        )
        if RealtimeTranslatedAudioOutputSafety.isLikelyRoomSpeaker(route) {
            precondition(confirmedStatus == .blockedLikelySpeakerOutputWithMicActive)
        } else if RealtimeTranslatedAudioOutputSafety.isLikelyHeadphones(route) {
            precondition(confirmedStatus == .ready)
        } else {
            precondition(confirmedStatus == .unavailable("current output is not recognized as headphones or a safe non-speaker route"))
        }

        let unconfirmedStatus = RealtimeTranslatedAudioOutputSafety.status(
            isMicEnabled: true,
            safeOutputConfirmed: false,
            confirmedRouteFingerprint: nil,
            route: route
        )
        if RealtimeTranslatedAudioOutputSafety.isLikelyRoomSpeaker(route) {
            precondition(unconfirmedStatus == .blockedLikelySpeakerOutputWithMicActive)
        } else if RealtimeTranslatedAudioOutputSafety.isLikelyHeadphones(route) {
            precondition(unconfirmedStatus == .needsHeadphonesConfirmation)
        } else {
            precondition(unconfirmedStatus == .unavailable("current output is not recognized as headphones or a safe non-speaker route"))
        }

        let speakerRoute = RealtimeTranslatedAudioOutputRoute(
            name: "MacBook Pro Speakers",
            manufacturer: "Apple Inc.",
            transportType: "built-in",
            dataSource: "ispk"
        )
        precondition(
            RealtimeTranslatedAudioOutputSafety.status(
                isMicEnabled: true,
                safeOutputConfirmed: true,
                confirmedRouteFingerprint: speakerRoute.fingerprint,
                route: speakerRoute
            ) == .blockedLikelySpeakerOutputWithMicActive
        )

        let appState = try! String(
            contentsOfFile: "Sources/MeetingTranslator/Managers/AppState.swift",
            encoding: .utf8
        )
        precondition(appState.contains("AudioOutputRouteInspector.currentDefaultOutputRoute()"))
        precondition(appState.contains("realtimeTranslatedAudioSafeOutputRouteFingerprint"))
        precondition(appState.contains("UserDefaults.standard.set(false, forKey: realtimeTranslatedAudioSafeOutputConfirmedKey)"))
        precondition(appState.contains("UserDefaults.standard.set(false, forKey: realtimeTranslatedAudioPlaybackEnabledKey)"))
        precondition(appState.contains("removeObject(forKey: realtimeTranslatedAudioSafeOutputRouteFingerprintKey)"))
        precondition(appState.contains("startRealtimeTranslatedAudioOutputRouteObserver()"))
        precondition(appState.contains("handleRealtimeTranslatedAudioOutputRouteChanged()"))

        print(
            "translated audio output safety smoke ok: "
            + "route=\(route.name) "
            + "speaker=\(RealtimeTranslatedAudioOutputSafety.isLikelyRoomSpeaker(route)) "
            + "headphones=\(RealtimeTranslatedAudioOutputSafety.isLikelyHeadphones(route))"
        )
    }
}
