import Foundation

/// Represents a single transcription + translation entry in the timeline
struct TranscriptionEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    var translatedText: String?
    var detectedLanguage: String?       // ISO code: "en", "zh", "ja", etc.
    var isTranslating: Bool
    var source: AudioSource
    var speakerLabel: String?
    var isDraft: Bool                   // true = fast-track draft, will be replaced by stitch pass
    var isQualityResult: Bool           // true = stitch/quality pass result (final)

    enum AudioSource: String, Equatable {
        case microphone = "Mic"
        case system = "System"
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        originalText: String,
        translatedText: String? = nil,
        detectedLanguage: String? = nil,
        isTranslating: Bool = false,
        source: AudioSource = .microphone,
        speakerLabel: String? = nil,
        isDraft: Bool = false,
        isQualityResult: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedLanguage = detectedLanguage
        self.isTranslating = isTranslating
        self.source = source
        self.speakerLabel = speakerLabel
        self.isDraft = isDraft
        self.isQualityResult = isQualityResult
    }

    /// Get the full language name from ISO code
    var languageName: String? {
        guard let code = detectedLanguage?.lowercased() else { return nil }
        return Self.languageNames[code] ?? code.capitalized
    }

    /// Get the flag emoji for the detected language
    var languageFlag: String? {
        guard let code = detectedLanguage?.lowercased() else { return nil }
        return Self.languageFlags[code]
    }

    /// Mapping from ISO codes to full language names
    static let languageNames: [String: String] = [
        "en": "English",
        "zh": "Chinese",
        "ja": "Japanese",
        "ko": "Korean",
        "es": "Spanish",
        "fr": "French",
        "de": "German",
        "pt": "Portuguese",
        "ru": "Russian",
        "ar": "Arabic",
        "hi": "Hindi",
        "it": "Italian",
        "nl": "Dutch",
        "tr": "Turkish",
        "th": "Thai",
        "vi": "Vietnamese",
        "pl": "Polish",
        "sv": "Swedish",
        "da": "Danish",
        "fi": "Finnish",
        "no": "Norwegian",
        "id": "Indonesian",
        "ms": "Malay",
        "uk": "Ukrainian",
        "cs": "Czech",
        "el": "Greek",
        "he": "Hebrew",
        "hu": "Hungarian",
        "ro": "Romanian",
        "bg": "Bulgarian",
        "hr": "Croatian",
        "sk": "Slovak",
        "sl": "Slovenian",
        "sr": "Serbian",
        "lt": "Lithuanian",
        "lv": "Latvian",
        "et": "Estonian",
        "nn": "Nynorsk",
        "nb": "Norwegian",
        "ca": "Catalan",
        "gl": "Galician",
        "eu": "Basque",
        "cy": "Welsh",
        "af": "Afrikaans",
        "sw": "Swahili",
        "tl": "Filipino",
        "ta": "Tamil",
        "te": "Telugu",
        "ml": "Malayalam",
        "bn": "Bengali",
        "ur": "Urdu",
        "fa": "Persian",
        "unknown": "Unknown"
    ]

    /// Mapping from ISO codes to flag emojis
    static let languageFlags: [String: String] = [
        "en": "🇺🇸", "zh": "🇨🇳", "ja": "🇯🇵", "ko": "🇰🇷",
        "es": "🇪🇸", "fr": "🇫🇷", "de": "🇩🇪", "pt": "🇧🇷",
        "ru": "🇷🇺", "ar": "🇸🇦", "hi": "🇮🇳", "it": "🇮🇹",
        "nl": "🇳🇱", "tr": "🇹🇷", "th": "🇹🇭", "vi": "🇻🇳",
        "pl": "🇵🇱", "sv": "🇸🇪", "da": "🇩🇰", "fi": "🇫🇮",
        "no": "🇳🇴", "id": "🇮🇩", "ms": "🇲🇾", "uk": "🇺🇦",
        "cs": "🇨🇿", "el": "🇬🇷", "he": "🇮🇱", "hu": "🇭🇺",
        "ro": "🇷🇴", "bg": "🇧🇬", "hr": "🇭🇷", "sk": "🇸🇰",
        "nn": "🇳🇴", "nb": "🇳🇴", "ca": "🇪🇸", "af": "🇿🇦",
        "sw": "🇰🇪", "tl": "🇵🇭", "ta": "🇮🇳", "bn": "🇧🇩",
        "ur": "🇵🇰", "fa": "🇮🇷"
    ]
}
