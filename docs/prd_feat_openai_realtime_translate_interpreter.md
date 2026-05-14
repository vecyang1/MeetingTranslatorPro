# PRD: OpenAI Realtime Translate Interpreter

**Version:** 1.3
**Date:** 2026-05-13
**Status:** Implemented and verified
**Stage:** M7
**Primary user promise:** same-time translated subtitles for live meetings
**Primary model:** `gpt-realtime-translate`
**Source-caption audit sidecar:** `gpt-realtime-whisper`
**Historical predecessor:** `docs/prd_feat_openai_realtime_translation_next_stage.md`
**Companion PRDs:** `docs/prd_feat_realtime_settings_runtime_clarity.md`, `docs/prd_feat_realtime_translated_audio_playback.md`, `docs/prd_feat_realtime_speaker_recognition_sidecar.md`

---

## 1. Executive Decision

The simultaneous interpretation feature must be built on `gpt-realtime-translate`, not on Whisper, not on legacy Whisper + GPT, and not on `gpt-realtime-2`.

`gpt-realtime-translate` is the product route because the user-facing promise is "listen to source speech and stream translated subtitles while the speaker is still talking." The app may run a paired `gpt-realtime-whisper` session only as a source-caption audit sidecar so the user can see what was heard in the original language. Whisper is not the translation model and should not be described in the UI as the interpreter.

Sharp routing rule:

| Product need | Correct route | Why |
|---|---|---|
| Live source captions only | `gpt-realtime-whisper` | Low-latency source transcript deltas. |
| Same-time translated subtitles | `gpt-realtime-translate` + optional `gpt-realtime-whisper` source sidecar | Dedicated realtime translation endpoint; source sidecar preserves auditability. |
| Voice assistant / reasoning / tool use | `gpt-realtime-2` | Reasoning voice-agent model, not the interpreter MVP. |
| Legacy fallback after realtime failure | OpenAI Whisper + GPT or Gemini fallback engine | Slower fallback, not the primary realtime route. |

The older M7 document contains useful implementation notes and probe evidence, but it is no longer the canonical product plan because it can read as if the feature is already complete. This PRD is the canonical goal source until the installed app proves the behavior end to end.

Official OpenAI anchors:

- Realtime translation guide: https://developers.openai.com/api/docs/guides/realtime-translation
- `gpt-realtime-translate` model page: https://developers.openai.com/api/docs/models/gpt-realtime-translate
- Realtime transcription guide for source-caption sidecar: https://developers.openai.com/api/docs/guides/realtime-transcription
- Realtime costs guide: https://developers.openai.com/api/docs/guides/realtime-costs

---

## 2. Problem Statement

The app now has a strong realtime caption foundation, but the Settings panel and docs still blur three different ideas:

1. live source captions,
2. live translated subtitles,
3. future translated audio playback or assistant behavior.

The user wants true same-time translation. That means the app should start a dedicated `gpt-realtime-translate` session when the user intentionally enters interpreter mode. It should not silently run legacy post-transcription translation and call that "realtime interpreter."

Current risk:

- A checkbox named "Live translation session" is visible, but the surrounding copy still makes it easy to think Realtime Whisper is doing translation.
- Synthetic provider tests exist, but the installed app has not yet been proven as a complete user-facing interpreter flow.
- Translated audio playback is not part of M7. M8 owns the optional safe-preview playback path and keeps M7 text interpretation independent from playback.
- Speaker recognition is a separate future sidecar, not part of the realtime-translate route.

---

## 3. Goals

### G1. True Realtime Translate Path

When interpreter mode is active, the runtime must open the dedicated realtime translation route and stream translated text while source audio is still arriving.

### G2. Source Caption Audit Trail

The user should see or export the original-language source text when possible. Source captions come from the paired `gpt-realtime-whisper` sidecar and attach to the same timeline item as translated text.

### G3. No Hidden Spend

The app must never start `gpt-realtime-translate` unless all explicit spend gates are true. Same-language, auto-detect source, hidden translations, and interpreter-mode-off must stay on caption-only or fallback routes.

### G4. Settings That Match Runtime

Settings must expose exactly the controls needed for realtime translation and remove misleading legacy Whisper + GPT timing controls from the Realtime section.

### G5. Installed-App Proof

Completion requires a real installed `/Applications/MeetingTranslator.app` run or the strongest safe equivalent, not just reducer tests.

---

## 4. Non-Goals

