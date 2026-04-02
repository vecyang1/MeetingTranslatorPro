import SwiftUI
import AppKit

/// Main content view — elegant glassmorphic design for real-time meeting translation
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isSettingsPresented = false
    @State private var isHoveringRecord = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().opacity(0.5)
            transcriptionList
            Divider().opacity(0.5)
            controlBar
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 480, idealHeight: 640)
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Meeting Translator")
                        .font(.system(size: 14, weight: .semibold))

                    // Engine badge
                    Text(appState.selectedEngine.shortName)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(engineBadgeColor)
                        )
                }
                HStack(spacing: 6) {
                    if appState.isRecording {
                        RecordingPulse()
                    }
                    Text(appState.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(appState.isRecording ? .green : .secondary)
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

                    // Session cost
                    if appState.costTracker.sessionCost > 0 {
                        Text(appState.costTracker.sessionCostFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Language selector
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
                HStack(spacing: 4) {
                    Text(appState.targetLanguage.flag)
                        .font(.system(size: 14))
                    Text(appState.targetLanguage.rawValue)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .help("Target translation language")

            Button(action: { isSettingsPresented = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VisualEffectBackground(material: .titlebar, blendingMode: .withinWindow))
    }

    private var engineBadgeColor: Color {
        switch appState.selectedEngine {
        case .openAI: return .blue
        case .geminiFlash: return .orange
        case .geminiLive: return .green
        }
    }

    // MARK: - Transcription List

    private var transcriptionList: some View {
        Group {
            if appState.entries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.entries) { entry in
                                TranscriptionRowView(
                                    entry: entry,
                                    showTranslation: appState.showTranslations
                                )
                                .id(entry.id)
                                if entry.id != appState.entries.last?.id {
                                    Divider()
                                        .padding(.leading, 80)
                                        .opacity(0.4)
                                }
                            }
                        }
                        .padding(.vertical, 8)
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
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.quaternary)

            VStack(spacing: 6) {
                Text("No Transcriptions Yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Press Start to begin capturing and translating meeting audio")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            if appState.selectedEngine.requiresOpenAIKey && appState.apiKey.isEmpty {
                warningBadge(
                    icon: "key.fill",
                    text: "Configure your OpenAI API key in Settings to get started",
                    color: .orange,
                    action: nil
                )
            }

            if appState.selectedEngine.requiresGoogleKey && appState.googleAPIKey.isEmpty {
                warningBadge(
                    icon: "key.fill",
                    text: "Configure your Google API key in Settings to use Gemini",
                    color: .blue,
                    action: nil
                )
            }

            if appState.systemAudioManager.permissionStatus == .denied {
                warningBadge(
                    icon: "lock.shield",
                    text: "Screen Recording permission needed for system audio capture",
                    color: .purple,
                    action: ("Open System Settings", {
                        appState.systemAudioManager.openScreenRecordingSettings()
                    })
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    private func warningBadge(icon: String, text: String, color: Color, action: (String, () -> Void)?) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.leading)
            }

            if let (label, handler) = action {
                Button(action: handler) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 10))
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(color.gradient)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.top, 4)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 16) {
            // Record button
            Button(action: { appState.toggleRecording() }) {
                HStack(spacing: 8) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(appState.isRecording ? "Stop" : "Start")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
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
                        .shadow(color: appState.isRecording ? .red.opacity(0.3) : .blue.opacity(0.3),
                                radius: isHoveringRecord ? 8 : 4, y: 2)
                )
                .scaleEffect(isHoveringRecord ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHoveringRecord)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringRecord = hovering
            }

            // Audio levels
            if appState.isRecording {
                HStack(spacing: 12) {
                    if appState.isMicEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                            AudioLevelIndicator(level: appState.micLevel, barCount: 5, color: .green)
                        }
                    }
                    if appState.isSystemAudioEnabled && appState.systemAudioManager.isCapturing {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.purple)
                            AudioLevelIndicator(level: appState.systemLevel, barCount: 5, color: .purple)
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
                    .frame(maxWidth: 200)
                    .help(error)
            }

            // Permission button
            if appState.systemAudioManager.permissionStatus == .denied && appState.isSystemAudioEnabled {
                Button(action: {
                    appState.systemAudioManager.openScreenRecordingSettings()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 10))
                        Text("Grant Permission")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .help("Open System Settings to grant Screen Recording permission")
            }

            // Action buttons
            HStack(spacing: 8) {
                // Toggle translations visibility
                Button(action: {
                    appState.showTranslations.toggle()
                    appState.saveSettings()
                }) {
                    Image(systemName: appState.showTranslations ? "text.bubble.fill" : "text.bubble")
                        .font(.system(size: 12))
                        .foregroundStyle(appState.showTranslations ? .blue : .secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(appState.showTranslations ? Color.blue.opacity(0.1) : Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help(appState.showTranslations ? "Hide translations" : "Show translations")

                if !appState.entries.isEmpty {
                    Button(action: exportTranscript) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Export transcript")

                    Button(action: { appState.clearEntries() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Clear all entries")
                }
            }

            Text("\(appState.entries.count) entries")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VisualEffectBackground(material: .contentBackground, blendingMode: .withinWindow))
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
