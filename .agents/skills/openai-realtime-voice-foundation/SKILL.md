---
name: openai-realtime-voice-foundation
description: Use when building or auditing OpenAI Realtime voice features for Meeting Translator Pro, native/server raw-audio pipelines, realtime transcription, live translation, voice-agent routing, or agent handoff docs that must preserve cost gates and runtime proof.
---

# OpenAI Realtime Voice Foundation

## Core Rule

Choose the realtime model by product outcome and UX promise:

| Outcome | Model | Endpoint |
|---|---|---|
| Main Meeting Translator Realtime captions / dialog understanding | `gpt-realtime-2` | `/v1/realtime` |
| Specialized raw STT fallback / transcript deltas | `gpt-realtime-whisper` | transcription session |
| Live translation / interpreter | `gpt-realtime-translate` | `/v1/realtime/translations` |
| Assistant, tools, actions, reasoning | `gpt-realtime-2` | `/v1/realtime` |

For Meeting Translator Pro, the user-facing `OpenAI Realtime (Recommended)` path is led by `gpt-realtime-2` for direct "hear, understand, output" captions/dialog. Keep meeting actions and tool calls approval-gated, but do not demote the main realtime caption experience back to chunked Whisper unless the Realtime-2 route is unavailable.

## Meeting Translator Invariants

- Do not alter bundle ID, signing identity, entitlements, permission behavior, or `build_app.sh` install path.
- Never start or maintain a translation session unless `!sameLanguage && showTranslations` and translated-audio/live-interpreter mode is enabled.
- Translation-off, same-language, and auto-detect-with-unknown-source modes should stay on `gpt-realtime-2` captions/dialog, not a translation session.
- For text-only OpenAI Realtime with a pinned non-same input language, let `gpt-realtime-2` produce the target text directly; do not layer a second legacy GPT text-translation call on agent finals.
- Preserve separate microphone and system-audio source labels.
- Partial transcript rows update in place by `(source, itemID)`; final rows still pass empty, hallucination, overlap, echo dedup, language, and translation gates.
- Provider final items may be transport chunks, not user dialog turns. Merge nearby same-source/same-language final chunks into readable utterance rows before display/export.
- Realtime-2 text may arrive as `response.output_text.*`, `response.output_item.done`, or `response.done`; future agents must parse nested final response containers before declaring "no caption output." For nested finals, reconcile by inner `item.id` / `response.output[].id` so existing partial rows finalize in place.
- ScreenCaptureKit system audio may stop delivering buffers immediately after short sounds; append a small silence tail on the system-audio Realtime-2 path so server VAD can close the turn. Do not add that tail to microphone audio.
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

- Treating `gpt-realtime-whisper` as the main user-facing realtime engine after `gpt-realtime-2` is available and verified.
- Using `gpt-realtime-2` to start a hidden translation spend path when translations are off, same-language, or source language is still unknown.
- Hiding translation UI while leaving a translation session connected.
- Mixing mic and system audio into one realtime stream without preserving source identity.
- Treating partial deltas as permanent transcript entries.
- Testing only clean synthetic audio, then claiming meeting-readiness.