- Do not use Whisper as the translation model.
- Do not use `gpt-realtime-2` for the default interpreter MVP.
- Do not make M7 subtitles depend on translated audio playback. M8 is specified separately in `docs/prd_feat_realtime_translated_audio_playback.md` and requires explicit opt-in plus feedback-safety proof before playback can be enabled.
- Do not add tool calls, summaries, assistant actions, or meeting controls.
- Do not implement speaker diarization in this M7 PRD.
- Do not mix microphone and system audio into one translation stream unless source identity is still proven.
- Do not log private audio or full private transcripts.
- Do not change bundle ID, signing, entitlements, install path, or permission behavior.

---

## 5. User Stories

### US-M7-001: Same-Time Translated Subtitles

As a user in a multilingual meeting, I want translated text to appear while the speaker is still talking so I can follow the conversation without waiting for the whole turn.

Acceptance criteria:

- [x] With a pinned source language different from the output language, interpreter mode opens `gpt-realtime-translate`.
- [x] Translated partial text appears before the synthetic long utterance ends.
- [x] Final translated text replaces or settles the partial without duplicating rows.
- [x] The status clearly says realtime translation is active.

### US-M7-002: Source Caption and Translation Stay Together

As a user, I want to see what was heard and what it means, attached to one readable row.

Acceptance criteria:

- [x] `gpt-realtime-whisper` sidecar source captions attach to the same source row as `gpt-realtime-translate` output.
- [x] Output-first events do not create orphan translation rows.
- [x] Source-first events show source text while waiting for translation.
- [x] Export includes source text, translated text, language, source, and timestamp.

### US-M7-003: Explicit Cost Gates

As a user, I do not want a paid translation session to start just because translations are visible somewhere in Settings.

Acceptance criteria:

- [x] `showTranslations == false` never starts `gpt-realtime-translate`.
- [x] Auto-detect or multiple input languages never starts `gpt-realtime-translate`.
- [x] Same-language source and target never starts `gpt-realtime-translate`.
- [x] Interpreter-session-off never starts `gpt-realtime-translate`.
- [x] Turning any gate off during recording restarts or downgrades the route safely.

### US-M7-004: Translated Audio Is Honest And Separate

As a user, I should get same-time translated subtitles even when translated audio is off, and any later audio option should be governed by its own safety gates.

Acceptance criteria:

- [x] M7 text subtitles work without translated audio playback.
- [x] Runtime forces translated audio playback off unless the separate M8 gate explicitly enables safe playback.
- [x] `session.output_audio.delta` is ignored unless M8 safe playback is enabled.
- [x] Settings copy says text interpretation is available, audio playback is safe-preview only, and room-speaker safety is not claimed.
- [x] Playback scope is split into `docs/prd_feat_realtime_translated_audio_playback.md` so M7 remains text-first and auditable.

### US-M7-005: Runtime Recovery Does Not Lie

As a user, I want transient TLS/WebSocket failures to recover, and permanent setup problems to explain what happened.

Acceptance criteria:

- [x] Transient startup failures retry through `RealtimeConnectionRecoveryPolicy`.
- [x] Permanent auth/quota/model-access failures do not spin in retry loops.
- [x] Caption-only fallback happens only after retry exhaustion when automatic fallback is enabled.
- [x] UI does not claim interpreter mode is active after route fallback.

---

## 6. Functional Requirements

### FR-M7-001: Interpreter Route Gate

The app may start `gpt-realtime-translate` only when this invariant is true:

```swift
let mayUseRealtimeTranslate =
    showTranslations
    && inputLanguages.count == 1
    && !specifiedInputMatchesTarget()
    && realtimeInterpreterSessionEnabled
```

If this invariant is false, the realtime route must remain caption-first, not translate.

### FR-M7-002: Translation Session Contract

`OpenAIRealtimeTranslationService` must:

- connect to `/v1/realtime/translations`;
- use `gpt-realtime-translate`;
- send 24 kHz PCM16 audio chunks with source identity preserved by the coordinator;
- parse translated text deltas and finals;
- parse translated audio events but suppress playback unless the separate M8 safe-preview gate is active;
- expose route state and recoverable errors through app-level events;
- never call assistant-style `response.create` for translation.

### FR-M7-003: Source Caption Sidecar Contract

When interpreter mode is active, the coordinator should also run a source-caption sidecar:

- use `gpt-realtime-whisper`;
- connect through the realtime transcription route;
- send only source audio already accepted by the primary `gpt-realtime-translate` session, so a sidecar-only row cannot wait forever for missing Translate output;
- parse `conversation.item.input_audio_transcription.delta` and completed events;
- attach source captions to the matching translation item/source row.

The sidecar exists for auditability, language display, export, and trust. It is not the translation engine.

A bounded near-silence continuity tail in interpreter mode should be forwarded to `gpt-realtime-translate` only after Translate accepts voiced audio. Realtime Translation is continuous and uses silence between phrases as part of the stream; the Whisper sidecar should not commit those near-silence chunks because they can create empty or unstable source rows, and the app must not send unlimited quiet audio.

