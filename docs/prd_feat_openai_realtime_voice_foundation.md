# PRD: OpenAI Realtime Voice Foundation for Meeting Translator Pro

**Version:** 0.2 implementation checkpoint
**Date:** 2026-05-10
**Status:** M0-M4 implemented with safe synthetic runtime proof; private live mic/system checks deferred
**Primary app:** Meeting Translator Pro
**Input brief:** `../../input/2026-5-10 9-39-34-Realtime_Voice_Skill_Build.md`
**Parent docs:** `docs/PRD.md`, `docs/API.md`, `AGENTS.md`

---

## 0. Implementation Status - 2026-05-10

Completed:

- **M0:** Model access probed with the configured OpenAI key. `gpt-realtime-whisper`, `gpt-realtime-translate`, and `gpt-realtime-2` all returned HTTP 200. A narrow GitNexus app index was refreshed, with the caveat that this local GitNexus install cannot parse Swift symbols.
- **M1:** Reusable skill and CLI foundation created and discoverable through `.agents/skills`, `.claude/skills`, and `.gemini/antigravity/skills`.
- **M2:** Native Swift realtime services, router, coordinator, reducer, and 16 kHz to 24 kHz PCM boundary implemented without changing existing capture format.
- **M3:** UI exposes `OpenAI Realtime (Recommended)`, realtime partial rows, caption latency settings, automatic fallback state, and translation-off rerouting.
- **M4:** Build/sign/install passed; synthetic OpenAI realtime transcription and translation WebSocket probes passed; docs updated.
- **Runtime hotfix:** Realtime captions now use continuous latency-preset chunks instead of VAD-held chunks, manual turn detection is explicit, and non-empty live partial rows are stop-finalized through the same confirmation/filter gates instead of disappearing when final events are delayed.

Safety notes:

- Realtime translation sessions start only when translations are visible, the input language is explicitly pinned to a different target language, and translated-audio playback is enabled.
- Auto-detect and text-only translation start with realtime transcription and may translate final non-same text through the existing gated GPT text translation path.
- Audio probes require an explicit CLI consent flag and should use synthetic or non-private fixtures.
- Private live microphone/system-audio verification was not performed while the user was asleep; synthetic audio probes were used instead.
- User screenshot feedback showed that VAD-first chunking made realtime captions appear late and draft cleanup could erase visible live text. This is now guarded by `RealtimeCaptionLatencyPreset.realtimeCaptureChunkDuration` and `RealtimeDraftFinalizer`.

Known follow-up:

- Implement a true reconnect/retry loop before depending on realtime during unreliable networks. Current behavior surfaces the failure and uses automatic legacy OpenAI fallback when enabled.

---

## 1. Executive Decision

Meeting Translator Pro should make the OpenAI Realtime family the main future live-voice stack, but it should not blindly use `gpt-realtime-2` for every job.

Recommended routing:

| Product need | Primary model | Why |
|---|---|---|
| Live meeting captions / transcript timeline | `gpt-realtime-whisper` | Purpose-built for streaming speech-to-text deltas with tunable latency. |
| Live interpreter / translated audio plus transcript | `gpt-realtime-translate` | Purpose-built translation session on `/v1/realtime/translations`; lower operational complexity than agent-mediated translation. |
| Voice assistant, meeting actions, tool calls, "ask the meeting app to do X" | `gpt-realtime-2` | Reasoning voice model with stronger instruction following and tool reliability. |

The implementation should be **Skill + CLI + native Swift runtime**, with SDKs used selectively:

- **Skill:** durable operating doctrine for future agents: model routing, integration rules, eval checklist, and source links.
- **CLI:** repeatable probes and scaffolds: check model availability, test a sample audio file, recommend route, and generate starter code.
- **Native Swift runtime:** actual Meeting Translator Pro integration using the app's existing microphone/system-audio capture and signed macOS build.
- **OpenAI Agents SDK / official repos:** reference and future web/agent foundation, not a forced dependency in the native Swift app.

---

## 2. Existing Product Context

Meeting Translator Pro is a signed native macOS app that captures microphone audio with AVAudioEngine and system audio with ScreenCaptureKit. The app already has:

