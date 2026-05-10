import Foundation
import SwiftUI
import Combine

/// Central application state manager — orchestrates audio capture, transcription, and translation
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State
    @Published var entries: [TranscriptionEntry] = []
    @Published var isRecording = false
    @Published var isMicEnabled = true
    @Published var isSystemAudioEnabled = true
    @Published var micLevel: Float = 0.0
    @Published var systemLevel: Float = 0.0
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published var targetLanguage: SupportedLanguage = .english
    @Published var apiKey: String = ""
    @Published var googleAPIKey: String = ""
    @Published var processingCount: Int = 0
    @Published var selectedEngine: TranscriptionEngine = .openAI
    @Published var showTranslations: Bool = true
    @Published var isGeminiLiveConnected: Bool = false
    @Published var realtimeCaptionLatency: RealtimeCaptionLatencyPreset = .balanced
    @Published var realtimeReasoningEffort: RealtimeReasoningEffort = .low
    @Published var realtimeTranslatedAudioPlayback: Bool = false
    @Published var realtimeAutomaticFallback: Bool = true
    @Published var openAIRealtimeState: RealtimeSessionState = .disconnected
    @Published var activeRealtimeMode: RealtimeRouteMode?

    // MARK: - Recording Timer
    @Published var recordingElapsedSeconds: Int = 0
    private var recordingStartDate: Date?
    private var recordingTimer: Task<Void, Never>?

    // MARK: - Pipeline Timing Settings (user-configurable)
    /// Fast draft interval in seconds (Layer 1). Default 3s.
    @Published var fastInterval: Double = 3.0
    /// Stitch pass interval in seconds (Layer 2, OpenAI). Default 15s.
    @Published var stitchInterval: Double = 15.0
    /// Gemini quality pass interval in seconds (Layer 2, Gemini Flash). Default 12s.
    @Published var geminiQualityInterval: Double = 12.0
    /// RMS noise gate threshold (0.0–1.0). Chunks below this are skipped.
    /// Default 0.003 — very conservative, only skips near-silence.
    @Published var noiseGateThreshold: Double = 0.003

    // MARK: - Managers & Services
    let micManager = MicrophoneManager()
    let systemAudioManager = SystemAudioManager()
    let costTracker = CostTracker()
    private var whisperService: WhisperService
    private var translationService: TranslationService
    private var geminiFlashService: GeminiFlashService
    private var geminiLiveService: GeminiLiveService
    private let realtimeCoordinator = OpenAIRealtimeCoordinator()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Pipeline Buffers
    private var fastBuffer = Data()
    private var stitchBuffer = Data()
    private var geminiQualityBuffer = Data()
    private var overlapTailData = Data()
    private let overlapTailBytes = Int(1.5 * 16000 * 2)  // 1.5s at 16kHz 16-bit

    /// Maximum buffer size: ~60s of audio at 16kHz 16-bit mono = ~1.92MB
    /// Prevents unbounded memory growth during long sessions
    private let maxBufferBytes = Int(60 * 16000 * 2)

    /// Maximum entries to keep in memory — older confirmed entries are trimmed
    private let maxEntries = 500

    /// Realtime API items are transport chunks. Merge nearby final chunks into readable dialog rows.
    private let realtimeUtteranceMaxDurationSeconds: TimeInterval = 8.0
    private let realtimeUtteranceMaxCharacters = 240

    /// Consecutive error counter for circuit-breaker pattern
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 5

    /// Gemini Live auto-reconnect tracking
    private var geminiLiveReconnectAttempts = 0
    private let maxGeminiLiveReconnectAttempts = 5

    // MARK: - Pipeline Timers
    private var fastTimer: Task<Void, Never>?
    private var stitchTimer: Task<Void, Never>?
    private var geminiQualityTimer: Task<Void, Never>?

    // MARK: - Stitch Context
    private var lastConfirmedText: String = ""
    private var lastConfirmedTranslation: String? = nil
    private var lastConfirmedLanguage: String? = nil
    private var draftEntryIDs: Set<UUID> = []
    private var stitchWindowStart: Date = Date()

    /// Input languages the user expects speakers to use.
    /// Empty = auto-detect all. Single = strongest Whisper hint. Multiple = prompt hint.
    @Published var inputLanguages: Set<SupportedLanguage> = []

    // MARK: - Persistence Keys
    private let apiKeyKey = "com.meetingtranslator.apikey"
    private let googleAPIKeyKey = "com.meetingtranslator.googleapikey"
    private let targetLangKey = "com.meetingtranslator.targetlang"
    private let engineKey = "com.meetingtranslator.engine"
    private let showTranslationsKey = "com.meetingtranslator.showtranslations"
    private let fastIntervalKey = "com.meetingtranslator.fastinterval"
    private let stitchIntervalKey = "com.meetingtranslator.stitchinterval"
    private let geminiQualityIntervalKey = "com.meetingtranslator.geminiquality"
    private let noiseGateKey = "com.meetingtranslator.noisegate"
    private let inputLanguagesKey = "com.meetingtranslator.inputlanguages"
    private let realtimeCaptionLatencyKey = "com.meetingtranslator.realtime.captionlatency"
    private let realtimeReasoningEffortKey = "com.meetingtranslator.realtime.reasoningeffort"
    private let realtimeTranslatedAudioPlaybackKey = "com.meetingtranslator.realtime.translatedaudioplayback"
    private let realtimeAutomaticFallbackKey = "com.meetingtranslator.realtime.automaticfallback"

    // MARK: - Hallucination Detection

    private let hallucinationExactSet: Set<String> = [
        "you", "bye", "bye.", "so", "hmm", "uh", "um", "ah", "ok", "okay",
        "subtitle", "subtitles", "subscribe",
        "like and subscribe", "please subscribe",
        "ご視聴ありがとうございました", "ご視聴ありがとうございます",
        "お疲れ様でした", "おやすみなさい",
        "谢谢观看", "感谢观看", "请订阅", "字幕",
        "시청해주셔서 감사합니다",
        "...", "..", "."
    ]

    private let hallucinationPrefixSet: [String] = [
        "thank you for watching", "thanks for watching",
        "please subscribe", "like and subscribe",
        "subtitles by", "captions by",
        "整理&字幕", "字幕制作", "字幕组",
        "敬请期待", "敬请关注",
        "沛队字幕", "字幕by"
    ]

    private func isHallucination(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // Too short
        if trimmed.count < 2 { return true }

        // Exact match blocklist
        if hallucinationExactSet.contains(lower) { return true }

        // Realtime speech models can emit tiny acronym-like debris from code-switched words
        // (for example "P P" while hearing "GPT"). Do not let those fragments become rows.
        let words = tokenize(trimmed)
        if words.count >= 2 && words.count <= 3 && words.allSatisfy(isSingleLatinLetter) {
            return true
        }

        // Prefix blocklist
        for prefix in hallucinationPrefixSet {
            if lower.hasPrefix(prefix.lowercased()) { return true }
        }

        // Must have actual content characters
        let hasContent = trimmed.unicodeScalars.contains {
            CharacterSet.alphanumerics.contains($0) ||
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3040 && $0.value <= 0x30FF)
        }
        if !hasContent { return true }

        // --- Repeated character detection ---
        let chars = Array(trimmed.unicodeScalars).filter { $0.value != 32 && $0.value != 12288 }
        if chars.count > 8 {
            let uniqueChars = Set(chars.map { $0.value })
            // All same character
            if uniqueChars.count == 1 { return true }
            // Almost all same character (>90% one char)
            if chars.count > 20 {
                let maxFreq = uniqueChars.map { v in chars.filter { $0.value == v }.count }.max() ?? 0
                if Double(maxFreq) / Double(chars.count) > 0.85 { return true }
            }
        }

        // --- Repeated word/phrase detection ---
        // Split on spaces and CJK boundaries
        if words.count >= 4 {
            // Check if all words are the same
            let uniqueWords = Set(words)
            if uniqueWords.count == 1 { return true }

            // Check for repeating n-gram patterns (n=2,3,4)
            for n in 2...min(4, words.count / 2) {
                if hasRepeatingNgram(words: words, n: n, minRepeats: 3) { return true }
            }

            // Check for high repetition ratio (same word appears >50% of the time)
            if words.count >= 8 {
                let maxWordFreq = uniqueWords.map { w in words.filter { $0 == w }.count }.max() ?? 0
                if Double(maxWordFreq) / Double(words.count) > 0.5 { return true }
            }
        }

        return false
    }

    private func isSingleLatinLetter(_ token: String) -> Bool {
        guard token.count == 1, let scalar = token.unicodeScalars.first else { return false }
        return (scalar.value >= 0x41 && scalar.value <= 0x5A)
            || (scalar.value >= 0x61 && scalar.value <= 0x7A)
    }

    /// Tokenize text into words, treating CJK characters as individual tokens
    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var currentWord = ""
        for scalar in text.unicodeScalars {
            let v = scalar.value
            let isCJK = (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3040 && v <= 0x30FF) || (v >= 0xAC00 && v <= 0xD7AF)
            if isCJK {
                if !currentWord.isEmpty { tokens.append(currentWord); currentWord = "" }
                tokens.append(String(scalar))
            } else if v == 32 || v == 12288 || v == 44 || v == 12289 {
                // space, fullwidth space, comma, ideographic comma
                if !currentWord.isEmpty { tokens.append(currentWord); currentWord = "" }
            } else {
                currentWord.append(Character(scalar))
            }
        }
        if !currentWord.isEmpty { tokens.append(currentWord) }
        return tokens.filter { !$0.isEmpty }
    }

    /// Check if a sequence of words contains a repeating n-gram at least minRepeats times
    private func hasRepeatingNgram(words: [String], n: Int, minRepeats: Int) -> Bool {
        guard words.count >= n * minRepeats else { return false }
        for start in 0...(words.count - n) {
            let ngram = Array(words[start..<(start + n)])
            var count = 0
            var i = 0
            while i <= words.count - n {
                if Array(words[i..<(i + n)]) == ngram {
                    count += 1
                    i += n
                } else {
                    i += 1
                }
            }
            if count >= minRepeats { return true }
        }
        return false
    }

    // MARK: - Echo / Duplicate Suppression

    /// Maximum time window (seconds) to look back for duplicate entries
    private let echoDedupWindowSeconds: TimeInterval = 15.0

    /// Similarity threshold (0.0–1.0). Entries with similarity above this are considered duplicates.
    /// 0.70 = 70% character overlap — catches echo while allowing legitimately similar sentences.
    private let echoDedupThreshold: Double = 0.70

    /// Check if a new transcription text is a near-duplicate of any recent entry.
    /// Uses character-level bigram similarity (Dice coefficient) which is fast and language-agnostic.
    /// Returns true if the text should be dropped as an echo duplicate.
    private func isDuplicateOfRecent(
        _ text: String,
        within window: TimeInterval? = nil,
        excluding entryID: UUID? = nil,
        excludingEntryIDs: Set<UUID> = []
    ) -> Bool {
        let lookback = window ?? echoDedupWindowSeconds
        let cutoff = Date().addingTimeInterval(-lookback)
        let normalizedNew = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedNew.count >= 4 else { return false }  // Too short to judge

        let newBigrams = characterBigrams(normalizedNew)
        guard !newBigrams.isEmpty else { return false }

        // Check recent entries (walk backwards for efficiency)
        for entry in entries.reversed() {
            if let entryID, entry.id == entryID { continue }
            if excludingEntryIDs.contains(entry.id) { continue }
            // Stop once we're outside the time window
            if entry.timestamp < cutoff { break }

            let existing = entry.originalText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard existing.count >= 4 else { continue }

            let existingBigrams = characterBigrams(existing)
            let similarity = diceCoefficient(newBigrams, existingBigrams)
            if similarity >= echoDedupThreshold {
                return true
            }
        }
        return false
    }

    /// Generate character bigrams from a string (language-agnostic, works for CJK and Latin)
    private func characterBigrams(_ text: String) -> [String: Int] {
        let chars = Array(text)
        guard chars.count >= 2 else { return [:] }
        var bigrams: [String: Int] = [:]
        for i in 0..<(chars.count - 1) {
            let bg = String(chars[i]) + String(chars[i + 1])
            bigrams[bg, default: 0] += 1
        }
        return bigrams
    }

    /// Dice coefficient between two bigram frequency maps (0.0–1.0)
    private func diceCoefficient(_ a: [String: Int], _ b: [String: Int]) -> Double {
        let totalA = a.values.reduce(0, +)
        let totalB = b.values.reduce(0, +)
        guard totalA > 0, totalB > 0 else { return 0.0 }

        var intersection = 0
        for (bigram, countA) in a {
            if let countB = b[bigram] {
                intersection += min(countA, countB)
            }
        }
        return (2.0 * Double(intersection)) / Double(totalA + totalB)
    }

    // MARK: - RMS Energy Check

    /// Calculate RMS energy of PCM audio (16-bit signed, little-endian)
    /// Returns value in 0.0–1.0 range (normalized against Int16.max)
    private func rmsEnergy(of pcmData: Data) -> Double {
        guard pcmData.count >= 2 else { return 0.0 }
        var sumSquares: Double = 0.0
        let sampleCount = pcmData.count / 2
        pcmData.withUnsafeBytes { ptr in
            let samples = ptr.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let s = Double(samples[i]) / Double(Int16.max)
                sumSquares += s * s
            }
        }
        return sqrt(sumSquares / Double(sampleCount))
    }

    /// Returns true if audio chunk has enough energy to be worth processing
    private func hasEnoughEnergy(_ pcmData: Data) -> Bool {
        let rms = rmsEnergy(of: pcmData)
        return rms >= noiseGateThreshold
    }

    // MARK: - Same-Language Detection

    private func isSameLanguage(detected: String?, target: SupportedLanguage) -> Bool {
        guard let code = detected?.lowercased() else { return false }
        return target.allISOCodes.contains(code)
    }

    // MARK: - Context Helpers

    private func extractContext(from text: String, maxChars: Int = 224) -> String {
        if text.count <= maxChars { return text }
        let idx = text.index(text.endIndex, offsetBy: -maxChars)
        return String(text[idx...])
    }

    private func removeDuplicatePrefix(newText: String, previousText: String) -> String {
        guard !previousText.isEmpty, !newText.isEmpty else { return newText }
        let maxOverlap = min(previousText.count, newText.count, 60)
        for overlapLen in stride(from: maxOverlap, through: 8, by: -1) {
            let prevSuffix = String(previousText.suffix(overlapLen))
            if newText.hasPrefix(prevSuffix) {
                let trimmed = String(newText.dropFirst(overlapLen)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return newText
    }

    // MARK: - Init

    init() {
        let savedKey = UserDefaults.standard.string(forKey: apiKeyKey) ?? ""
        let savedGoogleKey = UserDefaults.standard.string(forKey: googleAPIKeyKey) ?? ""
        let savedLang = UserDefaults.standard.string(forKey: targetLangKey) ?? "English"
        let savedEngine = UserDefaults.standard.string(forKey: engineKey) ?? TranscriptionEngine.openAI.rawValue
        let savedShowTranslations = UserDefaults.standard.object(forKey: showTranslationsKey) as? Bool ?? true
        let savedFastInterval = UserDefaults.standard.object(forKey: fastIntervalKey) as? Double ?? 3.0
        let savedStitchInterval = UserDefaults.standard.object(forKey: stitchIntervalKey) as? Double ?? 15.0
        let savedGeminiQuality = UserDefaults.standard.object(forKey: geminiQualityIntervalKey) as? Double ?? 12.0
        let savedNoiseGate = UserDefaults.standard.object(forKey: noiseGateKey) as? Double ?? 0.003
        let savedInputLangs = UserDefaults.standard.stringArray(forKey: inputLanguagesKey) ?? []
        let restoredInputLangs = Set(savedInputLangs.compactMap { SupportedLanguage(rawValue: $0) })
        let savedRealtimeLatency = UserDefaults.standard.string(forKey: realtimeCaptionLatencyKey) ?? RealtimeCaptionLatencyPreset.balanced.rawValue
        let savedRealtimeReasoning = UserDefaults.standard.string(forKey: realtimeReasoningEffortKey) ?? RealtimeReasoningEffort.low.rawValue
        let savedRealtimeAudioPlayback = UserDefaults.standard.object(forKey: realtimeTranslatedAudioPlaybackKey) as? Bool ?? false
        let savedRealtimeFallback = UserDefaults.standard.object(forKey: realtimeAutomaticFallbackKey) as? Bool ?? true

        self.apiKey = savedKey
        self.googleAPIKey = savedGoogleKey
        self.targetLanguage = SupportedLanguage(rawValue: savedLang) ?? .english
        self.selectedEngine = TranscriptionEngine(rawValue: savedEngine) ?? .openAI
        self.showTranslations = savedShowTranslations
        self.fastInterval = savedFastInterval
        self.stitchInterval = savedStitchInterval
        self.geminiQualityInterval = savedGeminiQuality
        self.noiseGateThreshold = savedNoiseGate
        self.inputLanguages = restoredInputLangs
        self.realtimeCaptionLatency = RealtimeCaptionLatencyPreset(rawValue: savedRealtimeLatency) ?? .balanced
        self.realtimeReasoningEffort = RealtimeReasoningEffort(rawValue: savedRealtimeReasoning) ?? .low
        self.realtimeTranslatedAudioPlayback = savedRealtimeAudioPlayback
        self.realtimeAutomaticFallback = savedRealtimeFallback
        self.whisperService = WhisperService(apiKey: savedKey)
        self.translationService = TranslationService(apiKey: savedKey)
        self.geminiFlashService = GeminiFlashService(apiKey: savedGoogleKey)
        self.geminiLiveService = GeminiLiveService(apiKey: savedGoogleKey)

        setupBindings()
        setupGeminiLiveCallbacks()
        setupOpenAIRealtimeCallbacks()
    }

    private func setupBindings() {
        micManager.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$micLevel)

        systemAudioManager.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$systemLevel)

        micManager.onAudioChunkReady = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.routeAudioChunk(data, source: .microphone)
            }
        }

        systemAudioManager.onAudioChunkReady = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.routeAudioChunk(data, source: .system)
            }
        }
    }

    private func setupOpenAIRealtimeCallbacks() {
        realtimeCoordinator.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                await self?.handleOpenAIRealtimeEvent(event)
            }
        }
    }

    private func routeAudioChunk(_ data: Data, source: TranscriptionEntry.AudioSource) {
        switch selectedEngine {
        case .openAIRealtime:
            routeRealtimeAudioChunk(data, source: source)
        case .geminiLive:
            if isGeminiLiveConnected {
                geminiLiveService.sendAudio(data)
            } else if isRecording {
                // Auto-reconnect if disconnected during recording
                attemptGeminiLiveReconnect()
            }
        case .geminiFlash:
            fastBuffer.append(data)
            geminiQualityBuffer.append(data)
            // Cap buffer sizes to prevent unbounded memory growth
            capBufferIfNeeded(&fastBuffer)
            capBufferIfNeeded(&geminiQualityBuffer)
        case .openAI:
            fastBuffer.append(data)
            stitchBuffer.append(data)
            capBufferIfNeeded(&fastBuffer)
            capBufferIfNeeded(&stitchBuffer)
        }
    }

    /// Trim buffer to keep only the most recent audio if it exceeds the max
    private func capBufferIfNeeded(_ buffer: inout Data) {
        if buffer.count > maxBufferBytes {
            buffer = buffer.suffix(maxBufferBytes)
        }
    }

    /// Trim old confirmed entries to prevent unbounded memory growth
    private func trimEntriesIfNeeded() {
        guard entries.count > maxEntries else { return }
        let excess = entries.count - maxEntries
        // Remove oldest confirmed (non-draft) entries
        var removed = 0
        entries.removeAll { entry in
            guard removed < excess, !entry.isDraft else { return false }
            removed += 1
            return true
        }
    }

    /// Auto-reconnect Gemini Live with exponential backoff
    private func attemptGeminiLiveReconnect() {
        guard geminiLiveReconnectAttempts < maxGeminiLiveReconnectAttempts else {
            showError("Gemini Live: max reconnect attempts reached. Please restart.")
            return
        }
        geminiLiveReconnectAttempts += 1
        let delay = UInt64(pow(2.0, Double(geminiLiveReconnectAttempts))) * 1_000_000_000
        statusMessage = "Reconnecting Gemini Live (\(geminiLiveReconnectAttempts)/\(maxGeminiLiveReconnectAttempts))..."
        Task {
            try? await Task.sleep(nanoseconds: delay)
            guard self.isRecording, self.selectedEngine == .geminiLive, !self.isGeminiLiveConnected else { return }
            do {
                try await self.geminiLiveService.connect()
                self.geminiLiveReconnectAttempts = 0  // Reset on success
                self.statusMessage = "Listening..."
            } catch {
                self.showError("Reconnect failed: \(error.localizedDescription.prefix(40))")
            }
        }
    }

    private func setupGeminiLiveCallbacks() {
        geminiLiveService.onResult = { [weak self] result in
            Task { @MainActor [weak self] in
                await self?.handleGeminiLiveResult(result)
            }
        }
        geminiLiveService.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.showError("Live: \(error.localizedDescription.prefix(60))")
            }
        }
        geminiLiveService.onConnectionStateChanged = { [weak self] connected in
            Task { @MainActor [weak self] in
                self?.isGeminiLiveConnected = connected
                if !connected && self?.isRecording == true && self?.selectedEngine == .geminiLive {
                    self?.statusMessage = "Live disconnected. Reconnecting..."
                }
            }
        }
    }

    // MARK: - OpenAI Realtime

    private func startOpenAIRealtimeSessions() async {
        stopOpenAIRealtimeSessions()

        let sources = activeAudioSources()
        guard !sources.isEmpty else {
            showError("Enable at least one audio source.")
            return
        }

        let sameLanguage = specifiedInputMatchesTarget()
        openAIRealtimeState = .connecting
        statusMessage = "Connecting OpenAI Realtime..."

        do {
            let decision = try await realtimeCoordinator.start(
                apiKey: apiKey,
                sources: sources,
                showTranslations: shouldUseRealtimeTranslationSession(sameLanguage: sameLanguage),
                sameLanguage: sameLanguage,
                targetLanguageCode: targetLanguage.isoCode,
                languageHint: inputLanguages.count == 1 ? inputLanguages.first?.isoCode : nil,
                latencyPreset: realtimeCaptionLatency,
                reasoningEffort: realtimeReasoningEffort
            )
            activeRealtimeMode = decision.mode
            if isRecording {
                statusMessage = "Waiting for realtime session..."
            }
        } catch {
            showError("OpenAI Realtime unavailable. \(error.localizedDescription.prefix(60))")
            if realtimeAutomaticFallback {
                activateLegacyOpenAIFallback()
            }
            return
        }
    }

    private func stopOpenAIRealtimeSessions() {
        realtimeCoordinator.stop()
        activeRealtimeMode = nil
        openAIRealtimeState = .disconnected
    }

    private func routeRealtimeAudioChunk(_ data: Data, source: TranscriptionEntry.AudioSource) {
        guard hasEnoughEnergy(data) else { return }
        _ = realtimeCoordinator.sendAudio(data, source: source)
    }

    private func handleOpenAIRealtimeEvent(_ event: RealtimeAppEvent) async {
        switch event {
        case .sessionStateChanged(_, let state):
            openAIRealtimeState = state
            if isRecording { statusMessage = state.userMessage }
        case .recoverableError(_, let message, _):
            showError(message)
            if isRecording && realtimeAutomaticFallback {
                activateLegacyOpenAIFallback()
            }
        case .audioQueued(_, let mode, let audioDuration):
            switch mode {
            case .transcription:
                costTracker.logOpenAIRealtimeWhisper(audioDurationSeconds: audioDuration)
            case .translation:
                costTracker.logOpenAIRealtimeTranslate(audioDurationSeconds: audioDuration)
            case .agent:
                costTracker.logOpenAIRealtimeAgent(audioDurationSeconds: audioDuration, inputTokens: 0, outputTokens: 0)
            }
        case .usageUpdated(_, let mode, let audioDuration, let inputTokens, let outputTokens):
            switch mode {
            case .transcription:
                costTracker.logOpenAIRealtimeWhisper(audioDurationSeconds: audioDuration)
            case .translation:
                costTracker.logOpenAIRealtimeTranslate(audioDurationSeconds: audioDuration)
            case .agent:
                costTracker.logOpenAIRealtimeAgent(audioDurationSeconds: audioDuration, inputTokens: inputTokens, outputTokens: outputTokens)
            }
        case .translatedAudioChunk:
            // Text-first release: translated audio playback stays off by default.
            break
        case .partialTranscript, .finalTranscript, .partialTranslation, .finalTranslation:
            guard let reduced = realtimeCoordinator.reduce(event) else { return }
            if reduced.isFinal {
                await confirmRealtimeEntry(reduced)
            } else {
                upsertRealtimePartial(reduced)
            }
        }
    }

    private func upsertRealtimePartial(_ reduced: RealtimeReducedEntry) {
        if reduced.isTranslationOnly {
            let text = (reduced.translatedText ?? reduced.text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            if let idx = entries.firstIndex(where: { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }) {
                if entries[idx].detectedLanguage == targetLanguage.isoCode && entries[idx].translatedText == nil {
                    entries[idx].originalText = text
                } else {
                    entries[idx].translatedText = text
                }
                entries[idx].isTranslating = false
                entries[idx].isDraft = true
            } else {
                let entry = TranscriptionEntry(
                    timestamp: reduced.timestamp,
                    originalText: text,
                    translatedText: nil,
                    detectedLanguage: targetLanguage.isoCode,
                    isTranslating: false,
                    source: reduced.source,
                    speakerLabel: buildSpeakerLabel(source: reduced.source, language: targetLanguage.isoCode),
                    isDraft: true,
                    realtimeItemID: reduced.itemID
                )
                insertEntryChronologically(entry)
                trimEntriesIfNeeded()
            }
            return
        }

        let text = reduced.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let idx = entries.firstIndex(where: { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }) {
            entries[idx].originalText = text
            entries[idx].translatedText = reduced.translatedText ?? entries[idx].translatedText
            entries[idx].detectedLanguage = reduced.language ?? entries[idx].detectedLanguage
            entries[idx].isDraft = true
            return
        }

        let detected = reduced.language ?? detectLanguageFromText(text)
        let sameLanguage = isSameLanguage(detected: detected, target: targetLanguage)
        let entry = TranscriptionEntry(
            timestamp: reduced.timestamp,
            originalText: text,
            translatedText: reduced.translatedText,
            detectedLanguage: detected,
            isTranslating: showTranslations && !sameLanguage && activeRealtimeMode == .translation,
            source: reduced.source,
            speakerLabel: buildSpeakerLabel(source: reduced.source, language: detected),
            isDraft: true,
            realtimeItemID: reduced.itemID
        )
        insertEntryChronologically(entry)
        trimEntriesIfNeeded()
    }

    private func confirmRealtimeEntry(
        _ reduced: RealtimeReducedEntry,
        modeOverride: RealtimeRouteMode? = nil,
        applyDuplicatePrefix: Bool = true
    ) async {
        let realtimeMode = modeOverride ?? activeRealtimeMode

        if reduced.isTranslationOnly {
            let text = (reduced.translatedText ?? reduced.text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                removeRealtimeEntry(itemID: reduced.itemID, source: reduced.source)
                return
            }
            if let idx = entries.firstIndex(where: { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }) {
                if entries[idx].detectedLanguage == targetLanguage.isoCode && entries[idx].translatedText == nil {
                    entries[idx].originalText = text
                } else {
                    entries[idx].translatedText = text
                }
                entries[idx].isTranslating = false
                entries[idx].isDraft = false
            } else {
                let entry = TranscriptionEntry(
                    timestamp: reduced.timestamp,
                    originalText: text,
                    translatedText: nil,
                    detectedLanguage: targetLanguage.isoCode,
                    isTranslating: false,
                    source: reduced.source,
                    speakerLabel: buildSpeakerLabel(source: reduced.source, language: targetLanguage.isoCode),
                    isDraft: false,
                    realtimeItemID: reduced.itemID
                )
                insertEntryChronologically(entry)
            }
            lastConfirmedTranslation = text
            trimEntriesIfNeeded()
            return
        }

        let currentEntry = entries.first { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }
        let visibleDraftText = currentEntry?.isDraft == true
            ? currentEntry?.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        var text = reduced.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (text.isEmpty || isHallucination(text)),
           let visibleDraftText,
           !visibleDraftText.isEmpty,
           !isHallucination(visibleDraftText) {
            text = visibleDraftText
        }
        guard !text.isEmpty, !isHallucination(text) else {
            removeRealtimeEntry(itemID: reduced.itemID, source: reduced.source)
            return
        }

        if applyDuplicatePrefix && !lastConfirmedText.isEmpty {
            text = removeDuplicatePrefix(newText: text, previousText: lastConfirmedText)
            guard !text.isEmpty else {
                removeRealtimeEntry(itemID: reduced.itemID, source: reduced.source)
                return
            }
        }

        let detected = reduced.language ?? detectLanguageFromText(text)
        let mergeTarget = realtimeMode == .translation ? nil : realtimeMergeCandidate(
            reduced: reduced,
            text: text,
            detected: detected
        )
        let existingID = currentEntry?.id
        let duplicateExclusions = Set([existingID, mergeTarget?.id].compactMap { $0 })
        guard !isDuplicateOfRecent(text, excludingEntryIDs: duplicateExclusions) else {
            removeRealtimeEntry(itemID: reduced.itemID, source: reduced.source)
            return
        }

        var finalText = text
        var translatedPrefix: String?
        let mergeTargetID = mergeTarget?.id
        if let mergeTarget {
            guard let merged = RealtimeUtteranceMerger.mergedText(
                previous: mergeTarget.originalText,
                next: text
            ) else {
                removeRealtimeEntry(itemID: reduced.itemID, source: reduced.source)
                return
            }
            finalText = merged
            translatedPrefix = mergeTarget.translatedText
        }

        let sameLanguage = isSameLanguage(detected: detected, target: targetLanguage)
        var translatedSegment = sameLanguage || !showTranslations ? nil : reduced.translatedText
        if translatedSegment == nil && showTranslations && !sameLanguage && realtimeMode != .translation {
            do {
                statusMessage = "Translating..."
                translatedSegment = try await translationService.translate(text: text, to: targetLanguage.rawValue)
            } catch {
                showError("Translation failed: \(error.localizedDescription.prefix(60))")
            }
        }
        let translated = mergeTranslations(previous: translatedPrefix, next: translatedSegment)

        if let mergeTargetID, let mergeIndex = entries.firstIndex(where: { $0.id == mergeTargetID }) {
            let keptEntryID = entries[mergeIndex].id
            entries[mergeIndex].originalText = finalText
            entries[mergeIndex].translatedText = translated
            entries[mergeIndex].detectedLanguage = detected
            entries[mergeIndex].isTranslating = realtimeMode == .translation && translated == nil && showTranslations && !sameLanguage
            entries[mergeIndex].speakerLabel = buildSpeakerLabel(source: reduced.source, language: detected)
            entries[mergeIndex].isDraft = false
            entries[mergeIndex].isQualityResult = false
            entries.removeAll {
                $0.id != keptEntryID && $0.realtimeItemID == reduced.itemID && $0.source == reduced.source
            }
        } else if let idx = entries.firstIndex(where: { $0.realtimeItemID == reduced.itemID && $0.source == reduced.source }) {
            entries[idx].originalText = finalText
            entries[idx].translatedText = translated
            entries[idx].detectedLanguage = detected
            entries[idx].isTranslating = realtimeMode == .translation && translated == nil && showTranslations && !sameLanguage
            entries[idx].speakerLabel = buildSpeakerLabel(source: reduced.source, language: detected)
            entries[idx].isDraft = false
            entries[idx].isQualityResult = false
        } else {
            let entry = TranscriptionEntry(
                timestamp: reduced.timestamp,
                originalText: finalText,
                translatedText: translated,
                detectedLanguage: detected,
                isTranslating: realtimeMode == .translation && translated == nil && showTranslations && !sameLanguage,
                source: reduced.source,
                speakerLabel: buildSpeakerLabel(source: reduced.source, language: detected),
                isDraft: false,
                realtimeItemID: reduced.itemID
            )
            insertEntryChronologically(entry)
        }

        lastConfirmedText = finalText
        lastConfirmedTranslation = translated
        lastConfirmedLanguage = detected
        markProcessingSuccess()
        trimEntriesIfNeeded()
        if isRecording { statusMessage = openAIRealtimeState.userMessage }
    }

    private func realtimeMergeCandidate(
        reduced: RealtimeReducedEntry,
        text: String,
        detected: String?
    ) -> TranscriptionEntry? {
        guard let idx = entries.indices.reversed().first(where: { idx in
            let entry = entries[idx]
            guard entry.realtimeItemID != reduced.itemID else { return false }
            return RealtimeUtteranceMerger.canMerge(
                previous: entry,
                nextText: text,
                nextLanguage: detected,
                nextSource: reduced.source,
                nextTimestamp: reduced.timestamp,
                maxDuration: realtimeUtteranceMaxDurationSeconds,
                maxCharacters: realtimeUtteranceMaxCharacters
            )
        }) else { return nil }
        return entries[idx]
    }

    private func mergeTranslations(previous: String?, next: String?) -> String? {
        guard let next, !next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return previous
        }
        guard let previous, !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return next
        }
        return RealtimeUtteranceMerger.mergedText(previous: previous, next: next) ?? previous
    }

    private func removeRealtimeEntry(itemID: String, source: TranscriptionEntry.AudioSource) {
        entries.removeAll { $0.realtimeItemID == itemID && $0.source == source }
    }

    private func activeAudioSources() -> [TranscriptionEntry.AudioSource] {
        var sources: [TranscriptionEntry.AudioSource] = []
        if isMicEnabled { sources.append(.microphone) }
        if isSystemAudioEnabled { sources.append(.system) }
        return sources
    }

    private func specifiedInputMatchesTarget() -> Bool {
        guard inputLanguages.count == 1, let input = inputLanguages.first else { return false }
        return isSameLanguage(detected: input.isoCode, target: targetLanguage)
    }

    private func shouldUseRealtimeTranslationSession(sameLanguage: Bool) -> Bool {
        showTranslations && !sameLanguage && inputLanguages.count == 1 && realtimeTranslatedAudioPlayback
    }

    private func activateLegacyOpenAIFallback() {
        guard selectedEngine == .openAIRealtime, realtimeAutomaticFallback else { return }
        stopOpenAIRealtimeSessions()
        stopPipelineTimers()
        selectedEngine = .openAI
        configureAudioCaptureForSelectedEngine()
        fastBuffer = Data()
        stitchBuffer = Data()
        statusMessage = "Switched to legacy OpenAI fallback"
        if isRecording {
            startPipelineTimers()
        }
    }

    // MARK: - Public Actions

    func checkPermissions() {
        systemAudioManager.checkAndRequestPermission()
        if systemAudioManager.permissionStatus == .denied && isSystemAudioEnabled {
            systemAudioManager.openScreenRecordingSettings()
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(apiKey, forKey: apiKeyKey)
        UserDefaults.standard.set(googleAPIKey, forKey: googleAPIKeyKey)
        UserDefaults.standard.set(targetLanguage.rawValue, forKey: targetLangKey)
        UserDefaults.standard.set(selectedEngine.rawValue, forKey: engineKey)
        UserDefaults.standard.set(showTranslations, forKey: showTranslationsKey)
        UserDefaults.standard.set(fastInterval, forKey: fastIntervalKey)
        UserDefaults.standard.set(stitchInterval, forKey: stitchIntervalKey)
        UserDefaults.standard.set(geminiQualityInterval, forKey: geminiQualityIntervalKey)
        UserDefaults.standard.set(noiseGateThreshold, forKey: noiseGateKey)
        UserDefaults.standard.set(inputLanguages.map { $0.rawValue }, forKey: inputLanguagesKey)
        UserDefaults.standard.set(realtimeCaptionLatency.rawValue, forKey: realtimeCaptionLatencyKey)
        UserDefaults.standard.set(realtimeReasoningEffort.rawValue, forKey: realtimeReasoningEffortKey)
        UserDefaults.standard.set(realtimeTranslatedAudioPlayback, forKey: realtimeTranslatedAudioPlaybackKey)
        UserDefaults.standard.set(realtimeAutomaticFallback, forKey: realtimeAutomaticFallbackKey)
        whisperService.updateAPIKey(apiKey)
        translationService.updateAPIKey(apiKey)
        geminiFlashService.updateAPIKey(googleAPIKey)
        geminiLiveService.updateAPIKey(googleAPIKey)
        geminiLiveService.updateTargetLanguage(targetLanguage.rawValue, isoCode: targetLanguage.isoCode)
        realtimeCoordinator.updateAPIKey(apiKey)
        if isRecording {
            configureAudioCaptureForSelectedEngine()
        }
        if selectedEngine == .openAIRealtime,
           activeRealtimeMode == .translation,
           !shouldUseRealtimeTranslationSession(sameLanguage: specifiedInputMatchesTarget()) {
            stopOpenAIRealtimeSessions()
        }
        Task { await refreshOpenAIRealtimeRoutingIfNeeded() }
    }

    func setShowTranslations(_ enabled: Bool) {
        guard showTranslations != enabled else { return }
        showTranslations = enabled
        if selectedEngine == .openAIRealtime && activeRealtimeMode == .translation {
            stopOpenAIRealtimeSessions()
            statusMessage = enabled ? "Restarting realtime translation..." : "Translation off"
        }
        saveSettings()
    }

    private func refreshOpenAIRealtimeRoutingIfNeeded() async {
        guard isRecording, selectedEngine == .openAIRealtime else { return }
        await startOpenAIRealtimeSessions()
    }

    func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    func startRecording() {
        if selectedEngine.requiresOpenAIKey && apiKey.isEmpty {
            errorMessage = "Please configure your OpenAI API key in Settings."
            return
        }
        if selectedEngine.requiresGoogleKey && googleAPIKey.isEmpty {
            errorMessage = "Please configure your Google API key in Settings."
            return
        }

        errorMessage = nil
        processingCount = 0
        costTracker.resetSession()
        resetPipelineState()

        configureAudioCaptureForSelectedEngine()

        if selectedEngine == .geminiLive {
            Task {
                do {
                    geminiLiveService.updateTargetLanguage(targetLanguage.rawValue, isoCode: targetLanguage.isoCode)
                    try await geminiLiveService.connect()
                } catch {
                    showError("Gemini Live connection failed: \(error.localizedDescription.prefix(60))")
                }
            }
        } else if selectedEngine == .openAIRealtime {
            Task {
                await startOpenAIRealtimeSessions()
            }
        }

        if isMicEnabled {
            do { try micManager.startCapturing() }
            catch { showError("Mic error: \(error.localizedDescription)") }
        }

        if isSystemAudioEnabled {
            Task {
                do {
                    try await systemAudioManager.startCapturing()
                } catch let error as SystemAudioError {
                    if case .permissionDenied = error {
                        systemAudioManager.openScreenRecordingSettings()
                        showError("Screen Recording permission needed. Opening Settings...")
                    } else {
                        showError(error.localizedDescription)
                    }
                } catch {
                    let errStr = error.localizedDescription
                    if errStr.contains("TCC") || errStr.contains("declined") || errStr.contains("permission") {
                        systemAudioManager.openScreenRecordingSettings()
                    } else {
                        showError("System audio: \(errStr)")
                    }
                }
            }
        }

        isRecording = true
        statusMessage = "Listening..."
        startRecordingTimer()
        startPipelineTimers()
    }

    func stopRecording() {
        let engineAtStop = selectedEngine
        let realtimeModeAtStop = activeRealtimeMode

        micManager.stopCapturing()
        Task { await systemAudioManager.stopCapturing() }
        stopPipelineTimers()

        if engineAtStop == .geminiLive { geminiLiveService.disconnect() }
        if engineAtStop == .openAIRealtime { stopOpenAIRealtimeSessions() }

        isRecording = false
        stopRecordingTimer()

        // Process any remaining audio in the quality buffers.
        let remainingStitch = stitchBuffer
        let remainingGemini = geminiQualityBuffer
        fastBuffer = Data(); stitchBuffer = Data(); geminiQualityBuffer = Data()

        if processingCount > 0 {
            statusMessage = "Finishing \(processingCount) pending..."
        } else {
            statusMessage = "Ready"
        }

        // Run final stitch/quality pass on remaining audio
        Task {
            await self.finalizeDraftEntries(realtimeMode: realtimeModeAtStop)

            if engineAtStop == .openAI && remainingStitch.count > Int(16000 * 2) {
                await self.processStitchLayerWithData(remainingStitch)
            } else if engineAtStop == .geminiFlash && remainingGemini.count > Int(16000 * 2) {
                await self.processGeminiQualityLayerWithData(remainingGemini)
            }
            if !self.isRecording {
                self.statusMessage = "Ready"
                self.processingCount = 0
            }
        }
    }

    /// Promote all remaining draft entries to confirmed (remove draft badge)
    private func finalizeDraftEntries(realtimeMode: RealtimeRouteMode?) async {
        let realtimeFinals = RealtimeDraftFinalizer.collectRealtimeDraftFinals(entries: &entries, draftEntryIDs: &draftEntryIDs) { entry in
            let text = entry.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty || isHallucination(text)
        }
        for reduced in realtimeFinals {
            await confirmRealtimeEntry(reduced, modeOverride: realtimeMode, applyDuplicatePrefix: false)
        }
    }

    func clearEntries() {
        entries.removeAll()
        resetPipelineState()
    }

    func exportTranscript() -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm:ss"
        var out = "Meeting Transcript — \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))\n"
        out += "Engine: \(selectedEngine.rawValue)\n"
        out += String(repeating: "=", count: 60) + "\n\n"
        for entry in entries where !entry.isDraft {
            let time = df.string(from: entry.timestamp)
            let speaker = entry.speakerLabel ?? entry.source.rawValue
            let lang = entry.languageName ?? entry.detectedLanguage?.uppercased() ?? "??"
            out += "[\(time)] [\(speaker)] [\(lang)]\n"
            out += "  Original:   \(entry.originalText)\n"
            if let t = entry.translatedText { out += "  Translated: \(t)\n" }
            out += "\n"
        }
        out += "\n" + costTracker.exportLog()
        return out
    }

    // MARK: - Recording Timer

    private func startRecordingTimer() {
        recordingStartDate = Date()
        recordingElapsedSeconds = 0
        recordingTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self = self, self.isRecording else { break }
                if let start = self.recordingStartDate {
                    self.recordingElapsedSeconds = Int(Date().timeIntervalSince(start))
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.cancel()
        recordingTimer = nil
    }

    /// Format elapsed seconds as HH:MM:SS or MM:SS
    var recordingTimeFormatted: String {
        let h = recordingElapsedSeconds / 3600
        let m = (recordingElapsedSeconds % 3600) / 60
        let s = recordingElapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Pipeline State

    private func resetPipelineState() {
        fastBuffer = Data()
        stitchBuffer = Data()
        geminiQualityBuffer = Data()
        overlapTailData = Data()
        lastConfirmedText = ""
        lastConfirmedTranslation = nil
        lastConfirmedLanguage = nil
        draftEntryIDs = []
        stitchWindowStart = Date()
    }

    private func configureAudioCaptureForSelectedEngine() {
        let realtime = selectedEngine == .openAIRealtime
        let chunkDuration = realtime ? realtimeCaptionLatency.realtimeCaptureChunkDuration : 1.0
        micManager.configureChunking(chunkDuration: chunkDuration, continuous: realtime)
        systemAudioManager.configureChunking(chunkDuration: chunkDuration, continuous: realtime)
    }

    private func stopPipelineTimers() {
        fastTimer?.cancel(); fastTimer = nil
        stitchTimer?.cancel(); stitchTimer = nil
        geminiQualityTimer?.cancel(); geminiQualityTimer = nil
    }

    private func startPipelineTimers() {
        stopPipelineTimers()

        // Layer 1: Fast draft
        fastTimer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let interval = self.selectedEngine == .openAIRealtime ? 1.0 : self.fastInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard self.isRecording else { break }
                if self.selectedEngine != .openAIRealtime {
                    await self.processFastLayer()
                }
            }
        }

        switch selectedEngine {
        case .openAIRealtime:
            break
        case .openAI:
            stitchTimer = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.stitchInterval * 0.5 * 1_000_000_000))
                while !Task.isCancelled {
                    guard self.isRecording else { break }
                    await self.processStitchLayer()
                    try? await Task.sleep(nanoseconds: UInt64(self.stitchInterval * 1_000_000_000))
                }
            }
        case .geminiFlash:
            geminiQualityTimer = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: UInt64(6.0 * 1_000_000_000))
                while !Task.isCancelled {
                    guard self.isRecording else { break }
                    await self.processGeminiQualityLayer()
                    try? await Task.sleep(nanoseconds: UInt64(self.geminiQualityInterval * 1_000_000_000))
                }
            }
        case .geminiLive:
            break
        }
    }

    // MARK: - Layer 1: Fast Draft

    private func processFastLayer() async {
        let minBytes = Int(fastInterval * 16000 * 2 * 0.4)
        guard fastBuffer.count >= minBytes else { return }

        let audioWithOverlap: Data = overlapTailData.isEmpty ? fastBuffer : overlapTailData + fastBuffer

        if fastBuffer.count >= overlapTailBytes {
            overlapTailData = fastBuffer.suffix(overlapTailBytes)
        }

        let capturedBuffer = fastBuffer
        fastBuffer = Data()

        // Noise gate — skip if too quiet (very conservative default)
        guard hasEnoughEnergy(capturedBuffer) else {
            return
        }

        let source: TranscriptionEntry.AudioSource = isMicEnabled ? .microphone : .system

        switch selectedEngine {
        case .openAIRealtime:
            break
        case .openAI:
            await processOpenAIFast(audio: audioWithOverlap, rawChunk: capturedBuffer, source: source)
        case .geminiFlash:
            await processGeminiFast(audio: audioWithOverlap, source: source)
        case .geminiLive:
            break
        }
    }

    // MARK: - Layer 1a: OpenAI Fast Draft

    private func processOpenAIFast(audio: Data, rawChunk: Data, source: TranscriptionEntry.AudioSource) async {
        let duration = Double(rawChunk.count) / (16000.0 * 2.0)
        processingCount += 1
        defer {
            processingCount -= 1
            if processingCount <= 0 { processingCount = 0; statusMessage = isRecording ? "Listening..." : "Ready" }
        }
        statusMessage = "Transcribing..."

        do {
            let contextPrompt = extractContext(from: lastConfirmedText)
            let langCodes = inputLanguages.map { $0.isoCode }
            let result = try await whisperService.transcribe(
                pcmData: audio,
                prompt: contextPrompt.isEmpty ? nil : contextPrompt,
                inputLanguageCodes: langCodes
            )
            costTracker.logWhisperTranscription(audioDurationSeconds: duration)

            var text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !isHallucination(text) else { return }

            if !overlapTailData.isEmpty && !lastConfirmedText.isEmpty {
                text = removeDuplicatePrefix(newText: text, previousText: lastConfirmedText)
                guard !text.isEmpty else { return }
            }

            // Echo suppression — drop if near-duplicate of a recent entry
            guard !isDuplicateOfRecent(text) else { return }

            let sameLanguage = isSameLanguage(detected: result.language, target: targetLanguage)
            let needsTranslation = !sameLanguage && showTranslations
            let speakerLabel = buildSpeakerLabel(source: source, language: result.language)

            let entry = TranscriptionEntry(
                originalText: text,
                detectedLanguage: result.language,
                isTranslating: needsTranslation,
                source: source,
                speakerLabel: speakerLabel,
                isDraft: true
            )
            entries.append(entry)
            draftEntryIDs.insert(entry.id)
            trimEntriesIfNeeded()
            markProcessingSuccess()

            if needsTranslation {
                do {
                    let translated = try await translationService.translate(text: text, to: targetLanguage.rawValue)
                    let inputTokens = text.count / 4 + 50
                    let outputTokens = translated.count / 4
                    costTracker.logGPTTranslation(inputTokens: inputTokens, outputTokens: outputTokens)
                    if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                        entries[idx].translatedText = translated
                        entries[idx].isTranslating = false
                    }
                } catch {
                    if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                        entries[idx].isTranslating = false
                    }
                }
            } else {
                // Same language or translations disabled — no API call needed
                if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[idx].isTranslating = false
                }
            }
        } catch {
            handleProcessingError(error)
        }
    }

    // MARK: - Layer 2: OpenAI Stitch Pass

    private func processStitchLayer() async {
        let capturedBuffer = stitchBuffer
        stitchBuffer = Data()
        await processStitchLayerWithData(capturedBuffer)
    }

    private func processStitchLayerWithData(_ audio: Data) async {
        // Require at least 1 second of audio (very lenient)
        let minBytes = Int(16000 * 2 * 1)
        guard audio.count >= minBytes else { return }

        // Check if there's enough energy in the stitch buffer to bother
        guard hasEnoughEnergy(audio) else {
            removeDraftEntriesInWindow(windowStart: stitchWindowStart)
            stitchWindowStart = Date()
            return
        }

        let windowStart = stitchWindowStart
        stitchWindowStart = Date()

        let duration = Double(audio.count) / (16000.0 * 2.0)
        processingCount += 1
        defer {
            processingCount -= 1
            if processingCount <= 0 { processingCount = 0; statusMessage = isRecording ? "Listening..." : "Ready" }
        }
        statusMessage = "Stitching..."

        do {
            let contextPrompt = extractContext(from: lastConfirmedText)
            let langCodes = inputLanguages.map { $0.isoCode }
            let result = try await whisperService.transcribe(
                pcmData: audio,
                prompt: contextPrompt.isEmpty ? nil : contextPrompt,
                inputLanguageCodes: langCodes
            )
            costTracker.logWhisperTranscription(audioDurationSeconds: duration)

            var text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !isHallucination(text) else {
                removeDraftEntriesInWindow(windowStart: windowStart)
                return
            }

            if !lastConfirmedText.isEmpty {
                text = removeDuplicatePrefix(newText: text, previousText: lastConfirmedText)
                guard !text.isEmpty else {
                    removeDraftEntriesInWindow(windowStart: windowStart)
                    return
                }
            }

            let sameLanguage = isSameLanguage(detected: result.language, target: targetLanguage)
            let needsTranslation = !sameLanguage && showTranslations
            let source: TranscriptionEntry.AudioSource = isMicEnabled ? .microphone : .system
            let speakerLabel = buildSpeakerLabel(source: source, language: result.language)

            var translated: String? = nil
            if needsTranslation {
                do {
                    translated = try await translationService.translate(text: text, to: targetLanguage.rawValue)
                    let inputTokens = text.count / 4 + 50
                    let outputTokens = (translated?.count ?? 0) / 4
                    costTracker.logGPTTranslation(inputTokens: inputTokens, outputTokens: outputTokens)
                } catch { }
            }

            removeDraftEntriesInWindow(windowStart: windowStart)

            let stitchedEntry = TranscriptionEntry(
                timestamp: windowStart,
                originalText: text,
                translatedText: translated,
                detectedLanguage: result.language,
                isTranslating: false,
                source: source,
                speakerLabel: speakerLabel,
                isDraft: false,
                isQualityResult: true
            )
            insertEntryChronologically(stitchedEntry)
            trimEntriesIfNeeded()
            markProcessingSuccess()

            lastConfirmedText = text
            lastConfirmedTranslation = translated
            lastConfirmedLanguage = result.language

        } catch {
            handleProcessingError(error)
        }
    }

    // MARK: - Layer 1b: Gemini Fast Draft

    private func processGeminiFast(audio: Data, source: TranscriptionEntry.AudioSource) async {
        let duration = Double(audio.count) / (16000.0 * 2.0)
        processingCount += 1
        defer {
            processingCount -= 1
            if processingCount <= 0 { processingCount = 0; statusMessage = isRecording ? "Listening..." : "Ready" }
        }
        statusMessage = "Transcribing..."

        do {
            let contextHint = lastConfirmedText.isEmpty ? nil : extractContext(from: lastConfirmedText, maxChars: 60)
            let langCodes = inputLanguages.map { $0.isoCode }
            let result = try await geminiFlashService.transcribeAndTranslate(
                pcmData: audio,
                targetLanguage: targetLanguage.rawValue,
                targetISOCode: targetLanguage.isoCode,
                previousContext: contextHint,
                isOverlapChunk: !overlapTailData.isEmpty,
                inputLanguageCodes: langCodes
            )
            costTracker.logGeminiFlash(audioDurationSeconds: duration, outputTokens: result.outputTokens)

            var text = result.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !isHallucination(text) else { return }

            if !lastConfirmedText.isEmpty {
                text = removeDuplicatePrefix(newText: text, previousText: lastConfirmedText)
                guard !text.isEmpty else { return }
            }

            // Echo suppression — drop if near-duplicate of a recent entry
            guard !isDuplicateOfRecent(text) else { return }

            let sameLanguage = isSameLanguage(detected: result.detectedLanguage, target: targetLanguage)
            let useTranslation = !sameLanguage && showTranslations
            let speakerLabel = buildSpeakerLabel(source: source, language: result.detectedLanguage)

            let entry = TranscriptionEntry(
                originalText: text,
                translatedText: useTranslation ? result.translatedText : nil,
                detectedLanguage: result.detectedLanguage,
                isTranslating: false,
                source: source,
                speakerLabel: speakerLabel,
                isDraft: true
            )
            entries.append(entry)
            draftEntryIDs.insert(entry.id)
            trimEntriesIfNeeded()
            markProcessingSuccess()
        } catch {
            handleProcessingError(error)
        }
    }

    // MARK: - Layer 2b: Gemini Quality Pass

    private func processGeminiQualityLayer() async {
        let capturedBuffer = geminiQualityBuffer
        geminiQualityBuffer = Data()
        await processGeminiQualityLayerWithData(capturedBuffer)
    }

    private func processGeminiQualityLayerWithData(_ audio: Data) async {
        let minBytes = Int(16000 * 2 * 1)
        guard audio.count >= minBytes else { return }

        guard hasEnoughEnergy(audio) else {
            removeDraftEntriesInWindow(windowStart: stitchWindowStart)
            stitchWindowStart = Date()
            return
        }

        let windowStart = stitchWindowStart
        stitchWindowStart = Date()

        let duration = Double(audio.count) / (16000.0 * 2.0)
        processingCount += 1
        defer {
            processingCount -= 1
            if processingCount <= 0 { processingCount = 0; statusMessage = isRecording ? "Listening..." : "Ready" }
        }
        statusMessage = "Refining..."

        do {
            let contextHint = lastConfirmedText.isEmpty ? nil : extractContext(from: lastConfirmedText, maxChars: 60)
            let langCodes = inputLanguages.map { $0.isoCode }
            let result = try await geminiFlashService.transcribeAndTranslate(
                pcmData: audio,
                targetLanguage: targetLanguage.rawValue,
                targetISOCode: targetLanguage.isoCode,
                previousContext: contextHint,
                isOverlapChunk: false,
                inputLanguageCodes: langCodes
            )
            costTracker.logGeminiFlash(audioDurationSeconds: duration, outputTokens: result.outputTokens)

            var text = result.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !isHallucination(text) else {
                removeDraftEntriesInWindow(windowStart: windowStart)
                return
            }

            if !lastConfirmedText.isEmpty {
                text = removeDuplicatePrefix(newText: text, previousText: lastConfirmedText)
                guard !text.isEmpty else {
                    removeDraftEntriesInWindow(windowStart: windowStart)
                    return
                }
            }

            let sameLanguage = isSameLanguage(detected: result.detectedLanguage, target: targetLanguage)
            let useTranslation = !sameLanguage && showTranslations
            let source: TranscriptionEntry.AudioSource = isMicEnabled ? .microphone : .system
            let speakerLabel = buildSpeakerLabel(source: source, language: result.detectedLanguage)

            removeDraftEntriesInWindow(windowStart: windowStart)

            let qualityEntry = TranscriptionEntry(
                timestamp: windowStart,
                originalText: text,
                translatedText: useTranslation ? result.translatedText : nil,
                detectedLanguage: result.detectedLanguage,
                isTranslating: false,
                source: source,
                speakerLabel: speakerLabel,
                isDraft: false,
                isQualityResult: true
            )
            insertEntryChronologically(qualityEntry)

            lastConfirmedText = text
            lastConfirmedTranslation = result.translatedText
            lastConfirmedLanguage = result.detectedLanguage
            markProcessingSuccess()

        } catch {
            handleProcessingError(error)
        }
    }

    // MARK: - Entry Management

    private func removeDraftEntriesInWindow(windowStart: Date) {
        let idsToRemove = draftEntryIDs
        entries.removeAll { entry in
            idsToRemove.contains(entry.id) && entry.timestamp >= windowStart
        }
        let remainingIDs = Set(entries.map { $0.id })
        draftEntryIDs = draftEntryIDs.filter { remainingIDs.contains($0) }
    }

    private func insertEntryChronologically(_ entry: TranscriptionEntry) {
        if let insertIdx = entries.firstIndex(where: { $0.timestamp > entry.timestamp }) {
            entries.insert(entry, at: insertIdx)
        } else {
            entries.append(entry)
        }
    }

    // MARK: - Gemini Live Handler

    private func handleGeminiLiveResult(_ result: GeminiLiveService.LiveResult) async {
        let text = result.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isHallucination(text) else { return }

        // Echo suppression — drop if near-duplicate of a recent entry
        guard !isDuplicateOfRecent(text) else { return }

        costTracker.logGeminiLive(audioDurationSeconds: Double(text.count) / 20.0, outputTokens: result.outputTokens)

        let detectedLang = detectLanguageFromText(text)
        let sameLanguage = isSameLanguage(detected: detectedLang, target: targetLanguage)
        let needsTranslation = !sameLanguage && showTranslations
        let speakerLabel = buildSpeakerLabel(source: .system, language: detectedLang)

        let entry = TranscriptionEntry(
            originalText: text,
            translatedText: nil,
            detectedLanguage: detectedLang,
            isTranslating: needsTranslation,
            source: .system,
            speakerLabel: speakerLabel,
            isDraft: false
        )
        entries.append(entry)

        if needsTranslation {
            do {
                let translated = try await translationService.translate(text: text, to: targetLanguage.rawValue)
                if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[idx].translatedText = translated
                    entries[idx].isTranslating = false
                }
            } catch {
                if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[idx].isTranslating = false
                }
            }
        }

        lastConfirmedText = text
        if isRecording { statusMessage = "Listening..." }
    }

    // MARK: - Language Detection from Text

    private func detectLanguageFromText(_ text: String) -> String {
        var cjk = 0, hira = 0, latin = 0, arabic = 0, korean = 0
        for s in text.unicodeScalars {
            let v = s.value
            if (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF) { cjk += 1 }
            if (v >= 0x3040 && v <= 0x30FF) { hira += 1 }
            if (v >= 0x0041 && v <= 0x007A) { latin += 1 }
            if (v >= 0x0600 && v <= 0x06FF) { arabic += 1 }
            if (v >= 0xAC00 && v <= 0xD7AF) { korean += 1 }
        }
        let total = max(1, cjk + hira + latin + arabic + korean)
        if hira > 0 { return "ja" }
        if korean > Int(Double(total) * 0.3) { return "ko" }
        if cjk > Int(Double(total) * 0.3) { return "zh" }
        if arabic > Int(Double(total) * 0.3) { return "ar" }
        return "en"
    }

    // MARK: - Error Handling

    private func handleProcessingError(_ error: Error) {
        consecutiveErrors += 1
        let msg = error.localizedDescription

        if msg.contains("401") {
            showError("Invalid API key. Check Settings.")
            // Don't count auth errors toward circuit breaker — they won't self-heal
            consecutiveErrors = 0
        } else if msg.contains("429") {
            showError("Rate limited. Backing off...")
        } else if msg.contains("timeout") || msg.contains("Timeout") || msg.contains("timed out") {
            showError("Request timed out. Retrying...")
        } else if msg.contains("404") {
            showError("Model not found. Check engine settings.")
            consecutiveErrors = 0  // Won't self-heal
        } else {
            showError("Error: \(msg.prefix(80))")
        }

        // Circuit breaker: if too many consecutive errors, pause pipeline briefly
        if consecutiveErrors >= maxConsecutiveErrors {
            showError("Multiple failures detected. Pausing 10s before retry...")
            Task {
                // Temporarily pause pipeline timers to let things cool down
                stopPipelineTimers()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if self.isRecording {
                    self.consecutiveErrors = 0
                    self.startPipelineTimers()
                    self.statusMessage = "Listening..."
                }
            }
        }
    }

    /// Called on successful processing to reset the error counter
    private func markProcessingSuccess() {
        consecutiveErrors = 0
    }

    private func showError(_ message: String) {
        errorMessage = message
        let m = message
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if self.errorMessage == m { self.errorMessage = nil }
        }
    }

    // MARK: - Speaker Label

    private func buildSpeakerLabel(source: TranscriptionEntry.AudioSource, language: String?) -> String {
        if source == .microphone { return "You" }
        guard let lang = language?.lowercased() else { return "Speaker" }
        let langName = TranscriptionEntry.languageNames[lang] ?? lang.capitalized
        return "Speaker (\(langName))"
    }
}
