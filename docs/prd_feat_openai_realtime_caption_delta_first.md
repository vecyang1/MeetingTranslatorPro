# PRD: OpenAI Realtime Delta-First Captions

**Version:** 1.4
**Date:** 2026-05-12
**Status:** Ready for implementation
**Stage:** M6
**Primary goal:** show useful transcript text while the user is still speaking
**Parent PRD:** `docs/prd_feat_openai_realtime_voice_foundation.md`
**Related docs:** `docs/PRD.md`, `docs/API.md`, `CHANGELOG.md`, `.agents/skills/openai-realtime-voice-foundation/SKILL.md`

---

## 1. Executive Decision

For caption-only OpenAI Realtime, Meeting Translator Pro should use `gpt-realtime-whisper` as the primary route.

The reason is product-specific: the user's main aim is not assistant behavior, tool use, or speech-to-speech dialog. The goal is that grey/live transcript text appears while a person is still speaking. OpenAI's realtime transcription guide documents incremental `conversation.item.input_audio_transcription.delta` events, and the transcription model is intended for low-latency transcript deltas from live audio. `gpt-realtime-2` remains important for later dialog understanding and assistant workflows, but it should not be the default for exact captions if server VAD response boundaries make the user wait until a pause.

Realtime translation is explicitly not part of M6. It is covered by `docs/prd_feat_openai_realtime_translation_next_stage.md`.

Official reference anchors:

- Realtime transcription streams audio chunks and emits incremental transcript deltas: https://developers.openai.com/api/docs/guides/realtime-transcription
- OpenAI developer overview describes `gpt-realtime-whisper` as the model for low-latency transcript deltas: https://developers.openai.com/
- Realtime VAD `silence_duration_ms` affects turn-boundary timing; waiting for a turn boundary is not enough for this UX: https://developers.openai.com/api/docs/guides/realtime-vad

---

## 2. Problem Statement

Current observed behavior: long speech can produce correct grey/live text briefly, but the app may wait for a pause before committing text into the main transcript, or may lose correct grey text during finalization. The user experiences this as missing context while listening and as damaged transcript completeness.

Root product issue:

- A transcript that only appears after the speaker pauses is not "realtime enough" for meetings.
- Realtime-2 with `server_vad` and response boundaries is useful for voice-agent turns, but can behave like "wait until done speaking" for captions.
- The app needs a caption-first path that consumes transcript deltas as they arrive.

---

## 3. Goals

### G1. Text During Speech

The app must show useful source-language transcript text while the speaker is still talking, before the final pause.

Target bands for first visible useful text:

| Preset | Target first useful partial |
|---|---:|
| Aggressive | 0.4-0.8 seconds after sufficient speech audio enters the realtime service |
| Balanced | 1.0-1.6 seconds |
| Accuracy | 2.0-2.8 seconds |

These are targets, not fake guarantees. Completion requires app-level proof that partial text appears before the utterance-ending pause.

### G2. Completeness Over Cosmetic Stability

Partial text may revise, but correct words must not disappear permanently. A stale shorter final must not overwrite a longer correct live draft. A clear correction may replace draft text.

### G3. Preserve Existing Product Boundaries

The feature must preserve source labels, existing engines, signing, permissions, cost tracking, export behavior, hallucination filtering, echo suppression, and same-language translation gates.

### G4. Future-Agent Clarity

Future agents should be able to inspect docs, code, and runtime state and know whether the app used:

- `gpt-realtime-whisper` transcription route
- `gpt-realtime-2` dialog/assistant route
- `gpt-realtime-translate` translation route

---

## 4. Non-Goals

- Do not implement realtime translation in M6.
- Do not add assistant actions, summaries, tool calls, or meeting commands.
- Do not redesign the whole UI.
- Do not remove legacy OpenAI Whisper+GPT, Gemini Flash, or Gemini Live engines; legacy Whisper+GPT is fallback after the Realtime series is available.
- Do not send private ambient meeting audio during tests.
- Do not hardcode secrets or raw transcripts into logs/docs.
- Do not change bundle ID, signing identity, entitlements, or install path.

---

## 5. User Stories

### US-M6-001: Long Speech Shows Text Before Pause

As a user listening to a long sentence, I want grey/live text to appear and keep growing while the speaker continues talking.

Acceptance criteria:

