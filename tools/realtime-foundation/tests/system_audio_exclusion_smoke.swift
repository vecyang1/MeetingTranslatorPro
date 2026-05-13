import Foundation
import ScreenCaptureKit

@main
struct SystemAudioExclusionSmoke {
    static func main() {
        let enabled = SystemAudioManager.makeStreamConfiguration(excludeCurrentProcessAudio: true)
        precondition(enabled.capturesAudio)
        precondition(enabled.sampleRate == 16_000)
        precondition(enabled.channelCount == 1)
        if #available(macOS 13.0, *) {
            precondition(enabled.excludesCurrentProcessAudio)
        }

        let disabled = SystemAudioManager.makeStreamConfiguration(excludeCurrentProcessAudio: false)
        if #available(macOS 13.0, *) {
            precondition(!disabled.excludesCurrentProcessAudio)
        }

        precondition(SystemAudioManager.currentProcessAudioExclusionSupported)
        print("system audio exclusion smoke ok")
    }
}
