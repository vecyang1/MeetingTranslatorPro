import Foundation

@main
struct SettingsCopySmoke {
    static func main() {
        let realtimeDescription = TranscriptionEngine.openAIRealtime.description
        precondition(realtimeDescription.contains("Primary live captions"))
        precondition(realtimeDescription.contains("gpt-realtime-whisper"))
        precondition(!realtimeDescription.lowercased().contains("future path"))

        let legacyOpenAIDescription = TranscriptionEngine.openAI.description
        precondition(legacyOpenAIDescription.contains("Legacy fallback"))
        precondition(legacyOpenAIDescription.contains("Whisper + GPT"))

        let geminiLiveDescription = TranscriptionEngine.geminiLive.description
        precondition(!geminiLiveDescription.contains("Best for live meetings"))
        precondition(geminiLiveDescription.contains("alternate"))

        let settingsPath = "Sources/MeetingTranslator/Views/SettingsView.swift"
        let settings = try! String(contentsOfFile: settingsPath, encoding: .utf8)
        precondition(settings.contains("settingsSection(title: \"Realtime Captions\""))
        precondition(settings.contains("settingsSection(title: \"Live Interpretation\""))
        precondition(settings.contains("settingsSection(title: \"Speaker Recognition\""))
        precondition(settings.contains("settingsSection(title: \"Display Behavior\""))
        precondition(settings.contains("settingsSection(title: \"Audio Input Filter\""))
        precondition(settings.contains("settingsSection(title: \"Legacy Fallback Controls\""))
        precondition(settings.contains("Done saves persistent settings"))
        precondition(settings.contains("Translated Audio"))
        precondition(settings.contains("Uses gpt-realtime-translate output audio"))
        precondition(settings.contains("Speaker/display output is blocked while the microphone is on"))
        precondition(settings.contains("Headphones / non-speaker output confirmed"))
        precondition(settings.contains("realtimeTranslatedAudioPlaybackBinding"))
        precondition(settings.contains("no audio is sent while this mode is Off"))
        precondition(settings.contains("add an OpenAI API key before starting live interpretation"))

        let appStatePath = "Sources/MeetingTranslator/Managers/AppState.swift"
        let appState = try! String(contentsOfFile: appStatePath, encoding: .utf8)
        precondition(appState.contains("realtime.translatedaudioplayback.m8.enabled"))
        precondition(appState.contains("realtime.translatedaudioplayback.m8.safeoutputroute"))
        precondition(!appState.contains("forKey: realtimeTranslatedAudioPlaybackKey"))
        precondition(appState.contains("Translated audio playback: enabled"))
        precondition(appState.contains("Playback mode: safe preview"))

        print("settings copy smoke ok")
    }
}
