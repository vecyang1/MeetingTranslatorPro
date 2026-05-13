# PRD: Realtime Translated Audio Playback

**Version:** 1.0
**Date:** 2026-05-13
**Status:** Goal-ready, not implemented
**Stage:** M8, after M7 text interpretation
**Primary user promise:** hear the translated meeting audio safely while same-time translated subtitles remain available
**Primary model:** `gpt-realtime-translate`
**Source-caption sidecar:** existing `gpt-realtime-whisper` source-caption sidecar from M7
**Depends on:** `docs/prd_feat_openai_realtime_translate_interpreter.md`
**Companion PRDs:** `docs/prd_feat_realtime_settings_runtime_clarity.md`, `docs/prd_feat_realtime_speaker_recognition_sidecar.md`

---

## 1. Executive Decision

Translated audio playback must be a separate M8 feature, not a hidden side effect of M7 text interpretation.

M7 deliberately kept playback disabled because the translation model can emit `session.output_audio.delta` while the app is also capturing microphone and system audio. If that translated audio is played through speakers and then recaptured by ScreenCaptureKit or the microphone, the app can create duplicate captions, feedback loops, false speaker rows, and extra Realtime spend.

M8 may enable playback only when a feedback-safety preflight passes. The first shipped version should be a conservative "Headphones / safe output preview" mode, not a room-speaker broadcast mode.

Current OpenAI documentation reviewed on 2026-05-13:

- Realtime translation guide: https://developers.openai.com/api/docs/guides/realtime-translation
- `gpt-realtime-translate` model page: https://developers.openai.com/api/docs/models/gpt-realtime-translate
- Realtime WebSocket guide: https://developers.openai.com/api/docs/guides/realtime-websocket
- Realtime cost guide: https://developers.openai.com/api/docs/guides/realtime-costs

Docs facts that shape this PRD:

- `gpt-realtime-translate` is the dedicated streaming speech-to-speech translation model.
- The translation endpoint is `/v1/realtime/translations`.
- Translation sessions stream continuously from incoming audio and do not use `response.create`.
- The model returns translated audio and transcript deltas while source audio is still arriving.
- WebSocket is the right connection for native/server raw-audio pipelines.
- `session.output_audio.delta` is the translated-audio event to play.
- `session.output_transcript.delta` remains the translated subtitle event.
- Production controls should expose original audio, translated audio, subtitles, mute, and volume.
- Conversational translation should keep speaker tracks separate.

---

## 2. Problem Statement

The app already receives translated audio events from `gpt-realtime-translate`, but runtime currently discards them by design:

- `OpenAIRealtimeTranslationService` emits `.translatedAudioChunk` only when constructed with `translatedAudioPlaybackEnabled == true`.
- `AppState.startOpenAIRealtimeSessions()` currently passes `translatedAudioPlaybackEnabled: false`.
- `AppState.handleOpenAIRealtimeEvent()` ignores `.translatedAudioChunk`.
- Settings displays `Translated audio playback (coming later)` as disabled.

That is correct for M7. It is not enough for M8, because simply flipping the boolean would be unsafe.

M8 must add a complete audio-output path with:

- an explicit user opt-in;
- a playback engine that handles streaming PCM chunks without blocking captions;
- immediate mute/stop behavior;
- feedback prevention for ScreenCaptureKit system audio;
- microphone/speaker safety gating;
- clear Settings copy and runtime state;
- tests and provider probes that prove audio can play without breaking text captions, row attachment, cost tracking, or fallback behavior.

---

## 3. Goals

### G1. Safe Translated Audio Playback

When the user explicitly enables playback and the safety preflight passes, translated audio from `gpt-realtime-translate` should play with low latency while translated subtitles continue to stream.

### G2. Preserve Text Interpretation

Text captions remain the primary proof path. Playback must not block, delay, duplicate, or reorder source captions and translated subtitles.

### G3. Feedback-Proof Runtime

The app must prevent its own translated audio from being recaptured as meeting/system audio when system capture is active. If that cannot be proven in the current macOS runtime, playback stays unavailable.

### G4. Plain Controls

