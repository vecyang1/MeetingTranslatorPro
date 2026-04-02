import Foundation

/// Gemini 3.1 Flash Live — WebSocket streaming for real-time transcription
/// Architecture: Uses inputAudioTranscription for raw STT, then calls GeminiFlash for translation
/// Upgraded from gemini-2.0-flash-live-001 to gemini-3.1-flash-live-preview for much better quality.
/// Includes proper setupComplete handshake, auto-reconnect, and heartbeat ping.
final class GeminiLiveService: NSObject, @unchecked Sendable, URLSessionWebSocketDelegate {
    private var apiKey: String
    private let model = "gemini-3.1-flash-live-preview"
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnected = false
    private var isSetupComplete = false
    private var targetLanguage: String = "English"
    private var targetISOCode: String = "en"

    /// Callback for received transcription results (original text + language only)
    var onTranscription: ((String, String) -> Void)?  // (text, detectedLanguage)

    /// Callback for errors
    var onError: ((Error) -> Void)?

    /// Callback for connection state changes
    var onConnectionStateChanged: ((Bool) -> Void)?

    // Keep for compatibility with AppState
    var onResult: ((LiveResult) -> Void)?

    struct LiveResult {
        let originalText: String
        let translatedText: String?
        let detectedLanguage: String
        let outputTokens: Int
        let isPartial: Bool
    }

    // Accumulate transcription segments within a turn
    private var accumulatedTranscription: String = ""
    private var lastEmittedTranscription: String = ""

    // Heartbeat / keep-alive
    private var pingTask: Task<Void, Never>?

    // Setup completion continuation for proper handshake
    private var setupContinuation: CheckedContinuation<Void, Error>?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    func updateTargetLanguage(_ language: String, isoCode: String) {
        self.targetLanguage = language
        self.targetISOCode = isoCode
        if isConnected {
            Task { await reconnect() }
        }
    }

    // MARK: - Connection

    func connect() async throws {
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        let wsURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: wsURL) else {
            throw GeminiError.invalidURL
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600  // 1 hour max session
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.urlSession = session
        let task = session.webSocketTask(with: url)
        self.webSocket = task
        task.resume()

        // Wait briefly for WebSocket to open, then send setup
        try await Task.sleep(nanoseconds: 500_000_000)

        // Send setup and wait for setupComplete acknowledgement (with timeout)
        try await sendSetupAndWait()

        isConnected = true
        onConnectionStateChanged?(true)

        // Start receive loop
        Task { await receiveLoop() }

        // Start heartbeat ping every 30s to detect stale connections
        startPingLoop()
    }

    func disconnect() {
        isConnected = false
        isSetupComplete = false
        accumulatedTranscription = ""
        lastEmittedTranscription = ""
        pingTask?.cancel()
        pingTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        onConnectionStateChanged?(false)
    }

    private func reconnect() async {
        disconnect()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        try? await connect()
    }

    // MARK: - Setup

    /// Send setup message and wait for setupComplete acknowledgement.
    /// Times out after 8 seconds if no acknowledgement is received.
    private func sendSetupAndWait() async throws {
        let setupMessage: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "generationConfig": [
                    "responseModalities": ["TEXT"],
                    "temperature": 0
                ],
                "systemInstruction": [
                    "parts": [[
                        "text": "You are a speech-to-text transcription engine. Transcribe the audio exactly as spoken. Do NOT add words, do NOT complete sentences, do NOT hallucinate. If there is silence or noise, output nothing."
                    ]]
                ],
                "realtimeInputConfig": [
                    "automaticActivityDetection": [
                        "disabled": false,
                        "startOfSpeechSensitivity": "START_SENSITIVITY_LOW",
                        "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
                        "silenceDurationMs": 800
                    ]
                ],
                "inputAudioTranscription": [String: Any]()
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: setupMessage)
        try await webSocket?.send(.data(jsonData))

        // Wait for setupComplete with a timeout
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setupContinuation = continuation

