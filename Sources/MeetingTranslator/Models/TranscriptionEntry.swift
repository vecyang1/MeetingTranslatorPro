import Foundation

/// Represents a single transcription + translation entry in the timeline
struct TranscriptionEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    var originalText: String
    var translatedText: String?
    var detectedLanguage: String?       // ISO code: "en", "zh", "ja", etc.
    var isTranslating: Bool
    var source: AudioSource
    var speakerLabel: String?
    var speakerID: String?
    var speakerDisplayName: String?
    var speakerConfidence: Double?
    var speakerSource: SpeakerAttributionSource?
    var isDraft: Bool                   // true = fast-track draft, will be replaced by stitch pass
    var isQualityResult: Bool           // true = stitch/quality pass result (final)
    var realtimeItemID: String?         // Provider item id for partial/final realtime reconciliation
    var realtimeLastMergedAt: Date?     // Last realtime chunk timestamp merged into this readable row

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
        speakerID: String? = nil,
        speakerDisplayName: String? = nil,
        speakerConfidence: Double? = nil,
        speakerSource: SpeakerAttributionSource? = nil,
        isDraft: Bool = false,
        isQualityResult: Bool = false,
        realtimeItemID: String? = nil,
        realtimeLastMergedAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedLanguage = detectedLanguage
        self.isTranslating = isTranslating
        self.source = source
        self.speakerLabel = speakerLabel
        self.speakerID = speakerID
        self.speakerDisplayName = speakerDisplayName
        self.speakerConfidence = speakerConfidence
        self.speakerSource = speakerSource
        self.isDraft = isDraft
        self.isQualityResult = isQualityResult
        self.realtimeItemID = realtimeItemID
        self.realtimeLastMergedAt = realtimeLastMergedAt
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

enum SpeakerAttributionSource: String, Equatable {
    case diarization
    case knownSpeaker
    case manual
}

enum SpeakerRecognitionMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case delayedDiarization = "Delayed diarization"
    case meetingRoomLab = "Meeting-room lab"

    var id: String { rawValue }

    var isEnabled: Bool {
        self != .off
    }
}

struct DiarizedSpeechSegment: Equatable {
    let speakerID: String
    let speakerDisplayName: String
    let start: TimeInterval
    let end: TimeInterval
    let text: String
    let confidence: Double?
}

enum SpeakerDiarizationMatcher {
    static func apply(
        segments: [DiarizedSpeechSegment],
        to entries: inout [TranscriptionEntry],
        matchWindowSeconds: TimeInterval = 1.0
    ) -> Int {
        var updateCount = 0
        var usedEntryIDs = Set<UUID>()

        for segment in segments {
            let candidates = entries.indices.compactMap { index -> (index: Int, score: Double)? in
                let entry = entries[index]
                guard entry.source == .system,
                      !entry.isDraft,
                      !usedEntryIDs.contains(entry.id),
                      timestamp(entry.timestamp, isNear: segment, tolerance: matchWindowSeconds) else {
                    return nil
                }
                let score = textSimilarity(entry.originalText, segment.text)
                guard score >= 0.72 else { return nil }
                return (index, score)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return entries[lhs.index].timestamp < entries[rhs.index].timestamp
                }
                return lhs.score > rhs.score
            }

            guard let best = candidates.first else { continue }
            if candidates.count > 1, abs(best.score - candidates[1].score) < 0.08 {
                continue
            }

            entries[best.index].speakerID = segment.speakerID
            entries[best.index].speakerDisplayName = segment.speakerDisplayName
            entries[best.index].speakerConfidence = segment.confidence
            entries[best.index].speakerSource = .diarization
            entries[best.index].speakerLabel = segment.speakerDisplayName
            usedEntryIDs.insert(entries[best.index].id)
            updateCount += 1
        }

        return updateCount
    }

    private static func timestamp(
        _ timestamp: Date,
        isNear segment: DiarizedSpeechSegment,
        tolerance: TimeInterval
    ) -> Bool {
        let seconds = timestamp.timeIntervalSince1970
        return seconds >= segment.start - tolerance && seconds <= segment.end + tolerance
    }

    private static func textSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = tokenSet(lhs)
        let rhsTokens = tokenSet(rhs)
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }
        let intersection = lhsTokens.intersection(rhsTokens).count
        return (2.0 * Double(intersection)) / Double(lhsTokens.count + rhsTokens.count)
    }

    private static func tokenSet(_ text: String) -> Set<String> {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let tokens = folded
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        if tokens.count > 1 {
            return Set(tokens)
        }
        return Set(folded.unicodeScalars.filter { !$0.properties.isWhitespace }.map { String($0) })
    }
}

struct KnownSpeakerReference: Equatable {
    let name: String
    let audioDataURL: String
}

enum SpeakerDiarizationRequestBuilder {
    static let model = "gpt-4o-transcribe-diarize"
    static let responseFormat = "diarized_json"
    static let chunkingStrategy = "auto"

    static func fields(knownSpeakers: [KnownSpeakerReference] = []) -> [(String, String)] {
        var fields: [(String, String)] = [
            ("model", model),
            ("response_format", responseFormat),
            ("chunking_strategy", chunkingStrategy)
        ]
        for speaker in knownSpeakers.prefix(4) {
            fields.append(("known_speaker_names[]", speaker.name))
            fields.append(("known_speaker_references[]", speaker.audioDataURL))
        }
        return fields
    }
}

