# Changelog

## 2026-05-10

### Added

- Added `OpenAI Realtime (Recommended)` as a native macOS engine path.
- Added Swift realtime foundation services: model router, coordinator, event reducer, 16 kHz to 24 kHz PCM resampler, transcription service, translation service, and dev-only agent service.
- Added realtime cost tracking for `gpt-realtime-whisper`, `gpt-realtime-translate`, and `gpt-realtime-2`.
- Added reusable `.agents/skills/openai-realtime-voice-foundation` skill with Claude/Gemini symlinks.
- Added `tools/realtime-foundation/realtime-foundation` CLI for model routing, model probes, explicit synthetic audio probes, and Swift scaffolding.

### Changed

- Realtime translation sessions are gated at session start: translation sockets are not started when translations are hidden, translated-audio playback is off, same-language is pinned, or source language is unknown.
- Realtime partial deltas now accumulate by source/item before final confirmation.
- Realtime audio cost is logged only after a ready session accepts an audio chunk for sending.
- `build_app.sh` now compiles the realtime Swift service files without changing signing, entitlements, bundle ID, or install path.

### Verified

- `./build_app.sh` exited 0 and installed `/Applications/MeetingTranslator.app`.
- Synthetic OpenAI realtime transcription and translation WebSocket probes passed using a macOS `say` fixture and the explicit audio consent flag.

### Fixed

- Removed unsupported `server_vad` turn detection from `gpt-realtime-whisper` sessions and explicitly commit each appended realtime transcription chunk.
