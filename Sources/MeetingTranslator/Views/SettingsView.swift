import SwiftUI

/// Elegant settings panel for API keys, engine selection, language, and audio configuration
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showOpenAIKey = false
    @State private var showGoogleKey = false
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
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
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Engine Selection
                    settingsSection(title: "Transcription Engine", icon: "cpu", iconColor: .purple) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(TranscriptionEngine.allCases) { engine in
                                engineButton(engine)
                            }
                        }
                    }

                    // OpenAI API Key
                    settingsSection(title: "OpenAI API", icon: "key.fill", iconColor: .orange) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if showOpenAIKey {
                                    TextField("sk-...", text: $appState.apiKey)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                } else {
                                    SecureField("Enter your OpenAI API key", text: $appState.apiKey)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                }
                                Button(action: { showOpenAIKey.toggle() }) {
                                    Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
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

                            HStack(spacing: 4) {
                                Image(systemName: appState.selectedEngine.requiresOpenAIKey ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(appState.selectedEngine.requiresOpenAIKey ? Color.green : Color.secondary)
                                Text(appState.selectedEngine.requiresOpenAIKey
                                     ? "Required for current engine"
                                     : "Not required for current engine")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Google API Key
                    settingsSection(title: "Google Gemini API", icon: "key.fill", iconColor: .blue) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if showGoogleKey {
                                    TextField("AIza...", text: $appState.googleAPIKey)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                } else {
                                    SecureField("Enter your Google API key", text: $appState.googleAPIKey)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                }
                                Button(action: { showGoogleKey.toggle() }) {
                                    Image(systemName: showGoogleKey ? "eye.slash" : "eye")
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

                            HStack(spacing: 4) {
                                Image(systemName: appState.selectedEngine.requiresGoogleKey ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(appState.selectedEngine.requiresGoogleKey ? Color.green : Color.secondary)
                                Text(appState.selectedEngine.requiresGoogleKey
                                     ? "Required for current engine"
                                     : "Not required for current engine")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Translation Settings
                    settingsSection(title: "Translation", icon: "globe", iconColor: .blue) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Target Language")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(SupportedLanguage.allCases) { lang in
                                    languageButton(lang)
                                }
                            }
                        }
                    }

                    // Input Languages
                    settingsSection(title: "Input Languages", icon: "mic.badge.plus", iconColor: .orange) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Expected speaker languages (optional)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("Select one or more languages to improve transcription accuracy. Leave empty to auto-detect all.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
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
                                         ? "Single language → strongest accuracy hint (Whisper `language` param)"
                                         : "Multiple languages → vocabulary bias hint (Whisper `prompt` + Gemini system instruction)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Audio Settings
                    settingsSection(title: "Audio Sources", icon: "waveform", iconColor: .green) {
                        VStack(spacing: 12) {
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

                    // Advanced — collapsible
                    settingsSection(title: "Advanced", icon: "slider.horizontal.3", iconColor: .gray) {
                        VStack(alignment: .leading, spacing: 16) {

                            // Expand/collapse toggle
                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() } }) {
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
                                VStack(alignment: .leading, spacing: 20) {

                                    // Pipeline diagram
                                    pipelineDiagram

                                    Divider()

                                    // Fast interval
                                    sliderRow(
                                        label: "Fast Draft Interval",
                                        value: $appState.fastInterval,
                                        range: 2...10,
                                        step: 1,
                                        unit: "s",
                                        hint: "How often to show a quick draft. Shorter = faster display, more API calls.",
                                        color: .orange
                                    )

                                    // Stitch interval (OpenAI only)
                                    if appState.selectedEngine == .openAI {
                                        sliderRow(
                                            label: "Stitch Pass Interval",
                                            value: $appState.stitchInterval,
                                            range: 8...30,
                                            step: 1,
                                            unit: "s",
                                            hint: "How often to re-transcribe a longer window and replace drafts. Longer = better context stitching.",
                                            color: .blue
                                        )
                                    }

                                    // Gemini quality interval
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
                                        Text("⚠️ Keep this low (0.003–0.008). Too high will skip real speech, especially from far away.")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange.opacity(0.8))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                    // Cost Tracking
                    settingsSection(title: "API Cost Tracking", icon: "dollarsign.circle", iconColor: .orange) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Session Cost")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(appState.costTracker.sessionCostFormatted)
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("All-Time Total")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(appState.costTracker.totalCostFormatted)
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.orange)
                                }
                            }

                            if !appState.costTracker.logEntries.isEmpty {
                                Divider()
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

            // Footer
            HStack {
                Spacer()
                Button(action: {
                    appState.saveSettings()
                    dismiss()
                }) {
                    Text("Save & Close")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.gradient)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480, height: 760)
        .background(VisualEffectBackground(material: .popover, blendingMode: .behindWindow))
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
                    Text("S1 replaces F1–F\(stitchInt / fastInt)")
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

    // MARK: - Slider Row Helper

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
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.system(size: 14))
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
