# Agent Principles — Meeting Translator Pro

> **READ THIS FILE FIRST** before making any changes to the codebase.
> This document captures hard-won design decisions and constraints.
> Violating these principles will cause regressions, broken builds, or user frustration.

---

## 1. Code Signing — DO NOT Break It

The app is signed with the developer's identity. **Never** modify `build_app.sh`, entitlements, `Info.plist`, or the bundle structure in ways that would invalidate the signature. The user must not be prompted to re-grant permissions (Microphone, Screen Recording) after a rebuild. If you change the bundle identifier, signing identity, or entitlements, the user will have to re-authorize everything in System Settings.

**Rule:** Keep the signing configuration identical unless the user explicitly asks to change it.

---

## 2. Translation Toggle (`showTranslations`) Gates Everything

The `showTranslations` flag in `AppState` is not just a UI visibility toggle — it controls whether translation API calls are made at all. This is intentional for two reasons:

- **Cost savings:** Translation API calls cost money. When the user disables translations, no translation requests should be sent.
- **Performance:** Skipping translation reduces latency and processing load, especially during live meetings.

**All translation paths must check `showTranslations` before calling the translation service:**

| Engine | Fast Draft (Layer 1) | Quality/Stitch (Layer 2) |
|---|---|---|
| OpenAI | `processOpenAIFast` — check `needsTranslation = !sameLanguage && showTranslations` | `processStitchLayerWithData` — same pattern |
| Gemini Flash | `processGeminiFast` — check `useTranslation = !sameLanguage && showTranslations` | `processGeminiQualityLayerWithData` — same pattern |
| Gemini Live | `handleGeminiLiveResult` — check `needsTranslation = !sameLanguage && showTranslations` | N/A (no Layer 2) |

**Rule:** If you add a new translation path, gate it behind `!sameLanguage && showTranslations`.

---

## 3. Same-Language Suppression — Two Layers of Defense

When the detected language matches the output target language, the user sees duplicate text (original + identical "translation"). This is prevented at **two levels**:

1. **Backend (AppState):** The `isSameLanguage()` check prevents translation API calls when languages match. Translation result is set to `nil`.
2. **Frontend (TranscriptionRowView):** The `isSameAsTarget` computed property hides the translation bubble even if a `translatedText` value somehow exists.

Both layers are necessary. The backend layer saves API costs. The frontend layer is a safety net for edge cases (e.g., Gemini Flash returns translation in the same API call regardless).

**Rule:** Never remove either layer. If the detected language matches the target, the user should see only the original text.

---

## 4. Architecture — Two-Layer Pipeline

The app uses a two-layer transcription pipeline:

- **Layer 1 (Fast Draft):** Quick, low-latency transcription every `fastInterval` seconds. Entries are marked `isDraft: true`.
- **Layer 2 (Stitch/Quality):** Higher-quality pass on accumulated audio every `stitchInterval` / `geminiQualityInterval` seconds. Replaces draft entries with `isQualityResult: true` entries.

**Rule:** Draft entries are ephemeral. Quality entries replace them. Never treat drafts as final output.

---

## 5. Gemini Flash — Translation Is Embedded in the API Call

For the Gemini Flash engine, transcription and translation happen in a **single API call** (`transcribeAndTranslate`). The translation result comes back from the API regardless of whether the user wants it. The gating happens at the **entry creation** level — we set `translatedText` to `nil` when translation is not needed.

This is different from OpenAI, where transcription (Whisper) and translation (GPT) are separate API calls, and we can skip the translation call entirely.

**Rule:** For Gemini Flash, you cannot avoid the translation cost at the API level. Only suppress it at the display/entry level.

---

## 6. `SupportedLanguage.allISOCodes` — Handle Language Variants

Chinese has multiple ISO codes (`zh`, `cmn`, `yue`, `wuu`). The `allISOCodes` property on `SupportedLanguage` maps all variants to the canonical language. Always use `allISOCodes` (via `isSameLanguage()`) for comparison, never compare raw ISO codes directly.