            // Timeout after 8 seconds
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if !self.isSetupComplete {
                    self.setupContinuation?.resume(throwing: GeminiError.connectionError("Setup timed out — no setupComplete received"))
                    self.setupContinuation = nil
                }
            }
        }
    }

    // MARK: - Heartbeat Ping

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds
                guard let self = self, self.isConnected else { break }
                self.webSocket?.sendPing { error in
                    if let error = error {
                        Task { @MainActor [weak self] in
                            self?.onError?(GeminiError.connectionError("Ping failed: \(error.localizedDescription)"))
                            self?.isConnected = false
                            self?.onConnectionStateChanged?(false)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Send Audio

    /// Send raw PCM audio chunk (16-bit, 16kHz, mono, little-endian)
    func sendAudio(_ pcmData: Data) {
        guard isConnected, isSetupComplete else { return }

        let base64Audio = pcmData.base64EncodedString()
        let audioMessage: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "data": base64Audio,
                    "mimeType": "audio/pcm;rate=16000"
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: audioMessage) else { return }
        webSocket?.send(.data(jsonData)) { [weak self] error in
            if let error = error {
                self?.onError?(GeminiError.connectionError("Send failed: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        guard let ws = webSocket else { return }

        while isConnected {
            do {
                let message = try await ws.receive()
                switch message {
                case .data(let data):
                    processServerMessage(data)
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        processServerMessage(data)
                    }
                @unknown default:
                    break
                }
            } catch {
                if isConnected {
                    onError?(GeminiError.connectionError("WebSocket receive error: \(error.localizedDescription)"))
                    isConnected = false
                    onConnectionStateChanged?(false)
                }
                break
            }
        }
    }

    private func processServerMessage(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Handle setup complete — resume the continuation
        if json["setupComplete"] != nil {
            isSetupComplete = true
            setupContinuation?.resume()
            setupContinuation = nil
            return
        }

        if let serverContent = json["serverContent"] as? [String: Any] {
            // inputTranscription — this is the actual speech-to-text from Gemini Live
            if let inputTranscription = serverContent["inputTranscription"] as? [String: Any],
               let text = inputTranscription["text"] as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !isRepeatedHallucination(trimmed) {
                    accumulatedTranscription += trimmed + " "
                }
            }

            // Turn complete — emit the accumulated transcription
            let turnComplete = serverContent["turnComplete"] as? Bool ?? false
            if turnComplete {
                let finalText = accumulatedTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalText.isEmpty && finalText != lastEmittedTranscription && !isRepeatedHallucination(finalText) {
                    lastEmittedTranscription = finalText
                    let result = LiveResult(
                        originalText: finalText,
                        translatedText: nil,  // AppState will handle translation
                        detectedLanguage: "unknown",  // AppState will detect from text
                        outputTokens: finalText.count / 4,
                        isPartial: false
                    )
                    onResult?(result)
                }
                accumulatedTranscription = ""
            }

            // Interrupted — discard partial accumulation
            if serverContent["interrupted"] as? Bool == true {
                accumulatedTranscription = ""
            }
        }
    }

    // MARK: - Hallucination Detection

    private func isRepeatedHallucination(_ text: String) -> Bool {
        guard text.count > 6 else { return false }

        let chars = Array(text.unicodeScalars).filter { $0.value != 32 && $0.value != 12288 }
        guard !chars.isEmpty else { return false }

        // All same character
        let firstChar = chars[0]
        if chars.allSatisfy({ $0 == firstChar }) { return true }

        // High repetition ratio (CJK)
        let uniqueChars = Set(chars.map { $0.value })
        if chars.count > 15 && uniqueChars.count <= 3 { return true }

        // Repeated words
        let words = text.split(separator: " ").map { String($0) }
        if words.count >= 5 {
            let unique = Set(words)
            if unique.count == 1 { return true }
        }

        return false
    }

    // MARK: - URLSessionWebSocketDelegate

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Connected — setup will be sent from connect()
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor [weak self] in
            self?.isConnected = false
            self?.isSetupComplete = false
            self?.pingTask?.cancel()
            self?.onConnectionStateChanged?(false)
        }
    }
}
