# Product Requirements Document — Meeting Translator Pro

**Version:** 2.6
**Last Updated:** 2026-05-14
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
| **OpenAI (Whisper + GPT)** | 10–15s | Highest | Medium | Legacy fallback: `gpt-4o-mini-transcribe` for STT, `gpt-4o-mini` for translation |
| **Gemini 2.5 Flash** | 3–5s | High | Low | Single API call: transcription + translation in one request |
| **Gemini 3.1 Flash Live** | <1s | Good | Lowest | WebSocket streaming: real-time STT via `inputAudioTranscription`, then separate translation |
| **OpenAI Realtime (Recommended)** | <1s target | High | Medium | WebSocket sessions using `gpt-realtime-whisper` transcript deltas for caption-first live text, with `gpt-realtime-2` reserved for dialog/assistant understanding and gated `gpt-realtime-translate` plus a Whisper source-caption sidecar for explicit live interpreter mode |

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

The current realtime route is caption-first unless the paid interpreter invariant is fully satisfied. Caption-only OpenAI Realtime uses `gpt-realtime-whisper` transcript deltas so grey/live text appears while the user is still speaking. `gpt-realtime-2` is reserved for dialog understanding and future approval-gated assistant features. Realtime translation uses `gpt-realtime-translate` only when translations are visible, exactly one source language is pinned, source and target differ, and the explicit interpreter-session gate is enabled. In M7, source captions are still proven by a paired `gpt-realtime-whisper` source-caption sidecar because live provider probes showed translation output events from `gpt-realtime-translate` but did not consistently emit source transcript events.

Cost-driven model choice: realtime captions use `gpt-realtime-whisper` at about `$1.02/hour/source`; translation output uses `gpt-realtime-translate` at about `$2.04/hour/source`; M7 live interpreter with source captions runs both and is about `$3.06/hour/source`. `gpt-realtime-2` is token-metered and roughly `$5.76/hour` for one hour of user audio plus one hour of assistant audio, so it should not be the default translation engine.

Readability rule: Realtime provider final items are transport chunks, not guaranteed sentence boundaries. The app keeps live partials visible, then merges nearby same-source `gpt-realtime-whisper` finals into readable utterance rows, filters unstable tiny fragments, and lets CJK row text wrap naturally instead of inserting manual newlines.

Settings rule: when `OpenAI Realtime (Recommended)` is selected, Settings separates `Realtime Captions`, `Live Interpretation`, `Display Behavior`, `Audio Input Filter`, and optional `Speaker Recognition`. Legacy Whisper + GPT fast/stitch timing lives under `Legacy Fallback Controls` so users do not mistake those intervals for `gpt-realtime-whisper` controls.

### 3.12 Realtime Feature PRD Map

Realtime work is now split into explicit feature PRDs so future agents do not blur captions, interpretation, settings, and speaker labels:

| PRD | Status | Product boundary |
|---|---|---|
| `docs/prd_feat_openai_realtime_caption_delta_first.md` | Implemented/hardening | `gpt-realtime-whisper` source captions while speech is still arriving. |
| `docs/prd_feat_openai_realtime_translate_interpreter.md` | Implemented and provider-verified | Same-time translated subtitles with `gpt-realtime-translate`; Whisper is only a source-caption audit sidecar. |
| `docs/prd_feat_realtime_translated_audio_playback.md` | Implemented and verified | Safe preview translated audio playback from `gpt-realtime-translate` output audio, gated by explicit opt-in, interpreter gates, ScreenCaptureKit exclusion, and route-aware headphone/non-speaker safety. |
| `docs/prd_feat_realtime_settings_runtime_clarity.md` | Implemented locally | Settings panel reflects actual Realtime runtime controls and hides legacy Whisper + GPT timing under Realtime. |
| `docs/prd_feat_realtime_speaker_recognition_sidecar.md` | Implemented as off-by-default delayed sidecar foundation | Optional delayed speaker labels through a diarization sidecar; not part of realtime translation core. |
| `docs/prd_feat_openai_realtime_translation_next_stage.md` | Historical/superseded | Retained for earlier probe notes only; do not use as completion proof. |

Same-time interpretation decision: `gpt-realtime-translate` is the interpreter model. `gpt-realtime-whisper` may run beside it only to provide original-language captions and export/audit text. `gpt-realtime-2` remains reserved for future voice-agent or meeting-assistant workflows.

