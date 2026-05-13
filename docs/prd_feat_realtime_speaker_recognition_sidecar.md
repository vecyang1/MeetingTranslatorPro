# PRD: Realtime Speaker Recognition Sidecar

**Version:** 1.0
**Date:** 2026-05-13
**Status:** Goal-ready for a later stage, off by default
**Stage:** M8
**Primary goal:** add speaker labels without breaking the realtime caption/interpreter flow
**Depends on:** `docs/prd_feat_openai_realtime_translate_interpreter.md`

---

## 1. Executive Decision

Speaker recognition should not be built into the realtime translation core.

OpenAI's realtime transcription and translation routes are the right foundation for live captions and same-time translation. Speaker diarization should be an optional after-final sidecar using `gpt-4o-transcribe-diarize` through `/v1/audio/transcriptions`, because the official speech-to-text docs state that this diarization model is available through the Transcriptions API and is not supported in the Realtime API.

Product rule:

- realtime path owns speed and user-visible text;
- diarization sidecar owns delayed speaker labels;
- the sidecar may annotate rows, but must not rewrite trusted realtime transcript text by default.

Official OpenAI anchors:

- Speech-to-text speaker diarization: https://developers.openai.com/api/docs/guides/speech-to-text
- Audio transcription API `diarized_json`: https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create
- `gpt-4o-transcribe-diarize` model: https://developers.openai.com/api/docs/models/gpt-4o-transcribe-diarize

---

## 2. Problem Statement

The current app labels microphone as `You` and system audio as `Speaker` or `Speaker (Language)`. That is safe but coarse. In real meetings, multiple remote people may speak through system audio, and the user wants rows to be easier to read.

The risky mistake would be to force speaker recognition into the realtime caption/translation route and degrade latency or row stability. Diarization should be delayed, optional, and reversible.

---

## 3. Goals

### G1. Preserve Production Realtime Flow

Realtime captions and interpreter mode must work exactly as before when speaker recognition is off.

### G2. Add Delayed Speaker Labels

When enabled, rows may receive labels such as `Speaker 1`, `Speaker 2`, or known speaker names after a background diarization result is available.

### G3. Avoid Text Rewrite Risk

Diarization transcript text can be stored for audit/debug, but it should not overwrite the realtime transcript unless a future explicit correction feature is designed.

### G4. Keep Privacy Clear

The sidecar sends longer meeting audio windows to the Transcriptions API, so it must be off by default and clearly disclosed.

---

## 4. Non-Goals

- Do not claim true realtime speaker diarization.
- Do not block captions or translations on diarization.
- Do not identify people by real name without known-speaker references or user-provided labels.
- Do not record or persist raw meeting audio indefinitely.
- Do not support more than four known-speaker reference samples in the first pass.
- Do not rewrite transcript text by default.

---

## 5. User Stories

### US-SPK-001: Delayed Speaker Labels

As a user, I want system-audio rows to become `Speaker 1`, `Speaker 2`, etc. after a short delay.

Acceptance criteria:

- [ ] Captions appear immediately with the existing safe label.
- [ ] After diarization, matching rows update speaker labels without moving text between rows.
- [ ] Low-confidence or unmatched rows keep the existing label.

### US-SPK-002: No Production Regression

As a user, I want speaker recognition to be optional and non-disruptive.

Acceptance criteria:

- [ ] Feature defaults off.
- [ ] Realtime caption and translation tests pass unchanged when off.
- [ ] Background diarization failure does not stop realtime sessions.

### US-SPK-003: Known Speakers Later

As a user, I may want "Alice" and "Bob" labels if I provide short references.

Acceptance criteria:

- [ ] Settings can store up to four known speaker names and reference clips in a future-safe model.
- [ ] First implementation may hide known-speaker capture behind a lab flag.
- [ ] Unknown speakers still fall back to numbered labels.

---

## 6. Functional Requirements

### FR-SPK-001: Sidecar Modes

Add a speaker recognition setting:

| Mode | Behavior |
|---|---|
| Off | Default. No audio windows are sent for diarization. |
| After-final labels | Send bounded finalized audio windows and annotate rows later. |
| Meeting-room lab | Future mode for known-speaker references and more aggressive testing. |

### FR-SPK-002: Audio Window Buffer

If enabled, keep bounded rolling audio windows for system audio:

- target window: 15-45 seconds;
- max retention: configurable, default no longer than needed for processing;
- include source and timestamp metadata;
- do not store raw audio in exports unless user explicitly asks.

### FR-SPK-003: Diarization Request

Use `/v1/audio/transcriptions` with:

- `model=gpt-4o-transcribe-diarize`;
- `response_format=diarized_json`;
- `chunking_strategy=auto`;
- optional `known_speaker_names[]`;
- optional `known_speaker_references[]` data URLs for 2-10 second samples.

### FR-SPK-004: Row Matching

Match diarized segments to existing `TranscriptionEntry` rows by:

1. audio source;
2. timestamp overlap;
3. text similarity only as a secondary signal;
4. confidence/overlap threshold.

If the match is ambiguous, do not update the row.

### FR-SPK-005: Data Model

Extend row metadata in a backwards-compatible way:

```swift
var speakerID: String?
var speakerDisplayName: String?
var speakerConfidence: Double?
var speakerSource: SpeakerAttributionSource?
```

Existing `speakerLabel` can remain the display fallback until migration is safe.

### FR-SPK-006: UI

Timeline should show:

- `You` for microphone;
- `Speaker` or `Speaker (Language)` before diarization;
- `Speaker 1`, `Speaker 2`, etc. after accepted diarization;
- known names only when references or user edits support them.

Do not make rows jump or reorder after speaker labels arrive.

---

## 7. Test and Verification Plan

Required tests:

- sidecar off leaves realtime route untouched;
- diarized segment matches a row by timestamp overlap;
- ambiguous overlap does not update row;
- failed diarization request leaves rows unchanged;
- known speaker request payload uses `known_speaker_names[]` and `known_speaker_references[]`;
- export includes updated speaker label when present.

Provider probe should use synthetic multi-speaker audio only.

---

## 8. Done Means

- [ ] Speaker recognition is off by default.
- [ ] Realtime caption and interpreter flows pass with sidecar off.
- [ ] Sidecar can annotate rows after finalization without rewriting text.
- [ ] Ambiguous results are ignored safely.
- [ ] Settings clearly discloses delayed labels, cost, and privacy.
- [ ] Docs/API/changelog reflect the new data model and sidecar contract.

---

## 9. Stop Conditions

Stop and report if:

- diarization requires Realtime API support;
- audio retention would need to be unbounded;
- row matching cannot be made deterministic enough;
- implementation would rewrite realtime transcript text by default;
- provider access to `gpt-4o-transcribe-diarize` is unavailable.

---

## 10. Revision History

| Date | Version | Change |
|---|---:|---|
| 2026-05-13 | 1.0 | Goal-ready delayed speaker recognition sidecar PRD. |
