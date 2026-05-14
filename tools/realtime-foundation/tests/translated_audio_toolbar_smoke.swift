import Foundation

@main
struct TranslatedAudioToolbarSmoke {
    static func main() {
        let contentView = try! String(
            contentsOfFile: "Sources/MeetingTranslator/Views/ContentView.swift",
            encoding: .utf8
        )
        let appState = try! String(
            contentsOfFile: "Sources/MeetingTranslator/Managers/AppState.swift",
            encoding: .utf8
        )

        precondition(
            contentView.contains("realtimeTranslatedAudioToolbarButton"),
            "main window must expose a translated-audio toolbar control even before playback is enabled"
        )
        precondition(
            contentView.contains("Image(systemName: \"headphones\")"),
            "translated-audio activation should use a headphones icon so it is not confused with system-audio capture"
        )
        precondition(
            contentView.contains("enableRealtimeTranslatedAudioPlaybackFromCurrentRoute()"),
            "toolbar activation must confirm the current safe route and enable playback in one explicit click"
        )
        precondition(
            appState.contains("func enableRealtimeTranslatedAudioPlaybackFromCurrentRoute()"),
            "AppState must provide one explicit action that confirms current headphones and enables playback"
        )
        precondition(
            appState.contains("confirmRealtimeTranslatedAudioSafeOutputForCurrentRoute()"),
            "one-click activation must bind safe output confirmation to the current route"
        )
        precondition(
            !appState.contains("setRealtimeTranslatedAudioSafeOutputConfirmed(true)"),
            "one-click activation must not route through the public setter because it would schedule an extra Realtime reconnect"
        )

        let speakerRoute = RealtimeTranslatedAudioOutputRoute(
            name: "MacBook Pro Speakers",
            manufacturer: "Apple Inc.",
            transportType: "built-in",
            dataSource: "ispk"
        )
        let speakerStatus = RealtimeTranslatedAudioOutputSafety.status(
            isMicEnabled: true,
            safeOutputConfirmed: true,
            confirmedRouteFingerprint: speakerRoute.fingerprint,
            route: speakerRoute
        )
        let speakerPlan = RealtimeTranslatedAudioToolbarActivation.plan(
            showTranslations: true,
            inputLanguageCount: 1,
            sameLanguage: false,
            interpreterSessionEnabled: true,
            currentSafetyStatus: speakerStatus,
            confirmedCurrentRouteStatus: nil
        )
        precondition(!speakerPlan.canEnablePlayback)
        precondition(!speakerPlan.shouldConfirmCurrentRoute)

        let unrecognizedRoute = RealtimeTranslatedAudioOutputRoute(
            name: "Loopback Audio",
            transportType: "virtual",
            uniqueID: "loopback-output"
        )
        let unrecognizedStatus = RealtimeTranslatedAudioOutputSafety.status(
            isMicEnabled: true,
            safeOutputConfirmed: true,
            confirmedRouteFingerprint: unrecognizedRoute.fingerprint,
            route: unrecognizedRoute
        )
        let unrecognizedPlan = RealtimeTranslatedAudioToolbarActivation.plan(
            showTranslations: true,
            inputLanguageCount: 1,
            sameLanguage: false,
            interpreterSessionEnabled: true,
            currentSafetyStatus: unrecognizedStatus,
            confirmedCurrentRouteStatus: nil
        )
        precondition(!unrecognizedPlan.canEnablePlayback)

        let headphones = RealtimeTranslatedAudioOutputRoute(
            name: "Vy’s AirPods Max",
            manufacturer: "Apple Inc.",
            transportType: "bluetooth",
            dataSource: "hdpn",
            uniqueID: "airpods-max-output"
        )
        let unconfirmedHeadphonesStatus = RealtimeTranslatedAudioOutputSafety.status(
            isMicEnabled: true,
            safeOutputConfirmed: false,
            confirmedRouteFingerprint: nil,
            route: headphones
        )
        let confirmedHeadphonesStatus = RealtimeTranslatedAudioOutputSafety.status(
            isMicEnabled: true,
            safeOutputConfirmed: true,
            confirmedRouteFingerprint: headphones.fingerprint,
            route: headphones
        )
        let headphonesPlan = RealtimeTranslatedAudioToolbarActivation.plan(
            showTranslations: true,
            inputLanguageCount: 1,
            sameLanguage: false,
            interpreterSessionEnabled: true,
            currentSafetyStatus: unconfirmedHeadphonesStatus,
            confirmedCurrentRouteStatus: confirmedHeadphonesStatus
        )
        precondition(headphonesPlan.shouldConfirmCurrentRoute)
        precondition(headphonesPlan.canEnablePlayback)

        let captionOnlyPlan = RealtimeTranslatedAudioToolbarActivation.plan(
            showTranslations: false,
            inputLanguageCount: 1,
            sameLanguage: false,
            interpreterSessionEnabled: true,
            currentSafetyStatus: .ready,
            confirmedCurrentRouteStatus: nil
        )
        precondition(!captionOnlyPlan.canEnablePlayback)

        let sameLanguagePlan = RealtimeTranslatedAudioToolbarActivation.plan(
            showTranslations: true,
            inputLanguageCount: 1,
            sameLanguage: true,
            interpreterSessionEnabled: true,
            currentSafetyStatus: .ready,
            confirmedCurrentRouteStatus: nil
        )
        precondition(!sameLanguagePlan.canEnablePlayback)

        let autoDetectPlan = RealtimeTranslatedAudioToolbarActivation.plan(
            showTranslations: true,
            inputLanguageCount: 0,
            sameLanguage: false,
            interpreterSessionEnabled: true,
            currentSafetyStatus: .ready,
            confirmedCurrentRouteStatus: nil
        )
        precondition(!autoDetectPlan.canEnablePlayback)

        print("translated audio toolbar smoke ok")
    }
}
