# Product Requirements Document — Meeting Translator Pro

**Version:** 2.2
**Last Updated:** 2026-05-10
**Status:** Active Development
**Platform:** macOS 14.0+ (Sonoma)

---

## 1. Vision and Purpose

Meeting Translator Pro is a native macOS application that provides **real-time transcription and translation of meeting audio**. It captures both the user's microphone and system audio (from Zoom, Teams, Google Meet, etc.) simultaneously, transcribes speech to text, detects the spoken language, and translates it into the user's chosen output language — all in real time.

The core value proposition is enabling multilingual meeting participation without requiring all participants to speak the same language. A Chinese-speaking engineer can follow an English meeting in real time, or vice versa, with minimal latency and high accuracy.

---

## 2. Target Users

Meeting Translator Pro serves professionals who regularly participate in multilingual meetings, including international business teams, remote workers collaborating across language barriers, interpreters seeking a real-time reference, and language learners who want to follow native-speed conversations. The app is designed for single-user desktop use on macOS, running alongside video conferencing applications.

---

## 3. Core Features

### 3.1 Dual Audio Capture

The app captures audio from two independent sources simultaneously:

| Source | Technology | Purpose |
|---|---|---|
| Microphone | AVAudioEngine (AVFoundation) | Captures the user's own voice |
| System Audio | ScreenCaptureKit | Captures all system audio (meeting participants via Zoom, Teams, etc.) |

Both sources produce 16-bit PCM audio at 16kHz mono, chunked at 1-second intervals and fed into the transcription pipeline.

### 3.2 Multi-Engine Transcription

Four transcription engines are supported, each with different latency/accuracy/cost trade-offs:

| Engine | Latency | Accuracy | Cost | Architecture |
|---|---|---|---|---|
| **OpenAI (Whisper + GPT)** | 10–15s | Highest | Medium | Two-step: `gpt-4o-mini-transcribe` for STT, `gpt-4o-mini` for translation |
| **Gemini 2.5 Flash** | 3–5s | High | Low | Single API call: transcription + translation in one request |
| **Gemini 3.1 Flash Live** | <1s | Good | Lowest | WebSocket streaming: real-time STT via `inputAudioTranscription`, then separate translation |
| **OpenAI Realtime (Recommended)** | <1s target | High | Medium | WebSocket sessions using `gpt-realtime-2` for direct live captions/dialog understanding, with gated `gpt-realtime-translate` only for explicit translated-audio interpretation |

### 3.3 Two-Layer Pipeline

To balance speed and accuracy, the app uses a two-layer pipeline:

**Layer 1 — Fast Draft:** Every `fastInterval` seconds (default 3s), the accumulated audio buffer is sent for quick transcription. Results appear immediately as draft entries (marked with an orange "draft" badge and spinner). This gives the user near-instant feedback.

**Layer 2 — Quality/Stitch Pass:** Every `stitchInterval` seconds (default 15s for OpenAI, 12s for Gemini Flash), a longer audio window is re-transcribed at higher quality. The quality result replaces all draft entries from that time window, producing cleaner, more coherent text. Quality entries are marked with `isQualityResult: true`.

This architecture means the user sees fast but rough text within seconds, which is then silently replaced by polished text a few seconds later.

### 3.4 Translation

Translation is triggered only when:
1. The detected language differs from the output target language (`isSameLanguage` check)
2. The user has translations enabled (`showTranslations` toggle)

When both conditions are met, the translation service is called. For OpenAI, this is a separate GPT-4o-mini API call. For Gemini Flash, translation is embedded in the same API call as transcription (but the result is suppressed at the entry level if not needed). For Gemini Live, translation uses a separate GPT call after the WebSocket delivers the transcription.

When translations are disabled, **no translation API calls are made**, saving cost and reducing latency.

### 3.5 Same-Language Suppression

When the detected language matches the output language (e.g., speaking Chinese with output set to Chinese), the translation bubble is hidden at two levels:

1. **Backend:** `AppState` sets `translatedText` to `nil` and skips the translation API call
2. **Frontend:** `TranscriptionRowView` checks `isSameAsTarget` and hides the translation bubble

This prevents the user from seeing duplicate identical text.

### 3.6 Language Support

The app supports 16 output languages with auto-detection of 50+ input languages:

| Language | ISO Code | Flag |
|---|---|---|
| English | en | US |
| Chinese (Simplified) | zh | CN |
| Japanese | ja | JP |
| Korean | ko | KR |
| Spanish | es | ES |
| French | fr | FR |
| German | de | DE |
| Portuguese | pt | BR |
| Russian | ru | RU |
| Arabic | ar | SA |
| Hindi | hi | IN |
| Italian | it | IT |
| Dutch | nl | NL |
| Turkish | tr | TR |
| Thai | th | TH |
| Vietnamese | vi | VN |

Input language can be set to "Auto-Detect" (default) or pinned to a specific language for stronger accuracy hints.

### 3.7 Cost Tracking

Every API call is logged with estimated cost based on current pricing. The `CostTracker` service maintains both session and all-time cost totals, displayed in the title bar during recording.

### 3.8 Hallucination Detection

Whisper and Gemini models can produce hallucinated text (e.g., "Thank you for watching", repeated characters, YouTube-style subtitles). The `isHallucination()` method in `AppState` filters these using:
- Exact-match blocklist (common hallucination phrases in multiple languages)
- Prefix-match blocklist
- Repeated character detection (>85% same character)
- Repeated n-gram detection (same phrase repeated 3+ times)
- Minimum content check (must contain actual alphanumeric or CJK characters)

### 3.9 Echo / Duplicate Suppression

When both microphone and system audio are active, the user's voice is captured twice: directly by the mic, and via system audio loopback (speakers). This produces near-duplicate transcription entries a few seconds apart.

The app applies **post-transcription deduplication** using character-bigram Dice coefficient similarity. Before any new Layer 1 entry is appended, `isDuplicateOfRecent()` checks if the text is >70% similar to any entry from the last 15 seconds. If so, the new entry is silently dropped.

| Parameter | Value | Rationale |
|---|---|---|
| Similarity threshold | 0.70 (70%) | Balances catching echoes vs. preserving legitimately similar sentences |
| Lookback window | 15 seconds | Covers the lag between mic capture and system audio capture |
| Algorithm | Character-bigram Dice coefficient | Language-agnostic — works for CJK, Latin, Arabic, etc. |

**Scope:**
- Applied to Layer 1 Fast Draft (OpenAI and Gemini Flash) and Gemini Live handler
- **Not** applied to Layer 2 Stitch/Quality passes, which replace drafts and are expected to produce similar text

### 3.10 Safety Guards

| Guard | Threshold | Purpose |
|---|---|---|
| Buffer cap | 60s of audio (~1.92MB) | Prevents unbounded memory growth |
| Entry cap | 500 entries | Trims oldest confirmed entries |
| Circuit breaker | 5 consecutive errors | Pauses pipeline for 10s |
| Noise gate | 0.003 RMS (configurable) | Skips near-silent chunks |
| Retry with backoff | 2 retries, exponential | Handles transient API failures |

### 3.11 OpenAI Realtime Voice Foundation

The OpenAI Realtime feature PRD lives at `docs/prd_feat_openai_realtime_voice_foundation.md`. The implemented foundation adds:

- A reusable skill at `.agents/skills/openai-realtime-voice-foundation` with symlinks for Claude and Gemini agents.
- A CLI at `tools/realtime-foundation/realtime-foundation` for model routing, model probes, explicit synthetic audio probes, and Swift scaffolding.
- Native Swift services under `Sources/MeetingTranslator/Services/OpenAIRealtime/`.
- A coordinator boundary so `AppState` remains responsible for app orchestration and entry confirmation, not raw Realtime protocol parsing.

