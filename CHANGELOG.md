# Changelog

## 2026-05-13

### Added

- Implemented the local M7 live interpreter route with `gpt-realtime-translate` plus a `gpt-realtime-whisper` source-caption sidecar, gated by visible translations, exactly one pinned source language, non-same source/target languages, and the explicit interpreter-session toggle.
- Added off-by-default delayed speaker-recognition metadata and matching support: finalized system-audio rows can receive later diarization labels without rewriting transcript text, while ambiguous matches are ignored.
- Added Settings `Realtime Captions`, `Live Interpretation`, and `Speaker Recognition` sections so realtime caption controls, interpreter prerequisites, and delayed-label privacy/cost disclosures are separate.
- Added a macOS synthetic provider-audio fixture generator and `probe --max-audio-seconds` so long-utterance realtime translation probes can be run without private meeting audio.
- Added a reusable realtime mission verification runner that executes the local gates, build/install/runtime inspection, and, when not in `--local-only` mode, the synthetic provider probes.
- Added the canonical `docs/prd_feat_openai_realtime_translate_interpreter.md` PRD for true same-time interpretation with `gpt-realtime-translate`; `gpt-realtime-whisper` is documented only as a source-caption audit sidecar in that mode.
- Added `docs/prd_feat_realtime_translated_audio_playback.md` as the M8 goal-ready PRD for safe translated audio playback from `gpt-realtime-translate` output audio, with explicit feedback-safety gates before playback can be enabled.
- Added `docs/prd_feat_realtime_settings_runtime_clarity.md` so the Settings panel can be implemented around realtime captions, live interpretation prerequisites, display behavior, and fallback controls without misleading legacy Whisper + GPT timing.
- Added `docs/prd_feat_realtime_speaker_recognition_sidecar.md` for a later delayed speaker-label sidecar using `gpt-4o-transcribe-diarize`, explicitly outside the realtime translation core.

### Changed

- Marked the older realtime translation PRD as historical/superseded so it is not mistaken for proof that the installed app has shipped user-facing same-time interpretation.
- Updated `docs/PRD.md`, `docs/API.md`, and the OpenAI realtime foundation skill to point future agents at the new PRD split and the `gpt-realtime-translate` interpreter route.
- Updated the realtime docs and skill references so "Translated audio playback (coming later)" now points to the M8 playback PRD instead of an undefined future task.
- Updated the realtime foundation CLI so `recommend --task interpreter` requires `--pinned-source-language` and `--interpreter-session`; translated audio remains a deprecated alias and is no longer the conceptual gate.

### Fixed

- Fixed the pure realtime router so auto-detect and multi-source-language modes cannot start hidden `gpt-realtime-translate` spend even if the interpreter toggle is enabled.
- Fixed output-first translation rebinding so a temporary translation-only row is removed after the paired Whisper source-caption row arrives.
- Fixed translation-mode status presentation so a later sidecar caption socket cannot downgrade the visible runtime state from translation active to captions active.
- Fixed audio provider probe connection handling so TLS/WebSocket setup uses a real connect timeout and invalid keys report a clean session-update error instead of a traceback or premature timeout.
- Fixed the provider probe harness so it can run on the login-shell Python without optional `websocket-client` or `audioop` dependencies.

### Verified

- Local smokes currently pass for realtime core, synthetic realtime app E2E, Settings copy, Settings input-filter placement, transcript follow behavior, language detection, app-logo UI, app-icon visual checks, and `./build_app.sh`.
- Installed `/Applications/MeetingTranslator.app` launches with bundle id `com.meetingtranslator.app`, version `1.0.0`, and the expected Apple Development signature; installed binary strings include the new realtime Settings sections.
- GitNexus `detect_changes` was reviewed for the full diff and reports critical risk in the expected realtime/AppState/routing/reducer/cost flows.
- Full realtime mission verification passes with generated synthetic audio: `gpt-realtime-whisper` source transcript deltas, `gpt-realtime-translate` EN->ZH, `gpt-realtime-translate` ZH->EN, `gpt-realtime-translate` code-switch, and `gpt-realtime-2` agent text output.

## 2026-05-12

### Changed

