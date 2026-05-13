import Foundation

@main
struct SystemAudioExclusionRuntimeProbe {
    static func main() async {
        if #available(macOS 13.0, *) {
            do {
                let snapshot = try await SystemAudioCurrentProcessExclusionProbe.run()
                print("system audio current-process exclusion runtime probe ok \(snapshot.summary)")
            } catch {
                fputs("system audio current-process exclusion runtime probe failed: \(error.localizedDescription)\n", stderr)
                Foundation.exit(1)
            }
        } else {
            fputs("system audio current-process exclusion runtime probe failed: macOS 13+ required\n", stderr)
            Foundation.exit(1)
        }
    }
}
