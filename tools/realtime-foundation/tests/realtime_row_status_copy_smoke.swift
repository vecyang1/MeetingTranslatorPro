import Foundation

let row = try! String(
    contentsOfFile: "Sources/MeetingTranslator/Views/TranscriptionRowView.swift",
    encoding: .utf8
)
precondition(row.contains("live caption"))
precondition(row.contains("Waiting for live translation..."))
precondition(!row.contains("Text(\"Translating...\")"))

let content = try! String(
    contentsOfFile: "Sources/MeetingTranslator/Views/ContentView.swift",
    encoding: .utf8
)
precondition(content.contains("activeRealtimeMode"))

print("realtime row status copy smoke ok")
