import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

@available(macOS 13.0, *)
final class CurrentProcessAudioExclusionProbeCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    enum Phase {
        case quiet
        case externalSyntheticPlayback
        case currentProcessPlayback
    }

    struct Snapshot {
        let quietBytes: Int
        let externalBytes: Int
        let currentProcessBytes: Int
        let quietMaxRMS: Float
        let externalMaxRMS: Float
        let currentProcessMaxRMS: Float

        var summary: String {
            "quiet_bytes=\(quietBytes) external_bytes=\(externalBytes) current_process_bytes=\(currentProcessBytes) " +
            "quiet_max_rms=\(String(format: "%.5f", quietMaxRMS)) " +
            "external_max_rms=\(String(format: "%.5f", externalMaxRMS)) " +
            "current_process_max_rms=\(String(format: "%.5f", currentProcessMaxRMS))"
        }
    }

    private let lock = NSLock()
    private var phase: Phase = .quiet
    private var quietBytes = 0
    private var externalBytes = 0
    private var currentProcessBytes = 0
    private var quietMaxRMS: Float = 0
    private var externalMaxRMS: Float = 0
    private var currentProcessMaxRMS: Float = 0

    func setPhase(_ phase: Phase) {
        lock.lock()
        self.phase = phase
        lock.unlock()
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            quietBytes: quietBytes,
            externalBytes: externalBytes,
            currentProcessBytes: currentProcessBytes,
            quietMaxRMS: quietMaxRMS,
            externalMaxRMS: externalMaxRMS,
            currentProcessMaxRMS: currentProcessMaxRMS
        )
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio,
              sampleBuffer.isValid,
              let blockBuffer = sampleBuffer.dataBuffer else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr,
              let pointer = dataPointer,
              length > 0 else { return }

        let rms = Self.calculateRMS(pointer: pointer, length: length, sampleBuffer: sampleBuffer)
        lock.lock()
        switch phase {
        case .quiet:
            quietBytes += length
            quietMaxRMS = max(quietMaxRMS, rms)
        case .externalSyntheticPlayback:
            externalBytes += length
            externalMaxRMS = max(externalMaxRMS, rms)
        case .currentProcessPlayback:
            currentProcessBytes += length
            currentProcessMaxRMS = max(currentProcessMaxRMS, rms)
        }
        lock.unlock()
    }

    private static func calculateRMS(
        pointer: UnsafeMutablePointer<Int8>,
        length: Int,
        sampleBuffer: CMSampleBuffer
    ) -> Float {
        guard let formatDesc = sampleBuffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            return calculateFloat32RMS(pointer: pointer, length: length)
        }
        if asbd.mBitsPerChannel == 16 {
            return calculateInt16RMS(pointer: pointer, length: length)
        }
        return calculateFloat32RMS(pointer: pointer, length: length)
    }

    private static func calculateFloat32RMS(pointer: UnsafeMutablePointer<Int8>, length: Int) -> Float {
        let sampleCount = length / MemoryLayout<Float32>.size
        guard sampleCount > 0 else { return 0 }
        var sum: Float = 0
        pointer.withMemoryRebound(to: Float32.self, capacity: sampleCount) { samples in
            for index in 0..<sampleCount {
                let sample = max(-1, min(1, samples[index]))
                sum += sample * sample
            }
        }
        return sqrt(sum / Float(sampleCount))
    }

    private static func calculateInt16RMS(pointer: UnsafeMutablePointer<Int8>, length: Int) -> Float {
        let sampleCount = length / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 0 }
        var sum: Float = 0
        pointer.withMemoryRebound(to: Int16.self, capacity: sampleCount) { samples in
            for index in 0..<sampleCount {
                let sample = Float(samples[index]) / Float(Int16.max)
                sum += sample * sample
            }
        }
        return sqrt(sum / Float(sampleCount))
    }
}

enum SystemAudioCurrentProcessExclusionProbeError: LocalizedError {
    case screenRecordingPermissionMissing
    case noDisplay
    case externalSyntheticAudioNotCaptured(CurrentProcessAudioExclusionProbeCapture.Snapshot)
    case currentProcessPlaybackRecaptured(CurrentProcessAudioExclusionProbeCapture.Snapshot)

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionMissing:
            return "Screen Recording permission is required for the current-process audio exclusion runtime probe."
        case .noDisplay:
            return "No display was available for ScreenCaptureKit runtime probing."
        case .externalSyntheticAudioNotCaptured(let snapshot):
            return "ScreenCaptureKit did not capture the external synthetic control audio. \(snapshot.summary)"
        case .currentProcessPlaybackRecaptured(let snapshot):
            return "Current-process playback appears in system capture. \(snapshot.summary)"
        }
    }
}