enum LanguageDetector {
    static func detect(_ text: String) -> String {
        let normalized = text.lowercased()
        var cjk = 0
        var kana = 0
        var latin = 0
        var arabic = 0
        var korean = 0
        var cyrillic = 0
        var devanagari = 0
        var thai = 0
        var greek = 0
        var hebrew = 0
        var bengali = 0
        var tamil = 0
        var telugu = 0
        var malayalam = 0

        for scalar in normalized.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) { cjk += 1 }
            if (0x3040...0x30FF).contains(v) { kana += 1 }
            if (0x0041...0x007A).contains(v) || (0x00C0...0x024F).contains(v) { latin += 1 }
            if (0x0600...0x06FF).contains(v) { arabic += 1 }
            if (0xAC00...0xD7AF).contains(v) { korean += 1 }
            if (0x0400...0x04FF).contains(v) { cyrillic += 1 }
            if (0x0900...0x097F).contains(v) { devanagari += 1 }
            if (0x0E00...0x0E7F).contains(v) { thai += 1 }
            if (0x0370...0x03FF).contains(v) { greek += 1 }
            if (0x0590...0x05FF).contains(v) { hebrew += 1 }
            if (0x0980...0x09FF).contains(v) { bengali += 1 }
            if (0x0B80...0x0BFF).contains(v) { tamil += 1 }
            if (0x0C00...0x0C7F).contains(v) { telugu += 1 }
            if (0x0D00...0x0D7F).contains(v) { malayalam += 1 }
        }

        let total = cjk + kana + latin + arabic + korean + cyrillic + devanagari + thai + greek + hebrew + bengali + tamil + telugu + malayalam
        guard total > 0 else { return "unknown" }

        if kana > 0 { return "ja" }
        if dominant(korean, total) { return "ko" }
        if dominant(cjk, total) { return "zh" }
        if dominant(arabic, total) { return "ar" }
        if dominant(devanagari, total) { return "hi" }
        if dominant(thai, total) { return "th" }
        if dominant(greek, total) { return "el" }
        if dominant(hebrew, total) { return "he" }
        if dominant(bengali, total) { return "bn" }
        if dominant(tamil, total) { return "ta" }
        if dominant(telugu, total) { return "te" }
        if dominant(malayalam, total) { return "ml" }
        if dominant(cyrillic, total) { return "ru" }

        if let latinLanguage = detectLatinScriptLanguage(normalized) {
            return latinLanguage
        }

        return latin > 0 ? "en" : "unknown"
    }

    private static func dominant(_ count: Int, _ total: Int) -> Bool {
        count > Int(Double(total) * 0.3)
    }

    private static func detectLatinScriptLanguage(_ text: String) -> String? {
        let padded = " \(text) "
        let candidates: [(code: String, signalCharacters: String, phrases: [String])] = [
            (
                "vi",
                "ăâđêôơưáàảãạấầẩẫậắằẳẵặéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ",
                [" bay gio", " bây giờ", " minh ", " mình ", " dang ", " đang ", " noi ", " nói ", " chuyen ", " chuyện ", " tieng viet", " tiếng việt", " khong", " không", " duoc", " được"]
            ),
            (
                "tr",
                "çğıöşüı",
                [" benim ", " yüzden", " yuzden", " kendi ", " gerekiyor", " degil", " değil", " icin ", " için "]
            ),
            (
                "es",
                "ñ¿¡áéíóúü",
                [" hola", " como ", " cómo ", " estas", " estás", " necesito ", " traduccion", " traducción", " rapido", " rápido", " gracias"]
            ),
            (
                "fr",
                "àâæçéèêëîïôœùûüÿ",
                [" bonjour", " merci", " avec ", " pour ", " traduction", " français"]
            ),
            (
                "de",
                "äöüß",
                [" danke", " bitte", " nicht", " übersetzung", " fuer ", " für "]
            ),
            (
                "pt",
                "ãõçáàâéêíóôú",
                [" ola ", " olá", " voce", " você", " traducao", " tradução", " obrigado"]
            ),
            (
                "it",
                "àèéìíîòóù",
                [" ciao", " grazie", " traduzione", " perche", " perché"]
            )
        ]

        var best: (code: String, score: Int)?
        for candidate in candidates {
            let score = scalarHits(in: text, from: candidate.signalCharacters) + phraseHits(in: padded, phrases: candidate.phrases) * 2
            guard score > 0 else { continue }
            if best == nil || score > best!.score {
                best = (candidate.code, score)
            }
        }

        guard let best, best.score >= 2 else { return nil }
        return best.code
    }

    private static func scalarHits(in text: String, from signalCharacters: String) -> Int {
        let signals = Set(signalCharacters.unicodeScalars.map(\.value))
        return text.unicodeScalars.reduce(0) { total, scalar in
            total + (signals.contains(scalar.value) ? 1 : 0)
        }
    }

    private static func phraseHits(in text: String, phrases: [String]) -> Int {
        phrases.reduce(0) { total, phrase in
            total + (text.contains(phrase) ? 1 : 0)
        }
    }
}
