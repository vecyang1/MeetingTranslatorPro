# PRD: OpenAI Realtime Translation Next Stage

**Version:** 1.2
**Date:** 2026-05-12
**Status:** Historical reference - superseded by `docs/prd_feat_openai_realtime_translate_interpreter.md`
**Stage:** M7
**Primary goal:** stream translated subtitles and optional translated audio after caption-first realtime transcription is solid
**Parent PRD:** `docs/prd_feat_openai_realtime_voice_foundation.md`
**Prerequisite:** `docs/prd_feat_openai_realtime_caption_delta_first.md` complete

---

## 0. Supersession Notice - 2026-05-13

Do not use this file as proof that user-facing simultaneous interpretation is complete.

This document is retained as historical context for the first M7 design and synthetic probe notes. The canonical implementation PRD is now `docs/prd_feat_openai_realtime_translate_interpreter.md`.

Current product decision:

- `gpt-realtime-translate` is the same-time interpretation model.
- `gpt-realtime-whisper` is allowed only as a source-caption audit sidecar in interpreter mode.
- Installed-app E2E must prove translated subtitles before this feature is marked complete.
- Translated audio playback is now governed by `docs/prd_feat_realtime_translated_audio_playback.md`: off by default, safe-preview only, and never required for translated subtitles.

---

## 1. Executive Decision

Realtime translation is the next stage, not the current caption fix. It should use `gpt-realtime-translate` through the dedicated realtime translation endpoint when the user explicitly wants live interpreter behavior.

OpenAI's realtime translation guide separates translation sessions from voice-agent sessions. Translation sessions stream continuously from incoming audio and produce translated audio plus transcript deltas. They do not require the assistant-style response lifecycle that `gpt-realtime-2` uses.

Implementation note from provider verification on 2026-05-12: `gpt-realtime-translate` produced translated output transcript/audio events in both English -> Chinese and Chinese -> English probes, but source transcript events were not consistently emitted in the provider stream. M7 therefore pairs `gpt-realtime-translate` with a `gpt-realtime-whisper` source-caption sidecar for the same accepted audio chunks. This keeps the translation model dedicated to interpretation while preserving proven source caption deltas from the realtime transcription model.

Official reference anchors:

- Realtime translation guide: https://developers.openai.com/api/docs/guides/realtime-translation
- `gpt-realtime-translate` model page: https://developers.openai.com/api/docs/models/gpt-realtime-translate
- Realtime transcription guide for the M6 prerequisite: https://developers.openai.com/api/docs/guides/realtime-transcription

---

## 2. Problem Statement

After M6, Meeting Translator Pro should already show source captions while speech is happening. M7 adds a second layer: live translated subtitles and optional translated audio.

The risk is cost and feedback-loop complexity. Translation sessions are more expensive than caption-only transcription and can output audio that may feed back into meeting/system capture. Therefore M7 must be explicit, gated, observable, and reversible.

---

## 3. Goals

### G1. Live Translated Subtitles

When live interpreter mode is enabled, translated text should stream while source speech is still arriving.

### G2. Preserve Source Transcript

The app should render source transcript and translated transcript together when useful. Source text remains the audit trail.

### G3. Optional Translated Audio

Translated audio playback is optional and off by default. If enabled through the later M8 safe-preview path, it must not create a feedback loop into microphone/system audio.

### G4. Strict Cost Gates

No `gpt-realtime-translate` session may start unless all translation-spend gates are satisfied.

Cost target: M7 same-time translation output uses `gpt-realtime-translate`, about `$2.04/hour/source` at `$0.034/min`. Because Meeting Translator Pro also needs source captions as the audit trail, the implemented interpreter route adds a paired `gpt-realtime-whisper` source-caption sidecar at `$1.02/hour/source`, for about `$3.06/hour/source` total. Do not default to `gpt-realtime-2`; it is a token-priced voice-agent model and belongs to assistant flows, not the cost-efficient translation MVP.

---

## 4. Non-Goals

- Do not start M7 before M6 caption streaming is complete.
- Do not replace source captions with translation-only output.
- Do not enable translated audio by default.
- Do not support many-to-many group translation in the first M7 pass.
- Do not add assistant actions or tool calls.
- Do not mix microphone and system audio into one translation stream unless source identity is still proven.

---

## 5. Prerequisite Gate

M7 may begin only when M6 has proof for:

- microphone caption E2E
- system-audio caption E2E
- pre-pause partial text
- complete final transcript
- build/sign/install
- docs/changelog updated

If M6 is incomplete, the implementation goal must stop before M7.

---

## 6. User Stories

### US-M7-001: Live Translated Subtitles

As a user listening to a foreign-language meeting, I want translated text to appear while the speaker is still talking.

Acceptance criteria:

