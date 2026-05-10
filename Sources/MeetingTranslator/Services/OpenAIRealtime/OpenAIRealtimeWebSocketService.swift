import Foundation

class OpenAIRealtimeWebSocketService: NSObject, @unchecked Sendable, URLSessionWebSocketDelegate {
    let source: TranscriptionEntry.AudioSource
    private var apiKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnected = false
    private var isReady = false
    private var isIntentionalDisconnect = false
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 4

    var onEvent: ((RealtimeAppEvent) -> Void)?

    init(apiKey: String, source: TranscriptionEntry.AudioSource) {
        self.apiKey = apiKey
        self.source = source
        super.init()
    }

    func updateAPIKey(_ key: String) {
        apiKey = key
    }

    func connect(url: URL) async throws {
        guard !apiKey.isEmpty else { throw OpenAIRealtimeError.noAPIKey }
        disconnect()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        urlSession = session

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("meeting-translator-pro-local", forHTTPHeaderField: "OpenAI-Safety-Identifier")

        let socket = session.webSocketTask(with: request)
        webSocket = socket
        socket.resume()
        isConnected = true
        isReady = false
        isIntentionalDisconnect = false
        reconnectAttempts = 0
        receiveTask = Task { [weak self] in await self?.receiveLoop() }
        startPingLoop()
    }

    func disconnect() {
        isIntentionalDisconnect = true
        pingTask?.cancel()
        receiveTask?.cancel()
        pingTask = nil
        receiveTask = nil
        isConnected = false
        isReady = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        onEvent?(.sessionStateChanged(source: source, state: .disconnected))
    }

    @discardableResult
    func sendJSON(_ payload: [String: Any]) -> Bool {
        guard isConnected else { return false }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            emitRecoverableError("Realtime payload could not be encoded.", action: "Retry")
            return false
        }
        guard let json = String(data: data, encoding: .utf8) else {
            emitRecoverableError("Realtime payload could not be encoded.", action: "Retry")
            return false
        }
        webSocket?.send(.string(json)) { [weak self] error in
            if let error {
                self?.emitRecoverableError("Realtime send failed: \(error.localizedDescription)", action: "Retry")
            }
        }
        return true
    }

    @discardableResult
    func sendAudioAppend(type: String, pcm24kData: Data, durationSeconds: Double) -> Bool {
        guard isReady else { return false }
        guard isConnected, let data = try? JSONSerialization.data(withJSONObject: [
            "type": type,
            "audio": pcm24kData.base64EncodedString()
        ]) else { return false }
        guard let json = String(data: data, encoding: .utf8) else { return false }
        webSocket?.send(.string(json)) { [weak self] error in
            guard let self else { return }
            if let error {
                self.emitRecoverableError("Realtime send failed: \(error.localizedDescription)", action: "Retry")
            } else {
                self.onEvent?(.audioQueued(source: self.source, mode: self.sessionMode, audioDurationSeconds: durationSeconds))
            }
        }
        return true
    }

    var sessionMode: RealtimeRouteMode {
        .transcription
    }

    func processServerEvent(_ event: [String: Any]) {
        _ = event
    }

    func handleDisconnectError(_ error: Error) {
        emitRecoverableError("Realtime connection dropped.", action: "Use fallback")
    }

    func markSessionReady() {
        guard isConnected, !isReady else { return }
        isReady = true
        onEvent?(.sessionStateChanged(source: source, state: .connected(sessionMode)))
    }

    private func receiveLoop() async {
        guard let socket = webSocket else { return }
        while isConnected && !Task.isCancelled {
            do {
                let message = try await socket.receive()
                let data: Data?
                switch message {
                case .data(let messageData): data = messageData
                case .string(let text): data = text.data(using: .utf8)
                @unknown default: data = nil
                }
                guard let data,
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                processServerEvent(event)
            } catch {
                if !Task.isCancelled && isConnected {
                    isConnected = false
                    handleDisconnectError(error)
                    onEvent?(.sessionStateChanged(source: source, state: .failed(error.localizedDescription)))
                }
                break
            }
        }
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard let self, self.isConnected else { break }
                self.webSocket?.sendPing { [weak self] error in
                    if let error {
                        self?.emitRecoverableError("Realtime heartbeat failed: \(error.localizedDescription)", action: "Retry")
                    }
                }
            }
        }
    }

    func emitRecoverableError(_ message: String, action: String) {
        guard !isIntentionalDisconnect else { return }
        onEvent?(.recoverableError(source: source, message: message, action: action))
    }
}

enum OpenAIRealtimeError: LocalizedError {
    case noAPIKey
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key is not configured."
        case .invalidURL:
            return "Invalid OpenAI Realtime URL."
        }
    }
}
