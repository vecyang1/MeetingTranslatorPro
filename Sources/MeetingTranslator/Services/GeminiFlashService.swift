import Foundation

/// Gemini 2.5 Flash REST API — single-call transcribe + translate via generateContent
/// Supports context-hint stitching to reconnect dialogue cut across chunk boundaries
final class GeminiFlashService: @unchecked Sendable {
    private var apiKey: String
    private let model = "gemini-2.5-flash-preview-04-17"

    struct GeminiResult {
        let originalText: String
        let translatedText: String?
        let detectedLanguage: String  // ISO code
        let outputTokens: Int
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Main Transcription Call

    /// Transcribe and translate PCM audio in a single API call.
    /// - Parameters:
    ///   - pcmData: Raw 16-bit PCM at 16kHz mono
    ///   - targetLanguage: Display name of target language (e.g. "Chinese")
    ///   - targetISOCode: ISO 639-1 code (e.g. "zh")
    ///   - previousContext: Last ~30 chars of the previous segment for stitching continuity
    ///   - isOverlapChunk: If true, the first ~1.5s of audio overlaps with the previous chunk
    func transcribeAndTranslate(
        pcmData: Data,
        targetLanguage: String,
        targetISOCode: String,
        previousContext: String? = nil,
        isOverlapChunk: Bool = false,
        inputLanguageCodes: [String] = []
    ) async throws -> GeminiResult {
        guard !apiKey.isEmpty else { throw GeminiError.noAPIKey }

        let wavData = createWAVData(from: pcmData, sampleRate: 16000, channels: 1, bitsPerSample: 16)
        let base64Audio = wavData.base64EncodedString()

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw GeminiError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let targetLangDescription = buildTargetLangDescription(targetLanguage: targetLanguage, targetISOCode: targetISOCode)

        // Build context-hint section for stitching
        var contextSection = ""
        if let ctx = previousContext, !ctx.isEmpty {
            contextSection = """

CONTINUITY CONTEXT:
The previous transcription segment ended with: "...\(ctx)"
Your transcription should naturally continue from where that left off.
Do NOT repeat text already in the previous segment.
"""
        }

        var overlapSection = ""
        if isOverlapChunk {
            overlapSection = """

OVERLAP NOTE:
The first ~1.5 seconds of this audio clip may overlap with the previous segment.
Skip any words at the beginning that were already captured in the previous segment (shown in CONTINUITY CONTEXT above).
Start your transcription from new content only.
"""
        }

        // Build input language hint section
        var inputLangSection = ""
        if !inputLanguageCodes.isEmpty {
            let langList = inputLanguageCodes.joined(separator: ", ")
            inputLangSection = """

        INPUT LANGUAGE HINT:
        The speaker is expected to speak one of these languages: [\(langList)].
        Use this to disambiguate ambiguous audio. For example, if audio could be Chinese or Japanese,
        prefer the language in this list. If the audio clearly sounds like a different language not in
        this list, still transcribe it correctly.
        """
        }

        let systemPrompt = """
        You are a real-time meeting transcription and translation engine.

        TASK:
        1. Transcribe the speech EXACTLY as spoken. Do NOT add, remove, or infer words not actually spoken.
        2. Detect the language (return ISO 639-1 code: "en", "zh", "ja", "ko", etc.).
        3. If the detected language is NOT \(targetLangDescription), translate the transcription to \(targetLangDescription).
        4. If the detected language IS \(targetLangDescription), set "translated" to null.
        5. If the audio contains no speech, silence, or noise only, return {"original":"","language":"unknown","translated":null}.
        \(contextSection)\(overlapSection)\(inputLangSection)
        STRICT RULES:
        - NEVER fabricate or hallucinate words not spoken in the audio.
        - NEVER repeat words or characters.
        - NEVER auto-complete sentences.
        - If audio is unclear, transcribe only what you are confident about.
        - Japanese (ja) uses hiragana (あいう) and katakana (アイウ). Chinese (zh) does NOT. Never confuse them.
        - \(targetISOCode == "zh" ? "Always use Simplified Chinese (简体中文) characters. NEVER use Traditional Chinese (繁體字)." : "")

        OUTPUT FORMAT: Return ONLY valid JSON, no markdown, no code fences, no explanation:
        {"original":"exact transcription","language":"xx","translated":"translation or null"}
        """

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "audio/wav",
                                "data": base64Audio
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0,
                "maxOutputTokens": 1024,
                "responseMimeType": "application/json"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { throw GeminiError.invalidResponse }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let textPart = parts.first?["text"] as? String else {
            throw GeminiError.parseError("Failed to parse Gemini response structure")
        }

        let outputTokens: Int
        if let usageMetadata = json["usageMetadata"] as? [String: Any],
           let candidatesTokenCount = usageMetadata["candidatesTokenCount"] as? Int {
            outputTokens = candidatesTokenCount
        } else {
            outputTokens = textPart.count / 4
        }

        return try parseResultJSON(textPart, outputTokens: outputTokens)
    }

