import SwiftUI

/// Elegant settings panel — refined layout with clear visual grouping
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showOpenAIKey = false
    @State private var showGoogleKey = false
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Engine Selection
                    settingsSection(title: "Transcription Engine", icon: "cpu", iconColor: .purple) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(TranscriptionEngine.allCases) { engine in
                                engineButton(engine)
                            }
                        }
                    }

                    // API Keys
                    settingsSection(title: "API Keys", icon: "key.fill", iconColor: .orange) {
                        VStack(alignment: .leading, spacing: 14) {
                            apiKeyField(
                                label: "OpenAI API Key",
                                placeholder: "sk-...",
                                value: $appState.apiKey,
                                isVisible: $showOpenAIKey,
                                isRequired: appState.selectedEngine.requiresOpenAIKey
                            )

                            Divider().opacity(0.3)

                            apiKeyField(
                                label: "Google Gemini API Key",
                                placeholder: "AIza...",
                                value: $appState.googleAPIKey,
                                isVisible: $showGoogleKey,
                                isRequired: appState.selectedEngine.requiresGoogleKey
                            )
                        }
                    }

                    // Language Settings
                    settingsSection(title: "Languages", icon: "globe", iconColor: .blue) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Target language
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Output Language")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 6) {
                                    ForEach(SupportedLanguage.allCases) { lang in
                                        languageButton(lang)
                                    }
                                }
                            }

                            Divider().opacity(0.3)

                            // Input languages
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Input Languages")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                Text("Select expected speaker languages to improve accuracy. Leave empty for auto-detect.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 6) {
                                    ForEach(SupportedLanguage.allCases) { lang in
                                        inputLanguageCheckbox(lang)
                                    }
                                }

                                if !appState.inputLanguages.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.blue)
                                        Text(appState.inputLanguages.count == 1
                                             ? "Single language mode — strongest accuracy"
                                             : "Multi-language mode — vocabulary bias hint")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Audio Sources
                    settingsSection(title: "Audio Sources", icon: "waveform", iconColor: .green) {
                        VStack(spacing: 10) {
                            audioToggle(
                                title: "Microphone",
                                subtitle: "Capture your voice",
                                icon: "mic.fill",
                                color: .green,
                                isOn: $appState.isMicEnabled
                            )
                            audioToggle(
                                title: "System Audio",
                                subtitle: "Capture meeting sounds",
                                icon: "speaker.wave.2.fill",
                                color: .purple,
                                isOn: $appState.isSystemAudioEnabled
                            )
                        }
                    }

                    // Advanced Settings
                    settingsSection(title: "Advanced", icon: "slider.horizontal.3", iconColor: .gray) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(showAdvanced ? "Hide pipeline settings" : "Show pipeline settings")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if showAdvanced {
                                VStack(alignment: .leading, spacing: 18) {
                                    pipelineDiagram

                                    Divider().opacity(0.3)

                                    if appState.selectedEngine == .openAIRealtime {
                                        realtimeSettings
                                    } else {
                                        sliderRow(
                                            label: "Fast Draft Interval",
                                            value: $appState.fastInterval,
                                            range: 2...10,
                                            step: 1,
                                            unit: "s",
                                            hint: "How often to show a quick draft. Shorter = faster display, more API calls.",
                                            color: .orange
                                        )
                                    }

                                    if appState.selectedEngine == .openAI {
                                        sliderRow(
                                            label: "Stitch Pass Interval",
                                            value: $appState.stitchInterval,
                                            range: 8...30,
                                            step: 1,
                                            unit: "s",
                                            hint: "How often to re-transcribe a longer window and replace drafts.",
                                            color: .blue
                                        )
                                    }

                                    if appState.selectedEngine == .geminiFlash {
                                        sliderRow(
                                            label: "Quality Pass Interval",
                                            value: $appState.geminiQualityInterval,
                                            range: 8...30,
                                            step: 1,
                                            unit: "s",
                                            hint: "How often Gemini re-processes a longer audio window to replace drafts.",
                                            color: .blue
                                        )
                                    }

                                    // Noise gate
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.gray)
                                                    .frame(width: 8, height: 8)
                                                Text("Noise Gate Threshold")
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            Spacer()
                                            Text(noiseGateLabel)
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $appState.noiseGateThreshold, in: 0.001...0.05, step: 0.001)
                                            .tint(.gray)
                                        HStack {
                                            Text("Very sensitive")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("Ignore quiet audio")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                    // Cost Tracking
                    settingsSection(title: "API Cost Tracking", icon: "dollarsign.circle", iconColor: .orange) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Session Cost")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(appState.costTracker.sessionCostFormatted)
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("All-Time Total")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(appState.costTracker.totalCostFormatted)
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.orange)
                                }
                            }

                            if !appState.costTracker.logEntries.isEmpty {
                                Divider().opacity(0.3)
                                Text("Recent API Calls")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)

                                ForEach(appState.costTracker.logEntries.suffix(5)) { entry in
                                    HStack(spacing: 8) {
                                        Text(formatTime(entry.timestamp))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text(entry.engine)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(String(format: "$%.6f", entry.cost))
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }

                            HStack {
                                Button(action: { appState.costTracker.resetTotal() }) {
                                    Text("Reset Total")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()
            footer
        }
        .frame(width: 500, height: 780)
        .background(VisualEffectBackground(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Changes are saved automatically")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            Button(action: {
                appState.saveSettings()
                dismiss()
            }) {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Pipeline Diagram

    private var pipelineDiagram: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pipeline Timeline")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            let fastInt = Int(appState.fastInterval)
            let stitchInt = appState.selectedEngine == .openAI
                ? Int(appState.stitchInterval)
                : Int(appState.geminiQualityInterval)
            let totalSeconds = stitchInt + fastInt

            VStack(alignment: .leading, spacing: 4) {
                // Time axis
                HStack(spacing: 0) {
                    ForEach(0..<(totalSeconds / fastInt + 1), id: \.self) { i in
                        Text("\(i * fastInt)s")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Fast track
                HStack(spacing: 2) {
                    Text("Fast:")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .frame(width: 32, alignment: .leading)
                    HStack(spacing: 2) {
                        ForEach(0..<(stitchInt / fastInt), id: \.self) { i in
                            Text("F\(i+1)")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.7)))
                        }
                    }
                }

                // Stitch/quality track
                HStack(spacing: 2) {
                    Text(appState.selectedEngine == .openAI ? "Stitch:" : "Quality:")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.blue)
                        .frame(width: 42, alignment: .leading)
                    Text("S1 replaces F1\u{2013}F\(stitchInt / fastInt)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.blue.opacity(0.7)))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }

    // MARK: - Noise Gate Label

    private var noiseGateLabel: String {
        let v = appState.noiseGateThreshold
        if v <= 0.002 { return "Off (~\(String(format: "%.3f", v)))" }
        if v <= 0.005 { return "Low (\(String(format: "%.3f", v)))" }
        if v <= 0.015 { return "Med (\(String(format: "%.3f", v)))" }
        return "High (\(String(format: "%.3f", v)))"
    }

    private var realtimeSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Caption Latency")
                    .font(.system(size: 12, weight: .medium))
                Picker("", selection: $appState.realtimeCaptionLatency) {
                    ForEach(RealtimeCaptionLatencyPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                Text(appState.realtimeCaptionLatency.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Toggle("Automatic fallback to legacy OpenAI", isOn: $appState.realtimeAutomaticFallback)
                .font(.system(size: 12, weight: .medium))

            Toggle("Translated audio playback", isOn: $appState.realtimeTranslatedAudioPlayback)
                .font(.system(size: 12, weight: .medium))
                .disabled(true)

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Realtime uses separate source-aware sessions for mic and system audio. Translated audio stays disabled until feedback behavior is proven.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Slider Row

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        hint: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                }
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .tint(color)
            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(iconColor.opacity(0.1))
                    )
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func apiKeyField(
        label: String,
        placeholder: String,
        value: Binding<String>,
        isVisible: Binding<Bool>,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                if isRequired {
                    Text("Required")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green))
                } else {
                    Text("Optional")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
            }

            HStack {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: value)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                } else {
                    SecureField("Enter your API key", text: value)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                }
                Button(action: { isVisible.wrappedValue.toggle() }) {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }

    private func engineButton(_ engine: TranscriptionEngine) -> some View {
        Button(action: { appState.selectedEngine = engine }) {
            HStack(spacing: 10) {
                Image(systemName: appState.selectedEngine == engine ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(appState.selectedEngine == engine ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(engine.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(appState.selectedEngine == engine
                          ? Color.accentColor.opacity(0.08)
                          : Color.primary.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(appState.selectedEngine == engine
                                    ? Color.accentColor.opacity(0.3)
                                    : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func languageButton(_ lang: SupportedLanguage) -> some View {
        Button(action: { appState.targetLanguage = lang }) {
            HStack(spacing: 4) {
                Text(lang.flag)
                    .font(.system(size: 13))
                Text(lang.rawValue)
                    .font(.system(size: 11, weight: appState.targetLanguage == lang ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(appState.targetLanguage == lang
                          ? Color.accentColor.opacity(0.15)
                          : Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(appState.targetLanguage == lang
                                    ? Color.accentColor.opacity(0.4)
                                    : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func inputLanguageCheckbox(_ lang: SupportedLanguage) -> some View {
        let isSelected = appState.inputLanguages.contains(lang)
        return Button(action: {
            if isSelected {
                appState.inputLanguages.remove(lang)
            } else {
                appState.inputLanguages.insert(lang)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary)
                Text(lang.flag)
                    .font(.system(size: 13))
                Text(lang.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected
                          ? Color.orange.opacity(0.10)
                          : Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isSelected
                                    ? Color.orange.opacity(0.35)
                                    : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func audioToggle(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.1))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
