import Foundation

let contentPath = "Sources/MeetingTranslator/Views/ContentView.swift"
let appStatePath = "Sources/MeetingTranslator/Managers/AppState.swift"
let rowPath = "Sources/MeetingTranslator/Views/TranscriptionRowView.swift"
let settingsPath = "Sources/MeetingTranslator/Views/SettingsView.swift"

let content = try String(contentsOfFile: contentPath, encoding: .utf8)
let appState = try String(contentsOfFile: appStatePath, encoding: .utf8)
let row = try String(contentsOfFile: rowPath, encoding: .utf8)
let settings = try String(contentsOfFile: settingsPath, encoding: .utf8)

precondition(appState.contains("@Published var followLatestCaptions: Bool = true"))
precondition(appState.contains("followLatestCaptionsKey"))
precondition(appState.contains("com.meetingtranslator.followlatestcaptions"))
precondition(appState.contains("savedFollowLatestCaptions"))
precondition(appState.contains("UserDefaults.standard.set(followLatestCaptions, forKey: followLatestCaptionsKey)"))
precondition(appState.contains("func setFollowLatestCaptions(_ enabled: Bool)"))
precondition(appState.contains("func setRealtimeInterpreterSessionEnabled(_ enabled: Bool)"))
precondition(appState.contains("[\\(entry.source.rawValue)]"))

func functionBody(named name: String, in source: String) -> String {
    guard let range = source.range(of: "func \(name)") else {
        preconditionFailure("missing function \(name)")
    }
    let tail = source[range.lowerBound...]
    guard let firstBrace = tail.firstIndex(of: "{") else {
        preconditionFailure("missing opening brace for \(name)")
    }
    var depth = 0
    var index = firstBrace
    while index < source.endIndex {
        let char = source[index]
        if char == "{" { depth += 1 }
        if char == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[firstBrace...index])
            }
        }
        index = source.index(after: index)
    }
    preconditionFailure("missing closing brace for \(name)")
}

let followSetter = functionBody(named: "setFollowLatestCaptions", in: appState)
precondition(followSetter.contains("UserDefaults.standard.set(enabled, forKey: followLatestCaptionsKey)"))
precondition(!followSetter.contains("saveSettings()"))
precondition(!followSetter.contains("refreshOpenAIRealtimeRoutingIfNeeded"))
precondition(!followSetter.contains("configureAudioCaptureForSelectedEngine"))

let interpreterSetter = functionBody(named: "setRealtimeInterpreterSessionEnabled", in: appState)
precondition(interpreterSetter.contains("UserDefaults.standard.set(enabled, forKey: realtimeInterpreterSessionEnabledKey)"))
precondition(interpreterSetter.contains("let needsRoutingRefresh"))
precondition(interpreterSetter.contains("refreshOpenAIRealtimeRoutingIfNeeded"))

precondition(content.contains("private let transcriptBottomID"))
precondition(content.contains("followLatestCaptionsButton"))
precondition(content.contains("appState.setFollowLatestCaptions(!appState.followLatestCaptions)"))
precondition(content.contains("appState.followLatestCaptions"))
precondition(content.contains("proxy.scrollTo(transcriptBottomID, anchor: .bottom)"))
precondition(content.contains("Follow latest captions"))
precondition(content.contains("Keep transcript in place"))

precondition(content.contains("private var transcriptScrollSignature: String"))
precondition(content.contains("return appState.entries.map { entry in"))

guard let listStart = content.range(of: "private var transcriptionList: some View"),
      let emptyStart = content.range(of: "private var emptyState: some View") else {
    preconditionFailure("transcription list structure changed")
}
let listBody = content[listStart.lowerBound..<emptyStart.lowerBound]
precondition(listBody.contains("if appState.followLatestCaptions"))
precondition(!listBody.contains("withAnimation"))

precondition(row.contains(".fixedSize(horizontal: false, vertical: true)"))
precondition(row.contains(".animation(nil, value: entry.originalText)"))
precondition(row.contains(".transaction { transaction in"))

precondition(settings.contains("settingsSection(title: \"Display Behavior\""))
precondition(settings.contains("followLatestCaptionsBinding"))
precondition(settings.contains("realtimeInterpreterSessionBinding"))
precondition(settings.contains("Toggle(\"Live translation session\", isOn: realtimeInterpreterSessionBinding)"))
precondition(!settings.contains("Toggle(\"Live translation session\", isOn: $appState.realtimeInterpreterSessionEnabled)"))
precondition(settings.contains("Follow latest captions"))
precondition(settings.contains("New captions keep the bottom in view. Turn off when reading earlier transcript text."))

print("transcript follow UI smoke ok")
