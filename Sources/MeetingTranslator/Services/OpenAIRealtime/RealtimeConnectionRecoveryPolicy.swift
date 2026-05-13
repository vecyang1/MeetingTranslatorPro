import Foundation

enum RealtimeConnectionRecoveryPolicy {
    static let maxAttempts = 2

    static func shouldRetry(message: String, attemptsUsed: Int) -> Bool {
        attemptsUsed < maxAttempts && isRecoverableNetworkError(message)
    }

    static func retryDelayNanoseconds(forAttempt attempt: Int) -> UInt64 {
        let clampedAttempt = max(1, min(attempt, maxAttempts))
        let seconds = 0.8 * pow(2.0, Double(clampedAttempt - 1))
        return UInt64(seconds * 1_000_000_000)
    }

    static func isRecoverableNetworkError(_ message: String) -> Bool {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }

        let permanentHints = [
            "invalid api key",
            "unauthorized",
            "authentication",
            "forbidden",
            "billing",
            "quota",
            "insufficient_quota",
            "model_not_found",
            "permission",
            "401",
            "403"
        ]
        if permanentHints.contains(where: normalized.contains) {
            return false
        }

        let transientHints = [
            "tls error",
            "secure connection",
            "ssl",
            "0: 13",
            "0:13",
            "network connection was lost",
            "timed out",
            "cannot connect",
            "connection dropped",
            "connection reset",
            "connection interrupted",
            "heartbeat failed",
            "websocket",
            "nsurlerrordomain",
            "kcferrordomaincfnetwork",
            "posix"
        ]
        return transientHints.contains(where: normalized.contains)
    }
}