enum SystemAudioCurrentProcessExclusionProbe {
    static func runAndExit() -> Never {
        let outputURL = outputFileURL()
        if #available(macOS 13.0, *) {
            Task {
                do {
                    let snapshot = try await run()
                    report("system audio current-process exclusion runtime probe ok \(snapshot.summary)", outputURL: outputURL, isError: false)
                    Foundation.exit(0)
                } catch {
                    report("system audio current-process exclusion runtime probe failed: \(error.localizedDescription)", outputURL: outputURL, isError: true)
                    Foundation.exit(1)
                }
            }
            dispatchMain()
        } else {
            report("system audio current-process exclusion runtime probe failed: macOS 13+ required", outputURL: outputURL, isError: true)
            Foundation.exit(1)
        }
    }

    private static func outputFileURL() -> URL? {
        let arguments = CommandLine.arguments
        for (index, argument) in arguments.enumerated() {
            if argument == "--system-audio-exclusion-probe-output",
               index + 1 < arguments.count {
                return URL(fileURLWithPath: arguments[index + 1])
            }
            if argument.hasPrefix("--system-audio-exclusion-probe-output=") {
                let path = String(argument.dropFirst("--system-audio-exclusion-probe-output=".count))
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private static func report(_ message: String, outputURL: URL?, isError: Bool) {
        if let outputURL {
            try? (message + "\n").write(to: outputURL, atomically: true, encoding: .utf8)
        }
        if isError {
            fputs(message + "\n", stderr)
        } else {
            print(message)
        }
    }

    @available(macOS 13.0, *)
    static func run() async throws -> CurrentProcessAudioExclusionProbeCapture.Snapshot {
        guard SystemAudioManager.currentProcessAudioExclusionSupported else {
            throw SystemAudioCurrentProcessExclusionProbeError.screenRecordingPermissionMissing
        }
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        guard CGPreflightScreenCaptureAccess() else {
            throw SystemAudioCurrentProcessExclusionProbeError.screenRecordingPermissionMissing
        }

        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = availableContent.displays.first else {
            throw SystemAudioCurrentProcessExclusionProbeError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SystemAudioManager.makeStreamConfiguration(excludeCurrentProcessAudio: true)
        precondition(configuration.excludesCurrentProcessAudio)

        let capture = CurrentProcessAudioExclusionProbeCapture()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: capture)
        try stream.addStreamOutput(capture, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))
        try await stream.startCapture()

        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            capture.setPhase(.externalSyntheticPlayback)
            let externalURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("mtp_external_synthetic_control.wav")
            try writeToneWAV(to: externalURL, sampleRate: 24_000, frequency: 440, duration: 1.0, amplitude: 0.75)
            let externalPlayer = Process()
            externalPlayer.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
            externalPlayer.arguments = [externalURL.path]
            try externalPlayer.run()
            externalPlayer.waitUntilExit()

            try await Task.sleep(nanoseconds: 1_000_000_000)
            capture.setPhase(.currentProcessPlayback)
            try await Task.sleep(nanoseconds: 400_000_000)
            let player = RealtimeTranslatedAudioPlayer(startEngine: true, maxQueuedBytes: 128_000)
            let pcm = makeTonePCM16(sampleRate: 24_000, frequency: 880, duration: 1.0, amplitude: 0.65)
            try player.configure(sampleRate: 24_000, channels: 1, volume: 0.8)
            player.enqueuePCM16(pcm, itemID: "synthetic-current-process-exclusion", source: .system, sampleRate: 24_000)
            try await Task.sleep(nanoseconds: 1_500_000_000)
            player.stop(clearQueue: true)
        } catch {
            try? await stream.stopCapture()
            throw error
        }

        try await stream.stopCapture()
        let snapshot = capture.snapshot()
        let externalIncrease = max(0, snapshot.externalMaxRMS - snapshot.quietMaxRMS)
        let currentProcessIncrease = max(0, snapshot.currentProcessMaxRMS - snapshot.quietMaxRMS)
        guard externalIncrease >= Float(0.05) else {
            throw SystemAudioCurrentProcessExclusionProbeError.externalSyntheticAudioNotCaptured(snapshot)
        }

        let allowedCurrentProcessIncrease = max(Float(0.05), externalIncrease * Float(0.25))
        guard currentProcessIncrease <= allowedCurrentProcessIncrease else {
            throw SystemAudioCurrentProcessExclusionProbeError.currentProcessPlaybackRecaptured(snapshot)
        }
        return snapshot
    }

    private static func makeTonePCM16(
        sampleRate: Int,
        frequency: Double,
        duration: Double,
        amplitude: Double
    ) -> Data {
        let frameCount = Int(Double(sampleRate) * duration)
        var data = Data(capacity: frameCount * MemoryLayout<Int16>.size)
        for index in 0..<frameCount {
            let phase = (Double(index) / Double(sampleRate)) * frequency * 2 * Double.pi
            var sample = Int16(max(-1, min(1, sin(phase) * amplitude)) * Double(Int16.max))
            data.append(Data(bytes: &sample, count: MemoryLayout<Int16>.size))
        }
        return data
    }

    private static func writeToneWAV(
        to url: URL,
        sampleRate: Int,
        frequency: Double,
        duration: Double,
        amplitude: Double
    ) throws {
        let pcm = makeTonePCM16(sampleRate: sampleRate, frequency: frequency, duration: duration, amplitude: amplitude)
        var wav = Data()
        let byteRate = sampleRate * 2
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let subchunk2Size = UInt32(pcm.count)
        let chunkSize = UInt32(36 + pcm.count)

        wav.append(contentsOf: Array("RIFF".utf8))
        appendLE(chunkSize, to: &wav)
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        appendLE(UInt32(16), to: &wav)
        appendLE(UInt16(1), to: &wav)
        appendLE(UInt16(1), to: &wav)
        appendLE(UInt32(sampleRate), to: &wav)
        appendLE(UInt32(byteRate), to: &wav)
        appendLE(blockAlign, to: &wav)
        appendLE(bitsPerSample, to: &wav)
        wav.append(contentsOf: Array("data".utf8))
        appendLE(subchunk2Size, to: &wav)
        wav.append(pcm)
        try wav.write(to: url, options: .atomic)
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        data.append(Data(bytes: &littleEndianValue, count: MemoryLayout<T>.size))
    }
}
