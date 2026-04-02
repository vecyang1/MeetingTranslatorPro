// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeetingTranslator",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MeetingTranslator",
            path: "Sources/MeetingTranslator",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
            ]
        )
    ]
)
