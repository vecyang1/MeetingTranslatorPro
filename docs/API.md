# Internal API Reference — Meeting Translator Pro

**Version:** 2.4
**Last Updated:** 2026-05-13

This document describes the internal service APIs, data models, and external API integrations used by Meeting Translator Pro. It is intended for developers and AI agents working on the codebase.

---

## 1. External API Integrations

### 1.1 OpenAI Audio Transcription API

**Service:** `WhisperService`
**Model:** `gpt-4o-mini-transcribe`
**Endpoint:** `POST https://api.openai.com/v1/audio/transcriptions`
**Cost:** $0.003 per minute of audio

This is a multipart form-data endpoint that accepts WAV audio and returns transcribed text.

**Request Parameters:**

| Field | Type | Required | Description |
|---|---|---|---|
| `file` | Binary (WAV) | Yes | Audio file, 16-bit PCM, 16kHz mono |
| `model` | String | Yes | Always `gpt-4o-mini-transcribe` |
| `response_format` | String | Yes | Always `json` (NOT `verbose_json`) |
| `language` | String | No | ISO 639-1 code. Strongest hint — skips language detection entirely |
| `prompt` | String | No | Context from previous segment for vocabulary/style bias |

**Response:**

```json
{
  "text": "transcribed text here"
}
```

**Important Notes:**
- `gpt-4o-mini-transcribe` only supports `json` or `text` response formats. Using `verbose_json` will cause a 400 error.
- The model does not return `language` or `no_speech_prob` fields. Language detection is handled downstream.
- The `language` parameter is the strongest accuracy hint. When exactly one input language is selected, it is passed directly.
- The `prompt` parameter biases transcription toward vocabulary from the previous segment (used for stitching continuity).
- Retry logic: 2 retries with exponential backoff (1s, 3s) on status codes 429, 500, 502, 503, and timeout errors.

---

### 1.2 OpenAI Chat Completions API (Translation)

**Service:** `TranslationService`
**Model:** `gpt-4o-mini`
**Endpoint:** `POST https://api.openai.com/v1/chat/completions`
**Cost:** $0.15/1M input tokens, $0.60/1M output tokens

**Request Body:**

```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {
      "role": "system",
      "content": "You are a professional meeting translator. Translate the spoken text to {targetLanguage}. Rules: Output ONLY the translation, nothing else. ..."
    },
    {
      "role": "user",
      "content": "{text to translate}"
    }
  ],
  "temperature": 0,
  "max_tokens": 1024
}
```

**Response:** Standard Chat Completions response. Translation is extracted from `choices[0].message.content`.

**Important Notes:**
- For Chinese targets, the system prompt explicitly requires Simplified Chinese and forbids Traditional Chinese.
- If the text is already in the target language, the prompt instructs the model to return it unchanged. However, this is now gated at the caller level — `AppState` skips the API call entirely when `isSameLanguage` is true.
- Timeout: 20 seconds.

---

### 1.3 Gemini 2.5 Flash REST API

**Service:** `GeminiFlashService`
**Model:** `gemini-2.5-flash`
**Endpoint:** `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={apiKey}`
**Cost:** $0.15/1M input tokens, $0.60/1M output tokens; audio input ~32 tokens/second

This is a single-call endpoint that performs both transcription and translation in one request.

**Request Body:**

```json
{
  "system_instruction": {
    "parts": [{"text": "system prompt with transcription + translation instructions"}]
  },
  "contents": [{
    "role": "user",
    "parts": [{
      "inline_data": {
        "mime_type": "audio/wav",
        "data": "{base64-encoded WAV audio}"
      }
    }]
  }],
  "generationConfig": {
    "temperature": 0,
    "maxOutputTokens": 1024,
    "responseMimeType": "application/json"
  }
}
```

**Expected JSON Response (in `candidates[0].content.parts[0].text`):**

```json
{
  "original": "exact transcription of speech",
  "language": "zh",
  "translated": "translation or null"
}
```

**System Prompt Sections:**
1. **Base task:** Transcribe exactly, detect language, translate if different from target
2. **Continuity context** (optional): Previous segment's tail text for cross-chunk stitching
3. **Overlap note** (optional): Instructions to skip the first ~1.5s that overlaps with previous chunk
4. **Input language hint** (optional): Expected speaker languages for disambiguation
5. **Strict rules:** No hallucination, no repetition, no auto-completion, CJK disambiguation