- Two-layer transcription: fast draft plus quality/stitch pass.
- OpenAI path: `gpt-4o-mini-transcribe` plus `gpt-4o-mini` translation.
- Gemini Flash REST path: single-call transcription and translation.
- Gemini Live WebSocket path: streaming transcription plus separate translation.
- Translation gating through `showTranslations`.
- Same-language suppression in backend and UI.
- Hallucination filters.
- Echo/duplicate suppression for mic plus speaker loopback.
- Cost tracking and runtime safety guards.

Important existing constraints from `AGENTS.md`:

- Do not break code signing, entitlements, bundle identifiers, or permission persistence.
- Every translation path must check `!sameLanguage && showTranslations`.
- Draft entries are ephemeral; quality entries replace drafts.
- Translation must happen after empty checks, hallucination filtering, overlap removal, and echo dedup.
- Long meetings must keep buffer caps, entry caps, circuit breakers, and noise gates.

---

## 3. Source Research Snapshot

### 3.1 OpenAI Realtime Models

`gpt-realtime-2` is OpenAI's realtime voice reasoning model. The current model page describes it as a reasoning model for realtime voice interactions with text/audio/image input, text/audio output, configurable reasoning effort, stronger tool use, 128K context, and 32K max output tokens. It supports the Realtime endpoint and function calling. Source: https://developers.openai.com/api/docs/models/gpt-realtime-2

`gpt-realtime-translate` is a streaming speech-to-speech translation model. It uses the dedicated realtime translation endpoint, returns translated audio plus transcript deltas while source audio is still arriving, and is priced by audio duration at $0.034/minute in the current model page. Source: https://developers.openai.com/api/docs/models/gpt-realtime-translate

`gpt-realtime-whisper` is a streaming speech-to-text model for live transcript deltas. It is designed for realtime use cases with tunable latency and is priced by audio duration at $0.017/minute in the current model page. Source: https://developers.openai.com/api/docs/models/gpt-realtime-whisper

OpenAI's realtime overview explicitly separates three session goals: voice agent on `/v1/realtime`, translation on `/v1/realtime/translations`, and transcription sessions for transcript deltas. It recommends `reasoning.effort: low` as a production starting point for Realtime 2 and says WebRTC fits browser/mobile audio while WebSocket fits server/raw-audio pipelines. Source: https://developers.openai.com/api/docs/guides/realtime

OpenAI's launch article from 2026-05-07 frames the release as three audio models: GPT-Realtime-2, GPT-Realtime-Translate, and GPT-Realtime-Whisper. It also states that developers must make clear to end users when they are interacting with AI unless obvious from context. Source: https://openai.com/index/advancing-voice-intelligence-with-new-models-in-the-api/

### 3.2 YouTube Video Research

`Read-Media-Gemini` successfully summarized the provided YouTube URL through Vector Engine on 2026-05-10. Key video-derived notes for this PRD:

- GPT-Realtime-2 expands realtime voice from 32K-class context to 128K context and supports multiple reasoning tiers.
- The video emphasizes low/default reasoning for realtime feel and higher reasoning only for complex analytical tasks.
- The video highlights parallel tool calling, preambles/filler phrases to cover backend work, tone control, and demos such as voice-to-action, voice-to-document, and voice-to-browser.
- Implementation caution: high reasoning increases latency; high-stakes workflows still require human review.

### 3.3 Existing Local Media Skill Foundation

The existing local skill at `/Users/vecsatfoxmailcom/.claude/skills/Read-Media-Gemini` is a symlink to `/Users/vecsatfoxmailcom/.gemini/antigravity/skills/Read-Media-Gemini`. It already supports YouTube URLs directly through Gemini `Part.from_uri`, plus `yt-dlp` fallback for many web video sources. It should be reused as the research ingestion layer for videos, demos, and model talks. Do not duplicate that media-reading capability in the new OpenAI realtime skill.

### 3.4 GitHub Foundations Checked

Current GitHub candidates checked on 2026-05-10:

