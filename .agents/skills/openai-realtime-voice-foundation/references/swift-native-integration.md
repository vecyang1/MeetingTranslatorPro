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
- `SpeakerDiarizationMatcher`: delayed sidecar row annotation for finalized system-audio rows only; it must not rewrite transcript text or run inside Realtime sessions.

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
- Translation input/source text: prefer paired `gpt-realtime-whisper` source captions (`conversation.item.input_audio_transcription.*`) for Meeting Translator Pro M7; still parse `session.input_transcript.delta` if the translation stream provides it.
- Translation audio: `session.output_audio.delta`.

Normalize to app events before touching UI state.

## 2026-05-10 Probe Notes

- Native transcription WebSocket uses `wss://api.openai.com/v1/realtime?intent=transcription`.
- Do not add `model=gpt-realtime-whisper` to that transcription URL; pass `gpt-realtime-whisper` in `session.update` instead.
- Do not send `server_vad` turn detection for `gpt-realtime-whisper`; set turn detection to `null` and commit each app audio chunk explicitly after `input_audio_buffer.append`.
- Mark a session ready only after `session.updated`, then allow audio chunks and cost logging.
- Treat `*.delta` payloads as incremental text and accumulate by stable item/turn ID.
- The realtime translation endpoint may emit output transcript/audio deltas without a stable `item_id`; keep a source-local fallback turn ID until a done/completed event.
- 2026-05-12 provider probes showed Translate output but not consistent translation-stream source transcript events. In interpreter mode, the coordinator should fan accepted source audio to both Translate and Whisper, then attach Translate output to the latest same-source Whisper item.
- Output-first translation rows are temporary. When the paired Whisper source caption appears, reducer output should include superseded item IDs so `AppState` removes the temporary translation-only row after rebinding.
- Delayed speaker labels use `/v1/audio/transcriptions` with `gpt-4o-transcribe-diarize`, `response_format=diarized_json`, and `chunking_strategy=auto`; Realtime events should never wait on diarization.

## 2026-05-10 Runtime Lesson

- Realtime models only feel realtime if local capture keeps feeding them. The legacy VAD-first managers can hold active speech until silence, so OpenAI Realtime must enable continuous timer chunking.
- Keep chunk duration owned by the latency preset: aggressive `0.4s`, balanced `1.4s`, accuracy `2.4s`.
- Favor readable utterance rows over one row per commit. `gpt-realtime-whisper` can emit a completed item for every manual commit; reducer/AppState should keep live partials visible, then merge nearby same-source finals and filter unstable tiny fragments before display/export.
- Do not hard-wrap CJK row text in the UI. Manual newline injection makes correctly merged Mandarin/Japanese/Korean text look chopped even when the transcript data is healthy.
- Non-empty realtime partial rows are visible user state, not disposable legacy drafts. If final events lag or are missing on stop, collect the live row as a final candidate and run it through existing filters instead of deleting it on cleanup. Avoid active-recording stale-timeout promotion unless late provider finals can replace the promoted text safely.
