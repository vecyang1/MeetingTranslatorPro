import Foundation

/// Handles communication with OpenAI GPT API for text translation
final class TranslationService: @unchecked Sendable {
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private var apiKey: String

    private struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    /// Translate text to the specified target language
    func translate(text: String, to targetLanguage: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TranslationError.noAPIKey
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        guard let url = URL(string: endpoint) else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        // Be explicit about Chinese script variant
        let targetDescription: String
        if targetLanguage.lowercased().contains("chinese") {
            targetDescription = "Simplified Chinese (简体中文). ONLY use Simplified Chinese characters. NEVER use Traditional Chinese (繁體字)."
        } else {
            targetDescription = targetLanguage
        }

        let systemPrompt = """
        You are a professional meeting translator. Translate the spoken text to \(targetDescription).
        Rules:
        - Output ONLY the translation, nothing else.
        - Do NOT add explanations, notes, or commentary.
        - Preserve the original meaning and tone.
        - If the text is already in \(targetLanguage), return it unchanged.
        - Do NOT add words or sentences not present in the original.
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw TranslationError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

enum TranslationError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key is not configured."
        case .invalidURL:
            return "Invalid API endpoint URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        }
    }
}