| Repo | Stars | Fit | Decision |
|---|---:|---|---|
| `openai/openai-realtime-agents` | 6,855 | Official TypeScript demo for advanced Realtime API agent patterns. | Use as primary architecture reference for voice agents, handoffs, tools, guardrails. |
| `openai/openai-agents-js` | 2,992 | Official TypeScript Agents SDK; includes realtime/voice agent surface. | Use for future web/browser agent foundations and skill references. |
| `openai/openai-agents-python` | 26,112 | Official Python Agents SDK; voice pipeline and realtime docs exist. | Use for eval helpers, scripted experiments, and non-Swift prototypes. |
| `thorwebdev/expo-webrtc-openai-realtime` | 144 | React Native WebRTC example. | Reference only for mobile/WebRTC patterns. |
| `realtime-ai/openai-realtime-webrtc-go` | 107 | Go WebRTC client. | Reference only if a server bridge is needed. |
| `realtime-ai/openai-realtime-webrtc-python` | 47 | Python WebRTC client. | Reference only after audit; not a primary foundation. |
| `Barty-Bart/openai-realtime-api-voice-assistant-V2` | 129 | Voice assistant with RAG/function calling/caller history. | Useful pattern library, but not a dependency. |

Use official OpenAI repos first. Third-party repos are idea mines only until license, security, dependency health, and maintenance cadence are reviewed.

---

## 4. Goals

### G1. Make OpenAI Realtime the recommended live engine family

The app should present OpenAI Realtime as the preferred path for live captions and live translation once verified, while preserving the existing OpenAI non-realtime and Gemini engines as fallback.

### G2. Reduce perceived latency

The user should see partial captions while speech is still happening. Target evaluation bands:

- Aggressive captions: first useful delta around 0.4-0.8 seconds.
- Balanced captions: first useful delta around 0.8-1.2 seconds.
- Accuracy-biased captions: first useful delta around 1.5-2.0 seconds.

The implementation must test against real meeting-style audio, accents, code-switching, background noise, product names, and numbers.

### G3. Keep translation intuitive and cost-aware

When translation is enabled and target language differs from the detected/spoken language, the app should route to realtime translation. When translation is disabled or same-language output is requested, it should not spend on translation.

### G4. Build a reusable foundation for future agents

Create a reusable OpenAI realtime skill and companion CLI so future agents can avoid rediscovering model routing, transport choices, event handling, and verification steps.

### G5. Preserve existing app reliability

Do not regress code signing, permissions, existing engines, cost tracking, duplicate suppression, same-language suppression, export, settings persistence, or long-meeting safeguards.

---

## 5. Non-Goals

- Do not replace all existing engines in the first implementation.
- Do not build a full browser app; this is a native macOS app.
- Do not make `gpt-realtime-2` the default translator for pure translation/caption workflows.
- Do not add autonomous meeting actions without a user-visible approval gate.
- Do not remove the two-layer legacy pipeline until realtime paths are proven better on real audio.
- Do not create a new YouTube/media reading skill; reuse `Read-Media-Gemini`.

---

## 6. User Stories

### US-001: Live captions with lower latency

As a user in a Zoom/Teams/Meet call, I want captions to appear while people are still talking so I can follow the meeting without waiting for chunked transcription.

Acceptance criteria:

- The engine can stream partial transcript deltas into the existing timeline.
- Final transcript events reconcile partial text without duplicate rows.
- The user can choose latency/accuracy behavior through clear presets.
- Existing hallucination and duplicate suppression still apply before final entries are confirmed.

### US-002: Live translation mode

As a user listening to a foreign-language meeting, I want translated text and optionally translated audio to arrive in near-real time.

Acceptance criteria:

- The app can start a dedicated realtime translation session.
- The app does not call translation when `showTranslations` is false.
- Same-language output routes to transcription-only rather than translation.
- Translation cost is visible in the title/status area.

### US-003: OpenAI Realtime as a safe default

As a non-coder user, I want the app to pick the right OpenAI realtime route automatically, without me needing to understand model names.

Acceptance criteria:

- UI shows one friendly engine label: `OpenAI Realtime`.
- Advanced settings expose the chosen mode only when needed.
- The app explains recoverable setup problems in plain language.
- Existing Gemini/OpenAI legacy engines remain selectable as fallback.