Realtime translation sessions are stricter than ordinary text translation: they start only when translations are visible, the input language is explicitly pinned to a different language than the output, and translated-audio playback is enabled. Auto-detect and text-only translation start as realtime transcription first; final non-same text can still use the existing GPT text translation path after language detection.

---

## 4. Architecture

```
MeetingTranslatorPro/
├── AGENTS.md                        # Key principles for AI agents
├── docs/
│   ├── PRD.md                       # This document
│   └── API.md                       # Internal API reference
├── build_app.sh                     # Build, bundle, sign script
├── Package.swift                    # Swift Package manifest
├── Resources/
│   ├── Info.plist                   # App bundle metadata
│   ├── MeetingTranslator.entitlements
│   └── AppIcon.png                  # App icon source (1024x1024)
└── Sources/MeetingTranslator/
    ├── MeetingTranslatorApp.swift   # @main entry point
    ├── Models/
    │   ├── TranscriptionEntry.swift # Data model for timeline entries
    │   └── AppSettings.swift        # Enums: engine, language, device
    ├── Services/
    │   ├── WhisperService.swift     # OpenAI gpt-4o-mini-transcribe client
    │   ├── TranslationService.swift # OpenAI GPT-4o-mini translation client
    │   ├── GeminiFlashService.swift # Gemini 2.5 Flash REST client
    │   ├── GeminiLiveService.swift  # Gemini 3.1 Flash Live WebSocket client
    │   └── CostTracker.swift        # API cost estimation and logging
    ├── Managers/
    │   ├── AppState.swift           # Central state orchestrator (~1150 lines)
    │   ├── MicrophoneManager.swift  # AVAudioEngine microphone capture
    │   └── SystemAudioManager.swift # ScreenCaptureKit system audio capture
    └── Views/
        ├── ContentView.swift        # Main window layout
        ├── SettingsView.swift       # Settings panel
        ├── TranscriptionRowView.swift # Individual entry card
        ├── AudioLevelIndicator.swift  # Real-time audio level bars
        └── VisualEffectBackground.swift # NSVisualEffectView wrapper
```

### Data Flow

```
Microphone ──► MicrophoneManager ──► PCM chunks ──┐
                                                    ├──► AppState.routeAudioChunk()
System Audio ► SystemAudioManager ► PCM chunks ──┘         │
                                                            ├── OpenAI path:
                                                            │   ├── Layer 1: WhisperService.transcribe()
                                                            │   │   └── TranslationService.translate()
                                                            │   └── Layer 2: WhisperService.transcribe()
                                                            │       └── TranslationService.translate()
                                                            ├── Gemini Flash path:
                                                            │   ├── Layer 1: GeminiFlashService.transcribeAndTranslate()
                                                            │   └── Layer 2: GeminiFlashService.transcribeAndTranslate()
                                                            └── Gemini Live path:
                                                                ├── GeminiLiveService.sendAudio() [WebSocket]
                                                                └── TranslationService.translate()
                                                                        │
                                                                        ▼
                                                            TranscriptionEntry ──► TranscriptionRowView
```

---

## 5. User Interface

The UI follows a **glassmorphic design** using macOS vibrancy effects (`NSVisualEffectView`). The window has four sections:

1. **Title Bar:** App name, engine badge, status indicator, processing count, recording timer, session cost
2. **Language Bar:** Input language selector (auto-detect or pinned) + output language selector + swap button
3. **Transcription List:** Scrollable timeline of `TranscriptionRowView` cards, each showing timestamp, speaker badge, language tag, original text, and translation bubble
4. **Control Bar:** Start/Stop button, audio level indicators, translation toggle, export button, clear button, entry count

---

## 6. Permissions

