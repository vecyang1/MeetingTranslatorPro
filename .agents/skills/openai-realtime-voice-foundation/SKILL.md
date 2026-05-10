---
name: openai-realtime-voice-foundation
description: Use when building or auditing OpenAI Realtime voice features for Meeting Translator Pro, native/server raw-audio pipelines, realtime transcription, live translation, voice-agent routing, or agent handoff docs that must preserve cost gates and runtime proof.
---

# OpenAI Realtime Voice Foundation

## Core Rule

Choose the realtime model by outcome, not hype:

| Outcome | Model | Endpoint |
|---|---|---|
| Live captions / transcript deltas | `gpt-realtime-whisper` | transcription session |
| Live translation / interpreter | `gpt-realtime-translate` | `/v1/realtime/translations` |
| Assistant, tools, actions, reasoning | `gpt-realtime-2` | `/v1/realtime` |

For Meeting Translator Pro, the default shipped path is captions/translation first. Keep `gpt-realtime-2` for hidden/dev assistant foundations until user-visible actions have approval gates.

## Meeting Translator Invariants

- Do not alter bundle ID, signing identity, entitlements, permission behavior, or `build_app.sh` install path.
- Never start or maintain a translation session unless `!sameLanguage && showTranslations` and translated-audio/live-interpreter mode is enabled.
- Preserve separate microphone and system-audio source labels.
- Partial transcript rows update in place by `(source, itemID)`; final rows still pass empty, hallucination, overlap, echo dedup, language, and translation gates.
- Keep existing OpenAI Whisper+GPT, Gemini Flash, and Gemini Live engines selectable as fallbacks.
- Do not log raw audio or full private transcripts in debug output.

## Workflow

1. Refresh current OpenAI docs before model/API decisions.
2. Run `tools/realtime-foundation/realtime-foundation models` and `recommend`.
3. Probe model visibility with `probe --mode transcription`, `probe --mode translation`, and `probe --mode agent`.
4. For native macOS/server raw audio, prefer WebSocket and 24 kHz PCM16 at the realtime service boundary.
5. For browser/mobile audio, prefer WebRTC and ephemeral/client secrets.
6. Keep protocol parsing inside `OpenAIRealtime*Service` files and reducer logic inside `RealtimeEventReducer`; keep `AppState` orchestration-only.
7. Before claiming completion, run build, model probes, synthetic audio probes where possible, app launch, and safe runtime checks.

## Read These References

- Model routing: `references/model-routing.md`
- Swift integration boundaries: `references/swift-native-integration.md`
- Verification gates: `references/eval-checklist.md`
- Video/media research reuse: `references/read-media-gemini-integration.md`

## Common Mistakes

- Using `gpt-realtime-2` for pure translation because it is the "main" model.
- Hiding translation UI while leaving a translation session connected.
- Mixing mic and system audio into one realtime stream without preserving source identity.
- Treating partial deltas as permanent transcript entries.
- Testing only clean synthetic audio, then claiming meeting-readiness.