### US-004: Future-agent foundation

As a future agent working on voice features, I want a reusable skill and CLI so I can inspect docs, choose models, scaffold probes, and run evals consistently.

Acceptance criteria:

- A new skill exists under `.agents/skills/openai-realtime-voice-foundation`.
- Symlinks or copies exist for `.claude/skills` and `.gemini/antigravity/skills` if appropriate.
- The skill references `Read-Media-Gemini` for video/media ingestion.
- The CLI can recommend model route, probe env/model availability, and scaffold sample code.

---

## 7. Functional Requirements

### FR-001: Model Router

Create a single routing decision layer with this default behavior:

| Condition | Route |
|---|---|
| `showTranslations == false` | `gpt-realtime-whisper` transcription session. |
| Target language equals detected/specified input language | `gpt-realtime-whisper` transcription session. |
| Translation on, live translated speech wanted | `gpt-realtime-translate` translation session. |
| User asks the app to reason, call tools, summarize, or act | `gpt-realtime-2` voice-agent session. |
| Realtime session fails or quota unavailable | Existing OpenAI/Gemini fallback engine selected by user or automatic fallback setting. |

The router must be testable without audio hardware.

### FR-002: Swift Realtime Transport Layer

Add a native Swift transport boundary instead of mixing WebSocket logic directly into `AppState`.

Proposed services:

- `OpenAIRealtimeTranscriptionService`
- `OpenAIRealtimeTranslationService`
- `OpenAIRealtimeAgentService` for pilot/future assistant mode
- `RealtimeEventReducer`
- `AudioResampler`

The services should expose stable app-level events:

- `partialTranscript(source, itemID, text, timestamp)`
- `finalTranscript(source, itemID, text, language, timestamp)`
- `partialTranslation(source, itemID, text, timestamp)`
- `finalTranslation(source, itemID, text, language, timestamp)`
- `translatedAudioChunk(source, data, timestamp)` if translated audio playback ships
- `sessionStateChanged(state)`
- `usageUpdated(usage)`
- `recoverableError(message, action)`

### FR-003: Audio Format Compatibility

The current app captures 16 kHz mono PCM. OpenAI realtime WebSocket examples use 24 kHz PCM16 for raw audio. The implementation must add an explicit resampling boundary and verify accepted formats before shipping.

Acceptance criteria:

- 16 kHz capture remains unchanged for existing engines unless a broader audio refactor is approved.
- Realtime services receive the format they expect.
- Resampling is measured for CPU and latency on the user's M1 Max Mac.
- Audio source labels remain preserved for microphone vs system audio.

### FR-004: Dual Source Session Strategy

The app must keep microphone and system audio distinguishable. Default implementation should use separate realtime sessions per active audio source rather than merging sources into one stream.

Rationale:

- Existing UI has source labels.
- Echo suppression depends on source-aware comparison.
- Translation/transcription events are easier to reconcile by source.
- Speaker overlap from mic plus system audio is less likely to corrupt one shared session.

### FR-005: Partial Text Reconciliation

Partial deltas must not create permanent duplicate entries. The UI needs an in-progress row per `(source, itemID)` that updates until final completion.

Rules:

- Partial rows may revise text.
- Final rows pass through hallucination and duplicate checks before confirmation.
- Ordering must use item IDs and timestamps because completion events can arrive out of order.
- If a final event is missing while the session is stopped, visible partial rows are collected as final candidates and promoted through the same confirmation/filter gates. Stale partial auto-timeout during active recording is intentionally deferred until late-final replacement behavior is implemented.

### FR-006: Translation Gating

All realtime translation logic must preserve existing gating discipline:

```swift
let needsTranslation = !sameLanguage && showTranslations
```

For dedicated translation sessions, this means the app must not start or maintain a translation session when `needsTranslation` is false.

### FR-007: Realtime Cost Tracking

Extend `CostTracker` with realtime-specific entries:

