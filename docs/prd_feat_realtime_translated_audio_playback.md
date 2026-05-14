# PRD: Realtime Translated Audio Playback

**Version:** 1.6
**Date:** 2026-05-14
**Status:** Implemented and verified
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

Current OpenAI documentation reviewed on 2026-05-14:

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

Before M8, the app already received translated audio events from `gpt-realtime-translate`, but runtime discarded them by design:

- `OpenAIRealtimeTranslationService` emits `.translatedAudioChunk` only when constructed with `translatedAudioPlaybackEnabled == true`.
- `AppState.startOpenAIRealtimeSessions()` passed `translatedAudioPlaybackEnabled: false`.
- `AppState.handleOpenAIRealtimeEvent()` ignored `.translatedAudioChunk`.
- Settings displayed `Translated audio playback (coming later)` as disabled.

That was correct for M7. M8 replaces it with an explicit safe-preview playback path. The runtime still keeps playback off by default and only passes `translatedAudioPlaybackEnabled: true` when the full M7 interpreter gate and M8 safety gate are both ready.

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

- [x] Playback is off by default for fresh installs and existing installs.
- [x] Settings exposes playback only under Realtime `Live Interpretation`, not under caption-only controls.
- [x] Playback can be enabled only when M7 text interpreter gates are true:
  - `showTranslations == true`;
  - exactly one source language is pinned;
  - source language differs from target language;
  - `realtimeInterpreterSessionEnabled == true`.
- [x] Playback remains unavailable with a clear reason when system-audio feedback safety cannot be proven.
- [x] Enabling playback reroutes the active Realtime translation session without starting hidden caption-only translation spend.

### US-M8-002: Hear Streaming Translated Audio

As a user, I want translated audio to begin during a long synthetic utterance, not only after the full turn ends.

Acceptance criteria:

- [x] `session.output_audio.delta` is decoded from base64 PCM and queued for playback.
- [x] First playable audio is observed before a long synthetic utterance ends.
- [x] Audio playback continues through multiple 200 ms deltas without clicks from buffer underflow in the local synthetic smoke path.
- [x] `session.output_audio.done` drains or closes the current translated-audio segment without cutting off queued audio.
- [x] Muting stops output immediately while text captions continue.

### US-M8-003: Do Not Feed Back Into Capture

As a user, I do not want translated audio to be transcribed again as meeting speech.

Acceptance criteria:

- [x] `SystemAudioManager` configures ScreenCaptureKit to exclude current-process audio when supported by the local SDK/runtime.
- [x] A synthetic system-audio probe proves translated playback from the app is not captured back into the system-audio transcription path.
- [x] If current-process audio exclusion is unavailable or verification fails, Settings keeps playback disabled and states why.
- [x] If microphone capture is active and the default output appears to be speakers, display audio, HDMI/DisplayPort, AirPlay, aggregate/multi-output, or any unrecognized route, playback is blocked even when stale playback or safe-output confirmation exists.
- [x] Echo/duplicate suppression tests show playback does not create duplicate transcript rows in the synthetic loopback path.

### US-M8-004: Keep Rows, Costs, and Exports Stable

As a user, I want translated audio to be an extra output, not a source of transcript churn.

Acceptance criteria:

- [x] Source captions and translated text still attach to one stable row in source-first and output-first event orders.
- [x] Playback chunks do not create transcript rows.
- [x] Cost tracking keeps source-caption, realtime-translate, and playback state separate.
- [x] Cost UI does not double count playback as a second model session unless official billing docs require a separate output-audio lane.
- [x] Export remains text-only by default and includes a metadata note when translated audio playback was active.

### US-M8-005: Stop, Mute, and Failure Behavior

As a user, I want playback to stop predictably when I stop recording, mute output, or change route gates.

Acceptance criteria:

- [x] Stop recording immediately stops playback and clears queued translated audio.
- [x] Turning off `Show translations`, changing source language to Auto, changing target to same language, or disabling interpreter mode stops playback and reconnects/downgrades the realtime route safely.
- [x] Realtime reconnect clears stale audio queues before a new translation session becomes audible.
- [x] Permanent provider errors do not leave a stuck speaker icon or stale "playing" state.
- [x] Automatic fallback to legacy Whisper + GPT disables playback because legacy fallback does not provide realtime translated audio.

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
@Published var realtimeTranslatedAudioSafeOutputConfirmed: Bool = false
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

M8 uses `AudioOutputRouteInspector.currentDefaultOutputRoute()` to read the CoreAudio default output route name, UID, transport, manufacturer, and data source. `RealtimeTranslatedAudioOutputSafety` then classifies likely room speakers, built-in Mac speakers, display audio, HDMI/DisplayPort, AirPlay, aggregate/multi-output routes, unrecognized outputs, and headphone-like routes.

