import Foundation

let sourcePath = "Sources/MeetingTranslator/Views/SettingsView.swift"
let source = try String(contentsOfFile: sourcePath, encoding: .utf8)

guard let audioSources = source.range(of: "settingsSection(title: \"Audio Sources\""),
      let realtimeCaptions = source.range(of: "settingsSection(title: \"Realtime Captions\""),
      let liveInterpretation = source.range(of: "settingsSection(title: \"Live Interpretation\""),
      let speakerRecognition = source.range(of: "settingsSection(title: \"Speaker Recognition\""),
      let legacyFallback = source.range(of: "settingsSection(title: \"Legacy Fallback Controls\""),
      let costTracking = source.range(of: "settingsSection(title: \"API Cost Tracking\""),
      let firstNoiseGate = source.range(of: "noiseGateControls") else {
    preconditionFailure("settings panel structure changed; update noise gate UI smoke test")
}

precondition(firstNoiseGate.lowerBound > audioSources.lowerBound)
precondition(firstNoiseGate.lowerBound < realtimeCaptions.lowerBound)
precondition(realtimeCaptions.lowerBound < liveInterpretation.lowerBound)
precondition(liveInterpretation.lowerBound < speakerRecognition.lowerBound)
precondition(speakerRecognition.lowerBound < legacyFallback.lowerBound)

let realtimeSection = source[realtimeCaptions.lowerBound..<speakerRecognition.lowerBound]
precondition(!realtimeSection.contains("fastInterval"))
precondition(!realtimeSection.contains("stitchInterval"))

let fallbackSection = source[legacyFallback.lowerBound..<costTracking.lowerBound]
precondition(!fallbackSection.contains("noiseGateControls"))

precondition(source.contains("Audio Input Filter"))
precondition(source.contains("Applies before every engine"))
precondition(!source.contains("Very sensitive"))
precondition(!source.contains("Ignore quiet audio"))
precondition(!source.contains("Off (~"))

print("settings noise gate UI smoke ok")
