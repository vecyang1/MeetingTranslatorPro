import Foundation

@main
struct MicrophoneInputDeviceSmoke {
    static func main() {
        let devices = [
            AudioDevice(
                id: "BuiltInMicrophoneDevice",
                name: "MacBook Pro Microphone",
                isDefault: false,
                systemID: 111,
                uid: "BuiltInMicrophoneDevice"
            ),
            AudioDevice(
                id: "90-62-3F-9D-9B-C4:input",
                name: "Vy’s AirPods Max",
                isDefault: true,
                systemID: 161,
                uid: "90-62-3F-9D-9B-C4:input"
            )
        ]

        precondition(AudioInputDeviceSelection.resolvedDeviceID(preferredID: nil, devices: devices) == nil)
        precondition(
            AudioInputDeviceSelection.resolvedDeviceID(
                preferredID: "BuiltInMicrophoneDevice",
                devices: devices
            ) == "BuiltInMicrophoneDevice"
        )
        precondition(
            AudioInputDeviceSelection.resolvedDeviceID(
                preferredID: "missing-device",
                devices: devices
            ) == nil
        )

        var selectedID: String?
        var preferredIDs: [String?] = []
        var persistedIDs: [String?] = []
        var stopFlushFlags: [Bool] = []
        var startCount = 0

        let switched = try! MicrophoneInputDeviceSwitch.apply(
            currentID: selectedID,
            requestedID: "BuiltInMicrophoneDevice",
            isRecording: true,
            isMicEnabled: true,
            setSelectedDevice: { selectedID = $0 },
            setPreferredDevice: { preferredIDs.append($0) },
            persistSelection: { persistedIDs.append(selectedID) },
            stopCapturing: { stopFlushFlags.append($0) },
            startCapturing: { startCount += 1 }
        )
        precondition(switched.selectedID == "BuiltInMicrophoneDevice")
        precondition(switched.restartedCapture)
        precondition(selectedID == "BuiltInMicrophoneDevice")
        precondition(preferredIDs == ["BuiltInMicrophoneDevice"])
        precondition(persistedIDs == ["BuiltInMicrophoneDevice"])
        precondition(stopFlushFlags == [false])
        precondition(startCount == 1)

        let unchanged = try! MicrophoneInputDeviceSwitch.apply(
            currentID: selectedID,
            requestedID: "BuiltInMicrophoneDevice",
            isRecording: true,
            isMicEnabled: true,
            setSelectedDevice: { selectedID = $0 },
            setPreferredDevice: { preferredIDs.append($0) },
            persistSelection: { persistedIDs.append(selectedID) },
            stopCapturing: { stopFlushFlags.append($0) },
            startCapturing: { startCount += 1 }
        )
        precondition(!unchanged.changed)
        precondition(preferredIDs == ["BuiltInMicrophoneDevice"])
        precondition(stopFlushFlags == [false])
        precondition(startCount == 1)

        let changedWhileStopped = try! MicrophoneInputDeviceSwitch.apply(
            currentID: selectedID,
            requestedID: nil,
            isRecording: false,
            isMicEnabled: true,
            setSelectedDevice: { selectedID = $0 },
            setPreferredDevice: { preferredIDs.append($0) },
            persistSelection: { persistedIDs.append(selectedID) },
            stopCapturing: { stopFlushFlags.append($0) },
            startCapturing: { startCount += 1 }
        )
        precondition(changedWhileStopped.selectedID == nil)
        precondition(!changedWhileStopped.restartedCapture)
        precondition(selectedID == nil)
        precondition(preferredIDs == ["BuiltInMicrophoneDevice", nil])
        precondition(persistedIDs == ["BuiltInMicrophoneDevice", nil])
        precondition(stopFlushFlags == [false])
        precondition(startCount == 1)

        enum StartFailure: Error { case boom }
        selectedID = "BuiltInMicrophoneDevice"
        preferredIDs.removeAll()
        persistedIDs.removeAll()
        stopFlushFlags.removeAll()
        startCount = 0
        var shouldFailNextStart = true
        do {
            _ = try MicrophoneInputDeviceSwitch.apply(
                currentID: selectedID,
                requestedID: "90-62-3F-9D-9B-C4:input",
                isRecording: true,
                isMicEnabled: true,
                setSelectedDevice: { selectedID = $0 },
                setPreferredDevice: { preferredIDs.append($0) },
                persistSelection: { persistedIDs.append(selectedID) },
                stopCapturing: { stopFlushFlags.append($0) },
                startCapturing: {
                    startCount += 1
                    if shouldFailNextStart {
                        shouldFailNextStart = false
                        throw StartFailure.boom
                    }
                }
            )
            fatalError("expected restart failure")
        } catch {
            precondition(selectedID == "BuiltInMicrophoneDevice")
            precondition(preferredIDs == ["90-62-3F-9D-9B-C4:input", "BuiltInMicrophoneDevice"])
            precondition(persistedIDs == ["90-62-3F-9D-9B-C4:input", "BuiltInMicrophoneDevice"])
            precondition(stopFlushFlags == [false])
            precondition(startCount == 2)
        }

        let systemDefaultCopy = AudioInputDeviceSelection.displayName(
            preferredID: nil,
            activeDevice: devices[1],
            devices: devices
        )
        precondition(systemDefaultCopy.contains("System Default"))
        precondition(systemDefaultCopy.contains("Vy’s AirPods Max"))

        let selectedCopy = AudioInputDeviceSelection.displayName(
            preferredID: "BuiltInMicrophoneDevice",
            activeDevice: devices[0],
            devices: devices
        )
        precondition(selectedCopy == "MacBook Pro Microphone")

        let micManager = try! String(
            contentsOfFile: "Sources/MeetingTranslator/Managers/MicrophoneManager.swift",
            encoding: .utf8
        )
        precondition(micManager.contains("selectedInputDeviceID"))
        precondition(micManager.contains("kAudioOutputUnitProperty_CurrentDevice"))
        precondition(micManager.contains("stopCapturing(flushRemaining: Bool = true)"))
        precondition(micManager.contains("Thread.isMainThread"))

        let appState = try! String(
            contentsOfFile: "Sources/MeetingTranslator/Managers/AppState.swift",
            encoding: .utf8
        )
        precondition(appState.contains("selectedMicrophoneInputDeviceID"))
        precondition(appState.contains("setMicrophoneInputDevice"))
        precondition(appState.contains("microphoneInputShortName"))

        let settings = try! String(
            contentsOfFile: "Sources/MeetingTranslator/Views/SettingsView.swift",
            encoding: .utf8
        )
        precondition(settings.contains("Mic Input"))
        precondition(settings.contains("System Default"))

        let content = try! String(
            contentsOfFile: "Sources/MeetingTranslator/Views/ContentView.swift",
            encoding: .utf8
        )
        precondition(content.contains("microphoneInputShortName"))

        print("microphone input device smoke ok")
    }
}
