# Meeting Translator Pro

A world-class, elegant macOS application for real-time meeting transcription and translation, powered by OpenAI Whisper and GPT-4o.


<img width="600" height="640" alt="Meeting Translator 2026-04-02 19 11 37" src="https://github.com/user-attachments/assets/365520b9-8aaf-4b37-b83a-494a5c801d51" />


<img width="480" height="760" alt="image" src="https://github.com/user-attachments/assets/9d642d45-52f3-4815-9a2f-ed5035aa1e70" />


<img width="480" height="760" alt="image" src="https://github.com/user-attachments/assets/030cd0cd-8fe4-40c5-a938-ce9daaa9628d" />



## Features

- **Dual Audio Capture**: Simultaneously captures your microphone (your voice) and system audio (meeting participants) using native macOS APIs
- **Real-time Transcription**: OpenAI Whisper API for accurate speech-to-text in 50+ languages
- **Instant Translation**: GPT-4o-mini powered translation to 16 supported languages
- **Native macOS Design**: Glassmorphic SwiftUI interface with vibrancy effects, smooth animations, and dark mode support
- **Audio Level Monitoring**: Real-time visual feedback for both mic and system audio levels
- **Export Transcripts**: Save complete meeting transcripts with timestamps, sources, and translations
- **Language Auto-Detection**: Whisper automatically detects the spoken language
- **Configurable Chunk Duration**: Adjust the audio buffering window (3-15 seconds) for speed vs. accuracy

## Architecture

```
MeetingTranslatorPro/
├── Package.swift
├── build_app.sh                    # Build & package script
├── Resources/
│   ├── Info.plist                  # App bundle configuration
│   └── MeetingTranslator.entitlements
└── Sources/MeetingTranslator/
    ├── MeetingTranslatorApp.swift   # App entry point
    ├── Models/
    │   ├── TranscriptionEntry.swift # Data model for entries
    │   └── AppSettings.swift        # Language & device models
    ├── Services/
    │   ├── WhisperService.swift     # OpenAI Whisper API client
    │   └── TranslationService.swift # OpenAI GPT translation client
    ├── Managers/
    │   ├── AppState.swift           # Central state orchestrator
    │   ├── MicrophoneManager.swift  # AVAudioEngine mic capture
    │   └── SystemAudioManager.swift # ScreenCaptureKit system audio
    └── Views/
        ├── ContentView.swift        # Main UI layout
        ├── SettingsView.swift       # Settings panel
        ├── TranscriptionRowView.swift # Entry row component
        ├── AudioLevelIndicator.swift  # Audio level bars
        └── VisualEffectBackground.swift # NSVisualEffectView wrapper
```

## Technology Stack

| Component | Technology |
|---|---|
| UI Framework | SwiftUI with NSVisualEffectView |
| Microphone Capture | AVAudioEngine (AVFoundation) |
| System Audio Capture | ScreenCaptureKit |
| Audio Device Enumeration | CoreAudio |
| Transcription | OpenAI Whisper API |
| Translation | OpenAI GPT-4o-mini |
| State Management | Combine + @MainActor |

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64) or Intel Mac
- OpenAI API key with Whisper and Chat access
- Microphone permission (for voice capture)
- Screen Recording permission (for system audio capture)

## Building

### Quick Build
```bash
chmod +x build_app.sh
./build_app.sh
```

The built app will be at `build/Meeting Translator.app`.

### Manual Build
```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macosx14.0 -parse-as-library \
  -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework ScreenCaptureKit -framework CoreAudio -framework AudioToolbox \
  -framework CoreMedia -framework Combine \
  -o MeetingTranslator \
  Sources/MeetingTranslator/**/*.swift
```

## Usage

1. **Launch** the app
2. **Configure** your OpenAI API key in Settings (gear icon)
3. **Select** your target translation language
4. **Enable/disable** Microphone and System Audio sources as needed
5. **Press Start** to begin real-time transcription and translation
6. **Export** your transcript when done

## Permissions

On first launch, macOS will request:

1. **Microphone Access** — Required for capturing your voice
2. **Screen Recording** — Required for ScreenCaptureKit to capture system audio (meeting sounds from Zoom, Teams, etc.)

Both permissions can be managed in **System Settings > Privacy & Security**.

## API Key

Your OpenAI API key is stored locally in UserDefaults and never transmitted anywhere except to OpenAI's API endpoints. You can pre-configure it via:

```bash
defaults write com.meetingtranslator.app com.meetingtranslator.apikey "sk-your-key-here"
```

## License

Personal use. All rights reserved.
