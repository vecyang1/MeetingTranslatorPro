import Foundation
import AVFoundation
import Combine

/// Manages microphone audio capture using AVAudioEngine with dual-mode chunking:
/// 1. VAD-based: detects speech onset/offset and sends speech segments
/// 2. Timer-based fallback: always sends after chunkDuration even if VAD doesn't trigger
final class MicrophoneManager: ObservableObject {
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0
    @Published var availableDevices: [AudioDevice] = []

    private var audioEngine: AVAudioEngine?
    private let bufferLock = NSLock()
    private let targetSampleRate: Double = 16000.0

    // Dual-mode chunking
    private var accumulatedData = Data()
    private var chunkTimer: Timer?
    private var lastChunkTime = Date()

    // Voice Activity Detection parameters
    private var speechFrameCount: Int = 0
    private var silenceFrameCount: Int = 0
    private var isSpeechActive: Bool = false
    private var speechBuffer = Data()

    /// RMS threshold in dB — lowered to -45 dB to catch softer speech
    private let vadThresholdDB: Float = -45.0

    /// Number of consecutive "speech" frames needed to trigger speech start
    private let speechOnsetFrames: Int = 2

    /// Number of consecutive "silence" frames needed to end speech segment
    private let silenceTimeoutFrames: Int = 12

    /// Maximum speech segment duration before forced flush (seconds)
    private let maxSpeechDuration: TimeInterval = 25.0

    /// Callback when a chunk of audio is ready for transcription
    var onAudioChunkReady: ((Data) -> Void)?

    /// Duration in seconds for the fallback timer
    var chunkDuration: TimeInterval = 5.0

    init() {
        refreshDevices()
    }

    /// Refresh the list of available audio input devices
    func refreshDevices() {
        var devices: [AudioDevice] = []
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return }

        var defaultInputID: AudioDeviceID = 0
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddress,
            0, nil,
            &defaultSize,
            &defaultInputID
        )

        for deviceID in deviceIDs {
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            let streamStatus = AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &streamSize)
            guard streamStatus == noErr, streamSize > 0 else { continue }

            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameRef: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let nameStatus = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef)

            let deviceName: String
            if nameStatus == noErr, let ref = nameRef {
                deviceName = ref.takeUnretainedValue() as String
            } else {
                deviceName = "Unknown Device"
            }

            let device = AudioDevice(
                id: "\(deviceID)",
                name: deviceName,
                isDefault: deviceID == defaultInputID
            )
            devices.append(device)
        }

        DispatchQueue.main.async {
            self.availableDevices = devices
        }
    }

    /// Start capturing audio from the microphone
    func startCapturing() throws {
        guard !isCapturing else { return }

        // Reset all state
        speechFrameCount = 0
        silenceFrameCount = 0
        isSpeechActive = false
        speechBuffer = Data()
        accumulatedData = Data()
        lastChunkTime = Date()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw AudioCaptureError.formatError
        }

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let level = self.calculateLevel(buffer: buffer)
            DispatchQueue.main.async {
                self.audioLevel = level
            }

            if let converter = converter {
                let ratio = targetFormat.sampleRate / inputFormat.sampleRate
                let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else { return }

                var error: NSError?
                var inputConsumed = false
                converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                    if inputConsumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                if error == nil, outputBuffer.frameLength > 0 {
                    let data = self.bufferToData(outputBuffer)
                    self.processAudioData(data)
                }
            }
        }

        try engine.start()
        self.audioEngine = engine

        // Start fallback timer — fires every chunkDuration to flush accumulated audio
        let interval = chunkDuration
        DispatchQueue.main.async {
            self.chunkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.flushAccumulatedAudio()
            }
            self.isCapturing = true
        }
    }

    /// Stop capturing audio
    func stopCapturing() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        DispatchQueue.main.async {
            self.chunkTimer?.invalidate()
            self.chunkTimer = nil
        }

        // Flush remaining audio
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

        DispatchQueue.main.async {
            self.isCapturing = false
            self.audioLevel = 0
        }
    }

    // MARK: - Audio Processing (dual-mode)

    /// Process incoming audio data — both VAD and accumulation
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
                speechBuffer = accumulatedData  // Include pre-speech audio for context
            }
        } else {
            speechBuffer.append(data)

            let speechDuration = Double(speechBuffer.count) / (targetSampleRate * 2.0)

            if silenceFrameCount >= silenceTimeoutFrames || speechDuration >= maxSpeechDuration {
                let chunk = speechBuffer
                speechBuffer = Data()
                accumulatedData = Data()  // Clear accumulated since we're sending VAD chunk
                isSpeechActive = false
                speechFrameCount = 0
                silenceFrameCount = 0
                lastChunkTime = Date()
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

        // If VAD is actively tracking speech, let VAD handle it
        if isSpeechActive {
            bufferLock.unlock()
            return
        }

        let data = accumulatedData
        accumulatedData = Data()
        lastChunkTime = Date()
        bufferLock.unlock()

        // Only send if there's at least 1 second of audio
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

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        return Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }

    private func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channelData[0][i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(max(frames, 1)))
        let db = 20 * log10(max(rms, 0.000001))
        return max(0, min(1, (db + 60) / 60))
    }
}

enum AudioCaptureError: LocalizedError {
    case formatError
    case engineError(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .formatError:
            return "Failed to create audio format."
        case .engineError(let msg):
            return "Audio engine error: \(msg)"
        case .permissionDenied:
            return "Microphone permission denied."
        }
    }
}