- `OpenAI Realtime Whisper` duration cost.
- `OpenAI Realtime Translate` duration cost.
- `OpenAI Realtime 2` audio/text token cost.
- Optional cached-input cost if exposed by session usage events.

The cost UI must separate transcription, translation, and agentic voice costs.

### FR-008: Failure Recovery

Realtime connections must support:

- Initial connection timeout.
- Heartbeat/ping or equivalent session-health detection.
- Reconnect with bounded exponential backoff.
- Automatic fallback to existing engine if enabled.
- User-facing recovery copy with action buttons such as `Retry`, `Use Legacy OpenAI`, or `Use Gemini`.

### FR-009: User Settings

Add settings without breaking existing keys:

| Setting | Default | Notes |
|---|---|---|
| Realtime enabled | On after verified build | Feature flag until live E2E passes. |
| Realtime mode | Auto | Auto chooses transcription vs translation vs agent. |
| Caption latency preset | Balanced | Maps to transcription latency tuning. |
| Reasoning effort | Low | Only for `gpt-realtime-2`; advanced setting. |
| Translated audio playback | Off | Text-first by default to avoid meeting feedback loops. |
| Automatic fallback | On | Uses legacy OpenAI/Gemini path after recoverable realtime failure. |

### FR-010: Skill Foundation

Create a reusable skill:

```text
.agents/skills/openai-realtime-voice-foundation/
  SKILL.md
  references/
    model-routing.md
    swift-native-integration.md
    agents-sdk-foundations.md
    eval-checklist.md
    read-media-gemini-integration.md
  scripts/
    realtime_foundation_probe.py or realtime-foundation.mjs
```

Skill responsibilities:

- Explain when to use `gpt-realtime-2`, `gpt-realtime-translate`, and `gpt-realtime-whisper`.
- Route browser/mobile clients to WebRTC and native/server raw-audio pipelines to WebSocket.
- Reuse `Read-Media-Gemini` for YouTube/video/doc research.
- Point future agents to official OpenAI repos first.
- Include verification gates before claiming realtime work complete.

### FR-011: CLI Foundation

Add a small CLI for future agents:

```bash
realtime-foundation models
realtime-foundation recommend --task live-translation --client native-macos
realtime-foundation probe --mode transcription --audio sample.wav
realtime-foundation probe --mode translation --audio sample.wav --target ja
realtime-foundation scaffold --target swift-service
```

The CLI should not become the app runtime. It is for repeatable setup, probes, and scaffolding.

### FR-012: Documentation Updates

When implementation begins, update:

- `docs/API.md` with new services, events, settings, and pricing.
- `docs/PRD.md` with feature status or link to this PRD.
- `AGENTS.md` with new realtime pipeline invariants.
- `CHANGELOG.md` if it exists; otherwise create it only when code changes are meaningful.

---

## 8. UX Requirements

### 8.1 Engine Selection

Default label should be user-friendly:

```text
OpenAI Realtime (Recommended)
```

Advanced hover/detail copy:

```text
Uses live OpenAI sessions for captions, translation, or voice assistant features depending on your settings.
```

### 8.2 Live Timeline Behavior

- Partial text should feel stable, not jittery.
- Finalized text should visually settle without a distracting animation.
- Translation should appear below the original text exactly like current entries.
- If translated audio playback ships, it must be off by default to avoid feedback into meeting audio.

### 8.3 Setup Experience

The app should not expose raw model names as the main path. Settings should tell the user:

- Whether OpenAI API key is present.
- Whether realtime model access is available.
- Whether fallback is enabled.
- Whether the current mode is captions, translation, or assistant.

### 8.4 Error Copy

Never show raw transport errors as the primary message. Examples:

| Failure | User message |
|---|---|
| Missing API key | "Add your OpenAI API key to use OpenAI Realtime." |
| Realtime quota/access missing | "OpenAI Realtime is not available for this key yet. I can use the existing engine instead." |
| Network disconnect | "Realtime connection dropped. Reconnecting..." |
| Reconnect exhausted | "Realtime could not reconnect. Switched to fallback engine." |

---

## 9. Architecture

### 9.1 Target Runtime Flow