- Changed caption-only `OpenAI Realtime (Recommended)` routing from `gpt-realtime-2` to `gpt-realtime-whisper` so M6 live captions use the stream-transcription model as the default.
- Centralized realtime price constants for Whisper, Translate, and Realtime-2 estimate math, and documented the route choice: Whisper for captions, Translate for same-time translation MVP, Realtime-2 only for voice-agent/meeting-assistant workflows.
- Added a separate explicit realtime interpreter-session gate so `gpt-realtime-translate` session spend is not conflated with translated audio playback; subtitles can use translation deltas while audio playback stays off by default.
- Updated M7 live interpreter routing to pair `gpt-realtime-translate` output with a `gpt-realtime-whisper` source-caption sidecar, because provider probes proved Translate output events but not consistent source transcript events from the translation stream itself.
- Made `OpenAI Realtime (Recommended)` the fresh-install default engine now that the Realtime series is available, while preserving any existing saved user engine preference.
- Tuned realtime caption presets for readability: Balanced now sends 1.4s chunks and Accuracy sends 2.4s chunks, reducing one-row-per-second caption fragmentation while preserving delta-first live partials.
- Added 300ms per-source audio boundary context before each manual `gpt-realtime-whisper` commit so words at chunk edges are less likely to be cut off or misread.
- Removed manual CJK hard line breaks from transcript rows so Chinese/Japanese/Korean text wraps naturally instead of appearing over-split.
- Updated Settings copy and controls so `OpenAI Realtime (Recommended)` is clearly presented as the primary `gpt-realtime-whisper` live-caption path, while legacy Whisper + GPT fast/stitch intervals only appear under the fallback engine.
- Added a Settings translation toggle and live-interpreter readiness status so the user can see every condition required before `gpt-realtime-translate` can start.
- Added a persisted `Follow latest captions` display toggle in the control bar and Settings so the timeline can stop forcing itself to the bottom while the user reads earlier transcript text.
- Moved the shared noise gate out of `Engine Controls` into `Audio Input Filter`, and changed the copy to make clear it filters captured audio before Realtime, Whisper + GPT, or Gemini receive it.
- Replaced the app icon source with a generated teal/ink realtime-audio mark and warm translation accent, moving away from the old blue-purple theme; the in-app header and empty state now use the same app icon resource instead of the old purple waveform badge.
- Added a bounded OpenAI Realtime network recovery path so transient TLS/WebSocket startup errors retry briefly before automatic fallback.

### Fixed

- Fixed Realtime-2 stale final handling so a shorter provider final no longer overwrites a longer accurate grey/live draft and drops tail words from the transcript.
- Ignored explicit incomplete/cancelled/failed Realtime-2 nested done containers so interrupted responses cannot promote truncated text into the main transcript.
- Fixed missing provider `item_id` handling for `gpt-realtime-whisper` transcription events so deltas and completion share one stable fallback row ID before the next turn rotates.
- Fixed M7 row attachment so Translate output can bind to the latest same-source Whisper caption row, including the output-first case where translated text arrives before source caption text.
- Fixed a screenshot-reported realtime readability regression where short provider finals became many tiny rows, language labels flipped from fragment noise, and bad micro-mishears could survive as standalone entries.
- Expanded realtime utterance consolidation so nearby same-source final chunks merge into a readable paragraph-like row, while unstable tiny fragments are dropped without deleting useful connector words such as Mandarin "就是".
- Fixed rolling realtime utterance consolidation so longer continuous speech keeps merging by adjacent chunk gap instead of splitting once the row's original timestamp is older than the merge window.
- Fixed flashy transcript timeline behavior by removing animated forced scrolling, watching changes across all visible rows, and disabling implicit layout animation on growing live draft text.
- Fixed a Settings side-effect risk where the display-only `Follow latest captions` toggle could refresh active Realtime sessions by calling the full settings save path.
- Fixed the Realtime live-interpreter Settings toggle so it uses a route-aware setter instead of directly mutating saved state, keeping the visible toggle and active Realtime session aligned.
- Fixed a Settings mismatch where translated-audio playback looked disabled but could still be passed to the realtime translation service from an old saved value; translated audio now stays off until explicitly implemented.
- Fixed text-based language fallback so Vietnamese, Turkish, Spanish, and other high-signal Latin-script non-English transcript rows are no longer labeled as English when the realtime provider omits a language code.
- Fixed intermittent `A TLS error caused the secure connection to fail. 0: 13` style Realtime failures so the app shows a reconnecting state and restarts the Realtime session instead of immediately requiring a manual app restart.

### Verified