**Rule:** Use `isSameLanguage(detected:target:)` or `targetLanguage.allISOCodes.contains(code)` for language matching.

---

## 7. Build Process

```bash
# Quick build (recommended)
chmod +x build_app.sh
./build_app.sh

# The built app is at: build/Meeting Translator.app
```

The build script handles SDK detection, compilation, bundling, and code signing. Do not bypass it unless debugging a specific build issue.

---

## 8. State Persistence

User settings are persisted via `UserDefaults` with keys prefixed `com.meetingtranslator.*`. The `saveSettings()` method in `AppState` writes all settings and updates service API keys. Always call `saveSettings()` after changing any persisted setting.

---

## 9. Hallucination Detection

Whisper and Gemini can produce hallucinated text (e.g., "Thank you for watching", repeated characters, YouTube-style subtitles). The `isHallucination()` method in `AppState` filters these out. If you encounter new hallucination patterns, add them to `hallucinationExactSet` or `hallucinationPrefixSet`.

**Rule:** All transcription results must pass through `isHallucination()` before being added to entries.

---

## 10. Echo / Duplicate Suppression

When both microphone and system audio are enabled, the user's voice can be captured twice: once directly by the mic, and once by system audio (speaker loopback). This produces near-duplicate transcription entries.

The app uses **post-transcription deduplication** via character-bigram Dice coefficient similarity. Before any new entry is appended, `isDuplicateOfRecent()` checks if the text is >70% similar to any entry from the last 15 seconds. If so, the new entry is silently dropped.

**Where it's applied:**
- Layer 1 Fast Draft (OpenAI and Gemini Flash)
- Gemini Live handler

**Where it's NOT applied (intentionally):**
- Layer 2 Stitch/Quality passes — these replace draft entries and are expected to produce similar text.

**Rule:** Do not apply echo dedup to Layer 2 passes. Do not lower the threshold below 0.60 or you'll start dropping legitimately similar but different sentences. Do not raise it above 0.85 or echo duplicates will slip through.

---

## 11. Memory & Safety Guards

- **Buffer cap:** Audio buffers are capped at ~60s (`maxBufferBytes`) to prevent unbounded memory growth.
- **Entry cap:** Maximum 500 entries in memory (`maxEntries`). Oldest confirmed entries are trimmed.
- **Circuit breaker:** After 5 consecutive errors, the pipeline pauses for 10 seconds before retrying.
- **Noise gate:** Audio chunks below `noiseGateThreshold` RMS energy are silently skipped.

**Rule:** Do not remove these safety guards. Long meetings can run for hours.

---

## 12. Project Structure

```
MeetingTranslatorPro/
├── AGENTS.md                    # THIS FILE — read first
├── README.md                    # User-facing readme
├── build_app.sh                 # Build + sign + install script
├── MeetingTranslator.entitlements
├── Info.plist
├── docs/
│   ├── PRD.md                   # Product requirements document
│   └── API.md                   # Internal & external API reference
├── Resources/
│   └── AppIcon.png              # 1024x1024 source icon (used by build_app.sh)
├── Sources/MeetingTranslator/
│   ├── MeetingTranslatorApp.swift  # Entry point (SwiftUI App)
│   ├── Models/
│   │   ├── TranscriptionEntry.swift  # Timeline entry model
│   │   └── AppSettings.swift         # SupportedLanguage, TranscriptionEngine enums
│   ├── Managers/
│   │   ├── AppState.swift            # Central orchestrator (~1200 lines)
│   │   ├── MicrophoneManager.swift   # AVAudioEngine mic capture
│   │   └── SystemAudioManager.swift  # ScreenCaptureKit system audio
│   ├── Services/
│   │   ├── WhisperService.swift      # OpenAI Whisper transcription
│   │   ├── TranslationService.swift  # GPT translation
│   │   ├── GeminiFlashService.swift  # Gemini Flash REST API
│   │   ├── GeminiLiveService.swift   # Gemini Live WebSocket
│   │   └── CostTracker.swift         # Usage cost tracking
│   └── Views/
│       ├── ContentView.swift         # Main UI
│       ├── TranscriptionRowView.swift # Single entry row
│       └── SettingsView.swift        # Settings panel
└── build/                            # Build artifacts (gitignored)
```