```text
MicrophoneManager/SystemAudioManager
  -> source-tagged PCM chunks
  -> AudioResampler when needed
  -> RealtimeModelRouter
  -> OpenAIRealtime*Service
  -> RealtimeEventReducer
  -> AppState entry pipeline checks
  -> TranscriptionEntry timeline
```

### 9.2 Services

`AppState` should orchestrate but should not own protocol details. The new services own OpenAI connection setup, event parsing, reconnects, and usage events.

### 9.3 Fallback

The existing OpenAI Whisper + GPT, Gemini Flash, and Gemini Live engines remain valid. Realtime becomes the preferred route only after:

- Model access is confirmed.
- Build passes.
- Local live or file-based realtime smoke test passes.
- E2E UI behavior is visually checked.

### 9.4 Skill/CLI Separation

The reusable foundation should live outside app runtime concerns. It may know how to scaffold Swift code, but the app should not import a JS/Python CLI at runtime.

---

## 10. Security and Privacy

- Standard OpenAI API keys must never be exposed in a browser context.
- Native app keys should move toward Keychain storage. If key migration is in scope, preserve existing `UserDefaults` values by importing once and then clearing plaintext.
- Realtime sessions must start only after the user explicitly starts recording.
- The UI should make live AI transcription/translation obvious through app state.
- Do not send local meeting audio to any provider when recording is stopped.
- Add safety identifiers only if the app has a stable privacy-preserving user/session ID.
- Avoid logging raw meeting audio or full transcript text in debug logs.

---

## 11. Observability

Track per session:

- Realtime connection state.
- First delta latency.
- Final transcript latency.
- Reconnect count.
- Fallback count.
- Empty transcript count.
- Duplicate suppression count.
- Hallucination suppression count.
- Cost by model/mode.
- Audio dropped by noise gate.

Logs should be severity-filtered. Debug event traces can be available behind a developer setting but should not clutter normal user output.

---

## 12. Testing and Verification

### 12.1 Before Code

- Run `gitnexus analyze --embeddings --skills` or refresh the stale parent index before any implementation work.
- Run impact analysis before editing exported symbols or shared pipeline functions.
- Verify OpenAI model IDs and account access with a live model probe.

### 12.2 Unit Tests

Add tests for:

- Model router decisions.
- Event reducer partial/final reconciliation.
- Same-language and `showTranslations` gating.
- Reconnect state transitions.
- Cost calculations.
- Audio format conversion boundaries where practical.

### 12.3 Fixture Tests

Use short prerecorded audio fixtures:

- English only.
- Chinese only.
- Japanese only.
- English plus Chinese code-switching.
- Product names, dates, numbers, and email addresses.
- Background noise and overlapping speakers.

### 12.4 Runtime Verification

Minimum completion proof before claiming implementation done:

1. `./build_app.sh` succeeds and preserves signing.
2. App launches from `/Applications/MeetingTranslator.app`.
3. Microphone path streams partial and final captions.
4. System audio path streams partial and final captions from a real meeting/video source.
5. Translation mode works for at least two language pairs.
6. Turning translation off stops translation session spend.
7. Fallback engine works after forced realtime disconnect.
8. Cost display updates with realtime costs.
9. UI screenshot or visual check confirms no overlap or confusing layout.

---

## 13. Implementation Milestones

### M0: Research and Probe

- Save current OpenAI docs/source snapshot.
- Run model availability probe with the user's actual OpenAI key.
- Save YouTube/video summary from `Read-Media-Gemini` as a research note if needed.
- Refresh GitNexus.

### M1: Skill and CLI Foundation

- Create the reusable skill.
- Add CLI recommendation/probe/scaffold commands.
- Validate skill frontmatter and run CLI help/probe tests.
- Add symlinks for Claude/Gemini/Codex discovery if appropriate.

### M2: Native Swift Realtime Services

- Add transport services and event reducer.
- Add audio resampling boundary.
- Add model router and settings.
- Keep existing engines untouched.

### M3: UI Integration

- Add `OpenAI Realtime (Recommended)` engine option.
- Add live partial row behavior.
- Add advanced realtime settings.
- Add actionable error recovery.

### M4: Verification and Docs

