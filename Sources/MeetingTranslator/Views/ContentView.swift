import SwiftUI
import AppKit

/// Main content view — world-class glassmorphic design for real-time meeting translation
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isSettingsPresented = false
    @State private var isHoveringRecord = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().opacity(0.3)
            languageBar
            Divider().opacity(0.3)
            transcriptionList
            Divider().opacity(0.3)
            controlBar
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 520, idealHeight: 720)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environmentObject(appState)
        }
        .onAppear {
            appState.saveSettings()
            appState.checkPermissions()
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 10) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Title + status
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Meeting Translator")
                        .font(.system(size: 15, weight: .bold))

                    Text(appState.selectedEngine.shortName)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(engineBadgeColor))
                }

                HStack(spacing: 8) {
                    if appState.isRecording {
                        RecordingPulse()
                    }
                    Text(appState.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)

                    if appState.processingCount > 0 {
                        HStack(spacing: 3) {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 10, height: 10)
                            Text("\(appState.processingCount)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.blue)
                        }
                    }

                    if appState.isRecording {
                        Text(appState.recordingTimeFormatted)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                            .monospacedDigit()
                    }

                    if appState.costTracker.sessionCost > 0 {
                        Text(appState.costTracker.sessionCostFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Settings gear
            Button(action: { isSettingsPresented = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(VisualEffectBackground(material: .titlebar, blendingMode: .withinWindow))
    }

    // MARK: - Language Bar (Input + Output selectors)

    private var languageBar: some View {
        HStack(spacing: 0) {
            // Input language selector
            inputLanguageMenu
                .frame(maxWidth: .infinity)

            // Swap button
            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .help("Swap input and output languages")
            .padding(.horizontal, 4)

            // Output language selector
            outputLanguageMenu
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }

    private var inputLanguageMenu: some View {
        Menu {
            Button(action: {
                appState.inputLanguages.removeAll()
                appState.saveSettings()
            }) {
                HStack {
                    Text("Auto-Detect")
                    if appState.inputLanguages.isEmpty {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(SupportedLanguage.allCases) { lang in
                Button(action: {
                    // Single-select mode for input language (strongest Whisper hint)
                    if appState.inputLanguages.contains(lang) {
                        appState.inputLanguages.remove(lang)
                    } else {
                        appState.inputLanguages = [lang]
                    }
                    appState.saveSettings()
                }) {
                    HStack {
                        Text("\(lang.flag) \(lang.rawValue)")
                        if appState.inputLanguages.contains(lang) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text("INPUT")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                HStack(spacing: 4) {
                    if let inputLang = appState.inputLanguages.first, appState.inputLanguages.count == 1 {
                        Text(inputLang.flag)
                            .font(.system(size: 14))
                        Text(inputLang.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("Auto-Detect")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private var outputLanguageMenu: some View {
        Menu {
            ForEach(SupportedLanguage.allCases) { lang in
                Button(action: {
                    appState.targetLanguage = lang
                    appState.saveSettings()
                }) {
                    HStack {
                        Text("\(lang.flag) \(lang.rawValue)")
                        if appState.targetLanguage == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text("OUTPUT")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                HStack(spacing: 4) {
                    Text(appState.targetLanguage.flag)
                        .font(.system(size: 14))
                    Text(appState.targetLanguage.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func swapLanguages() {
        // Only swap if there's exactly one input language
        guard let inputLang = appState.inputLanguages.first, appState.inputLanguages.count == 1 else { return }
        let previousTarget = appState.targetLanguage
        appState.targetLanguage = inputLang
        appState.inputLanguages = [previousTarget]
        appState.saveSettings()
    }

    // MARK: - Transcription List

    private var transcriptionList: some View {
        Group {
            if appState.entries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(appState.entries) { entry in
                                TranscriptionRowView(
                                    entry: entry,
                                    showTranslation: appState.showTranslations,
                                    targetLanguage: appState.targetLanguage
                                )
                                .id(entry.id)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: appState.entries.count) { _, _ in
                        if let lastID = appState.entries.last?.id {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Ready to Translate")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))
                Text("Press Start to capture and translate\nmeeting audio in real time")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Warnings
            VStack(spacing: 10) {
                if appState.selectedEngine.requiresOpenAIKey && appState.apiKey.isEmpty {
                    warningBadge(
                        icon: "key.fill",
                        text: "OpenAI API key required",
                        color: .orange,
                        action: ("Open Settings", { isSettingsPresented = true })
                    )
                }

                if appState.selectedEngine.requiresGoogleKey && appState.googleAPIKey.isEmpty {
                    warningBadge(
                        icon: "key.fill",
                        text: "Google API key required for Gemini",
                        color: .blue,
                        action: ("Open Settings", { isSettingsPresented = true })
                    )
                }

                if appState.systemAudioManager.permissionStatus == .denied {
                    warningBadge(
                        icon: "lock.shield",
                        text: "Screen Recording permission needed",
                        color: .purple,
                        action: ("Grant Access", {
                            appState.systemAudioManager.openScreenRecordingSettings()
                        })
                    )
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private func warningBadge(icon: String, text: String, color: Color, action: (String, () -> Void)?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color.opacity(0.9))

            Spacer()

            if let (label, handler) = action {
                Button(action: handler) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(color.gradient))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 14) {
            // Record button
            Button(action: { appState.toggleRecording() }) {
                HStack(spacing: 8) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(appState.isRecording ? "Stop" : "Start")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            appState.isRecording
                            ? AnyShapeStyle(Color.red.gradient)
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        .shadow(
                            color: appState.isRecording ? .red.opacity(0.3) : .blue.opacity(0.3),
                            radius: isHoveringRecord ? 10 : 5, y: 2
                        )
                )
                .scaleEffect(isHoveringRecord ? 1.04 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHoveringRecord)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHoveringRecord = hovering }

            // Audio levels
            if appState.isRecording {
                HStack(spacing: 14) {
                    if appState.isMicEnabled {
                        HStack(spacing: 5) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                            AudioLevelIndicator(level: appState.micLevel, barCount: 6, color: .green)
                        }
                    }
                    if appState.isSystemAudioEnabled && appState.systemAudioManager.isCapturing {
                        HStack(spacing: 5) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.purple)
                            AudioLevelIndicator(level: appState.systemLevel, barCount: 6, color: .purple)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            Spacer()

            // Error message
            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 180)
                    .help(error)
            }

            // Permission shortcut
            if appState.systemAudioManager.permissionStatus == .denied && appState.isSystemAudioEnabled {
                Button(action: {
                    appState.systemAudioManager.openScreenRecordingSettings()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 10))
                        Text("Grant")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.purple.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            // Action buttons
            HStack(spacing: 6) {
                // Toggle translations
                Button(action: {
                    appState.setShowTranslations(!appState.showTranslations)
                }) {
                    Image(systemName: appState.showTranslations ? "text.bubble.fill" : "text.bubble")
                        .font(.system(size: 12))
                        .foregroundStyle(appState.showTranslations ? .blue : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(appState.showTranslations ? Color.blue.opacity(0.1) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .help(appState.showTranslations ? "Hide translations" : "Show translations")

                if !appState.entries.isEmpty {
                    Button(action: exportTranscript) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Export transcript")

                    Button(action: { appState.clearEntries() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Clear all entries")
                }
            }

            Text("\(appState.entries.count) entries")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(VisualEffectBackground(material: .contentBackground, blendingMode: .withinWindow))
    }

    // MARK: - Helpers

    private var engineBadgeColor: Color {
        switch appState.selectedEngine {
        case .openAIRealtime: return .mint
        case .openAI: return .blue
        case .geminiFlash: return .orange
        case .geminiLive: return .green
        }
    }

    private var statusColor: Color {
        if appState.isRecording {
            return .green
        }
        return .secondary
    }

    // MARK: - Actions

    private func exportTranscript() {
        let transcript = appState.exportTranscript()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "meeting-transcript.txt"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? transcript.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
