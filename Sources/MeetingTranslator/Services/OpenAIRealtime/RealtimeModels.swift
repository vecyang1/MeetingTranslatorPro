import Foundation

enum OpenAIRealtimeModel: String {
    case realtimeWhisper = "gpt-realtime-whisper"
    case realtimeTranslate = "gpt-realtime-translate"
    case realtimeAgent = "gpt-realtime-2"
}

enum RealtimePricing {
    static let whisperPerMinuteUSD: Double = 0.017
    static let translatePerMinuteUSD: Double = 0.034
    static let realtime2TextInputPerMillionUSD: Double = 4.00
    static let realtime2TextOutputPerMillionUSD: Double = 24.00
    static let realtime2AudioInputPerMillionUSD: Double = 32.00
    static let realtime2AudioOutputPerMillionUSD: Double = 64.00
    static let realtime2InputAudioTokensPerSecond: Double = 10.0
    static let realtime2OutputAudioTokensPerSecond: Double = 20.0

    static func whisperCost(audioDurationSeconds: Double) -> Double {
        (audioDurationSeconds / 60.0) * whisperPerMinuteUSD
    }

    static func translateCost(audioDurationSeconds: Double) -> Double {
        (audioDurationSeconds / 60.0) * translatePerMinuteUSD
    }

    static func realtime2Cost(
        inputAudioDurationSeconds: Double,
        outputAudioDurationSeconds: Double = 0,
        inputTextTokens: Int = 0,
        outputTextTokens: Int = 0
    ) -> Double {
        let inputAudioTokens = inputAudioDurationSeconds * realtime2InputAudioTokensPerSecond
        let outputAudioTokens = outputAudioDurationSeconds * realtime2OutputAudioTokensPerSecond
        return (inputAudioTokens / 1_000_000.0) * realtime2AudioInputPerMillionUSD
            + (outputAudioTokens / 1_000_000.0) * realtime2AudioOutputPerMillionUSD
            + (Double(inputTextTokens) / 1_000_000.0) * realtime2TextInputPerMillionUSD
            + (Double(outputTextTokens) / 1_000_000.0) * realtime2TextOutputPerMillionUSD
    }
}

enum RealtimeRouteMode: String {
    case transcription
    case translation
    case agent
}

enum TranslatedAudioSafetyStatus: Equatable {
    case ready
    case blockedSystemCaptureIncludesAppAudio
    case blockedLikelySpeakerOutputWithMicActive
    case needsHeadphonesConfirmation
    case providerFormatUnknown
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var userMessage: String {
        switch self {
        case .ready:
            return "Ready: translated audio safe preview is available."
        case .blockedSystemCaptureIncludesAppAudio:
            return "Blocked: system capture cannot prove the app's own audio is excluded."
        case .blockedLikelySpeakerOutputWithMicActive:
            return "Blocked: current output looks like speakers or display audio; switch to headphones."
        case .needsHeadphonesConfirmation:
            return "Waiting: use headphones or a non-speaker output, then confirm to avoid microphone feedback."
        case .providerFormatUnknown:
            return "Blocked: translated audio format is not confirmed as PCM16."
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        }
    }
}

struct RealtimeTranslatedAudioOutputRoute: Equatable {
    let name: String
    let manufacturer: String?
    let transportType: String?
    let dataSource: String?
    let uniqueID: String?

    init(
        name: String,
        manufacturer: String? = nil,
        transportType: String? = nil,
        dataSource: String? = nil,
        uniqueID: String? = nil
    ) {
        self.name = name
        self.manufacturer = manufacturer
        self.transportType = transportType
        self.dataSource = dataSource
        self.uniqueID = uniqueID
    }

    var searchableText: String {
        [name, manufacturer, transportType, dataSource, uniqueID]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    var fingerprint: String {
        [uniqueID, name, manufacturer, transportType, dataSource]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map {
                $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .lowercased()
            }
            .joined(separator: "|")
    }
}

enum RealtimeTranslatedAudioOutputSafety {
    static func status(
        isMicEnabled: Bool,
        safeOutputConfirmed: Bool,
        confirmedRouteFingerprint: String?,
        route: RealtimeTranslatedAudioOutputRoute?
    ) -> TranslatedAudioSafetyStatus {
        guard isMicEnabled else { return .ready }
        guard let route else {
            return .unavailable("default audio output route could not be identified")
        }
        if isLikelyRoomSpeaker(route) {
            return .blockedLikelySpeakerOutputWithMicActive
        }
        guard isConfirmableNonSpeakerRoute(route) else {
            return .unavailable("current output is not recognized as headphones or a safe non-speaker route")
        }
        guard safeOutputConfirmed else {
            return .needsHeadphonesConfirmation
        }
        guard confirmedRouteFingerprint == route.fingerprint else {
            return .needsHeadphonesConfirmation
        }
        return .ready
    }