- [ ] A long synthetic utterance produces visible text before the final pause.
- [ ] The first visible useful partial appears in the selected latency preset target band, or the measured miss is documented with reason.
- [ ] The partial row remains visible until a final row replaces or confirms it.
- [ ] The row source label remains microphone or speaker/system audio.

### US-M6-002: Final Transcript Preserves Complete Content

As a user, I want the final transcript to preserve correct words that were visible in grey/live text.

Acceptance criteria:

- [ ] Stale shorter finals preserve a longer correct draft.
- [ ] Corrected finals that are not stale prefixes can replace the draft.
- [ ] Empty or hallucinated finals do not erase good partial text.
- [ ] Duplicate or chopped final chunks do not create unreadable rows.

### US-M6-003: Microphone and System Audio Both Work

As a user, I want the same live-caption behavior for my microphone and for meeting audio from the system.

Acceptance criteria:

- [ ] Microphone E2E with synthetic audio proves pre-pause partial text and complete final text.
- [ ] System-audio E2E with synthetic audio proves pre-pause partial text and complete final text.
- [ ] Both sources keep separate sessions or equivalent source-aware routing.
- [ ] Echo/duplicate suppression still protects against mic/system loopback.

### US-M6-004: Route Is Inspectable

As a future agent or maintainer, I want the route choice to be visible in docs and debug state.

Acceptance criteria:

- [x] `docs/API.md` documents the caption-first route as `gpt-realtime-whisper`.
- [x] `docs/PRD.md` and this PRD agree on M6/M7 boundaries.
- [x] Runtime status or developer-visible state identifies the active realtime mode.
- [x] `CHANGELOG.md` records the behavior change.

---

## 6. Functional Requirements

### FR-M6-001: Caption-First Router

For `OpenAI Realtime (Recommended)` caption-only use, route to `OpenAIRealtimeTranscriptionService` using `gpt-realtime-whisper`.

Required route table:

| Condition | M6 route |
|---|---|
| `showTranslations == false` | `gpt-realtime-whisper` transcription |
| Target equals pinned input language | `gpt-realtime-whisper` transcription |
| Input language auto-detect / unknown | `gpt-realtime-whisper` transcription |
| Translation on but live-interpreter session off | `gpt-realtime-whisper` transcription, then existing text translation gates may run only after final source text if needed |
| Assistant/dialog/action workflow | out of scope for M6, keep `gpt-realtime-2` path available but not the caption default |
| Realtime translation/live interpreter | out of scope for M6, planned M7 |

### FR-M6-002: Transcription Session Contract

The transcription service must:

- Connect to the realtime transcription session endpoint.
- Configure `gpt-realtime-whisper`.
- Send source-tagged PCM audio after the 16 kHz to 24 kHz boundary expected by the service.
- Receive `conversation.item.input_audio_transcription.delta`.
- Receive `conversation.item.input_audio_transcription.completed`.
- Use `item_id` to map deltas and completions.
- Avoid generating a random new item ID for every event when provider item IDs are absent.

### FR-M6-003: Audio Send Cadence

The app must keep continuous small timer chunks during active speech:

| Preset | Capture chunk target |
|---|---:|
| Aggressive | 0.4 seconds |
| Balanced | 1.4 seconds |
| Accuracy | 2.4 seconds |

If turn detection is disabled for transcription sessions, commits should happen at the latency cadence so transcription begins before utterance-end. Manual Whisper commits should include a short same-source audio boundary tail, currently 300ms, so words spanning chunk edges are less likely to be cut off; that tail must clear after low-energy chunks and must not be prepended to the realtime translation primary stream. If server VAD is used experimentally, it must be proven not to wait for the final pause before showing partial text.

### FR-M6-004: Partial Row Reconciliation

Partial transcript rows must update in place by `(source, itemID)`.

Rules:

- Append incoming deltas for the same item.
- Keep a visible draft row while waiting for completion.
- Final completion runs through the same final confirmation filters as other transcript rows.
- Stale shorter final prefix keeps the longer draft.
- Clear non-prefix correction may replace the draft.
- Missing final at stop time promotes non-empty partials through the normal final filters.
- Provider completed items are transport chunks, not always sentence boundaries. The display pipeline must consolidate nearby same-source finals into one readable utterance row, filter unstable tiny fragments, and preserve useful connectors inside a larger utterance. Rolling consolidation must use the latest merged provider chunk timestamp, not only the visible row's first timestamp, so continuous speech does not split just because the row has been alive longer than the base merge window.
- The row UI must not hard-insert newlines into CJK text; it should let the layout wrap naturally so merged Mandarin/Japanese/Korean text remains readable.
- The transcript viewport must have a user-configurable follow mode. When follow is off, new partial/final rows must not force the scroll position down; when follow is on, delayed updates to any visible row should still keep the bottom anchored. While draft text is growing, the UI should avoid implicit layout animation so grey interim text expands below without shaking surrounding rows.

