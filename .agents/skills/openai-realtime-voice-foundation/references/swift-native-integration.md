# Swift Native Integration

## Boundary Shape

Add protocol logic in focused service files:

- `RealtimeModelRouter`: pure routing decisions.
- `RealtimeEventReducer`: partial/final event reconciliation.
- `AudioResampler`: explicit 16 kHz capture to 24 kHz realtime boundary.
- `OpenAIRealtimeTranscriptionService`: transcription WebSocket.
- `OpenAIRealtimeTranslationService`: translation WebSocket.
- `OpenAIRealtimeAgentService`: future/dev assistant mode.
- `OpenAIRealtimeCoordinator`: owns service lifecycle, routing, and reducer state so `AppState` stays orchestration-focused.

## AppState Role

`AppState` should:

- own user settings and runtime state,
- start/stop services when recording starts/stops,
- apply existing pipeline gates before confirming entries,
- update status and fallback state.

`AppState` should not parse raw Realtime JSON event dictionaries directly.

## Event Names To Normalize

- Transcription partial: `conversation.item.input_audio_transcription.delta`.
- Transcription final: `conversation.item.input_audio_transcription.completed`.
- Translation output text: `session.output_transcript.delta`.
- Translation input/source text: `session.input_transcript.delta`.
- Translation audio: `session.output_audio.delta`.

Normalize to app events before touching UI state.

## 2026-05-10 Probe Notes

- Native transcription WebSocket uses `wss://api.openai.com/v1/realtime?intent=transcription`.
- Do not add `model=gpt-realtime-whisper` to that transcription URL; pass `gpt-realtime-whisper` in `session.update` instead.
- Mark a session ready only after `session.updated`, then allow audio chunks and cost logging.
- Treat `*.delta` payloads as incremental text and accumulate by stable item/turn ID.
- The realtime translation endpoint may emit output transcript/audio deltas without a stable `item_id`; keep a source-local fallback turn ID until a done/completed event.
