import Foundation

/// Transcription engine options
enum TranscriptionEngine: String, CaseIterable, Identifiable {
    case openAIRealtime = "OpenAI Realtime (Recommended)"
    case openAI = "OpenAI Whisper + GPT"
    case geminiFlash = "Gemini 2.5 Flash"
    case geminiLive = "Gemini 3.1 Flash Live"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .openAIRealtime: return "Realtime"
        case .openAI: return "OpenAI"
        case .geminiFlash: return "Gemini Flash"
        case .geminiLive: return "Gemini Live"
        }
    }

    var description: String {
        switch self {
        case .openAIRealtime: return "Primary live captions: gpt-realtime-whisper with optional realtime translation session."
        case .openAI: return "Legacy fallback: Whisper + GPT-4o-mini translation. Accurate but slower (~10-15s)."
        case .geminiFlash: return "Single API call for transcription + translation. Good balance of speed and accuracy (~3-5s)."
        case .geminiLive: return "Experimental Gemini streaming alternate. Useful for comparison or fallback."
        }
    }

    var requiresGoogleKey: Bool {
        switch self {
        case .openAIRealtime, .openAI: return false
        case .geminiFlash, .geminiLive: return true
        }
    }

    var requiresOpenAIKey: Bool {
        switch self {
        case .openAIRealtime, .openAI: return true
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
    let systemID: UInt32
    let uid: String?
}

enum AudioInputDeviceSelection {
    static func resolvedDeviceID(preferredID: String?, devices: [AudioDevice]) -> String? {
        guard let preferredID,
              devices.contains(where: { $0.id == preferredID }) else {
            return nil
        }
        return preferredID
    }

    static func selectedDevice(preferredID: String?, devices: [AudioDevice]) -> AudioDevice? {
        guard let resolvedID = resolvedDeviceID(preferredID: preferredID, devices: devices) else {
            return nil
        }
        return devices.first { $0.id == resolvedID }
    }

    static func displayName(
        preferredID: String?,
        activeDevice: AudioDevice?,
        devices: [AudioDevice]
    ) -> String {
        if let selected = selectedDevice(preferredID: preferredID, devices: devices) {
            return selected.name
        }
        if let activeDevice {
            return "System Default (\(activeDevice.name))"
        }
        if let defaultDevice = devices.first(where: { $0.isDefault }) {
            return "System Default (\(defaultDevice.name))"
        }
        return "System Default"
    }

    static func shortDisplayName(_ displayName: String) -> String {
        let replacements = [
            "MacBook Pro Microphone": "Mac Mic",
            "MacBook Air Microphone": "Mac Mic",
            "System Default": "Default"
        ]
        var name = displayName
        for (source, replacement) in replacements {
            name = name.replacingOccurrences(of: source, with: replacement)
        }
        return name
    }
}

struct MicrophoneInputDeviceSwitchResult: Equatable {
    let selectedID: String?
    let changed: Bool
    let restartedCapture: Bool
}

enum MicrophoneInputDeviceSwitch {
    static func normalizedID(_ id: String?) -> String? {
        let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func apply(
        currentID: String?,
        requestedID: String?,
        isRecording: Bool,
        isMicEnabled: Bool,
        setSelectedDevice: (String?) -> Void,
        setPreferredDevice: (String?) -> Void,
        persistSelection: () -> Void,
        stopCapturing: (Bool) -> Void,
        startCapturing: () throws -> Void
    ) throws -> MicrophoneInputDeviceSwitchResult {
        let current = normalizedID(currentID)
        let next = normalizedID(requestedID)
        guard current != next else {
            return MicrophoneInputDeviceSwitchResult(
                selectedID: current,
                changed: false,
                restartedCapture: false
            )
        }

        setSelectedDevice(next)
        setPreferredDevice(next)
        persistSelection()

        guard isRecording && isMicEnabled else {
            return MicrophoneInputDeviceSwitchResult(
                selectedID: next,
                changed: true,
                restartedCapture: false
            )
        }

        stopCapturing(false)
        do {
            try startCapturing()
        } catch {
            setSelectedDevice(current)
            setPreferredDevice(current)
            persistSelection()
            try? startCapturing()
            throw error
        }

        return MicrophoneInputDeviceSwitchResult(
            selectedID: next,
            changed: true,
            restartedCapture: true
        )
    }
}
