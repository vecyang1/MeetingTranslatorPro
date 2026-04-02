import Foundation

/// Tracks API usage costs across all engines
@MainActor
final class CostTracker: ObservableObject {
    @Published var totalCost: Double = 0.0
    @Published var sessionCost: Double = 0.0
    @Published var logEntries: [CostLogEntry] = []

    struct CostLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let engine: String
        let operation: String
        let audioDuration: Double  // seconds
        let inputTokens: Int
        let outputTokens: Int
        let cost: Double
    }

    // MARK: - Pricing (per unit, as of 2026-04)

    // OpenAI Whisper: $0.006 per minute of audio
    private let whisperPricePerMinute: Double = 0.006

    // OpenAI GPT-4o-mini: $0.15 per 1M input tokens, $0.60 per 1M output tokens
    private let gpt4oMiniInputPer1M: Double = 0.15
    private let gpt4oMiniOutputPer1M: Double = 0.60

    // Gemini 2.5 Flash: $0.15 per 1M input tokens, $0.60 per 1M output tokens (text)
    // Audio input: ~32 tokens per second of audio
    private let geminiFlashInputPer1M: Double = 0.15
    private let geminiFlashOutputPer1M: Double = 0.60
    private let geminiFlashAudioTokensPerSecond: Double = 32.0

    // Gemini 3.1 Flash Live: $0.20 per 1M input tokens, $0.80 per 1M output tokens
    // Audio input: ~32 tokens per second
    private let geminiLiveInputPer1M: Double = 0.20
    private let geminiLiveOutputPer1M: Double = 0.80
    private let geminiLiveAudioTokensPerSecond: Double = 32.0

    private let persistKey = "com.meetingtranslator.totalcost"

    init() {
        totalCost = UserDefaults.standard.double(forKey: persistKey)
    }

    func resetSession() {
        sessionCost = 0.0
        logEntries.removeAll()
    }

    func resetTotal() {
        totalCost = 0.0
        sessionCost = 0.0
        logEntries.removeAll()
        UserDefaults.standard.set(0.0, forKey: persistKey)
    }

    // MARK: - Log Methods

    func logWhisperTranscription(audioDurationSeconds: Double) {
        let cost = (audioDurationSeconds / 60.0) * whisperPricePerMinute
        addEntry(engine: "OpenAI Whisper", operation: "Transcription",
                 audioDuration: audioDurationSeconds, inputTokens: 0, outputTokens: 0, cost: cost)
    }

    func logGPTTranslation(inputTokens: Int, outputTokens: Int) {
        let cost = (Double(inputTokens) / 1_000_000.0) * gpt4oMiniInputPer1M
                 + (Double(outputTokens) / 1_000_000.0) * gpt4oMiniOutputPer1M
        addEntry(engine: "GPT-4o-mini", operation: "Translation",
                 audioDuration: 0, inputTokens: inputTokens, outputTokens: outputTokens, cost: cost)
    }

    func logGeminiFlash(audioDurationSeconds: Double, outputTokens: Int) {
        let inputTokens = Int(audioDurationSeconds * geminiFlashAudioTokensPerSecond) + 50 // +50 for prompt
        let cost = (Double(inputTokens) / 1_000_000.0) * geminiFlashInputPer1M
                 + (Double(outputTokens) / 1_000_000.0) * geminiFlashOutputPer1M
        addEntry(engine: "Gemini 2.5 Flash", operation: "Transcribe+Translate",
                 audioDuration: audioDurationSeconds, inputTokens: inputTokens, outputTokens: outputTokens, cost: cost)
    }

    func logGeminiLive(audioDurationSeconds: Double, outputTokens: Int) {
        let inputTokens = Int(audioDurationSeconds * geminiLiveAudioTokensPerSecond) + 50
        let cost = (Double(inputTokens) / 1_000_000.0) * geminiLiveInputPer1M
                 + (Double(outputTokens) / 1_000_000.0) * geminiLiveOutputPer1M
        addEntry(engine: "Gemini 3.1 Flash Live", operation: "Stream Transcribe+Translate",
                 audioDuration: audioDurationSeconds, inputTokens: inputTokens, outputTokens: outputTokens, cost: cost)
    }

    private func addEntry(engine: String, operation: String, audioDuration: Double, inputTokens: Int, outputTokens: Int, cost: Double) {
        let entry = CostLogEntry(
            timestamp: Date(),
            engine: engine,
            operation: operation,
            audioDuration: audioDuration,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cost: cost
        )
        logEntries.append(entry)
        sessionCost += cost
        totalCost += cost
        UserDefaults.standard.set(totalCost, forKey: persistKey)
    }

    // MARK: - Formatted Strings

    var sessionCostFormatted: String {
        String(format: "$%.4f", sessionCost)
    }

    var totalCostFormatted: String {
        String(format: "$%.4f", totalCost)
    }

    func exportLog() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        var output = "API Cost Log\n"
        output += String(repeating: "=", count: 60) + "\n"
        output += "Session cost: \(sessionCostFormatted)\n"
        output += "Total cost (all time): \(totalCostFormatted)\n\n"

        for entry in logEntries {
            output += "[\(df.string(from: entry.timestamp))] \(entry.engine) — \(entry.operation)\n"
            if entry.audioDuration > 0 {
                output += "  Audio: \(String(format: "%.1f", entry.audioDuration))s"
            }
            if entry.inputTokens > 0 || entry.outputTokens > 0 {
                output += "  Tokens: \(entry.inputTokens) in / \(entry.outputTokens) out"
            }
            output += "  Cost: $\(String(format: "%.6f", entry.cost))\n"
        }
        return output
    }
}
