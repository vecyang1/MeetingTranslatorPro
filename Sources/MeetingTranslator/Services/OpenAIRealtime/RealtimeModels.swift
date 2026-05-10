import Foundation

enum OpenAIRealtimeModel: String {
    case realtimeWhisper = "gpt-realtime-whisper"
    case realtimeTranslate = "gpt-realtime-translate"
    case realtimeAgent = "gpt-realtime-2"
}

enum RealtimeRouteMode: String {
    case transcription
    case translation
    case agent
}

enum RealtimeCaptionLatencyPreset: String, CaseIterable, Identifiable {
    case aggressive = "Aggressive"
    case balanced = "Balanced"
    case accuracy = "Accuracy"

    var id: String { rawValue }

    var targetDelaySeconds: Double {
        switch self {
        case .aggressive: return 0.4
        case .balanced: return 1.0
        case .accuracy: return 1.8
        }
    }

    var realtimeCaptureChunkDuration: TimeInterval {
        targetDelaySeconds
    }

    var description: String {
        switch self {
        case .aggressive:
            return "Earliest partial text; may revise more often."
        case .balanced:
            return "Best default for live meetings."
        case .accuracy:
            return "Waits slightly longer for steadier captions."
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
            case .agent: return "Realtime assistant active"
            }
        case .reconnecting(let attempt):
            return "Realtime reconnecting (\(attempt))..."
        case .failed(let message):
            return message
        }
    }
}

struct RealtimeRouteDecision: Equatable {
    let mode: RealtimeRouteMode
    let model: String
    let endpointPath: String
    let reason: String
    let shouldStartTranslationSession: Bool
}

enum RealtimeAppEvent {
    case partialTranscript(source: TranscriptionEntry.AudioSource, itemID: String, text: String, timestamp: Date)
    case finalTranscript(source: TranscriptionEntry.AudioSource, itemID: String, text: String, language: String?, timestamp: Date)
    case partialTranslation(source: TranscriptionEntry.AudioSource, itemID: String, text: String, timestamp: Date)
    case finalTranslation(source: TranscriptionEntry.AudioSource, itemID: String, text: String, language: String?, timestamp: Date)
    case translatedAudioChunk(source: TranscriptionEntry.AudioSource, itemID: String, data: Data, timestamp: Date)
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