- [ ] `session.output_transcript.delta` updates the translated subtitle while source speech is still arriving.
- [x] `gpt-realtime-whisper` source-caption deltas update source text while `gpt-realtime-translate` provides output transcript deltas.
- [ ] Final translated text attaches to the correct source item/source row.
- [ ] Same-language output suppresses redundant translation.

### US-M7-002: Explicit Interpreter Mode

As a user, I want realtime translation to happen only when I intentionally enable it.

Acceptance criteria:

- [x] Translation session starts only when `showTranslations == true`.
- [x] Input language is pinned to exactly one source language.
- [x] Source language differs from target language.
- [x] Explicit realtime interpreter-session mode is enabled.
- [x] Turning any gate off stops or avoids the translation session.

### US-M7-003: Optional Translated Audio

As a user, I may want translated audio, but I do not want it to feed back into the meeting transcript.

Acceptance criteria:

- [x] Translated audio playback remains off by default.
- [x] When enabled, translated audio emits only through the explicit playback event path.
- [x] Feedback/echo risk is controlled by keeping playback disabled in UI until a safe playback device/mute path ships.
- [x] Text captions and translation transcripts do not depend on translated audio playback.

### US-M7-004: Language-Pair Quality

As a user, I want names, numbers, dates, product terms, and code-switching to survive translation.

Acceptance criteria:

- [ ] At least English -> Chinese and Chinese -> English synthetic fixtures pass.
- [ ] Numbers/dates/names are checked manually or by deterministic fixture assertions.
- [ ] Code-switching fixture is included.
- [ ] Known-bad outputs are documented as follow-up rather than hidden.

---

## 7. Functional Requirements

### FR-M7-001: Translation Route Gate

Start `OpenAIRealtimeTranslationService` only when:

```swift
showTranslations
&& inputLanguages.count == 1
&& !sameLanguage
&& realtimeInterpreterSessionEnabled
```

Translated audio playback is a separate output gate and remains off by default. Text subtitles can use `gpt-realtime-translate` without playing returned audio; audio deltas must be ignored unless M8 playback is explicitly enabled and feedback behavior is controlled.

### FR-M7-002: Translation Session Contract

The route must:

- connect to `/v1/realtime/translations`
- use `gpt-realtime-translate`
- send `session.input_audio_buffer.append`
- start a paired `gpt-realtime-whisper` source-caption session for the same source audio
- process source caption `conversation.item.input_audio_transcription.delta`
- process source caption `conversation.item.input_audio_transcription.completed`
- process `session.output_transcript.delta`
- process `session.output_transcript.done` / completed variants
- process `session.output_audio.delta` only when playback is enabled

### FR-M7-003: Source and Translation Row Mapping

Translation mode must keep source and target text attached to the right item/source.

Rules:

- Do not run final-row consolidation that merges transcript and translation finals before both sides attach.
- Preserve `(source, itemID)` until source and translation rows are stable.
- Attach translation output to the latest same-source Whisper source-caption item, including the output-first case where translation text arrives before source text.
- Avoid random item IDs that detach source and output transcript streams.
- Do not merge microphone and system audio without source proof.

### FR-M7-004: Cost Tracking

Cost tracker must separately show:

- realtime transcription/caption cost
- realtime translation audio-duration cost
- optional translated-audio playback state

The UI/status should make it obvious when realtime translation spend is active.

### FR-M7-005: Feedback Safety

If translated audio playback is enabled:

- system audio capture must not accidentally transcribe the app's own translated audio as meeting speech
- duplicate/echo suppression must be tested
- a mute/stop control must be available
- feedback risk must be documented in `docs/API.md`

### FR-M7-006: Failure Recovery

Translation session failures must:

- not stop source caption transcription unless necessary
- show plain-language state
- retry within bounded reconnect limits
- fall back to source captions when translation is unavailable

---

## 8. UX Requirements

### 8.1 User Controls

User-facing controls should stay simple:

- `Show translations` controls translated text visibility.
- `Translated audio playback` remains advanced/off by default.
- Status should distinguish `Realtime captions active` from `Realtime translation active`.

### 8.2 Timeline

The transcript row may show:

- source live text
- translated live text
- final source text
- final translated text

Text should not jump between rows or appear as duplicate entries.

### 8.3 Audio Playback

If translated audio is enabled:

- provide mute/volume control
- avoid auto-playing into speakers if it can feed back into system capture
- show a visible active playback state

---

## 9. Architecture

Target M7 flow:

```text
MicrophoneManager/SystemAudioManager
  -> source-tagged PCM chunks
  -> RealtimeModelRouter
  -> OpenAIRealtimeCoordinator fan-out
     -> OpenAIRealtimeTranscriptionService (gpt-realtime-whisper)
        -> conversation.item.input_audio_transcription.delta/completed
     -> OpenAIRealtimeTranslationService (gpt-realtime-translate)
        -> session.output_transcript.delta/done
        -> optional session.output_audio.delta
  -> RealtimeEventReducer
  -> AppState translation gates and row attachment
  -> TranscriptionEntry timeline
```

Keep one translation session per source/target pair unless a future design proves a shared session preserves speaker/source identity.

---

## 10. Observability

Track without private transcript logs:

- active route
- source language
- target language
- source
- target output language/session count
- first source caption delta latency
- first output transcript delta latency
- first translated audio latency, if enabled
- reconnect count
- translation session duration/cost

---

## 11. Test and Verification Plan

### 11.1 Smoke Tests

Extend realtime smoke coverage for:

- translation route gates
- source caption `conversation.item.input_audio_transcription.delta`
- `session.output_transcript.delta`
- final source/translation attachment
- turning translation off stops the translation session
- translated audio deltas ignored when playback is off

### 11.2 Probe

Use synthetic audio only:

```bash
OPENAI_API_KEY="$API_KEY" tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_m7_long_source.wav --target zh --i-understand-audio-is-sent-to-openai --timeout 30
```

Expected:

- sees source caption deltas from the paired `gpt-realtime-whisper` session
- sees output transcript deltas from `gpt-realtime-translate`
- sees translated audio deltas only when expected
- no timeout before useful translated text appears

### 11.3 App E2E

Evidence as of 2026-05-12:

- M6 caption E2E still passes: `realtime_app_e2e ok`, `realtime_core_smoke ok`.
- English -> Chinese provider probe passed with generated synthetic audio and explicit OpenAI audio consent flag; the paired route saw source caption text from `gpt-realtime-whisper` and translated output text from `gpt-realtime-translate`.
- Chinese -> English provider probe passed with generated synthetic audio and explicit OpenAI audio consent flag; the paired route saw source caption text from `gpt-realtime-whisper` and translated output text from `gpt-realtime-translate`.
- Synthetic app E2E verifies source caption deltas, output transcript deltas, source final, translated final, and one `(source, itemID)` row attachment for English -> Chinese and Chinese -> English.
- Gate-off tests verify hidden translations, same-language, and interpreter-session-off routes do not start `gpt-realtime-translate`.
- Translated audio playback remains off by default; the service suppresses `session.output_audio.delta` unless the M8 gate passes `translatedAudioPlaybackEnabled == true`.

---

## 12. Historical Probe Evidence (Not Current Done Means)

Historical synthetic evidence recorded on 2026-05-12:

- [x] M6 was completed before M7 work continued.
- [x] `gpt-realtime-translate` starts only behind explicit translation gates.
- [x] Source captions from `gpt-realtime-whisper` and translated transcript deltas from `gpt-realtime-translate` are parsed and attached in synthetic app E2E.
- [x] Source and translated finals attach to the correct item/source rows.
- [x] Translation cost is visible and separated from caption cost through `CostTracker.logOpenAIRealtimeTranslate`, `CostTracker.logOpenAIRealtimeWhisper`, and shared `RealtimePricing`.
- [x] Translated audio is off by default; playback events are emitted only when explicitly enabled.
- [x] English -> Chinese and Chinese -> English synthetic app E2E tests pass.
- [x] Provider translation probes pass in both directions with generated synthetic audio and explicit consent.
- [ ] Current installed-app completion must be judged against `docs/prd_feat_openai_realtime_translate_interpreter.md`, not this historical checklist.

---

## 13. Stop Conditions

Stop and report if:

- M6 is not complete.
- `gpt-realtime-translate` access is unavailable.
- Translation requires hidden spend outside explicit gates.
- Feedback/echo cannot be controlled with translated audio enabled.
- Correct row attachment cannot be preserved by `(source, itemID)`.
- Private audio would be needed for verification.
- Existing caption behavior regresses.

---

## 14. Revision History

| Date | Version | Change |
|---|---:|---|
| 2026-05-12 | 1.0 | Initial M7 PRD: realtime translation after delta-first caption streaming. |
| 2026-05-12 | 1.1 | Recorded M7 implementation evidence: explicit interpreter-session gates, transcript delta/final attachment, separated Translate pricing, audio playback suppression, and EN<->ZH synthetic probes. |
| 2026-05-12 | 1.2 | Updated M7 contract after provider probes: use `gpt-realtime-translate` for translated output plus paired `gpt-realtime-whisper` source-caption sidecar; record `$3.06/hour/source` combined route and output-first row attachment. |
| 2026-05-13 | 1.3 | Marked translated audio as governed by the newer M8 safe-preview playback PRD while preserving this file as historical M7 context. |
