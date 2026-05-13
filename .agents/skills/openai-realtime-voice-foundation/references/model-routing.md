# Model Routing

Use the smallest realtime session that matches the product outcome.

## Default Routes

- `showTranslations == false`: `gpt-realtime-whisper`.
- Target language equals known/detected source language: `gpt-realtime-whisper`.
- Translation on, target differs from source, and explicit live-interpreter session mode is enabled: `gpt-realtime-translate` plus a paired `gpt-realtime-whisper` source-caption session.
- User asks for commands, tool calls, summaries, or app actions: `gpt-realtime-2`.

## Transport

- Native macOS/server raw-audio pipeline: WebSocket.
- Browser/mobile capture/playback: WebRTC.
- Transcription sessions: WebSocket `wss://api.openai.com/v1/realtime?intent=transcription`, with `gpt-realtime-whisper` in `session.update`.
- Translation sessions: dedicated `/v1/realtime/translations` endpoint. In Meeting Translator Pro M7, also start a paired transcription session for source captions because provider probes proved translated output deltas from `gpt-realtime-translate` and source deltas from `gpt-realtime-whisper`.

## Cost Gates

Translation cost must be prevented at session start, not only hidden in UI. Start a translation session only when `showTranslations` is on, exactly one source language is pinned, the source differs from the target, and the explicit interpreter-session gate is enabled. In M7, this intentionally starts Translate + Whisper for source-captioned interpretation, so quote about `$3.06/source-hour`, not only the `$2.04/source-hour` Translate output cost. Translated audio playback is a separate output gate and stays off by default; do not use playback-off as proof that no translation session is running.

## Cost Model Snapshot

As refreshed on 2026-05-12:

| Model | Use | Price | Approx. one-hour route |
|---|---|---:|---:|
| `gpt-realtime-whisper` | Streaming captions/STT | `$0.017/min` | `$1.02/source-hour` |
| `gpt-realtime-translate` | Realtime interpretation | `$0.034/min` | `$2.04/source-hour` |
| `gpt-realtime-whisper` + `gpt-realtime-translate` | Separate caption and translation sessions | `$0.051/min` | `$3.06/source-hour` |
| `gpt-realtime-2` | Voice agent/meeting assistant | Audio input `$32/1M tokens`, audio output `$64/1M tokens` | about `$5.76` for 1h input plus 1h output |

`gpt-realtime-2` is not the cost-efficient same-time translation engine. Use it only when the product needs a speaking/reasoning assistant that can summarize, explain, interrupt, call tools, or take app actions.
