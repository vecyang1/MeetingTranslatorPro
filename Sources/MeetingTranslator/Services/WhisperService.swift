import Foundation

/// Handles communication with OpenAI Whisper API for audio transcription
final class WhisperService: @unchecked Sendable {
    private let endpoint = "https://api.openai.com/v1/audio/transcriptions"
    private var apiKey: String

    /// Verbose JSON response from Whisper — includes no_speech_prob
    struct WhisperVerboseResponse: Codable {
        let text: String
        let language: String?
        let segments: [Segment]?

        struct Segment: Codable {
            let text: String
            let no_speech_prob: Double?
            let avg_logprob: Double?
        }
    }

    struct WhisperResponse: Codable {
        let text: String
        let language: String?
        let noSpeechProbability: Double  // Aggregated from segments
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    /// Transcribe raw PCM audio data (16-bit, 16kHz, mono) to text.
    /// - Parameters:
    ///   - pcmData: Raw PCM bytes
    ///   - prompt: Optional context from previous segment to guide stitching.
    ///             Whisper uses this to bias vocabulary and continue naturally.
    ///             Pass the last ~30 chars of the previous transcription.
    ///   - inputLanguageCodes: ISO codes of expected input languages (e.g. ["zh", "en"]).
    ///             Single code → passed as Whisper `language` param (strongest hint).
    ///             Multiple codes → prepended to `prompt` as vocabulary bias.
    func transcribe(pcmData: Data, prompt: String? = nil, inputLanguageCodes: [String] = []) async throws -> WhisperResponse {
        let wavData = createWAVData(from: pcmData, sampleRate: 16000, channels: 1, bitsPerSample: 16)
        return try await transcribeWAV(wavData: wavData, prompt: prompt, inputLanguageCodes: inputLanguageCodes)
    }

    /// Transcribe WAV audio data with optional context prompt and language hints
    func transcribeWAV(wavData: Data, prompt: String? = nil, inputLanguageCodes: [String] = []) async throws -> WhisperResponse {
        guard !apiKey.isEmpty else {
            throw WhisperError.noAPIKey
        }
        guard let url = URL(string: endpoint) else {
            throw WhisperError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Model parameter
        appendFormField(&body, boundary: boundary, name: "model", value: "whisper-large-v3")

        // Response format — verbose_json gives us no_speech_prob and language
        appendFormField(&body, boundary: boundary, name: "response_format", value: "verbose_json")

        // Temperature = 0 for deterministic output, reduces hallucination
        appendFormField(&body, boundary: boundary, name: "temperature", value: "0")

        // Language hint — if exactly one input language is specified, pass it directly.
        // Whisper's `language` parameter is the strongest accuracy hint: it skips
        // language detection entirely and forces the model to transcribe in that language.
        if inputLanguageCodes.count == 1 {
            appendFormField(&body, boundary: boundary, name: "language", value: inputLanguageCodes[0])
        }

        // Context prompt for stitching — Whisper uses this to bias transcription
        // toward vocabulary and style from the previous segment.
        // For multi-language scenarios, also prepend a language hint to the prompt.
        var effectivePrompt = prompt ?? ""
        if inputLanguageCodes.count > 1 {
            // Prepend language hint so Whisper knows what to expect
            let langHint = "[Expected languages: \(inputLanguageCodes.joined(separator: ", "))]"
            effectivePrompt = effectivePrompt.isEmpty ? langHint : langHint + " " + effectivePrompt
        }
        if !effectivePrompt.isEmpty {
            appendFormField(&body, boundary: boundary, name: "prompt", value: effectivePrompt)
        }

        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let verbose = try decoder.decode(WhisperVerboseResponse.self, from: data)

        // Calculate aggregate no_speech_prob from segments
        let noSpeechProb: Double
        if let segments = verbose.segments, !segments.isEmpty {
            let probs = segments.compactMap { $0.no_speech_prob }
            noSpeechProb = probs.isEmpty ? 0.0 : probs.reduce(0, +) / Double(probs.count)
        } else {
            noSpeechProb = 0.0
        }

        return WhisperResponse(
            text: verbose.text,
            language: verbose.language,
            noSpeechProbability: noSpeechProb
        )
    }

    // MARK: - Helpers

    private func appendFormField(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    /// Create a WAV file header + data from raw PCM samples
    private func createWAVData(from pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        var wav = Data()
        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = pcmData.count
        let chunkSize = 36 + dataSize

        wav.append("RIFF".data(using: .ascii)!)
        wav.append(withUnsafeBytes(of: UInt32(chunkSize).littleEndian) { Data($0) })
        wav.append("WAVE".data(using: .ascii)!)
        wav.append("fmt ".data(using: .ascii)!)
        wav.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })
        wav.append("data".data(using: .ascii)!)
        wav.append(withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        wav.append(pcmData)

        return wav
    }
}

enum WhisperError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "OpenAI API key is not configured."
        case .invalidURL: return "Invalid API endpoint URL."
        case .invalidResponse: return "Invalid response from server."
        case .apiError(let code, let message): return "API error (\(code)): \(message)"
        }
    }
}
