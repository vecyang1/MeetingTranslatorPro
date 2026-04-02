import SwiftUI
import AppKit

@main
struct MeetingTranslatorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 640)
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
