import AVFoundation
import Foundation

final class RealtimeTranslatedAudioPlayer: ObservableObject {
    enum State: Equatable {
        case idle
        case warming
        case playing
        case muted
        case unavailable(String)
        case failed(String)
    }

    static let defaultSampleRate: Double = 24_000
    static let defaultChannels = 1

    @Published private(set) var state: State = .idle
    @Published private(set) var queuedByteCount = 0
    @Published private(set) var droppedChunkCount = 0
    @Published private(set) var underrunCount = 0

    private let startEngine: Bool
    private let maxQueuedBytes: Int
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var playbackFormat: AVAudioFormat?
    private(set) var isMuted = false
    private var volume: Double = 0.65

    init(startEngine: Bool = true, maxQueuedBytes: Int = 512_000) {
        self.startEngine = startEngine
        self.maxQueuedBytes = max(1, maxQueuedBytes)
    }

    func configure(sampleRate: Double, channels: Int, volume: Double) throws {
        guard sampleRate > 0, channels == Self.defaultChannels else {
            state = .unavailable("Translated audio requires mono PCM16 output.")
            throw RealtimeTranslatedAudioPlayerError.unsupportedFormat
        }

        self.volume = min(max(volume, 0), 1)
        playerNode?.volume = Float(self.volume)
        playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        )
        guard playbackFormat != nil else {
            state = .failed("Unable to create translated audio playback format.")
            throw RealtimeTranslatedAudioPlayerError.unsupportedFormat
        }

        guard startEngine else {
            state = isMuted ? .muted : .idle
            return
        }

        let engine = self.engine ?? AVAudioEngine()
        let playerNode = self.playerNode ?? AVAudioPlayerNode()
        self.engine = engine
        self.playerNode = playerNode
        playerNode.volume = Float(self.volume)
        if !engine.attachedNodes.contains(playerNode) {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: playbackFormat)
        }
        if !engine.isRunning {
            state = .warming
            try engine.start()
        }
        if !playerNode.isPlaying, !isMuted {
            playerNode.play()
        }
        state = isMuted ? .muted : .idle
    }

    func enqueuePCM16(
        _ data: Data,
        itemID: String,
        source: TranscriptionEntry.AudioSource,
        sampleRate: Double?
    ) {
        guard !data.isEmpty else { return }
        guard !isMuted else { return }
        if playbackFormat == nil {
            do {
                try configure(
                    sampleRate: sampleRate ?? Self.defaultSampleRate,
                    channels: Self.defaultChannels,
                    volume: volume
                )
            } catch {
                return
            }
        }
        guard queuedByteCount + data.count <= maxQueuedBytes else {
            droppedChunkCount += 1
            return
        }
        guard let buffer = makeBuffer(fromPCM16: data) else {
            state = .failed("Unable to decode translated PCM16 audio.")
            return
        }

        queuedByteCount += data.count
        state = .playing
        guard startEngine else { return }
        guard let playerNode else { return }
        if !playerNode.isPlaying {
            playerNode.play()
        }
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.queuedByteCount = max(0, self.queuedByteCount - data.count)
                if self.queuedByteCount == 0 && !self.isMuted {
                    self.state = .idle
                }
            }
        }
    }

    func finishSegment(itemID: String, source: TranscriptionEntry.AudioSource) {
        if queuedByteCount == 0 && !isMuted {
            state = .idle
        }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            stop(clearQueue: true)
            state = .muted
        } else {
            state = .idle
            if startEngine,
               engine?.isRunning == true,
               let playerNode,
               !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }

    func setVolume(_ volume: Double) {
        self.volume = min(max(volume, 0), 1)
        playerNode?.volume = Float(self.volume)
    }

    func stop(clearQueue: Bool) {
        if startEngine {
            playerNode?.stop()
        }
        if clearQueue {
            queuedByteCount = 0
        }
        state = isMuted ? .muted : .idle
    }

    private func makeBuffer(fromPCM16 data: Data) -> AVAudioPCMBuffer? {
        guard let format = playbackFormat else { return nil }
        let frameCount = data.count / MemoryLayout<Int16>.size
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(frameCount)
              ),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for index in 0..<frameCount {
                channel[index] = Float(Int16(littleEndian: samples[index])) / Float(Int16.max)
            }
        }
        return buffer
    }
}

enum RealtimeTranslatedAudioPlayerError: Error {
    case unsupportedFormat
}