Users should see simple controls: Off, Safe preview, mute, volume, output safety status, and why playback is unavailable.

### G5. No New Model Route

Playback uses the existing `gpt-realtime-translate` output audio. Do not add a second TTS model, do not call legacy speech generation, and do not use `gpt-realtime-2` for playback.

---

## 4. Non-Goals

- Do not ship translated speaker-room broadcast output in M8.
- Do not play translated audio when interpreter text gates are incomplete.
- Do not play translated audio in caption-only mode.
- Do not mix microphone and system audio into one translation track.
- Do not enable many-to-many group-room translation beyond the existing one target-language route.
- Do not add tool calls, assistant behavior, summaries, or meeting actions.
- Do not require private meeting audio for verification.
- Do not change bundle ID, signing identity, entitlements, install path, or permission behavior.
- Do not add new dependencies or modify `Package.swift` unless there is a proven hard blocker.

---

## 5. User Stories

### US-M8-001: Turn On Safe Preview Playback

As a user following a foreign-language meeting, I want to hear translated audio only when the app can do it safely.

Acceptance criteria:

- [ ] Playback is off by default for fresh installs and existing installs.
- [ ] Settings exposes playback only under Realtime `Live Interpretation`, not under caption-only controls.
- [ ] Playback can be enabled only when M7 text interpreter gates are true:
  - `showTranslations == true`;
  - exactly one source language is pinned;
  - source language differs from target language;
  - `realtimeInterpreterSessionEnabled == true`.
- [ ] Playback remains unavailable with a clear reason when system-audio feedback safety cannot be proven.
- [ ] Enabling playback reroutes the active Realtime translation session without starting hidden caption-only translation spend.

### US-M8-002: Hear Streaming Translated Audio

As a user, I want translated audio to begin during a long synthetic utterance, not only after the full turn ends.

Acceptance criteria:

- [ ] `session.output_audio.delta` is decoded from base64 PCM and queued for playback.
- [ ] First playable audio is observed before a long synthetic utterance ends.
- [ ] Audio playback continues through multiple 200 ms deltas without clicks from buffer underflow in the local synthetic smoke path.
- [ ] `session.output_audio.done` drains or closes the current translated-audio segment without cutting off queued audio.
- [ ] Muting stops output immediately while text captions continue.

### US-M8-003: Do Not Feed Back Into Capture

As a user, I do not want translated audio to be transcribed again as meeting speech.

Acceptance criteria:

- [ ] `SystemAudioManager` configures ScreenCaptureKit to exclude current-process audio when supported by the local SDK/runtime.
- [ ] A synthetic system-audio probe proves translated playback from the app is not captured back into the system-audio transcription path.
- [ ] If current-process audio exclusion is unavailable or verification fails, Settings keeps playback disabled and states why.
- [ ] If microphone capture is active and the default output appears to be speakers, the UI requires a headphones/safe-output confirmation before playback starts.
- [ ] Echo/duplicate suppression tests show playback does not create duplicate transcript rows in the synthetic loopback path.

### US-M8-004: Keep Rows, Costs, and Exports Stable

As a user, I want translated audio to be an extra output, not a source of transcript churn.

Acceptance criteria:

- [ ] Source captions and translated text still attach to one stable row in source-first and output-first event orders.
- [ ] Playback chunks do not create transcript rows.
- [ ] Cost tracking keeps source-caption, realtime-translate, and playback state separate.
- [ ] Cost UI does not double count playback as a second model session unless official billing docs require a separate output-audio lane.
- [ ] Export remains text-only by default and includes a metadata note when translated audio playback was active.

### US-M8-005: Stop, Mute, and Failure Behavior

As a user, I want playback to stop predictably when I stop recording, mute output, or change route gates.

Acceptance criteria:

- [ ] Stop recording immediately stops playback and clears queued translated audio.
- [ ] Turning off `Show translations`, changing source language to Auto, changing target to same language, or disabling interpreter mode stops playback and reconnects/downgrades the realtime route safely.
- [ ] Realtime reconnect clears stale audio queues before a new translation session becomes audible.
- [ ] Permanent provider errors do not leave a stuck speaker icon or stale "playing" state.
- [ ] Automatic fallback to legacy Whisper + GPT disables playback because legacy fallback does not provide realtime translated audio.

