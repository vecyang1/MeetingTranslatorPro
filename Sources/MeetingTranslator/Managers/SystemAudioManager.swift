import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreGraphics
import Combine

/// Manages system audio capture using ScreenCaptureKit (macOS 13+)
/// Captures all system audio output — meeting apps, browser calls, etc.
/// Uses dual-mode chunking: VAD-based + fallback timer
final class SystemAudioManager: NSObject, ObservableObject, @unchecked Sendable, SCStreamDelegate, SCStreamOutput {
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0
    @Published var permissionStatus: PermissionStatus = .unknown

    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case needsRestart
    }

    private var stream: SCStream?
    private let bufferLock = NSLock()
    private let targetSampleRate: Double = 16000.0

    // Dual-mode chunking
    private var accumulatedData = Data()
    private var chunkTimer: Timer?

    // Voice Activity Detection state
    private var speechFrameCount: Int = 0
    private var silenceFrameCount: Int = 0
    private var isSpeechActive: Bool = false
    private var speechBuffer = Data()

    /// RMS threshold in dB — lowered to -45 dB
    private let vadThresholdDB: Float = -45.0
    private let speechOnsetFrames: Int = 2
    private let silenceTimeoutFrames: Int = 12
    private let maxSpeechDuration: TimeInterval = 25.0

    /// Callback when a chunk of audio is ready for transcription
    var onAudioChunkReady: ((Data) -> Void)?

    /// Duration in seconds for fallback timer
    var chunkDuration: TimeInterval = 5.0

    // MARK: - Permission Handling

    func checkAndRequestPermission() {
        let hasAccess = CGPreflightScreenCaptureAccess()
        if hasAccess {
            DispatchQueue.main.async {
                self.permissionStatus = .granted
            }
        } else {
            let granted = CGRequestScreenCaptureAccess()
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .granted : .denied
            }
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Start capturing system audio
    func startCapturing() async throws {
        guard !isCapturing else { return }

        let hasAccess = CGPreflightScreenCaptureAccess()
        if !hasAccess {
            let granted = CGRequestScreenCaptureAccess()
            await MainActor.run {
                self.permissionStatus = granted ? .granted : .denied
            }
            if !granted {
                throw SystemAudioError.permissionDenied
            }
        } else {
            await MainActor.run {
                self.permissionStatus = .granted
            }
        }

        // Reset state
        speechFrameCount = 0
        silenceFrameCount = 0
        isSpeechActive = false
        speechBuffer = Data()
        accumulatedData = Data()

        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = availableContent.displays.first else {
            throw SystemAudioError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = Int(targetSampleRate)
        config.channelCount = 1
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))

        try await newStream.startCapture()
        self.stream = newStream

        // Start fallback timer
        let interval = chunkDuration
        await MainActor.run {
            self.chunkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.flushAccumulatedAudio()
            }
            self.isCapturing = true
        }
    }

    /// Stop capturing system audio
    func stopCapturing() async {
        guard let stream = stream else { return }

        do {
            try await stream.stopCapture()
        } catch {
            print("Error stopping system audio capture: \(error)")
        }

        self.stream = nil

        await MainActor.run {
            self.chunkTimer?.invalidate()
            self.chunkTimer = nil
        }

        // Flush remaining
        bufferLock.lock()
        let remaining: Data
        if isSpeechActive && speechBuffer.count > 0 {
            remaining = speechBuffer
        } else if accumulatedData.count > 0 {
            remaining = accumulatedData
        } else {
            remaining = Data()
        }
        speechBuffer = Data()
        accumulatedData = Data()
        isSpeechActive = false
        speechFrameCount = 0
        silenceFrameCount = 0
        bufferLock.unlock()

        let minBytes = Int(targetSampleRate * 2.0 * 0.5)
        if remaining.count >= minBytes {
            onAudioChunkReady?(remaining)
        }

        await MainActor.run {
            self.isCapturing = false
            self.audioLevel = 0
        }
    }

    // MARK: - SCStreamOutput

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard sampleBuffer.isValid else { return }
        guard let blockBuffer = sampleBuffer.dataBuffer else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard status == kCMBlockBufferNoErr, let pointer = dataPointer, length > 0 else { return }
        guard let formatDesc = sampleBuffer.formatDescription else { return }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee

        if let asbd = asbd {
            let pcmData: Data
            if asbd.mBitsPerChannel == 32 && asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                pcmData = convertFloat32ToInt16(pointer: pointer, length: length)
            } else if asbd.mBitsPerChannel == 16 {
                pcmData = Data(bytes: pointer, count: length)
            } else {
                pcmData = convertFloat32ToInt16(pointer: pointer, length: length)
            }

            let level = calculateLevel(from: pcmData)
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }

            processAudioData(pcmData)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isCapturing = false
            self?.audioLevel = 0
        }
    }

    // MARK: - Audio Processing (dual-mode)

    private func processAudioData(_ data: Data) {
        let energyDB = calculateEnergyDB(pcmData: data)
        let isSpeechFrame = energyDB > vadThresholdDB

        bufferLock.lock()

        // Always accumulate for fallback timer
        accumulatedData.append(data)

        // VAD state machine
        if isSpeechFrame {
            speechFrameCount += 1
            silenceFrameCount = 0
        } else {
            silenceFrameCount += 1
            if !isSpeechActive {
                speechFrameCount = 0
            }
        }

        if !isSpeechActive {
            if speechFrameCount >= speechOnsetFrames {
                isSpeechActive = true
                speechBuffer = accumulatedData
            }
        } else {
            speechBuffer.append(data)

            let speechDuration = Double(speechBuffer.count) / (targetSampleRate * 2.0)

            if silenceFrameCount >= silenceTimeoutFrames || speechDuration >= maxSpeechDuration {
                let chunk = speechBuffer
                speechBuffer = Data()
                accumulatedData = Data()
                isSpeechActive = false
                speechFrameCount = 0
                silenceFrameCount = 0
                bufferLock.unlock()

                let minBytes = Int(targetSampleRate * 2.0 * 0.8)
                if chunk.count >= minBytes {
                    onAudioChunkReady?(chunk)
                }
                return
            }
        }

        bufferLock.unlock()
    }

    /// Fallback: flush accumulated audio on timer
    private func flushAccumulatedAudio() {
        bufferLock.lock()

        if isSpeechActive {
            bufferLock.unlock()
            return
        }

        let data = accumulatedData
        accumulatedData = Data()
        bufferLock.unlock()

        let minBytes = Int(targetSampleRate * 2.0 * 1.0)
        if data.count >= minBytes {
            onAudioChunkReady?(data)
        }
    }

    // MARK: - Helpers

    private func calculateEnergyDB(pcmData: Data) -> Float {
        let sampleCount = pcmData.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return -100 }

        var sum: Float = 0
        pcmData.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let normalized = Float(samples[i]) / Float(Int16.max)
                sum += normalized * normalized
            }
        }

        let rms = sqrt(sum / Float(sampleCount))
        return 20 * log10(max(rms, 1e-10))
    }

    private func convertFloat32ToInt16(pointer: UnsafeMutablePointer<Int8>, length: Int) -> Data {
        let floatCount = length / MemoryLayout<Float32>.size
        var int16Data = Data(capacity: floatCount * MemoryLayout<Int16>.size)

        pointer.withMemoryRebound(to: Float32.self, capacity: floatCount) { floatPointer in
            for i in 0..<floatCount {
                let sample = floatPointer[i]
                let clamped = max(-1.0, min(1.0, sample))
                var int16Sample = Int16(clamped * Float(Int16.max))
                int16Data.append(Data(bytes: &int16Sample, count: MemoryLayout<Int16>.size))
            }
        }

        return int16Data
    }

    private func calculateLevel(from pcmData: Data) -> Float {
        let sampleCount = pcmData.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 0 }

        var sum: Float = 0
        pcmData.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let normalized = Float(samples[i]) / Float(Int16.max)
                sum += normalized * normalized
            }
        }

        let rms = sqrt(sum / Float(sampleCount))
        let db = 20 * log10(max(rms, 0.000001))
        return max(0, min(1, (db + 60) / 60))
    }
}

enum SystemAudioError: LocalizedError {
    case noDisplay
    case permissionDenied
    case captureError(String)

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "No display found for system audio capture."
        case .permissionDenied:
            return "Screen Recording permission is required."
        case .captureError(let msg):
            return "System audio capture error: \(msg)"
        }
    }
}