Translated audio playback decision: M8 safe preview playback uses only `gpt-realtime-translate` output audio from `/v1/realtime/translations`. Playback remains off by default and cannot be enabled by the old placeholder preference key. Runtime passes `translatedAudioPlaybackEnabled: true` only after explicit user opt-in, Realtime interpreter gates, ScreenCaptureKit current-process audio exclusion support, and microphone/output safety all pass. When the microphone is active, CoreAudio route inspection blocks likely speakers, display audio, HDMI/DisplayPort, AirPlay, aggregate/multi-output routes, and unrecognized outputs regardless of stale confirmation state. Safe-output confirmation is bound to the current route fingerprint and may unlock only positive headphone-like routes. Room-speaker safety is not claimed; Settings tells users to use headphones or a confirmed non-speaker output. The main window exposes a headphones control when the interpreter route is eligible; clicking it is the explicit opt-in that confirms the current headphone-like output route and enables translated audio, keeping it visually separate from the purple system-audio capture level meter.

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
3. **Transcription List:** Scrollable timeline of `TranscriptionRowView` cards, each showing timestamp, speaker badge, language tag, original text, and translation bubble. Live draft text updates without implicit layout animation, so grey interim text grows downward instead of visually vibrating the timeline.
4. **Control Bar:** Start/Stop button, audio level indicators, follow-latest captions toggle, translation toggle, export button, clear button, entry count

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
| `com.meetingtranslator.engine` | String | "OpenAI Realtime (Recommended)" | Selected engine for fresh installs; existing saved user preference is preserved |
| `com.meetingtranslator.showtranslations` | Bool | true | Translation display toggle |
| `com.meetingtranslator.followlatestcaptions` | Bool | true | Timeline auto-follow toggle; when false, new captions do not force the scroll position to the bottom |
| `com.meetingtranslator.fastinterval` | Double | 3.0 | Fast draft interval (seconds) |
| `com.meetingtranslator.stitchinterval` | Double | 15.0 | Stitch pass interval (seconds) |
| `com.meetingtranslator.geminiquality` | Double | 12.0 | Gemini quality pass interval |
| `com.meetingtranslator.noisegate` | Double | 0.003 | Shared RMS input-filter threshold applied before all engine routes |
| `com.meetingtranslator.inputlanguages` | [String] | [] | Expected input languages |
| `com.meetingtranslator.realtime.captionlatency` | String | "Balanced" | OpenAI Realtime caption latency preset |
| `com.meetingtranslator.realtime.reasoningeffort` | String | "low" | `gpt-realtime-2` effort setting; kept low for live caption latency |
| `com.meetingtranslator.realtime.interpretersessionenabled` | Bool | false | Explicit M7 live interpreter session gate for `gpt-realtime-translate` |
| `com.meetingtranslator.realtime.translatedaudioplayback.m8.enabled` | Bool | false | Explicit safe-preview translated-audio playback opt-in; old placeholder key is ignored |
| `com.meetingtranslator.realtime.translatedaudioplayback.m8.muted` | Bool | false | Local translated-audio mute state |
| `com.meetingtranslator.realtime.translatedaudioplayback.m8.volume` | Double | 0.65 | Local translated-audio playback volume |
| `com.meetingtranslator.realtime.translatedaudioplayback.m8.safeoutput` | Bool | false | Headphones/non-speaker output confirmation; likely speaker or display routes are blocked while mic capture is active |
| `com.meetingtranslator.realtime.translatedaudioplayback.m8.safeoutputroute` | String? | nil | Fingerprint of the exact default output route that was confirmed safe; cleared on route mismatch or safety downgrade |
| `com.meetingtranslator.realtime.automaticfallback` | Bool | true | Switch to legacy OpenAI after bounded transient Realtime retry is exhausted |
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

- **Speaker diarization in the realtime core:** The app does not distinguish between different remote speakers inside the live caption/interpreter route. Optional delayed labels are a separate off-by-default sidecar using `gpt-4o-transcribe-diarize` through `/v1/audio/transcriptions`.
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
| 2026-05-13 | 2.3 | Added canonical Realtime Translate interpreter PRD, Settings clarity PRD, and delayed speaker-recognition sidecar PRD. |
| 2026-05-13 | 2.4 | Implemented local M7 route gates, output-first row cleanup, split Realtime Settings sections, and off-by-default delayed speaker-label metadata/matching. |
| 2026-05-13 | 2.5 | Verified the full realtime mission runner with synthetic `gpt-realtime-whisper`, `gpt-realtime-translate`, and `gpt-realtime-2` provider probes; hardened the probe harness to avoid optional Python WebSocket/audio dependencies. |
| 2026-05-14 | 2.6 | Added main-window headphones activation for M8 translated audio so users can confirm the current safe output route without confusing it with system-audio capture. |