### FR-M7-004: Row Attachment Rules

The reducer and `AppState` must preserve a stable mapping:

```text
audio source + route-local item id + time window -> one visible timeline row
```

Rules:

- Keep source and translated text in the same `TranscriptionEntry` when they belong to the same audio item.
- If Translate output arrives before Whisper source text, create or update a pending row and later attach the source caption.
- If Whisper source text arrives before Translate output, show source text and mark translation as in progress only when the gate is still true.
- Do not run same-source final-row consolidation in a way that merges unrelated translation items.
- Do not split one continuous translated thought into many transport-chunk rows if source and item mapping are stable.

### FR-M7-005: Cost Tracking

Cost UI and logs must separate:

| Cost lane | Model | Unit |
|---|---|---|
| Source captions | `gpt-realtime-whisper` | audio duration |
| Realtime translated subtitles | `gpt-realtime-translate` | audio duration |
| Legacy fallback translation | `gpt-4o-mini` or Gemini | token estimate |
| Future assistant | `gpt-realtime-2` | token estimate |

The UI should show that interpreter mode costs more than caption-only mode. It should not hide the sidecar cost when source captions are on.

### FR-M7-006: Settings Contract

When `OpenAI Realtime (Recommended)` is selected, Settings must show:

- `Caption latency`;
- `Show translations`;
- `Live interpreter session` with a prerequisite status;
- pinned input-language requirement;
- automatic fallback;
- `Follow latest captions`;
- off-by-default M8 translated audio safe-preview controls, governed by `docs/prd_feat_realtime_translated_audio_playback.md`;
- audio input filter/noise gate outside engine controls.

Settings must not show legacy fast/stitch intervals in the Realtime panel. Those belong under `OpenAI Whisper + GPT`.

### FR-M7-007: Language Handling

Interpreter mode requires exactly one pinned source language. Auto-detect is allowed for caption-only mode, but it is not enough for a paid realtime translation session.

Language fallback must not label Vietnamese, Turkish, Spanish, or other Latin-script text as English when the provider omits a code.

### FR-M7-008: Privacy and Observability

Log only structured metadata:

- route mode;
- source;
- source and target language codes;
- session open/close/retry counts;
- first source caption delta latency;
- first translated output delta latency;
- final attach count;
- audio duration cost estimates.

Do not log raw audio or full private transcript text.

---

## 7. UX Requirements

### 7.1 Main Controls

The main screen should make the active mode legible:

| State | Preferred status copy |
|---|---|
| Caption only | `Realtime captions active` |
| Interpreter gates incomplete | `Pin one source language to start live interpretation` |
| Interpreter connecting | `Connecting live interpretation...` |
| Interpreter active | `Live interpretation active` |
| Reconnecting | `Realtime reconnecting...` |
| Fallback | `Realtime unavailable, using fallback captions` |

### 7.2 Timeline Row

For interpreter rows:

- source caption appears as the original text;
- translated subtitle appears as translated text;
- live/draft state is visually calm and does not shake layout;
- final text settles in place;
- language label reflects source language, not target language;
- no duplicate translation-only row should appear when source text arrives late.

### 7.3 Settings Panel

Settings should not require the user to understand model names. Model names may appear in a small advanced/detail line only:

- user-facing: `Live interpreter session`;
- developer detail: `Uses gpt-realtime-translate; source captions use gpt-realtime-whisper`.

---

## 8. Architecture

Target flow:

```text
MicrophoneManager / SystemAudioManager
  -> source-tagged PCM chunks
  -> RealtimeModelRouter
  -> OpenAIRealtimeCoordinator
     -> if caption-only:
          OpenAIRealtimeTranscriptionService (gpt-realtime-whisper)
     -> if interpreter:
          OpenAIRealtimeTranslationService (gpt-realtime-translate)
          OpenAIRealtimeTranscriptionService sidecar (gpt-realtime-whisper)
  -> RealtimeEventReducer
  -> AppState route gates, row attachment, filters
  -> TranscriptionEntry timeline
  -> ContentView / TranscriptionRowView
```

Ownership:

- Protocol parsing stays inside `Sources/MeetingTranslator/Services/OpenAIRealtime/*Service.swift`.
- Reducer text accumulation stays inside `RealtimeEventReducer`.
- Route decisions stay inside `RealtimeModelRouter`.
- `AppState` orchestrates, applies app-level filters, and owns UI state.
- Settings only mutates state through route-aware setters.

---

## 9. Test and Verification Plan

### 9.1 Unit and Smoke Coverage

Required smoke cases:

- translation gate truth table;
- no translation session for auto-detect input;
- no translation session for same-language input/output;
- route downgrade when `showTranslations` turns off;
- output-first translation attaches to later source caption;
- source-first caption attaches to later translation;
- translated audio deltas suppressed by default;
- cost tracker separates Whisper and Translate;
- settings copy does not mention legacy fast/stitch under Realtime.

### 9.2 Synthetic Provider Probes

Use generated or non-private audio only:

```bash
tools/realtime-foundation/generate_synthetic_probe_audio.sh
tools/realtime-foundation/realtime-foundation probe \
  --mode translation \
  --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav \
  --target zh \
  --max-audio-seconds 12 \
  --i-understand-audio-is-sent-to-openai \
  --show-text \
  --timeout 30
```

Required language pairs:

- English -> Chinese;
- Chinese -> English;
- one code-switching fixture;
- one long utterance fixture that proves partial translated text before utterance end.

2026-05-13 probe status: synthetic provider probes passed with a transient valid
`OPENAI_API_KEY` and generated macOS `say` fixtures. The passing run covered
`gpt-realtime-whisper` source transcript deltas, `gpt-realtime-translate` English -> Chinese,
`gpt-realtime-translate` Chinese -> English, `gpt-realtime-translate` code-switching audio, and
`gpt-realtime-2` agent text output. No private meeting audio was used.

### 9.3 Installed-App E2E

Completion requires at least one installed-app path:

1. Build and install with `./build_app.sh`.
2. Launch `/Applications/MeetingTranslator.app`.
3. Configure:
   - engine: OpenAI Realtime;
   - source language pinned;
   - target language different;
   - show translations on;
   - live interpreter session on.
4. Play synthetic audio through microphone or system audio.
5. Verify:
   - status says live interpretation active;
   - translated text appears before utterance end;
   - source caption and translation attach to one row;
- translated audio playback remains off unless the separate M8 safe-preview gate is explicitly enabled;
   - cost increases on Translate lane.

If full installed-app UI automation is unsafe or unavailable, document the blocker and run the strongest safe substitute: Swift app-level synthetic E2E plus provider probes plus screenshot or runtime inspection.

---

## 10. Documentation Requirements

Update these files in the same implementation pass:

- `docs/PRD.md`: roadmap and feature status;
- `docs/API.md`: realtime translation service contract and settings contract;
- `CHANGELOG.md`: user-facing behavior and verification;
- `.agents/skills/openai-realtime-voice-foundation/SKILL.md`: invariant that `gpt-realtime-translate` is the interpreter model;
- `tools/realtime-foundation/tests/*`: new smoke cases or updated expected strings.

---

## 11. Done Means

This PRD is complete only when:

- [x] `gpt-realtime-translate` is the only realtime interpreter model.
- [x] `gpt-realtime-whisper` is clearly documented and presented only as source-caption sidecar in interpreter mode.
- [x] Interpreter route starts only under explicit gates.
- [x] Translated partial text appears during a long utterance before speech ends.
- [x] Source and translated text attach to the same row in both source-first and output-first event order.
- [x] Translated audio playback is separate from M7 subtitles and remains off unless the M8 safe-preview gate is explicitly enabled.
- [x] Settings no longer misleads users with legacy Whisper + GPT controls in the Realtime section.
- [x] Cost tracking separates caption and translation lanes.
- [x] Core smoke, app synthetic E2E, provider probes, build, and installed-app verification pass.
- [x] Docs and changelog are updated.
- [x] GitNexus detect-changes is reviewed for unexpected symbol/flow changes.

---

## 12. Stop Conditions

Stop and report before continuing if:

- `gpt-realtime-translate` model access is unavailable.
- The dedicated translation endpoint contract differs from this PRD.
- Implementation would need to use private meeting audio for tests.
- The app cannot preserve source/translation row attachment.
- The route requires enabling translated audio playback to get text output.
- Existing caption-only Realtime behavior regresses.
- Build/sign/install would require changing bundle ID, entitlements, or install path.

---

## 13. Revision History

| Date | Version | Change |
|---|---:|---|
| 2026-05-13 | 1.0 | Canonical goal-ready PRD for true `gpt-realtime-translate` simultaneous interpretation; defines Whisper as source-caption sidecar only. |
| 2026-05-13 | 1.1 | Recorded full synthetic provider verification for Whisper captions, Translate EN->ZH/ZH->EN/code-switch output, and Realtime-2 agent text; no private audio used. |
| 2026-05-13 | 1.2 | Clarified that M8 safe-preview playback supersedes the old M7 "audio disabled" wording without making text subtitles depend on playback. |
| 2026-05-14 | 1.3 | Hardened the implemented interpreter fan-out after live testing: source-caption rows require Translate-accepted audio, a bounded quiet-continuity tail goes only to Translate, and Stop clears pending translation state. |