- Run build, unit tests, fixture tests, live runtime tests, and visual check.
- Update `docs/API.md`, `docs/PRD.md`, `AGENTS.md`, and changelog/version as needed.
- Commit in small milestones.

### M5: Optional Agentic Assistant Mode

- Add `gpt-realtime-2` mode for voice commands, summaries, and meeting actions.
- Keep actions approval-gated.
- Use official OpenAI realtime agent examples and Agents SDK docs as references.

---

## 14. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Realtime model access unavailable for the key | Feature cannot run live | Probe before coding deep; keep legacy engines. |
| WebSocket event complexity bloats `AppState` | Hard-to-debug regressions | Put protocol logic in services and reducer. |
| Translation session spends money while hidden | Cost leak | Never start translation session unless `needsTranslation` is true. |
| Partial transcript jitter feels messy | Poor UX | Use one in-progress row per item and reconcile final events. |
| 16 kHz to 24 kHz conversion adds latency | Worse realtime feel | Measure resampling cost and tune chunk size. |
| Meeting audio includes private content | Privacy risk | No debug raw audio logs; explicit recording state. |
| Agent mode performs unsafe actions | User trust risk | Keep agentic actions off by default and approval-gated. |
| GitNexus index stale | Bad blast-radius judgment | Refresh before implementation. |

---

## 15. Open Questions with Recommended Defaults

1. Should `gpt-realtime-2` ship in the first app release?
   - Recommendation: no. Build its foundation and optionally a hidden/dev assistant mode, but ship captions/translation first.

2. Should native macOS use WebRTC or WebSocket?
   - Recommendation: WebSocket first. The app already owns raw audio capture. WebRTC is better for browser/mobile clients that capture/play audio directly.

3. Should translated audio playback ship immediately?
   - Recommendation: no. Text-first is safer for meetings. Add translated audio after echo/feedback behavior is proven.

4. Where should the reusable skill live?
   - Recommendation: canonical source in `.agents/skills/openai-realtime-voice-foundation`, with symlinks into `.claude/skills` and `.gemini/antigravity/skills`.

5. Should OpenAI Realtime replace Gemini Live?
   - Recommendation: not until E2E evidence proves it is better for this app's real meeting conditions. Keep Gemini Live as fallback.

---

## 16. Done Means

This feature is complete only when:

- The PRD is accepted and implementation milestones are tracked.
- The reusable skill and CLI are created and validated.
- The native app builds, signs, launches, and runs from `/Applications/MeetingTranslator.app`.
- OpenAI Realtime transcription works on mic and system audio.
- OpenAI Realtime translation works with translation gating and cost tracking.
- Existing engines still work.
- Runtime/E2E proof is captured.
- API docs, project PRD link/status, AGENTS.md invariants, changelog, and version are updated.

---

## 17. Source Links

- OpenAI model: `gpt-realtime-2` - https://developers.openai.com/api/docs/models/gpt-realtime-2
- OpenAI model: `gpt-realtime-translate` - https://developers.openai.com/api/docs/models/gpt-realtime-translate
- OpenAI model: `gpt-realtime-whisper` - https://developers.openai.com/api/docs/models/gpt-realtime-whisper
- OpenAI realtime overview - https://developers.openai.com/api/docs/guides/realtime
- OpenAI realtime translation guide - https://developers.openai.com/api/docs/guides/realtime-translation
- OpenAI realtime transcription guide - https://developers.openai.com/api/docs/guides/realtime-transcription
- OpenAI voice agents guide - https://developers.openai.com/api/docs/guides/voice-agents
- OpenAI launch article, 2026-05-07 - https://openai.com/index/advancing-voice-intelligence-with-new-models-in-the-api/
- Official repo: `openai/openai-realtime-agents` - https://github.com/openai/openai-realtime-agents
- Official repo: `openai/openai-agents-js` - https://github.com/openai/openai-agents-js
- Official repo: `openai/openai-agents-python` - https://github.com/openai/openai-agents-python
- Existing media ingestion skill - `/Users/vecsatfoxmailcom/.claude/skills/Read-Media-Gemini`
