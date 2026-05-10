# Internal API Reference — Meeting Translator Pro

**Version:** 2.0
**Last Updated:** 2026-04-03

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
    let originalText: String
    var translatedText: String?
    var detectedLanguage: String?       // ISO 639-1 code
    var isTranslating: Bool             // true while translation API call is in-flight
    var source: AudioSource             // .microphone or .system
    var speakerLabel: String?           // "You", "Speaker (Chinese)", etc.
    var isDraft: Bool                   // true = Layer 1 fast draft
    var isQualityResult: Bool           // true = Layer 2 quality/stitch result
}
```

**Lifecycle:**
1. Created by `AppState` when transcription completes
2. If translation is needed, `isTranslating` is set to `true`
3. When translation completes, `translatedText` is set and `isTranslating` becomes `false`
4. Draft entries (`isDraft: true`) are replaced by quality entries when Layer 2 completes
5. When recording stops, remaining drafts are promoted to confirmed (`isDraft = false`)

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

Enum of 3 supported transcription engines.

```swift
enum TranscriptionEngine: String, CaseIterable, Identifiable {
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
| Captions | `gpt-realtime-whisper` | `OpenAIRealtimeTranscriptionService` over `wss://api.openai.com/v1/realtime?intent=transcription` |
| Live translation | `gpt-realtime-translate` | `OpenAIRealtimeTranslationService` over `/v1/realtime/translations` |
| Dev assistant foundation | `gpt-realtime-2` | `OpenAIRealtimeAgentService`, hidden/dev-only |

Realtime service ownership:

- `OpenAIRealtimeCoordinator`: source-aware session lifecycle, routing, reducer ownership, and audio send success/failure.
- `RealtimeModelRouter`: pure route decision.
- `RealtimeEventReducer`: accumulates `*.delta` text by `(source, itemID)` before final confirmation.
- `AudioResampler`: explicit 16 kHz capture to 24 kHz PCM16 realtime boundary.
- `RealtimeDraftFinalizer`: collects non-empty realtime live captions as stop-time final candidates so `AppState.confirmRealtimeEntry()` can apply the usual filters, while still dropping empty/hallucinated realtime drafts.
- `OpenAIRealtimeWebSocketService`: suppresses heartbeat/send errors during intentional shutdown so Stop does not trigger legacy fallback.

`gpt-realtime-whisper` transcription sessions do not use `server_vad`; the app sets manual turn detection (`null`), appends latency-preset PCM chunks, and commits each chunk explicitly. Realtime capture uses continuous timer chunking, not the legacy VAD-first behavior, so active speech continues flowing before silence.

App-level realtime events:

```swift
partialTranscript(source, itemID, text, timestamp)
finalTranscript(source, itemID, text, language, timestamp)
partialTranslation(source, itemID, text, timestamp)
finalTranslation(source, itemID, text, language, timestamp)
translatedAudioChunk(source, itemID, data, timestamp)
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
    && realtimeTranslatedAudioPlayback
```

If input language is auto-detected or translated-audio playback is off, realtime starts as transcription-only. Final non-same captions may still use the existing GPT text translation path, which preserves the `!sameLanguage && showTranslations` spend gate. This avoids silently generating translated audio while the text-only UI is active.

Realtime cost additions in `CostTracker`:

- OpenAI Realtime Whisper: `$0.017/min`
- OpenAI Realtime Translate: `$0.034/min`
- OpenAI Realtime 2: `$4/$24` text input/output per 1M and `$32/$64` audio input/output per 1M

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
- OpenAI Realtime bypasses `fastBuffer`/`stitchBuffer` and uses continuous mic/system chunks tied to the latency preset: Aggressive `0.4s`, Balanced `1.0s`, Accuracy `1.8s`. Non-realtime engines keep the existing VAD plus 1-second fallback timer behavior.

### 5.3 Noise Gate

Before processing, each audio chunk is checked for sufficient energy:

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
