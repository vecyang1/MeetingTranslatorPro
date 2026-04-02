import Foundation

/// Transcription engine options
enum TranscriptionEngine: String, CaseIterable, Identifiable {
    case openAI = "OpenAI Whisper + GPT"
    case geminiFlash = "Gemini 2.5 Flash"
    case geminiLive = "Gemini 3.1 Flash Live"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .geminiFlash: return "Gemini Flash"
        case .geminiLive: return "Gemini Live"
        }
    }

    var description: String {
        switch self {
        case .openAI: return "Two-step: Whisper transcription + GPT-4o-mini translation. Most accurate but slower (~10-15s)."
        case .geminiFlash: return "Single API call for transcription + translation. Good balance of speed and accuracy (~3-5s)."
        case .geminiLive: return "Real-time WebSocket streaming. Lowest latency, sub-second response. Best for live meetings."
        }
    }

    var requiresGoogleKey: Bool {
        switch self {
        case .openAI: return false
        case .geminiFlash, .geminiLive: return true
        }
    }

    var requiresOpenAIKey: Bool {
        switch self {
        case .openAI: return true
        case .geminiFlash, .geminiLive: return false
        }
    }
}

/// Supported languages for translation
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case chinese = "Chinese"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case japanese = "Japanese"
    case korean = "Korean"
    case portuguese = "Portuguese"
    case russian = "Russian"
    case arabic = "Arabic"
    case hindi = "Hindi"
    case italian = "Italian"
    case dutch = "Dutch"
    case turkish = "Turkish"
    case thai = "Thai"
    case vietnamese = "Vietnamese"

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .chinese: return "🇨🇳"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .portuguese: return "🇧🇷"
        case .russian: return "🇷🇺"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .italian: return "🇮🇹"
        case .dutch: return "🇳🇱"
        case .turkish: return "🇹🇷"
        case .thai: return "🇹🇭"
        case .vietnamese: return "🇻🇳"
        }
    }

    var isoCode: String {
        switch self {
        case .english: return "en"
        case .chinese: return "zh"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .arabic: return "ar"
        case .hindi: return "hi"
        case .italian: return "it"
        case .dutch: return "nl"
        case .turkish: return "tr"
        case .thai: return "th"
        case .vietnamese: return "vi"
        }
    }

    /// All ISO codes that map to this language (for same-language detection)
    var allISOCodes: [String] {
        switch self {
        case .chinese: return ["zh", "cmn", "yue", "wuu"]
        case .english: return ["en"]
        case .japanese: return ["ja"]
        case .korean: return ["ko"]
        case .spanish: return ["es"]
        case .french: return ["fr"]
        case .german: return ["de"]
        case .portuguese: return ["pt"]
        case .russian: return ["ru"]
        case .arabic: return ["ar"]
        case .hindi: return ["hi"]
        case .italian: return ["it"]
        case .dutch: return ["nl"]
        case .turkish: return ["tr"]
        case .thai: return ["th"]
        case .vietnamese: return ["vi"]
        }
    }
}

/// Audio input device descriptor
struct AudioDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let isDefault: Bool
}
