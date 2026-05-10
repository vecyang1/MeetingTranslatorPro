# Model Routing

Use the smallest realtime session that matches the product outcome.

## Default Routes

- `showTranslations == false`: `gpt-realtime-whisper`.
- Target language equals known/detected source language: `gpt-realtime-whisper`.
- Translation on, target differs from source, and translated-audio/live-interpreter mode is enabled: `gpt-realtime-translate`.
- User asks for commands, tool calls, summaries, or app actions: `gpt-realtime-2`.

## Transport

- Native macOS/server raw-audio pipeline: WebSocket.
- Browser/mobile capture/playback: WebRTC.
- Transcription sessions: WebSocket `wss://api.openai.com/v1/realtime?intent=transcription`, with `gpt-realtime-whisper` in `session.update`.
- Translation sessions: dedicated `/v1/realtime/translations` endpoint.

## Cost Gates

Translation cost must be prevented at session start, not only hidden in UI. If `showTranslations` is off, translated-audio playback is off, or the source is same-language, close or never open the translation session. Text-only translation can use realtime transcription followed by the app's existing gated text translation path.