- Added realtime smoke coverage for stale shorter finals preserving complete draft text and corrected finals still replacing draft text.
- Added realtime smoke coverage for incomplete nested `response.output_item.done` and `response.done` containers being ignored as transcript finals.
- Added realtime smoke coverage for M6 route choice, no hidden translation session in caption mode, Realtime Whisper/Translate hourly cost math, Realtime-2 rough full-duplex hourly estimate, stable transcription fallback IDs, M7 input/output transcript attachment, and translated-audio delta suppression unless playback is explicitly enabled.
- Added realtime smoke coverage for chopped Mandarin final-row consolidation, unstable tiny-fragment filtering, and preserving useful connector fragments inside merged utterances.
- Added realtime smoke coverage for the 300ms per-source audio boundary context, source-specific reset behavior, and cross-source isolation.
- Added realtime smoke coverage for rolling same-source Mandarin chunk merges after the first merged row is older than the base merge window.
- Added synthetic app-level realtime E2E coverage for microphone and system caption rows: visible draft text appears before the synthetic utterance duration ends, then finalizes into one complete row with source-aware labels preserved.
- Verified generated synthetic provider audio against `gpt-realtime-whisper`; OpenAI returned a transcript delta before finalization.
- Extended synthetic app-level realtime E2E coverage for M7 translation: explicit gate-on/off routing, input/output transcript deltas, source/translation final attachment, English -> Chinese, Chinese -> English, separated Translate pricing, and translated-audio suppression by default.
- Verified generated synthetic provider audio in English -> Chinese and Chinese -> English using the M7 paired route; `gpt-realtime-whisper` returned source caption text and `gpt-realtime-translate` returned translated output text in both directions.
- Added Settings copy smoke coverage for Realtime, legacy Whisper + GPT, and Gemini Live engine descriptions.
- Added Settings noise gate UI smoke coverage so the shared input filter cannot drift back under engine-specific controls.
- Added transcript follow UI smoke coverage for the follow-latest setting, non-animated scroll behavior, Settings exposure, stable live draft text rendering, narrow display-only persistence, route-aware interpreter toggling, and all-row scroll-change signatures.
- Added app icon visual smoke coverage, app-logo UI smoke coverage, waveform centerline alignment checks, and a deterministic generator for the icon source asset.
- Added language detector smoke coverage for Vietnamese, Turkish, Spanish, English, and Chinese labels.
- Added realtime smoke coverage for TLS/secure-connection recovery classification, retry limits, permanent auth error exclusion, and exponential retry delay ordering.

## 2026-05-10

### Added

- Added `OpenAI Realtime (Recommended)` as a native macOS engine path.
- Added Swift realtime foundation services: model router, coordinator, event reducer, 16 kHz to 24 kHz PCM resampler, transcription service, translation service, and `gpt-realtime-2` agent/caption service.
- Added realtime cost tracking for `gpt-realtime-whisper`, `gpt-realtime-translate`, and `gpt-realtime-2`.
- Added reusable `.agents/skills/openai-realtime-voice-foundation` skill with Claude/Gemini symlinks.
- Added `tools/realtime-foundation/realtime-foundation` CLI for model routing, model probes, explicit synthetic audio probes, and Swift scaffolding.

### Changed

- Realtime translation sessions are gated at session start: translation sockets are not started when translations are hidden, interpreter mode is off, same-language is pinned, or source language is unknown. Translated-audio playback is a separate output gate.
- `OpenAI Realtime (Recommended)` initially used `gpt-realtime-2` as the main direct captions/dialog path, with `gpt-realtime-whisper` retained as a specialized STT fallback; the 2026-05-12 M6 follow-up changes the caption default to `gpt-realtime-whisper`.
- Text-first OpenAI Realtime no longer layers a separate legacy GPT translation call on top of Realtime-2 agent finals; pinned non-same-language text output is requested directly from Realtime-2.
- Realtime-2 agent parsing now accepts nested final response events and filters short acronym-like debris so code-switched words do not split a sentence into junk rows.
- Realtime partial deltas now accumulate by source/item before final confirmation.
- Realtime final transport chunks now merge into readable same-source/same-language utterance rows instead of one permanent row per committed audio chunk.
- Realtime final confirmation now performs a same-source consolidation pass outside translation mode to repair chopped system-audio rows that finalize without partial text, with strict gates for tail-only duplicate finals.
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