### FR-M6-005: Source Separation

Microphone and system audio must remain source-aware.

Implementation may use one realtime transcription session per active source. If a shared session is ever considered, it must first prove it preserves source labels, overlapping speech, and echo suppression.

### FR-M6-006: Observability Without Transcript Leakage

Record enough runtime evidence to debug latency without logging private content:

- active realtime route
- audio source
- audio chunk duration
- first audio append timestamp
- first partial event timestamp
- final event timestamp
- event type counts
- reconnect/fallback count

Do not log raw audio or full private transcript text.

### FR-M6-007: Failure Recovery

If `gpt-realtime-whisper` session setup or send fails:

- show a plain-language recoverable status
- retry within bounded reconnect limits
- if automatic fallback is enabled, fall back to legacy OpenAI or selected fallback engine
- never silently switch to a hidden translation session

### FR-M6-008: Tests and Probes

Add or extend tests for:

- route choice table
- transcription delta accumulation
- stable item ID fallback
- stale shorter final preservation
- corrected final replacement
- stop-time partial promotion
- incomplete/cancelled done containers ignored
- no hidden translation session in M6 caption mode

---

## 7. UX Requirements

### 7.1 Main Timeline

- Grey/live text should appear as soon as useful partial text exists.
- The row should not flicker in/out.
- The final row should visually settle in place when possible.
- Text must not overflow or overlap controls on narrow windows.

### 7.2 Status Copy

Normal user-facing labels:

- `Realtime captions active`
- `Connecting realtime captions...`
- `Realtime reconnecting...`
- `Switched to fallback engine`

Developer/debug wording may include model names:

- `OpenAI Realtime route: transcription / gpt-realtime-whisper`
- `OpenAI Realtime route: agent / gpt-realtime-2`
- `OpenAI Realtime route: translation / gpt-realtime-translate`

### 7.3 Settings

The friendly engine label remains `OpenAI Realtime (Recommended)`.

Settings must reinforce the runtime model split:

- Realtime is the primary live-caption path: show caption latency, automatic fallback, input-language hinting, translation visibility, and the explicit live-interpreter gate/status.
- Legacy Whisper + GPT is a fallback path: show fast draft and stitch-pass intervals only when `OpenAI Whisper + GPT` is selected.
- Gemini Flash may show its fast/quality pipeline only when selected.
- Gemini Live should be positioned as an alternate/fallback, not as "best for live meetings."
- Translated audio playback remains off/disabled until feedback behavior is proven.

The old fast/stitch pipeline diagram must not appear under `OpenAI Realtime (Recommended)`, because it makes users believe legacy Whisper/GPT intervals affect `gpt-realtime-whisper` captioning.

---

## 8. Architecture

Target M6 flow:

```text
MicrophoneManager / SystemAudioManager
  -> continuous source-tagged PCM chunks
  -> AudioResampler 16 kHz -> 24 kHz
  -> RealtimeModelRouter
  -> OpenAIRealtimeTranscriptionService (gpt-realtime-whisper)
  -> conversation.item.input_audio_transcription.delta/completed
  -> RealtimeEventReducer
  -> AppState final confirmation gates
  -> TranscriptionEntry timeline
```

`AppState` should remain orchestration-only. Realtime protocol parsing belongs inside `OpenAIRealtime*Service` files. Event reduction belongs inside `RealtimeEventReducer`.

---

## 9. Safety and Privacy

- No background capture when recording is off.
- No private ambient audio in tests.
- No raw audio logs.
- No full private transcript logs.
- No hardcoded API keys.
- Keep OpenAI API key handling as-is unless a separate Keychain migration is explicitly scoped.
- Preserve macOS permissions and signed app behavior.

---

## 10. Test and Verification Plan

### 10.1 Unit/Smoke

Required command:

```bash
swiftc Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/*.swift tools/realtime-foundation/tests/realtime_core_smoke.swift -o /tmp/realtime_core_smoke && /tmp/realtime_core_smoke
```

Expected output includes:

```text
realtime core smoke ok
```

### 10.2 Build and Signing

Required commands:

