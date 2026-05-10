# Changelog

## 2026-05-10

### Added

- Added `OpenAI Realtime (Recommended)` as a native macOS engine path.
- Added Swift realtime foundation services: model router, coordinator, event reducer, 16 kHz to 24 kHz PCM resampler, transcription service, translation service, and `gpt-realtime-2` agent/caption service.
- Added realtime cost tracking for `gpt-realtime-whisper`, `gpt-realtime-translate`, and `gpt-realtime-2`.
- Added reusable `.agents/skills/openai-realtime-voice-foundation` skill with Claude/Gemini symlinks.
- Added `tools/realtime-foundation/realtime-foundation` CLI for model routing, model probes, explicit synthetic audio probes, and Swift scaffolding.

### Changed

- Realtime translation sessions are gated at session start: translation sockets are not started when translations are hidden, translated-audio playback is off, same-language is pinned, or source language is unknown.
- `OpenAI Realtime (Recommended)` now uses `gpt-realtime-2` as the main direct captions/dialog path, with `gpt-realtime-whisper` retained as a specialized STT fallback rather than the default user-facing route.
- Text-first OpenAI Realtime no longer layers a separate legacy GPT translation call on top of Realtime-2 agent finals; pinned non-same-language text output is requested directly from Realtime-2.
- Realtime-2 agent parsing now accepts nested final response events and filters short acronym-like debris so code-switched words do not split a sentence into junk rows.
- Realtime partial deltas now accumulate by source/item before final confirmation.
- Realtime final transport chunks now merge into readable same-source/same-language utterance rows instead of one permanent row per committed audio chunk.
- System-audio Realtime-2 chunks now include a short silence tail so server VAD can close short ScreenCaptureKit turns.
- Realtime audio cost is logged only after a ready session accepts an audio chunk for sending.
- `build_app.sh` now compiles the realtime Swift service files without changing signing, entitlements, bundle ID, or install path.

### Verified

- `./build_app.sh` exited 0 and installed `/Applications/MeetingTranslator.app`.
- Synthetic OpenAI realtime transcription, translation, and Realtime-2 agent WebSocket probes passed using local fixtures and the explicit audio consent flag.
- Installed app runtime produced one meaningful Realtime-2 Chinese caption row from a synthetic `say` fixture.
- Installed app runtime also produced a `Speaker (Chinese)` row from system audio alone with microphone capture disabled.

### Fixed

- Removed unsupported `server_vad` turn detection from `gpt-realtime-whisper` sessions and explicitly commit each appended realtime transcription chunk.
- Fixed realtime caption latency and disappearing live text by using continuous latency-preset capture chunks and preserving non-empty realtime partial rows during cleanup/finalization.
- Fixed chopped realtime dialog rows where manual per-chunk commits produced multiple tiny confirmed entries for one continuous thought.
- Fixed intentional realtime Stop/disconnect so heartbeat shutdown errors do not switch the app to the legacy OpenAI fallback.