Rules:

- likely speaker/display/shared routes are blocked while microphone capture is active, regardless of saved confirmation state;
- stale playback opt-in and safe-output confirmation are cleared when a blocked or unrecognized route is detected;
- confirmation is bound to the current output-route fingerprint and must be cleared on route mismatch;
- default-output route changes must refresh the safety gate immediately and stop/reroute active translated playback when the new route is unsafe;
- confirmation may unlock only positive headphone-like routes;
- if the output route cannot be identified, playback remains unavailable instead of guessing;
- Settings copy must say speaker/display output is blocked while the microphone is on and direct users to headphones/non-speaker output.

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

- headphones activation button when the interpreter route is eligible but playback is still off; clicking it is the explicit opt-in that confirms the current headphone-like output route and enables M8 playback when all safety gates pass;
- speaker/mute icon button once playback is enabled;
- visible "translated audio playing" state only while audio is actively queued or playing;
- keep this translated-audio output control visually distinct from the purple system-audio capture level meter so users do not confuse input capture with interpreter playback;
- keep the active microphone input name visible beside the green mic meter, because headphone output safety does not prove the headset microphone is the right input device;
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
- Audio fan-out treats `OpenAIRealtimeTranslationService` as primary. Source-caption sidecar rows may be created only after the same chunk is accepted by Translate; a bounded near-silence continuity tail is sent only to Translate after accepted voiced chunks to preserve interpreter boundaries without committing silence to Whisper or sending unlimited quiet audio.
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

Implementation note: `tools/realtime-foundation/realtime_foundation.py` now supports `--capture-output-audio` and writes the captured translated PCM16 stream as a WAV file for synthetic probes.

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

- [x] The latest official OpenAI docs still support `gpt-realtime-translate` on `/v1/realtime/translations` with translated audio and transcript deltas.
- [x] Playback remains off by default and cannot be enabled from old saved placeholder state.
- [x] Playback starts only when M7 interpreter gates and M8 safety gates are true.
- [x] `session.output_audio.delta` is decoded, queued, and played or captured in the synthetic safe-output path.
- [x] `session.output_audio.done`, Stop, mute, route downgrade, and reconnect clear or drain audio predictably.
- [x] System audio capture config excludes current-process audio, with a local smoke test guarding the ScreenCaptureKit setting.
- [x] Microphone/speaker feedback is blocked for likely speaker/display routes and otherwise requires headphones/non-speaker confirmation.
- [x] Source captions, translated text, row attachment, export, and cost tracking remain stable in local smokes.
- [x] Settings and main-window controls are clear, small, and honest about safety.
- [x] Core smoke, app E2E, Settings smoke, provider probes, `./build_app.sh`, app launch/runtime inspection, and GitNexus `detect-changes` all pass.
- [x] Docs, changelog, skill references, and PRD checkboxes are updated after final verification.
- [x] Meaningful milestone commits exist, with a final commit after verification.

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
| 2026-05-13 | 1.1 | Recorded the local M8 implementation contract: off-by-default safe preview controls, M8 persistence keys, focused PCM16 playback manager, ScreenCaptureKit exclusion config smoke, and provider capture-output probe support. |
| 2026-05-13 | 1.2 | Marked M8 implemented and verified after full mission verification passed with installed-app current-process audio exclusion proof, captured translated output WAVs, build/install/runtime checks, and GitNexus detect-changes. |
| 2026-05-13 | 1.3 | Tightened microphone feedback safety after live use showed MacBook speaker playback could re-enter the microphone. CoreAudio output-route inspection now blocks likely speaker/display/HDMI/AirPlay/aggregate/unrecognized routes while mic capture is active, binds confirmation to the exact route fingerprint, and clears stale playback opt-in plus safe-output confirmation on safety downgrade. |
| 2026-05-14 | 1.4 | Added the main-window headphones activation contract after live use showed AirPods were correctly detected but playback stayed off because confirmation and opt-in were hidden in Settings. |
| 2026-05-14 | 1.5 | Added the microphone-input clarity requirement after live AirPods testing showed headphone output can switch macOS input to the headset mic; users must be able to select Mac mic while keeping translated audio on headphones. |
| 2026-05-14 | 1.6 | Recorded the live-translation hang fix: Translate is now primary in fan-out, a bounded quiet-continuity tail reaches `gpt-realtime-translate`, and Stop clears stale pending translation state before playback/safety completion is claimed. |