---

## 6. Functional Requirements

### FR-M8-001: Playback Route Gate

The runtime may pass `translatedAudioPlaybackEnabled: true` into `OpenAIRealtimeTranslationService` only when:

```swift
let mayUseTranslatedAudioPlayback =
    showTranslations
    && inputLanguages.count == 1
    && !specifiedInputMatchesTarget()
    && realtimeInterpreterSessionEnabled
    && realtimeTranslatedAudioPlaybackEnabled
    && translatedAudioSafetyStatus == .ready
```

If any condition is false, the app must keep using M7 text interpretation with translated audio suppressed.

### FR-M8-002: Persisted Settings

Add or reuse a persisted setting only after the new M8 semantics exist:

```swift
@Published var realtimeTranslatedAudioPlaybackEnabled: Bool = false
@Published var realtimeTranslatedAudioMuted: Bool = false
@Published var realtimeTranslatedAudioVolume: Double = 0.65
```

Rules:

- Fresh default is Off.
- Old saved values from the pre-M8 placeholder era must not silently enable playback.
- Settings writes must use route-aware setters that restart/reconfigure active Realtime sessions safely.
- Volume and mute changes must not call the full `saveSettings()` path if they do not require route refresh.

### FR-M8-003: Playback Manager

Add a focused playback component, for example:

```swift
final class RealtimeTranslatedAudioPlayer: ObservableObject {
    enum State { case idle, warming, playing, muted, unavailable(String), failed(String) }
    func configure(sampleRate: Double, channels: Int, volume: Double) throws
    func enqueuePCM16(_ data: Data, itemID: String, source: TranscriptionEntry.AudioSource, sampleRate: Double?)
    func setMuted(_ muted: Bool)
    func setVolume(_ volume: Double)
    func stop(clearQueue: Bool)
}
```

Implementation expectations:

- Use built-in Apple audio APIs already available to the app, such as `AVAudioEngine` and `AVAudioPlayerNode`.
- Accept PCM16 mono chunks from `session.output_audio.delta`.
- Convert PCM16 to the playback engine's required `AVAudioPCMBuffer`.
- Preserve chunk order per source/item.
- Bound the queue so provider bursts cannot grow memory unbounded.
- Drop or fade stale queued chunks after reconnect/stop.
- Do not block the main actor while decoding or scheduling audio.

### FR-M8-004: Output-Audio Event Parsing

`OpenAIRealtimeTranslationService` must parse translated audio events conservatively:

- `session.output_audio.delta`;
- `session.output_audio.done`;
- optional `item_id`;
- optional `sample_rate`;
- optional `channels`;
- optional `format`.

If `format` is present and not `pcm16`, stop before implementing a decoder guess.
If `sample_rate` is absent, use the provider-proven default from synthetic probes and document it in `docs/API.md`.

### FR-M8-005: ScreenCaptureKit Feedback Guard

`SystemAudioManager` must support excluding Meeting Translator Pro's own audio from system capture.

The local SDK exposes:

```objc
@property(nonatomic, assign) BOOL excludesCurrentProcessAudio API_AVAILABLE(macos(13.0));
```

M8 must:

- set `SCStreamConfiguration.excludesCurrentProcessAudio = true` when system capture is active and translated audio playback is possible;
- expose a testable configuration builder or probe so this does not regress;
- keep bundle ID, entitlements, and screen-recording permission behavior unchanged;
- keep playback disabled if the property is unavailable or runtime verification shows current-process audio is still captured.

### FR-M8-006: Microphone/Speaker Feedback Guard

ScreenCaptureKit exclusion does not prevent laptop speakers from bleeding into the microphone.

M8 must add a microphone safety decision:

```swift
enum TranslatedAudioSafetyStatus: Equatable {
    case ready
    case blockedSystemCaptureIncludesAppAudio
    case blockedLikelySpeakerOutputWithMicActive
    case needsHeadphonesConfirmation
    case providerFormatUnknown
    case unavailable(String)
}
```