    // MARK: - JSON Parsing

    private func parseResultJSON(_ text: String, outputTokens: Int) throws -> GeminiResult {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            let filtered = lines.filter { !$0.hasPrefix("```") }
            cleaned = filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find JSON object within text
        if let jsonStart = cleaned.firstIndex(of: "{"),
           let jsonEnd = cleaned.lastIndex(of: "}") {
            let jsonSubstring = String(cleaned[jsonStart...jsonEnd])
            if let resultData = jsonSubstring.data(using: .utf8),
               let resultJSON = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] {
                return extractResult(from: resultJSON, outputTokens: outputTokens)
            }
        }

        // Discard unparseable results — never show raw JSON to user
        return GeminiResult(originalText: "", translatedText: nil, detectedLanguage: "unknown", outputTokens: outputTokens)
    }

    private func extractResult(from json: [String: Any], outputTokens: Int) -> GeminiResult {
        let original = (json["original"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let language = (json["language"] as? String ?? "unknown").lowercased()
        var translated = json["translated"] as? String

        if translated == "null" || translated?.isEmpty == true { translated = nil }

        // Hallucination check
        if isRepeatedCharacterHallucination(original) {
            return GeminiResult(originalText: "", translatedText: nil, detectedLanguage: language, outputTokens: outputTokens)
        }

        return GeminiResult(originalText: original, translatedText: translated, detectedLanguage: language, outputTokens: outputTokens)
    }

    private func isRepeatedCharacterHallucination(_ text: String) -> Bool {
        guard text.count > 10 else { return false }
        let chars = Array(text.unicodeScalars).filter { $0.value != 32 && $0.value != 12288 }
        if chars.isEmpty { return false }
        if chars.allSatisfy({ $0 == chars[0] }) { return true }
        let words = text.split(separator: " ")
        if words.count >= 6 {
            let uniqueWords = Set(words.map { String($0) })
            if uniqueWords.count <= 2 { return true }
        }
        let uniqueChars = Set(chars.map { $0.value })
        if chars.count > 20 && uniqueChars.count <= 3 { return true }
        return false
    }

    // MARK: - Language Description Helper

    private func buildTargetLangDescription(targetLanguage: String, targetISOCode: String) -> String {
        if targetISOCode == "zh" {
            return "Simplified Chinese (简体中文, ISO code: zh)"
        }
        return "\(targetLanguage) (ISO code: \(targetISOCode))"
    }

    // MARK: - WAV Helper

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

enum GeminiError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case parseError(String)
    case apiError(statusCode: Int, message: String)
    case connectionError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Google API key is not configured."
        case .invalidURL: return "Invalid API endpoint URL."
        case .invalidResponse: return "Invalid response from Gemini server."
        case .parseError(let msg): return "Parse error: \(msg)"
        case .apiError(let code, let message): return "Gemini API error (\(code)): \(message.prefix(120))"
        case .connectionError(let msg): return "Connection error: \(msg)"
        }
    }
}
