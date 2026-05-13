import Foundation

let sourcePath = "Sources/MeetingTranslator/Views/ContentView.swift"
let source = try String(contentsOfFile: sourcePath, encoding: .utf8)

precondition(source.contains("appBrandIcon"))
precondition(source.contains("NSImage(named: \"AppIcon\")"))
precondition(source.contains("NSApp.applicationIconImage"))
precondition(!source.contains("Image(systemName: \"waveform.and.mic\")"))
precondition(!source.contains("colors: [Color.blue, Color.purple]"))

print("app logo UI smoke ok")