The first release may allow user-confirmed headphones preview if output-device classification is imperfect, but it must not claim room-speaker safety. The Settings copy must say "Use headphones to avoid microphone feedback" when mic capture is on.

### FR-M8-007: UI Contract

In Settings, replace the disabled row with a `Translated Audio` subsection only after the implementation exists.

Required UI elements:

- Off / Safe preview toggle or segmented control.
- Mute toggle or speaker button.
- Volume slider.
- Safety status line.
- Current route line: `Uses gpt-realtime-translate output audio`.
- A plain-language disabled reason when prerequisites are missing.

In the main window, add only compact controls:

- speaker/mute icon button when playback is available;
- visible "translated audio playing" state only while audio is actively queued or playing;
- no large new panel, no marketing copy.

### FR-M8-008: Cost and Observability

Log structured metadata only:

- playback enabled/disabled state;
- safety preflight result;
- first translated audio delta latency;
- first audible buffer latency;
- queue underrun count;
- queue drop count;
- mute/volume changes;
- reconnect queue clears.

Do not log raw audio or private transcript text.

Cost display must state that playback uses the existing `gpt-realtime-translate` session unless the latest official pricing docs expose a separate output-audio charge.

### FR-M8-009: Export Behavior

Existing text exports remain the default. M8 should not add audio file export unless the implementation is intentionally scoped and tested.

If playback was active during a session, exported text metadata may include:

```text
Translated audio playback: enabled
Playback mode: safe preview
```

Do not write raw translated audio files by default.

---

## 7. Architecture

Target flow:

```text
MicrophoneManager / SystemAudioManager
  -> source-tagged PCM chunks
  -> OpenAIRealtimeCoordinator
     -> OpenAIRealtimeTranslationService (gpt-realtime-translate)
        -> session.output_transcript.delta -> RealtimeEventReducer -> text rows
        -> session.output_audio.delta -> RealtimeTranslatedAudioPlayer -> local audio output
     -> OpenAIRealtimeTranscriptionService sidecar (gpt-realtime-whisper)
        -> source captions -> RealtimeEventReducer -> same text rows
```

Ownership:

- Protocol parsing stays in `OpenAIRealtimeTranslationService`.
- Audio decoding and scheduling stays in a new playback manager.
- Feedback safety stays in app/runtime helpers, not in the reducer.
- Row attachment remains in `RealtimeEventReducer`.
- `AppState` owns route gates and calls the playback manager.
- Settings only mutates state through route-aware setters.

---

## 8. Test and Verification Plan

### 8.1 Local Unit and Smoke Tests

Required tests:

- playback route gate truth table;
- old saved placeholder value cannot enable playback;
- playback manager decodes and queues PCM16 chunks;
- unsupported output format blocks playback;
- mute stops output while text events still reduce;
- stop/reconnect clears queued audio;
- `session.output_audio.delta` ignored when playback gate is false;
- `session.output_audio.delta` reaches playback manager when gate is true and safety status is ready;
- system audio config sets `excludesCurrentProcessAudio`;
- system capture unavailable or exclusion failure disables playback;
- Settings copy separates text interpretation from translated audio playback;
- cost tracker does not double count playback as a second translation session;
- source/translation row attachment tests still pass.

### 8.2 Synthetic Provider Probes

Use generated or non-private audio only.

Required provider probes:

```bash
tools/realtime-foundation/generate_synthetic_probe_audio.sh
tools/realtime-foundation/realtime-foundation probe \
  --mode translation \
  --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav \
  --target zh \
  --max-audio-seconds 12 \
  --i-understand-audio-is-sent-to-openai \
  --show-text \
  --capture-output-audio /tmp/mtp_realtime_probe_audio/translated_audio_en_to_zh.wav \
  --timeout 30
```

If the CLI does not yet support `--capture-output-audio`, M8 must add it and verify:

- at least one `session.output_audio.delta` event arrives;
- output format and sample rate are known;
- captured translated audio duration is non-zero;
- translated transcript still arrives before utterance end;
- no private meeting audio is used.