    static func isConfirmableNonSpeakerRoute(_ route: RealtimeTranslatedAudioOutputRoute) -> Bool {
        isLikelyHeadphones(route) && !isLikelyRoomSpeaker(route) && !route.fingerprint.isEmpty
    }

    static func isLikelyHeadphones(_ route: RealtimeTranslatedAudioOutputRoute) -> Bool {
        let text = route.searchableText
        let terms = [
            "headphone", "headphones", "headset", "earbud", "earbuds", "earphone", "earphones",
            "airpods", "airpod", "earpods", "beats", "buds", "hdpn",
            "耳机", "耳機", "イヤホン", "ヘッドホン", "casque", "ecouteur", "écouteur", "auriculares"
        ]
        return terms.contains { text.contains($0) }
    }

    static func isLikelyRoomSpeaker(_ route: RealtimeTranslatedAudioOutputRoute) -> Bool {
        if isLikelyHeadphones(route) { return false }
        let text = route.searchableText
        let terms = [
            "speaker", "speakers", "internal speaker", "built-in speaker", "built in speaker",
            "macbook", "imac", "studio display", "display audio", "monitor", "television", " tv ",
            "hdmi", "displayport", "airplay", "aggregate", "multi-output", "multi output", "ispk",
            "扬声器", "揚聲器", "スピーカー"
        ]
        return terms.contains { text.contains($0) }
    }
}

enum RealtimeTranslatedAudioPlaybackGate {
    static func mayEnable(
        showTranslations: Bool,
        inputLanguageCount: Int,
        sameLanguage: Bool,
        interpreterSessionEnabled: Bool,
        userOptedIn: Bool,
        safetyStatus: TranslatedAudioSafetyStatus
    ) -> Bool {
        showTranslations
            && inputLanguageCount == 1
            && !sameLanguage
            && interpreterSessionEnabled
            && userOptedIn
            && safetyStatus.isReady
    }
}

enum RealtimeCaptionLatencyPreset: String, CaseIterable, Identifiable {
    case aggressive = "Aggressive"
    case balanced = "Balanced"
    case accuracy = "Accuracy"

    var id: String { rawValue }

    var targetDelaySeconds: Double {
        switch self {
        case .aggressive: return 0.4
        case .balanced: return 1.4
        case .accuracy: return 2.4
        }
    }

    var realtimeCaptureChunkDuration: TimeInterval {
        targetDelaySeconds
    }

    var description: String {
        switch self {
        case .aggressive:
            return "Earliest partial text; may produce choppier rows."
        case .balanced:
            return "Best default for readable live meetings."
        case .accuracy:
            return "Waits longer for steadier, less fragmented captions."
        }
    }
}

struct RealtimeAudioBoundaryContext {
    private let maxTailBytes: Int
    private var microphoneTail = Data()
    private var systemTail = Data()

    init(overlapSeconds: TimeInterval, sampleRate: Int = 16_000, bytesPerSample: Int = 2) {
        maxTailBytes = max(0, Int(overlapSeconds * TimeInterval(sampleRate * bytesPerSample)))
    }

    mutating func contextualizedAudio(_ data: Data, source: TranscriptionEntry.AudioSource) -> Data {
        guard !data.isEmpty, maxTailBytes > 0 else { return data }
        let tail = tailData(for: source)
        updateTail(with: data, source: source)
        guard !tail.isEmpty else { return data }
        return tail + data
    }

    mutating func reset() {
        microphoneTail = Data()
        systemTail = Data()
    }

    mutating func reset(source: TranscriptionEntry.AudioSource) {
        switch source {
        case .microphone:
            microphoneTail = Data()
        case .system:
            systemTail = Data()
        }
    }

    private func tailData(for source: TranscriptionEntry.AudioSource) -> Data {
        switch source {
        case .microphone:
            return microphoneTail
        case .system:
            return systemTail
        }
    }