**Important Notes:**
- Translation is always included in the API response (it's part of the prompt). The caller suppresses it by setting `translatedText = nil` when same-language or translations disabled.
- The response may include markdown code fences around the JSON. The parser strips them.
- Output token count is extracted from `usageMetadata.candidatesTokenCount`.
- Retry logic: same as WhisperService (2 retries, exponential backoff).

---

### 1.4 Gemini 3.1 Flash Live WebSocket API

**Service:** `GeminiLiveService`
**Model:** `gemini-3.1-flash-live-preview`
**Endpoint:** `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key={apiKey}`
**Cost:** $0.20/1M input tokens, $0.80/1M output tokens; audio input ~32 tokens/second

This is a bidirectional WebSocket connection for real-time streaming transcription.

**Connection Flow:**

```
Client                              Server
  │                                    │
  ├── WebSocket connect ──────────────►│
  │                                    │
  ├── Setup message ──────────────────►│
  │   (model, config, system prompt)   │
  │                                    │
  │◄────────── setupComplete ──────────┤
  │                                    │
  ├── realtimeInput (audio chunks) ───►│
  ├── realtimeInput (audio chunks) ───►│
  │                                    │
  │◄── serverContent.inputTranscription│
  │◄── serverContent.inputTranscription│
  │◄── serverContent.turnComplete ─────┤
  │                                    │
  ├── realtimeInput (audio chunks) ───►│
  │         ...                        │
```

**Setup Message:**

```json
{
  "setup": {
    "model": "models/gemini-3.1-flash-live-preview",
    "generationConfig": {
      "responseModalities": ["TEXT"],
      "temperature": 0
    },
    "systemInstruction": {
      "parts": [{"text": "transcription-only system prompt"}]
    },
    "realtimeInputConfig": {
      "automaticActivityDetection": {
        "disabled": false,
        "startOfSpeechSensitivity": "START_SENSITIVITY_LOW",
        "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
        "silenceDurationMs": 800
      }
    },
    "inputAudioTranscription": {}
  }
}
```

**Audio Input Message:**

```json
{
  "realtimeInput": {
    "audio": {
      "data": "{base64-encoded raw PCM}",
      "mimeType": "audio/pcm;rate=16000"
    }
  }
}
```

**Server Messages:**
- `setupComplete`: Handshake acknowledgement (must be received before sending audio)
- `serverContent.inputTranscription.text`: Partial transcription segment
- `serverContent.turnComplete`: End of speech turn — triggers emission of accumulated text
- `serverContent.interrupted`: Speech was interrupted — discard partial accumulation

**Important Notes:**
- Gemini Live does **not** translate. It only transcribes. Translation is handled by `AppState` calling `TranslationService.translate()` after receiving the transcription.
- The `detectedLanguage` from Gemini Live is always `"unknown"`. `AppState` uses `detectLanguageFromText()` (Unicode range analysis) to determine the language.
- Heartbeat ping every 30 seconds to detect stale connections.
- Auto-reconnect with exponential backoff (up to 5 attempts) on disconnection during recording.
- Session timeout: 1 hour (`timeoutIntervalForResource: 3600`).

---

## 2. Internal Data Models

### 2.1 TranscriptionEntry

The primary data model representing a single transcription/translation entry in the timeline.

```swift
struct TranscriptionEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    var originalText: String
    var translatedText: String?
    var detectedLanguage: String?       // ISO 639-1 code
    var isTranslating: Bool             // true while translation API call is in-flight
    var source: AudioSource             // .microphone or .system
    var speakerLabel: String?           // "You", "Speaker (Chinese)", etc.
    var isDraft: Bool                   // true = Layer 1 fast draft
    var isQualityResult: Bool           // true = Layer 2 quality/stitch result
    var realtimeItemID: String?         // provider item id for realtime reconciliation
    var realtimeLastMergedAt: Date?     // last provider chunk time merged into this readable realtime row
}
```

**Lifecycle:**
1. Created by `AppState` when transcription completes
2. If translation is needed, `isTranslating` is set to `true`
3. When translation completes, `translatedText` is set and `isTranslating` becomes `false`
4. Draft entries (`isDraft: true`) are replaced by quality entries when Layer 2 completes
5. When recording stops, remaining drafts are promoted to confirmed (`isDraft = false`)
6. Realtime final transport chunks may merge into one readable row; `realtimeLastMergedAt` preserves the latest merged chunk timestamp so the merge window is based on adjacent chunk gaps while the visible row keeps its original start timestamp.

### 2.2 SupportedLanguage

Enum of 16 supported output languages with ISO codes, flags, and variant mappings.

```swift
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english, chinese, spanish, french, german, japanese, korean,
         portuguese, russian, arabic, hindi, italian, dutch, turkish, thai, vietnamese

    var isoCode: String      // "en", "zh", "ja", etc.
    var flag: String          // Emoji flag
    var allISOCodes: [String] // All ISO variants (e.g., Chinese: ["zh", "cmn", "yue", "wuu"])
}
```

### 2.3 TranscriptionEngine

Enum of 4 supported transcription engines. The Realtime series is the fresh-install default; legacy Whisper+GPT remains selectable as a fallback.

```swift
enum TranscriptionEngine: String, CaseIterable, Identifiable {
    case openAIRealtime = "OpenAI Realtime (Recommended)"
    case openAI = "OpenAI Whisper + GPT"
    case geminiFlash = "Gemini 2.5 Flash"
    case geminiLive = "Gemini 3.1 Flash Live"

    var requiresOpenAIKey: Bool
    var requiresGoogleKey: Bool
}
```

---

## 3. Internal Service APIs

### 3.1 WhisperService

```swift
final class WhisperService {
    init(apiKey: String)
    func updateAPIKey(_ key: String)
    func transcribe(pcmData: Data, prompt: String?, inputLanguageCodes: [String]) async throws -> WhisperResponse
}

struct WhisperResponse {
    let text: String
    let language: String?           // Always nil for gpt-4o-mini-transcribe
    let noSpeechProbability: Double // Always 0.0
}
```

### 3.2 TranslationService

```swift
final class TranslationService {
    init(apiKey: String)
    func updateAPIKey(_ key: String)
    func translate(text: String, to targetLanguage: String) async throws -> String
}
```

### 3.3 GeminiFlashService

```swift
final class GeminiFlashService {
    init(apiKey: String)
    func updateAPIKey(_ key: String)
    func transcribeAndTranslate(
        pcmData: Data,
        targetLanguage: String,
        targetISOCode: String,
        previousContext: String?,
        isOverlapChunk: Bool,
        inputLanguageCodes: [String]
    ) async throws -> GeminiResult
}

struct GeminiResult {
    let originalText: String
    let translatedText: String?
    let detectedLanguage: String    // ISO code
    let outputTokens: Int
}
```

### 3.4 GeminiLiveService

```swift
final class GeminiLiveService: NSObject, URLSessionWebSocketDelegate {
    init(apiKey: String)
    func updateAPIKey(_ key: String)
    func updateTargetLanguage(_ language: String, isoCode: String)
    func connect() async throws
    func disconnect()
    func sendAudio(_ pcmData: Data)

    var onResult: ((LiveResult) -> Void)?
    var onError: ((Error) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
}

struct LiveResult {
    let originalText: String
    let translatedText: String?     // Always nil (translation handled by AppState)
    let detectedLanguage: String    // Always "unknown" (detected by AppState)
    let outputTokens: Int
    let isPartial: Bool
}
```

### 3.5 CostTracker

```swift
@MainActor final class CostTracker: ObservableObject {
    @Published var sessionCost: Double
    @Published var totalCost: Double

    func resetSession()
    func resetTotal()
    func logWhisperTranscription(audioDurationSeconds: Double)
    func logGPTTranslation(inputTokens: Int, outputTokens: Int)
    func logGeminiFlash(audioDurationSeconds: Double, outputTokens: Int)
    func logGeminiLive(audioDurationSeconds: Double, outputTokens: Int)
    func exportLog() -> String

    var sessionCostFormatted: String  // "$0.07"
    var totalCostFormatted: String
}
```

**Pricing (as of 2026-04):**

| Service | Pricing |
|---|---|
| gpt-4o-mini-transcribe | $0.003/minute of audio |
| GPT-4o-mini (translation) | $0.15/1M input tokens, $0.60/1M output tokens |
| Gemini 2.5 Flash | $0.15/1M input, $0.60/1M output, ~32 tokens/sec audio |
| Gemini 3.1 Flash Live | $0.20/1M input, $0.80/1M output, ~32 tokens/sec audio |

---

## 4. AppState — Central Orchestrator

`AppState` is the `@MainActor` `ObservableObject` that coordinates all components. Key responsibilities:

### 4.1 Published Properties

```swift
@Published var entries: [TranscriptionEntry]
@Published var isRecording: Bool
@Published var targetLanguage: SupportedLanguage
@Published var showTranslations: Bool
@Published var selectedEngine: TranscriptionEngine
@Published var processingCount: Int
@Published var statusMessage: String
@Published var errorMessage: String?
@Published var recordingElapsedSeconds: Int
@Published var inputLanguages: Set<SupportedLanguage>
```

### 4.2 Key Methods

| Method | Description |
|---|---|
| `toggleRecording()` | Start or stop recording |
| `startRecording()` | Initialize audio capture, start pipeline timers |
| `stopRecording()` | Stop capture, finalize drafts, process remaining audio |
| `saveSettings()` | Persist all settings to UserDefaults, update service API keys |
| `clearEntries()` | Remove all entries and reset pipeline state |
| `exportTranscript() -> String` | Generate plain-text transcript with timestamps |
| `checkPermissions()` | Check and request microphone/screen recording permissions |

### 4.3 Pipeline Methods (Private)

| Method | Layer | Engine | Description |
|---|---|---|---|
| `processFastLayer()` | 1 | All | Dispatches audio to engine-specific fast draft handler |
| `processOpenAIFast()` | 1 | OpenAI | Whisper transcription + GPT translation |
| `processGeminiFast()` | 1 | Gemini Flash | Single-call transcription + translation |
| `processStitchLayer()` | 2 | OpenAI | Re-transcribe longer window, replace drafts |
| `processGeminiQualityLayer()` | 2 | Gemini Flash | Re-process longer window, replace drafts |
| `handleGeminiLiveResult()` | — | Gemini Live | Process WebSocket transcription + translate |
| `isDuplicateOfRecent(_:)` | — | All | Echo dedup: check bigram similarity against recent entries |
| `characterBigrams(_:)` | — | All | Generate character bigrams for Dice coefficient |
| `diceCoefficient(_:_:)` | — | All | Compute Dice similarity between two bigram sets |

### 4.4 Translation Gating Logic

All translation paths follow this pattern:

```swift
let sameLanguage = isSameLanguage(detected: detectedLang, target: targetLanguage)
let needsTranslation = !sameLanguage && showTranslations

// For OpenAI: skip the translation API call entirely
if needsTranslation {
    let translated = try await translationService.translate(text: text, to: targetLanguage.rawValue)
    entry.translatedText = translated
}

// For Gemini Flash: suppress the already-returned translation
entry.translatedText = useTranslation ? result.translatedText : nil
```

### 4.5 Echo / Duplicate Suppression API

Three private methods in `AppState` implement post-transcription deduplication:

```swift
/// Generate character bigrams from text (language-agnostic — works for CJK, Latin, Arabic, etc.)
private func characterBigrams(_ text: String) -> [String]

/// Compute Dice coefficient similarity between two sets of bigrams (0.0–1.0)
private func diceCoefficient(_ a: [String], _ b: [String]) -> Double

/// Check if text is >70% similar to any entry from the last 15 seconds
/// Returns true if the text should be dropped as a duplicate
private func isDuplicateOfRecent(_ text: String) -> Bool
```

**Algorithm:** Character-bigram Dice coefficient — splits text into overlapping 2-character pairs, then computes `2 * |intersection| / (|A| + |B|)`.

**Parameters:**
- Similarity threshold: `0.70` (configurable constant)
- Lookback window: `15` seconds (configurable constant)

**Where called:**
- `processOpenAIFast()` — after hallucination check, before entry creation
- `processGeminiFast()` — after hallucination check, before entry creation
- `handleGeminiLiveResult()` — after hallucination check, before entry creation

**Where NOT called (by design):**
- `processStitchLayer()` / `processGeminiQualityLayer()` — Layer 2 passes replace drafts and are expected to produce similar text

### 4.6 OpenAI Realtime Voice Boundary

The realtime engine is exposed to users as one friendly option: `OpenAI Realtime (Recommended)`. Internally it routes to the correct model family:

| Mode | Model | Runtime boundary |
|---|---|---|
| Caption-first live text | `gpt-realtime-whisper` | `OpenAIRealtimeTranscriptionService` over `wss://api.openai.com/v1/realtime?intent=transcription` |
| Dialog/assistant understanding | `gpt-realtime-2` | `OpenAIRealtimeAgentService` over `/v1/realtime` with text output and server VAD |
| Live interpretation, M7 | `gpt-realtime-translate` plus optional `gpt-realtime-whisper` source-caption sidecar | `OpenAIRealtimeTranslationService` over `/v1/realtime/translations` fan-out with `OpenAIRealtimeTranscriptionService` |

Canonical feature contracts:

- `docs/prd_feat_openai_realtime_translate_interpreter.md` is the current source of truth for same-time translated subtitles. It explicitly makes `gpt-realtime-translate` the interpreter model; `gpt-realtime-whisper` is a source-caption audit sidecar only.
- `docs/prd_feat_realtime_settings_runtime_clarity.md` is the current source of truth for Settings copy and control grouping.
- `docs/prd_feat_realtime_speaker_recognition_sidecar.md` is the current source of truth for future delayed speaker labels. It must not be implemented inside the realtime translation core.

Realtime service ownership:

- `OpenAIRealtimeCoordinator`: source-aware session lifecycle, routing, reducer ownership, and audio send success/failure.
- `RealtimeModelRouter`: pure route decision. Translation mode requires visible translations, non-same source/target language, exactly one pinned source language, and the explicit interpreter-session gate.
- `RealtimeEventReducer`: accumulates `*.delta` text by `(source, itemID)` before final confirmation. Empty finals and stale shorter prefix finals preserve the longer visible draft text so accurate live captions do not disappear or lose tail words before `AppState` confirms the row. Output-first translation rows report superseded item IDs when they later bind to a Whisper source-caption row, allowing `AppState` to remove stale translation-only draft rows.
- `AudioResampler`: explicit 16 kHz capture to 24 kHz PCM16 realtime boundary.
- `RealtimeDraftFinalizer`: collects non-empty realtime live captions as stop-time final candidates so `AppState.confirmRealtimeEntry()` can apply the usual filters, while still dropping empty/hallucinated realtime drafts.
- `RealtimeUtteranceMerger`: treats provider final items as transport chunks and merges nearby same-source/same-language chunks into readable dialog rows before display/export. It compares new chunks with the latest merged provider timestamp (`realtimeLastMergedAt`) rather than only the row's original start time, so one continuous thought can keep rolling into a single row without losing the first timestamp. It also filters unstable tiny fragments such as one-character fillers, short Japanese/Korean hallucination tails, and known bad micro-mishears, while preserving useful connector fragments that belong inside a larger utterance.
- `RealtimeConnectionRecoveryPolicy`: classifies transient TLS/WebSocket/network startup failures for bounded retry, while excluding permanent auth, quota, permission, and model-access errors from retry loops.
- `RealtimeAudioBoundaryContext`: used by `OpenAIRealtimeTranscriptionService` to prepend the last 300ms of same-source audio to the next manual Whisper commit, mirroring the kind of prefix context VAD sessions normally provide while keeping microphone and system audio separate. Low-energy chunks clear the source tail so old speech does not leak across pauses; translation primary audio stays raw.
- `OpenAIRealtimeWebSocketService`: suppresses heartbeat/send errors during intentional shutdown so Stop does not trigger legacy fallback.

Realtime recovery behavior:

- `AppState` schedules up to two short OpenAI Realtime restarts for transient secure-connection, TLS, WebSocket, timeout, or dropped-connection errors. Legacy OpenAI fallback is used only after retries are exhausted and automatic fallback is enabled.
- While a recovery task is pending, later failure events from the same WebSocket close are absorbed so the UI stays in `Realtime reconnecting (...)` instead of flickering back to a raw transport error.
- Permanent failures such as invalid API key, unauthorized, forbidden, billing/quota, or unavailable model errors do not retry; they continue to surface through the existing setup/fallback path.

Transcript display behavior:

- `AppState.followLatestCaptions` persists under `com.meetingtranslator.followlatestcaptions` and defaults to `true` to preserve the existing caption-following behavior.
- `AppState.setFollowLatestCaptions(_:)` persists only that display preference and must not call `saveSettings()`, reconfigure audio capture, or refresh Realtime routing. Follow is a view behavior, not an engine/session setting.
- `ContentView.transcriptionList` gates all automatic scroll-to-bottom behavior behind `followLatestCaptions` and scrolls to a bottom anchor without animation. Turning the toggle off lets new captions arrive without moving the user's current reading position. The scroll trigger watches all visible row text lengths, so delayed non-last draft/final updates still keep the bottom anchored when follow mode is on.
- `TranscriptionRowView` disables implicit animation for draft text growth and uses natural wrapping, so grey live text expands downward instead of vibrating the surrounding layout before final-row consolidation.

`gpt-realtime-whisper` transcription sessions do not use `server_vad`; the app sets manual turn detection (`null`), appends latency-preset PCM chunks, and commits each chunk explicitly. Before each Whisper commit after the first per source, `OpenAIRealtimeTranscriptionService` prepends 300ms of same-source boundary context so words spanning chunk edges have enough audio context. Realtime capture uses continuous timer chunking, not the legacy VAD-first behavior, so active speech continues flowing before silence. Balanced latency uses 1.4s local chunks and Accuracy uses 2.4s local chunks to reduce over-fragmented rows while preserving during-speech partials.

For M6, caption-only OpenAI Realtime should prefer `gpt-realtime-whisper` because the product requirement is visible transcript deltas while the user is still speaking. `gpt-realtime-2` sessions remain available for dialog understanding and future approval-gated assistant workflows. They use low reasoning effort for latency, text output only, `server_vad` with a 700 ms silence window, and never enable tool/action behavior without a separate approval-gated assistant mode. Agent service parsing accepts both direct text events (`response.output_text.*`) and nested final response containers (`response.output_item.done`, `response.done`); nested finals are reconciled by inner message IDs (`item.id` / `response.output[].id`) so partial rows finalize in place. Explicitly incomplete, cancelled, or failed nested response containers are ignored as transcript finals because Realtime emits done events for non-completed responses too. System-audio chunks append a short silence tail before sending to Realtime-2 so server VAD closes short ScreenCaptureKit turns; microphone chunks are sent without that tail. Outside `gpt-realtime-translate` translation mode, AppState consolidates adjacent same-source realtime rows after final confirmation so transport chunks render as readable utterances; merge windows are evaluated against adjacent provider chunk gaps using `realtimeLastMergedAt`, and tail-only duplicate finals are dropped only after source, language, finalized-row, length, and short time-window gates pass. Translation mode is M7 and keeps item rows stable until transcript and translation finals attach.

For M7, `gpt-realtime-translate` is the same-time interpretation model. Provider probes showed Translate output transcript/audio events while source transcript events were not consistently emitted from the translation stream itself, so the app fans accepted audio to a paired `gpt-realtime-whisper` source-caption sidecar when the explicit interpreter gate is on. The reducer attaches translation output to the latest source-caption item for the same audio source, including the output-first case where Translate text arrives before Whisper source text, and removes the superseded translation-only draft row once it rebinds. This preserves source captions, proves source deltas with the realtime transcription model, and makes cost accounting explicit: M7 with source captions is Translate + Whisper. Whisper must not be described as the translation model.

Settings UI contract:

- When `selectedEngine == .openAIRealtime`, Settings must present Realtime controls only: caption latency, automatic fallback, live interpreter gate/status, translation visibility, and input-language hinting. It must not show legacy `fastInterval`, `stitchInterval`, or the old fast/stitch pipeline diagram because those controls do not affect `gpt-realtime-whisper`.
- Settings must separate `Realtime Captions`, `Live Interpretation`, `Display Behavior`, `Audio Input Filter`, and `Speaker Recognition`. Live interpretation uses `gpt-realtime-translate`; source captions use `gpt-realtime-whisper` for audit/export.
- The shared noise gate belongs in the Settings panel's `Audio Input Filter` section, outside `Engine Controls`, because it runs before every engine route rather than configuring a Realtime model.
- When `selectedEngine == .openAI`, Settings may show the legacy Whisper + GPT fast draft and stitch pass intervals under `Legacy Fallback Controls`.
- When `selectedEngine == .geminiFlash`, Settings may show Gemini Flash fast draft and quality pass intervals.
- When `selectedEngine == .geminiLive`, Settings should label Gemini Live as a streaming alternate and should not claim it is the best live-meeting route now that OpenAI Realtime is the primary path.
- The Settings translation toggle is bound through `AppState.setShowTranslations(_:)` so active realtime routing can restart safely if needed.
- The Settings live-interpreter toggle is bound through `AppState.setRealtimeInterpreterSessionEnabled(_:)` so enabling or disabling `gpt-realtime-translate` reroutes the active Realtime session immediately instead of waiting for another full settings save.
- `Follow latest captions` belongs under Settings `Display Behavior` and also appears as an icon button in the control bar for live reading. It is a UI display preference, not a Realtime model parameter.
- Translated audio playback appears under `Live Interpretation` only after M8 implementation. It is off by default, uses the existing `gpt-realtime-translate` output audio route, and is disabled with an explicit reason until interpreter and safety gates are satisfied.
- Speaker recognition is off by default. When enabled, Settings must disclose delayed labels, `gpt-4o-transcribe-diarize` cost/privacy implications, and that no audio is sent while the mode is Off.

App-level realtime events:

```swift
partialTranscript(source, itemID, text, timestamp)
finalTranscript(source, itemID, text, language, timestamp)
partialTranslation(source, itemID, text, timestamp)
finalTranslation(source, itemID, text, language, timestamp)
translatedAudioChunk(source, itemID, data, format, sampleRate, channels, timestamp)
translatedAudioDone(source, itemID, timestamp)
translatedAudioFormatUnsupported(source, itemID, format, timestamp)
sessionStateChanged(source, state)
usageUpdated(source, mode, audioDurationSeconds, inputTokens, outputTokens)
recoverableError(source, message, action)
```

Translation-spend invariant:

```swift
let sameLanguage = specifiedInputMatchesTarget()
let mayUseRealtimeTranslate = showTranslations
    && !sameLanguage
    && inputLanguages.count == 1
    && realtimeInterpreterSessionEnabled
```

If input language is auto-detected, same-language, translations are hidden, or the explicit interpreter-session gate is off, realtime stays on the caption-first transcription path rather than starting a translation session. `gpt-realtime-translate` is the M7 live interpreter route and must not start unless the translation-spend invariant is satisfied. Translated audio playback is a separate output gate and remains off by default so text subtitles can use the translation session without speaker feedback.

Translated audio playback M8 contract:

- Source of truth: `docs/prd_feat_realtime_translated_audio_playback.md`.
- Playback must use `gpt-realtime-translate` output audio from the existing `/v1/realtime/translations` session. Do not add `gpt-realtime-2`, legacy TTS, or another model for playback.
- Runtime may pass `translatedAudioPlaybackEnabled: true` to `OpenAIRealtimeTranslationService` only when `showTranslations`, exactly one pinned source language, non-same source/target language, `realtimeInterpreterSessionEnabled`, persisted M8 playback opt-in, and `TranslatedAudioSafetyStatus.ready` are all true.
- Old placeholder persistence under `com.meetingtranslator.realtime.translatedaudioplayback` is ignored. M8 stores explicit opt-in/mute/volume/safe-output under `.m8.*` keys.
- `session.output_audio.delta` is translated audio only. `OpenAIRealtimeTranslationService` parses optional `format`, `sample_rate`, and `channels`; unsupported non-`pcm16` format emits `.translatedAudioFormatUnsupported` and disables playback. Audio chunks must never create transcript rows.
- If `sample_rate` is absent, the native player uses the official WebSocket PCM boundary default of 24 kHz PCM16; provider probes with `--capture-output-audio` record final observed output details.
- `session.output_audio.done`, Stop, mute, route downgrade, fallback, and reconnect drain or clear queued playback audio through `RealtimeTranslatedAudioPlayer`.
- `RealtimeTranslatedAudioPlayer` accepts mono PCM16 chunks, converts to AVAudioEngine float buffers, bounds queued bytes, tracks drops, supports mute/volume, and has a no-engine test mode for deterministic smokes.
- `SystemAudioManager.makeStreamConfiguration(excludeCurrentProcessAudio:)` sets `SCStreamConfiguration.excludesCurrentProcessAudio = true` on supported macOS runtimes; `system_audio_exclusion_smoke.swift` verifies this config remains wired.
- If current-process audio exclusion is unavailable or a synthetic loopback/runtime probe shows app audio is still captured, playback stays disabled with a user-facing reason.
- ScreenCaptureKit exclusion does not stop laptop-speaker bleed into the microphone. When microphone capture is active, playback requires the user to confirm headphones/safe output; the UI never claims room-speaker safety.
- Cost UI should state that translated audio playback uses the already-active `gpt-realtime-translate` translation session unless current official OpenAI pricing docs require a separate output-audio charge.
- Text export remains the default. Do not write raw translated audio files unless a later export PRD scopes and verifies that behavior.

Language detection fallback:

- Realtime and Gemini Live providers may omit a reliable language code. In that case `AppState.detectLanguageFromText(_:)` delegates to `LanguageDetector.detect(_:)`.
- `LanguageDetector` first detects non-Latin scripts by Unicode range: Han/CJK, kana, Hangul, Arabic, Devanagari, Thai, Greek, Hebrew, Bengali, Tamil, Telugu, Malayalam, and Cyrillic.
- Latin-script text is not automatically English. The detector checks high-signal diacritics and common phrases for Vietnamese, Turkish, Spanish, French, German, Portuguese, and Italian before falling back to English.
- This fallback is a UI/translation gate helper, not a full probabilistic language identifier. Provider language codes and explicit input-language hints remain stronger when available.

Realtime cost additions in `CostTracker`:

- OpenAI Realtime Whisper: `$0.017/min`, about `$1.02/hour/source`.
- OpenAI Realtime Translate: `$0.034/min`, about `$2.04/hour/source`.
- OpenAI Realtime Whisper + Translate as two independent sessions: about `$3.06/hour/source`.
- OpenAI Realtime 2: `$4/$24` text input/output per 1M and `$32/$64` audio input/output per 1M; rough full-duplex voice-agent estimate is `$5.76/hour` for one hour of user audio plus one hour of assistant audio. Actual cost varies with speech duty cycle, silence, output length, and retained context.

Product route rule: use `gpt-realtime-translate` for same-time translation MVPs. Use `gpt-realtime-2` only for assistant-like meeting products that need reasoning, speaking, summaries, explanations, interruption, tool calls, or app actions.

Speaker recognition boundary:

- The live Realtime route does not provide trusted multi-person diarization.
- Speaker recognition uses `SpeakerRecognitionMode.off` by default. Off means no audio windows are sent for diarization.
- Delayed speaker recognition uses `gpt-4o-transcribe-diarize` through `/v1/audio/transcriptions` as a sidecar, with `response_format=diarized_json` and `chunking_strategy=auto`.
- Known-speaker references use `known_speaker_names[]` and `known_speaker_references[]`, capped at four references in the first-pass request builder.
- Diarization may annotate finalized system-audio rows with delayed speaker labels (`speakerID`, `speakerDisplayName`, `speakerConfidence`, `speakerSource`), but must not block realtime captions/translation or rewrite source text by default. Ambiguous timestamp/text matches are ignored.

Verification helpers:

- Core smoke: `swiftc Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/*.swift tools/realtime-foundation/tests/realtime_core_smoke.swift -o /tmp/realtime_core_smoke && /tmp/realtime_core_smoke`
- App icon visual smoke: `/Users/vecsatfoxmailcom/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tools/realtime-foundation/tests/app_icon_visual_smoke.py`
- App logo UI smoke: `swiftc tools/realtime-foundation/tests/app_logo_ui_smoke.swift -o /tmp/app_logo_ui_smoke && /tmp/app_logo_ui_smoke`
- Settings noise gate UI smoke: `swiftc tools/realtime-foundation/tests/settings_noise_gate_ui_smoke.swift -o /tmp/settings_noise_gate_ui_smoke && /tmp/settings_noise_gate_ui_smoke`
- Transcript follow UI smoke: `swiftc tools/realtime-foundation/tests/transcript_follow_ui_smoke.swift -o /tmp/transcript_follow_ui_smoke && /tmp/transcript_follow_ui_smoke`
- Language detector smoke: `swiftc Sources/MeetingTranslator/Models/TranscriptionEntry.swift tools/realtime-foundation/tests/language_detector_smoke.swift -o /tmp/language_detector_smoke && /tmp/language_detector_smoke`
- Synthetic app E2E: `swiftc Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/*.swift tools/realtime-foundation/tests/realtime_app_e2e.swift -o /tmp/realtime_app_e2e && /tmp/realtime_app_e2e`
- ScreenCaptureKit exclusion smoke: `swiftc -target arm64-apple-macosx14.0 -framework ScreenCaptureKit -framework AVFoundation -framework CoreGraphics -framework Combine Sources/MeetingTranslator/Managers/SystemAudioManager.swift tools/realtime-foundation/tests/system_audio_exclusion_smoke.swift -o /tmp/system_audio_exclusion_smoke && /tmp/system_audio_exclusion_smoke`
- Installed-app current-process exclusion probe: `"/Applications/MeetingTranslator.app/Contents/MacOS/MeetingTranslator" --run-system-audio-exclusion-probe` or the mission runner's `open -W` wrapper. The probe uses external synthetic `afplay` audio as a positive ScreenCaptureKit control, then plays a synthetic tone through `RealtimeTranslatedAudioPlayer` in the app process and fails if current-process playback is captured at a meaningful fraction of the external control.
- Provider translated-output capture: `tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav --target zh --max-audio-seconds 12 --i-understand-audio-is-sent-to-openai --show-text --capture-output-audio /tmp/mtp_realtime_probe_audio/translated_audio_en_to_zh.wav --timeout 30`
- Realtime foundation CLI recommendation smoke: `tools/realtime-foundation/realtime-foundation recommend --task interpreter --show-translations --no-same-language --pinned-source-language --interpreter-session`
- Provider probes must use generated/non-private fixtures and `--i-understand-audio-is-sent-to-openai`; never use private meeting audio. `tools/realtime-foundation/generate_synthetic_probe_audio.sh` creates macOS `say` fixtures under `/tmp/mtp_realtime_probe_audio`, and `probe --max-audio-seconds` can be raised for long-utterance translation checks. The probe CLI uses a standard-library WebSocket and PCM fallback when `websocket-client` or `audioop` are absent from the login-shell Python.
- Full local verification can be run with `tools/realtime-foundation/run_realtime_mission_verification.sh --local-only`. The same script without `--local-only` includes the synthetic provider probes and requires a valid OpenAI key; it uses `OPENAI_API_KEY` if set, otherwise reads the already-saved Meeting Translator app key from UserDefaults into the transient probe process without printing it. On 2026-05-13 it passed for `gpt-realtime-whisper`, `gpt-realtime-translate` EN->ZH, `gpt-realtime-translate` ZH->EN, `gpt-realtime-translate` code-switch, and `gpt-realtime-2` agent text.

---

## 5. Audio Pipeline Details

### 5.1 Audio Format

All audio is captured and processed as:
- **Sample rate:** 16,000 Hz
- **Bit depth:** 16-bit signed integer (little-endian)
- **Channels:** Mono
- **Format:** Raw PCM (wrapped in WAV header before API calls)

### 5.2 Buffer Management

```
Audio chunks (1s each) ──► fastBuffer ──► Layer 1 (every fastInterval)
                       └──► stitchBuffer / geminiQualityBuffer ──► Layer 2 (every stitchInterval)
```

- `overlapTailData`: Last 1.5 seconds of the previous fast chunk, prepended to the next chunk for cross-boundary continuity
- Buffers are capped at `maxBufferBytes` (60s) to prevent memory growth
- On stop, remaining buffer contents are processed in a final pass
- OpenAI Realtime bypasses `fastBuffer`/`stitchBuffer` and uses continuous mic/system chunks tied to the latency preset: Aggressive `0.4s`, Balanced `1.4s`, Accuracy `2.4s`. Each Whisper transcription source keeps its own 300ms boundary-context tail before manual commit, and low-energy chunks reset that source tail. Non-realtime engines keep the existing VAD plus 1-second fallback timer behavior.

### 5.3 Noise Gate

Before processing, each audio chunk is checked for sufficient energy. This is exposed in Settings as `Audio Input Filter`, not as an engine-specific model control, because it gates microphone/system PCM before Realtime, legacy OpenAI, or Gemini routes receive audio:

```swift
func rmsEnergy(of pcmData: Data) -> Double  // 0.0–1.0
func hasEnoughEnergy(_ pcmData: Data) -> Bool  // rms >= noiseGateThreshold
```

Default threshold is 0.003 (very conservative — only skips near-silence).

---

## 6. Error Handling

### 6.1 Error Types

```swift
enum WhisperError: LocalizedError {
    case noAPIKey, invalidURL, invalidResponse
    case apiError(statusCode: Int, message: String)
}

enum TranslationError: LocalizedError {
    case noAPIKey, invalidURL, invalidResponse
    case apiError(statusCode: Int, message: String)
}

enum GeminiError: LocalizedError {
    case noAPIKey, invalidURL, invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError(String)
    case connectionError(String)
}
```

### 6.2 Error Handling Strategy

| Error Type | Behavior |
|---|---|
| 401 Unauthorized | Show "Invalid API key" — no retry, no circuit breaker increment |
| 404 Not Found | Show "Model not found" — no retry |
| 429 Rate Limited | Retry with backoff, show "Rate limited" |
| 500/502/503 | Retry with backoff |
| Timeout | Retry with backoff |
| 5 consecutive errors | Circuit breaker: pause pipeline 10s, then resume |

Errors are displayed in the control bar for 6 seconds, then auto-dismissed.
