import SwiftUI
import AppKit

@main
struct MeetingTranslatorApp: App {
    @StateObject private var appState: AppState

    init() {
        if CommandLine.arguments.contains("--run-system-audio-exclusion-probe") {
            SystemAudioCurrentProcessExclusionProbe.runAndExit()
        }
        _appState = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 680, height: 720)
        .commands {
            // Remove default "New Window" command
            CommandGroup(replacing: .newItem) { }

            // Custom commands
            CommandGroup(after: .appSettings) {
                Button("Clear Transcript") {
                    appState.clearEntries()
                }
                .keyboardShortcut("K", modifiers: [.command])
            }
        }
    }
}