### 8.3 App E2E and Runtime Inspection

Required installed-app or strongest-safe equivalent:

1. Build and install with `./build_app.sh`.
2. Launch `/Applications/MeetingTranslator.app`.
3. Configure:
   - engine: OpenAI Realtime;
   - exactly one source language pinned;
   - different target language;
   - show translations on;
   - live interpreter session on;
   - translated audio playback on only after safety preflight passes.
4. Play synthetic audio.
5. Verify:
   - translated subtitles still appear before utterance end;
   - translated audio becomes audible or is captured by a safe local output probe;
   - source caption and translation attach to one row;
   - own translated audio is not re-captured by system audio;
   - microphone feedback guard blocks or requires headphones confirmation;
   - mute and stop behave immediately;
   - cost/status text is accurate.

If real audible output cannot be verified safely in the active environment, document the blocker and keep playback disabled.

---

## 9. Documentation Requirements

Update these files in the same implementation pass:

- `docs/PRD.md`: add M8 status and user-facing behavior.
- `docs/API.md`: document playback route gate, event contract, safety status, and verification commands.
- `CHANGELOG.md`: describe playback behavior and safety limits.
- `.agents/skills/openai-realtime-voice-foundation/SKILL.md`: add M8 playback rules.
- `docs/prd_feat_realtime_settings_runtime_clarity.md`: update Settings copy from "coming later" to the final implemented wording.
- `tools/realtime-foundation/realtime-foundation`: add or update provider probe support for captured translated audio.
- `tools/realtime-foundation/tests/*`: add playback, Settings, and safety smoke coverage.

---

## 10. Done Means

This PRD is complete only when:

- [ ] The latest official OpenAI docs still support `gpt-realtime-translate` on `/v1/realtime/translations` with translated audio and transcript deltas.
- [ ] Playback remains off by default and cannot be enabled from old saved placeholder state.
- [ ] Playback starts only when M7 interpreter gates and M8 safety gates are true.
- [ ] `session.output_audio.delta` is decoded, queued, and played or captured in the synthetic safe-output path.
- [ ] `session.output_audio.done`, Stop, mute, route downgrade, and reconnect clear or drain audio predictably.
- [ ] System audio capture excludes current-process audio, and a synthetic test proves translated audio is not recaptured.
- [ ] Microphone/speaker feedback is blocked or requires headphones/safe-output confirmation.
- [ ] Source captions, translated text, row attachment, export, and cost tracking remain stable.
- [ ] Settings and main-window controls are clear, small, and honest about safety.
- [ ] Core smoke, app E2E, Settings smoke, provider probes, `./build_app.sh`, app launch/runtime inspection, and GitNexus `detect-changes` all pass.
- [ ] Docs, changelog, skill references, and PRD checkboxes are updated.
- [ ] Meaningful milestone commits exist, with a final commit after verification.

---

## 11. Stop Conditions

Stop and report before continuing if:

- `gpt-realtime-translate` access or `/v1/realtime/translations` contract is unavailable.
- Official OpenAI docs contradict the event usage in this PRD.
- Output audio format cannot be identified without guessing.
- Playback requires enabling `gpt-realtime-2`, legacy TTS, or another model.
- Feedback safety cannot be proven without private meeting audio.
- ScreenCaptureKit current-process audio exclusion is unavailable or fails verification.
- Microphone feedback cannot be controlled and the implementation would need room speakers.
- Text subtitles require translated audio playback to function.
- Source/translation row attachment regresses.
- Caption-only mode starts hidden translation or playback spend.
- Build/sign/install requires changing bundle ID, entitlements, signing identity, or install path.
- Implementation requires new dependencies or `Package.swift` changes without a clear blocker and explicit approval.
- Existing tests fail and the only proposed fix is deleting, skipping, or weakening tests.

---

## 12. Revision History

| Date | Version | Change |
|---|---:|---|
| 2026-05-13 | 1.0 | Goal-ready M8 PRD for safe translated audio playback using `gpt-realtime-translate` output audio, with feedback-safety gates and synthetic verification requirements. |