---

## 13. Build & Install Workflow

The `build_app.sh` script does everything:
1. Detects macOS SDK path
2. Compiles all Swift sources with `swiftc`
3. Creates `.app` bundle with `Info.plist`, entitlements, icon
4. Generates `.icns` from `Resources/AppIcon.png` (resizes to all required sizes)
5. Signs with Apple Development certificate
6. Copies to `/Applications/MeetingTranslator.app`

**After any code change, always run `./build_app.sh` to rebuild and install.** The app at `/Applications/MeetingTranslator.app` is the user's primary launch target.

**Icon:** If regenerating the icon, save the 1024x1024 source to `Resources/AppIcon.png`. The build script handles all size variants and `.icns` creation. Ensure the icon fills the entire square canvas (no transparent padding that would cause cropping).

---

## 14. Entry Processing Pipeline Order

Every transcription result passes through these checks **in order** before being added to `entries`. Skipping or reordering will cause bugs:

1. **Empty check** — `text.isEmpty` guard
2. **Hallucination filter** — `isHallucination(text)` guard
3. **Overlap dedup** — `removeDuplicatePrefix()` against `lastConfirmedText`
4. **Echo dedup** — `isDuplicateOfRecent(text)` guard (Layer 1 and Gemini Live only)
5. **Language detection** — `isSameLanguage()` check
6. **Translation gating** — `!sameLanguage && showTranslations`
7. **Entry creation** — `TranscriptionEntry(...)` with appropriate fields
8. **Append** — `entries.append(entry)`

**Rule:** When adding new processing steps, insert them at the correct position in this pipeline. Translation should never happen before dedup checks.

---

## 15. OpenAI Realtime Voice Invariants

OpenAI Realtime is the preferred new live path, but the app must keep the existing OpenAI Whisper+GPT, Gemini Flash, and Gemini Live engines selectable.

**Architecture boundary:**
- `OpenAIRealtimeCoordinator` owns realtime service lifecycle, routing, reducer state, and source-aware session maps.
- `OpenAIRealtime*Service` files own WebSocket setup and raw event parsing.
- `RealtimeEventReducer` accumulates partial deltas by `(source, itemID)`.
- `AppState` confirms entries through the existing empty, hallucination, overlap, echo dedup, language, and translation gates.

**Cost/privacy gate:**
- Never start or maintain `gpt-realtime-translate` unless translation UI is visible, translated-audio playback is enabled, and the app knows the source language is different from the target.
- Translation-off and same-language modes must route to `gpt-realtime-whisper`, not a translation session.
- Auto-detect input and text-only translation are treated as transcription-first; translate final non-same text only after detection.
- Log realtime audio duration cost only after an audio chunk is accepted for sending by a ready session.

**Protocol notes verified 2026-05-10:**
- Transcription WebSocket URL: `wss://api.openai.com/v1/realtime?intent=transcription`.
- Put `gpt-realtime-whisper` in `session.update`, not in the transcription URL query.
- Translation WebSocket URL: `/v1/realtime/translations?model=gpt-realtime-translate`.
- A realtime session is ready only after `session.updated`; do not send user audio while still merely connected.

**Verification:**
- Use `tools/realtime-foundation/realtime-foundation probe --mode ...` for no-audio model checks.
- Audio probes require `--i-understand-audio-is-sent-to-openai` and must use synthetic or non-private fixtures.
- After any realtime code change, run `./build_app.sh`, `tools/realtime-foundation/tests/realtime_core_smoke.swift`, and at least synthetic OpenAI realtime transcription/translation probes when safe.