| Permission | API | Purpose | Required |
|---|---|---|---|
| Microphone | AVAudioEngine | Capture user's voice | Yes (for mic input) |
| Screen Recording | ScreenCaptureKit | Capture system audio | Yes (for meeting audio) |
| Network | URLSession / WebSocket | API calls to OpenAI/Google | Yes |

Permissions are requested on first launch and persisted via macOS TCC database. The app is code-signed with an Apple Development certificate to ensure permissions survive rebuilds.

---

## 7. Configuration and Persistence

All user settings are stored in `UserDefaults` under the `com.meetingtranslator.*` namespace:

| Key | Type | Default | Description |
|---|---|---|---|
| `com.meetingtranslator.apikey` | String | "" | OpenAI API key |
| `com.meetingtranslator.googleapikey` | String | "" | Google Gemini API key |
| `com.meetingtranslator.targetlang` | String | "English" | Output language |
| `com.meetingtranslator.engine` | String | "OpenAI Whisper + GPT" | Selected engine |
| `com.meetingtranslator.showtranslations` | Bool | true | Translation display toggle |
| `com.meetingtranslator.fastinterval` | Double | 3.0 | Fast draft interval (seconds) |
| `com.meetingtranslator.stitchinterval` | Double | 15.0 | Stitch pass interval (seconds) |
| `com.meetingtranslator.geminiquality` | Double | 12.0 | Gemini quality pass interval |
| `com.meetingtranslator.noisegate` | Double | 0.003 | RMS noise gate threshold |
| `com.meetingtranslator.inputlanguages` | [String] | [] | Expected input languages |
| `com.meetingtranslator.realtime.captionlatency` | String | "Balanced" | OpenAI Realtime caption latency preset |
| `com.meetingtranslator.realtime.reasoningeffort` | String | "low" | `gpt-realtime-2` effort setting; kept low for live caption latency |
| `com.meetingtranslator.realtime.translatedaudioplayback` | Bool | false | Reserved translated-audio playback toggle |
| `com.meetingtranslator.realtime.automaticfallback` | Bool | true | Switch to legacy OpenAI after recoverable realtime failure |
| `com.meetingtranslator.totalcost` | Double | 0.0 | All-time API cost |

---

## 8. Build and Distribution

The app is built using a custom shell script (`build_app.sh`) that:
1. Compiles all Swift sources with `swiftc` targeting `arm64-apple-macosx14.0`
2. Creates the `.app` bundle structure with `Info.plist`, `PkgInfo`, and icon
3. Signs with the Apple Development certificate (preserves permissions across rebuilds)

```bash
# Build and install
chmod +x build_app.sh
./build_app.sh
```

The app is distributed as a local build, not through the App Store. The bundle identifier is `com.meetingtranslator.app`.

---

## 9. Non-Goals

The following are explicitly out of scope for the current version:

- **Speaker diarization:** The app does not distinguish between different remote speakers (all system audio is attributed to "Speaker")
- **Offline mode:** All transcription and translation requires internet connectivity and API keys
- **App Store distribution:** The app uses non-sandboxed entitlements for ScreenCaptureKit access
- **iOS/iPadOS support:** macOS only, due to ScreenCaptureKit and AVAudioEngine dependencies
- **Recording/playback:** The app does not save audio files; only text transcripts can be exported

---

## 10. Revision History

| Date | Version | Changes |
|---|---|---|
| 2026-04-02 | 1.0 | Initial release with OpenAI Whisper + GPT engine |
| 2026-04-02 | 1.5 | Added Gemini Flash and Gemini Live engines, two-layer pipeline, input language selector |
| 2026-04-03 | 2.0 | Same-language suppression, translation toggle gates API calls, AGENTS.md, PRD/API docs |
| 2026-04-03 | 2.1 | Echo/duplicate suppression via character-bigram Dice coefficient deduplication |
| 2026-05-10 | 2.2 | Added OpenAI Realtime foundation: skill/CLI, native Swift services, gated translation sessions, and runtime probes |