```bash
./build_app.sh
codesign -dv /Applications/MeetingTranslator.app
```

Expected:

- build exits 0
- `/Applications/MeetingTranslator.app` exists
- valid signing identity/team output is present

### 10.3 Synthetic Audio Fixtures

Use synthetic audio only. Example fixture creation:

```bash
say -v Ting-Ting "这是一段比较长的测试语音，我希望字幕在我还没有说完整句话的时候就开始显示出来，并且最后不要丢掉任何一个正确的字。" -o /tmp/mtp_m6_long_zh.aiff
afconvert -f WAVE -d LEI16@16000 /tmp/mtp_m6_long_zh.aiff /tmp/mtp_m6_long_zh.wav
```

English fixture should include a long sentence with numbers, product names, and a deliberate pause at the end.

### 10.4 Probe Verification

Run the realtime foundation transcription probe with explicit consent flag and synthetic audio:

```bash
OPENAI_API_KEY="$API_KEY" tools/realtime-foundation/realtime-foundation probe --mode transcription --audio /tmp/mtp_m6_long_zh.wav --i-understand-audio-is-sent-to-openai --timeout 30
```

Expected:

- sees `conversation.item.input_audio_transcription.delta`
- sees a completion event
- does not time out before useful transcript text appears

### 10.5 App-Level E2E

Required app E2E evidence:

- `/Applications/MeetingTranslator.app` build/sign/install passed on 2026-05-12.
- Fresh-install default engine is `OpenAI Realtime (Recommended)`; existing saved user engine preference remains preserved.
- Provider fixture probe with generated synthetic speech saw `conversation.item.input_audio_transcription.delta` from `gpt-realtime-whisper` before finalization.
- `tools/realtime-foundation/tests/realtime_app_e2e.swift` verifies microphone and system synthetic realtime event flows through `OpenAIRealtimeTranscriptionService` parsing and `RealtimeEventReducer`, with a visible draft row before the synthetic utterance duration ends and one complete final row after completion.
- Microphone synthetic E2E preserves `You`; system synthetic E2E preserves `Speaker` / `Speaker (English)` labeling.
- Evidence avoids private/ambient audio and does not log raw audio or full private transcripts.

---

## 11. Done Means

M6 completion evidence as of 2026-05-12:

- [x] `gpt-realtime-whisper` is the primary caption-only OpenAI Realtime route.
- [x] Synthetic provider probe saw useful transcript delta before final pause/finalization.
- [x] Microphone and system-audio synthetic app-level event E2E both pass.
- [x] Partial rows do not disappear or lose correct tail words in reducer smoke tests.
- [x] Final rows preserve complete transcript content, including stale-prefix final preservation and corrected final replacement.
- [x] Screenshot-driven readability regression covered: nearby same-source Mandarin chunks are consolidated into one row, tiny unstable fragments are filtered, and CJK row text no longer gets manual hard line breaks.
- [x] Fresh installs default to `OpenAI Realtime (Recommended)` while legacy Whisper+GPT remains selectable as fallback.
- [ ] Final GitNexus detect-changes and full end-of-goal audit still required before final claim.

---

## 12. Stop Conditions

Stop and report if:

- OpenAI docs contradict the session/event model in this PRD.
- The configured OpenAI key cannot access `gpt-realtime-whisper`.
- The implementation requires changing signing identity, entitlements, bundle ID, or install path.
- A new dependency is required.
- Private/ambient audio would be needed for E2E.
- Existing tests fail and the only apparent path is weakening or skipping tests.
- Three different implementation attempts fail to produce pre-pause text.

---

## 13. Revision History

| Date | Version | Change |
|---|---:|---|
| 2026-05-12 | 1.0 | Initial M6 PRD: caption-first OpenAI Realtime route using `gpt-realtime-whisper`. |
| 2026-05-12 | 1.1 | Recorded M6 implementation evidence: Realtime Whisper route, provider delta probe, synthetic app E2E for microphone/system labels, and fresh-install Realtime default. |
| 2026-05-12 | 1.2 | Added 300ms same-source audio boundary context for manual Realtime Whisper commits to improve chunk-edge continuity. |
| 2026-05-12 | 1.3 | Added rolling row-consolidation requirement so adjacent final chunks keep merging into one readable utterance after the row's original timestamp is older than the merge window. |
| 2026-05-12 | 1.4 | Added Settings UI contract so Realtime controls do not expose misleading legacy Whisper + GPT pipeline intervals. |