    private mutating func updateTail(with data: Data, source: TranscriptionEntry.AudioSource) {
        let nextTail = Data(data.suffix(maxTailBytes))
        switch source {
        case .microphone:
            microphoneTail = nextTail
        case .system:
            systemTail = nextTail
        }
    }
}

enum RealtimeReasoningEffort: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var id: String { rawValue }
}

enum RealtimeSessionState: Equatable {
    case disconnected
    case connecting
    case connected(RealtimeRouteMode)
    case reconnecting(Int)
    case failed(String)

    var userMessage: String {
        switch self {
        case .disconnected:
            return "Realtime idle"
        case .connecting:
            return "Connecting realtime..."
        case .connected(let mode):
            switch mode {
            case .transcription: return "Realtime captions active"
            case .translation: return "Realtime translation active"
            case .agent: return "Realtime captions active"
            }
        case .reconnecting(let attempt):
            return "Realtime reconnecting (\(attempt))..."
        case .failed(let message):
            return message
        }
    }

    func presented(activeMode: RealtimeRouteMode?) -> RealtimeSessionState {
        guard case .connected = self, let activeMode else { return self }
        return .connected(activeMode)
    }
}

struct RealtimeRouteDecision: Equatable {
    let mode: RealtimeRouteMode
    let model: String
    let endpointPath: String
    let reason: String
    let shouldStartTranslationSession: Bool
    let shouldStartSourceCaptionSession: Bool
}

struct RealtimeSendResult: Equatable {
    let sentToPrimary: Bool
    let sentToSourceCaption: Bool

    var accepted: Bool {
        sentToPrimary || sentToSourceCaption
    }
}

enum RealtimeAppEvent {
    case partialTranscript(source: TranscriptionEntry.AudioSource, itemID: String, text: String, timestamp: Date)
    case finalTranscript(source: TranscriptionEntry.AudioSource, itemID: String, text: String, language: String?, timestamp: Date)
    case partialTranslation(source: TranscriptionEntry.AudioSource, itemID: String, text: String, timestamp: Date)
    case finalTranslation(source: TranscriptionEntry.AudioSource, itemID: String, text: String, language: String?, timestamp: Date)
    case translatedAudioChunk(
        source: TranscriptionEntry.AudioSource,
        itemID: String,
        data: Data,
        format: String?,
        sampleRate: Double?,
        channels: Int?,
        timestamp: Date
    )
    case translatedAudioDone(source: TranscriptionEntry.AudioSource, itemID: String, timestamp: Date)
    case translatedAudioFormatUnsupported(source: TranscriptionEntry.AudioSource, itemID: String, format: String, timestamp: Date)
    case sessionStateChanged(source: TranscriptionEntry.AudioSource, state: RealtimeSessionState)
    case usageUpdated(source: TranscriptionEntry.AudioSource, mode: RealtimeRouteMode, audioDurationSeconds: Double, inputTokens: Int, outputTokens: Int)
    case audioQueued(source: TranscriptionEntry.AudioSource, mode: RealtimeRouteMode, audioDurationSeconds: Double)
    case recoverableError(source: TranscriptionEntry.AudioSource, message: String, action: String)
}

struct RealtimeReducedEntry: Equatable {
    let source: TranscriptionEntry.AudioSource
    let itemID: String
    let text: String
    let translatedText: String?
    let language: String?
    let timestamp: Date
    let isFinal: Bool
    let isTranslationOnly: Bool
    let supersededItemIDs: [String]

    init(
        source: TranscriptionEntry.AudioSource,
        itemID: String,
        text: String,
        translatedText: String?,
        language: String?,
        timestamp: Date,
        isFinal: Bool,
        isTranslationOnly: Bool,
        supersededItemIDs: [String] = []
    ) {
        self.source = source
        self.itemID = itemID
        self.text = text
        self.translatedText = translatedText
        self.language = language
        self.timestamp = timestamp
        self.isFinal = isFinal
        self.isTranslationOnly = isTranslationOnly
        self.supersededItemIDs = supersededItemIDs
    }
}

struct RealtimePendingItem: Equatable {
    var source: TranscriptionEntry.AudioSource
    var itemID: String
    var transcript: String
    var translation: String?
    var language: String?
    var timestamp: Date
    var lastUpdated: Date
}
