import SwiftUI

/// A single transcription/translation entry row with speaker differentiation
struct TranscriptionRowView: View {
    let entry: TranscriptionEntry
    let showTranslation: Bool

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time + Speaker column
            VStack(alignment: .center, spacing: 6) {
                Text(timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                speakerBadge
            }
            .frame(width: 72)

            // Content column
            VStack(alignment: .leading, spacing: 6) {
                // Language tag row
                HStack(spacing: 6) {
                    if let flag = entry.languageFlag {
                        Text(flag)
                            .font(.system(size: 12))
                    }
                    if let langName = entry.languageName {
                        Text(langName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(languageColor.opacity(0.9))
                    }
                    Spacer()
                    // Draft indicator — shows while fast-track result awaits stitch pass
                    if entry.isDraft {
                        HStack(spacing: 3) {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 10, height: 10)
                            Text("draft")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.orange.opacity(0.7))
                        }
                    }
                }

                // Original text — italic and slightly dimmed for drafts
                Text(wrappedText(entry.originalText))
                    .font(.system(size: 13, weight: .regular))
                    .italic(entry.isDraft)
                    .foregroundStyle(entry.isDraft ? Color.primary.opacity(0.55) : Color.primary.opacity(0.85))
                    .textSelection(.enabled)
                    .lineSpacing(4)

                // Translated text or loading — only show if showTranslation is true
                if showTranslation {
                    if entry.isTranslating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                            Text("Translating...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    } else if let translated = entry.translatedText {
                        Text(wrappedText(translated))
                            .font(.system(size: 14, weight: entry.isDraft ? .regular : .medium))
                            .italic(entry.isDraft)
                            .foregroundStyle(entry.isDraft ? Color.primary.opacity(0.55) : Color.primary)
                            .textSelection(.enabled)
                            .lineSpacing(4)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(entry.isDraft ? translationBubbleColor.opacity(0.5) : translationBubbleColor)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .opacity(entry.isDraft ? 0.8 : 1.0)
    }

    // MARK: - Speaker Badge

    private var speakerBadge: some View {
        VStack(spacing: 3) {
            Image(systemName: entry.source == .microphone ? "mic.fill" : "speaker.wave.2.fill")
                .font(.system(size: 10))
                .foregroundStyle(speakerColor)

            Text(speakerDisplayName)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(speakerColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(speakerColor.opacity(0.1))
        )
    }

    // MARK: - Computed Properties

    private var speakerDisplayName: String {
        if let label = entry.speakerLabel {
            return label
        }
        return entry.source == .microphone ? "You" : "Meeting"
    }

    private var speakerColor: Color {
        if entry.source == .microphone {
            return .green
        }
        guard let code = entry.detectedLanguage?.lowercased() else { return .purple }
        return languageColorForCode(code)
    }

    private var languageColor: Color {
        guard let code = entry.detectedLanguage?.lowercased() else { return .gray }
        return languageColorForCode(code)
    }

    private var translationBubbleColor: Color {
        if entry.source == .microphone {
            return Color.green.opacity(0.06)
        }
        return Color.accentColor.opacity(0.08)
    }

    // MARK: - CJK Line Wrapping

    /// Insert newlines into CJK text every ~22 characters at natural break points
    /// to improve readability in the narrow column layout.
    private func wrappedText(_ text: String) -> String {
        // Only wrap if text is mostly CJK
        let cjkCount = text.unicodeScalars.filter { v in
            let val = v.value
            return (val >= 0x4E00 && val <= 0x9FFF) ||
                   (val >= 0x3040 && val <= 0x30FF) ||
                   (val >= 0xAC00 && val <= 0xD7AF)
        }.count
        guard cjkCount > text.count / 3 else { return text }

        let lineLength = 22
        var result = ""
        var lineCount = 0

        for char in text {
            // Natural break points: punctuation, spaces
            let isBreakable = "，。！？、；：\n ".contains(char)
            result.append(char)
            lineCount += 1

            if isBreakable {
                // After punctuation, reset counter (natural break)
                if lineCount >= lineLength - 5 {
                    result.append("\n")
                    lineCount = 0
                }
            } else if lineCount >= lineLength {
                result.append("\n")
                lineCount = 0
            }
        }
        return result.trimmingCharacters(in: .newlines)
    }

    private func languageColorForCode(_ code: String) -> Color {
        switch code {
        case "en": return .blue
        case "zh": return .red
        case "ja": return .pink
        case "ko": return .indigo
        case "es": return .orange
        case "fr": return .cyan
        case "de": return .brown
        case "pt": return .teal
        case "ru": return .purple
        case "ar": return .green
        case "hi": return .orange
        case "it": return .red
        case "nl": return .orange
        case "tr": return .red
        case "th": return .blue
        case "vi": return .red
        default: return .purple
        }
    }
}
