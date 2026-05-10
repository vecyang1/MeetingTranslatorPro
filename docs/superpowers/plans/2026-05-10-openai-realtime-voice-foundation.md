# OpenAI Realtime Voice Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the OpenAI Realtime Voice Foundation from `docs/prd_feat_openai_realtime_voice_foundation.md` through M0-M4 without regressing existing Meeting Translator Pro engines or signing.

**Architecture:** Keep reusable agent knowledge in a local skill and CLI, keep OpenAI Realtime protocol logic in new Swift services, and keep `AppState` as orchestration only. Realtime partial/final events flow through a reducer before becoming `TranscriptionEntry` rows.

**Tech Stack:** Swift 5.9, SwiftUI, URLSessionWebSocketTask, AVFoundation/ScreenCaptureKit, Python 3 CLI using standard library plus optional `websocket-client`, OpenAI Realtime API over WebSocket.

## Baseline Evidence

- Required files read: 22.
- PRD milestones: 6 (`M0`-`M5`).
- Functional requirements: 12 (`FR-001`-`FR-012`).
- Baseline build before code changes: `./build_app.sh` exited 0 and installed `/Applications/MeetingTranslator.app`.
- Model access probe: `gpt-realtime-whisper`, `gpt-realtime-translate`, and `gpt-realtime-2` all returned HTTP 200 from `/v1/models/{model}` using the configured OpenAI key.
- GitNexus app index: alias `MeetingTranslatorPro`, current commit `cf28781`, with caveat that Swift parser support is unavailable in this local GitNexus install.

## File Structure

- Create `.agents/skills/openai-realtime-voice-foundation/SKILL.md` and references under the same folder.
- Create `tools/realtime-foundation/realtime_foundation.py` plus optional executable wrapper `tools/realtime-foundation/realtime-foundation`.
- Create Swift service/model files under `Sources/MeetingTranslator/Services/OpenAIRealtime/`.
- Modify `Sources/MeetingTranslator/Models/AppSettings.swift` to add the friendly engine and realtime settings enums.
- Modify `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` to support stable realtime item IDs and partial state.
- Modify `Sources/MeetingTranslator/Services/CostTracker.swift` for realtime costs.
- Modify `Sources/MeetingTranslator/Managers/AppState.swift` only at orchestration boundaries.
- Modify `Sources/MeetingTranslator/Views/ContentView.swift`, `SettingsView.swift`, and `TranscriptionRowView.swift` for friendly UI and partial row rendering.
- Modify `build_app.sh` only to add new Swift source files to the existing compile list; do not change signing, entitlements, bundle IDs, or install behavior.
- Update `docs/API.md`, `docs/PRD.md`, `AGENTS.md`, and `CHANGELOG.md` after implementation proof.

## Task 1: Skill and CLI Foundation

**Files:**
- Create: `.agents/skills/openai-realtime-voice-foundation/SKILL.md`
- Create: `.agents/skills/openai-realtime-voice-foundation/references/model-routing.md`
- Create: `.agents/skills/openai-realtime-voice-foundation/references/swift-native-integration.md`
- Create: `.agents/skills/openai-realtime-voice-foundation/references/eval-checklist.md`
- Create: `.agents/skills/openai-realtime-voice-foundation/references/read-media-gemini-integration.md`
- Create: `tools/realtime-foundation/realtime_foundation.py`
- Create: `tools/realtime-foundation/realtime-foundation`

- [x] Write CLI tests by running `realtime_foundation.py models`, `recommend`, and `scaffold --target swift-service --dry-run` before the full implementation exists; expected failure is missing file/command.
- [x] Implement deterministic CLI commands: `models`, `recommend`, `probe`, and `scaffold`.
- [x] Use no-audio-spend model probes by default; require an explicit audio file for audio probes.
- [x] Write concise skill docs that route `gpt-realtime-whisper`, `gpt-realtime-translate`, and `gpt-realtime-2` by outcome.
- [x] Symlink skill into `/Users/vecsatfoxmailcom/.claude/skills` and `/Users/vecsatfoxmailcom/.gemini/antigravity/skills` if those roots exist and the target path is absent or already a matching symlink.
- [x] Validate `SKILL.md` frontmatter, CLI help, model recommendation output, and model access probe.

## Task 2: Swift Realtime Core

**Files:**
- Create: `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift`
- Create: `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModelRouter.swift`
- Create: `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeEventReducer.swift`
- Create: `Sources/MeetingTranslator/Services/OpenAIRealtime/AudioResampler.swift`
- Create: `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift`
- Create: `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift`
- Create: `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift`
- Modify: `build_app.sh`

- [x] Add testable pure Swift router and reducer APIs before connecting them to `AppState`.
- [x] Run a compile expecting missing integration references before wiring into the app.
- [x] Implement WebSocket session setup, event parsing, ready-state handling, and fallback state in services.
- [x] Keep audio resampling as an explicit boundary; existing 16 kHz capture remains unchanged.
- [x] Run `./build_app.sh` and fix compile errors.

## Task 3: AppState and UI Integration

**Files:**
- Modify: `Sources/MeetingTranslator/Models/AppSettings.swift`
- Modify: `Sources/MeetingTranslator/Models/TranscriptionEntry.swift`
- Modify: `Sources/MeetingTranslator/Services/CostTracker.swift`
- Modify: `Sources/MeetingTranslator/Managers/AppState.swift`
- Modify: `Sources/MeetingTranslator/Views/ContentView.swift`
- Modify: `Sources/MeetingTranslator/Views/SettingsView.swift`
- Modify: `Sources/MeetingTranslator/Views/TranscriptionRowView.swift`

- [x] Add `OpenAI Realtime (Recommended)` engine without removing existing engines.
- [x] Add persisted realtime settings using new keys only.
- [x] Route realtime audio chunks to separate source-aware sessions.
- [x] Add partial row reconciliation by `(source, itemID)` and final confirmation through existing empty, hallucination, dedup, language, and translation gates.
- [x] Ensure translation sessions start only when `!sameLanguage && showTranslations`.
- [x] Show friendly connection, fallback, and recoverable error states.
- [x] Run `./build_app.sh`.

## Task 4: Verification and Documentation

**Files:**
- Modify: `docs/API.md`
- Modify: `docs/PRD.md`
- Modify: `AGENTS.md`
- Create or modify: `CHANGELOG.md`
- Modify: `docs/prd_feat_openai_realtime_voice_foundation.md`

- [x] Run CLI no-audio model probe and any available synthetic audio probe.
- [x] Run `./build_app.sh` and verify `/Applications/MeetingTranslator.app` exists.
- [x] Launch the app, inspect process state, and capture the strongest safe UI/runtime proof.
- [x] If private live mic/system verification is unsafe while the user is asleep, record exactly what was skipped and why.
- [x] Update docs with realtime services, settings, costs, invariants, and remaining risks.
- [ ] Run GitNexus `detect_changes` and code review agents.
- [ ] Commit coherent milestones with clear messages.

## Verification Log

- `swiftc ... realtime_core_smoke.swift -o /tmp/realtime_core_smoke && /tmp/realtime_core_smoke` -> `realtime core smoke ok`.
- `./build_app.sh` -> exited 0, signed with existing Apple Development certificate, installed `/Applications/MeetingTranslator.app`.
- `tools/realtime-foundation/realtime-foundation probe --mode transcription` -> model visible.
- `tools/realtime-foundation/realtime-foundation probe --mode translation` -> model visible.
- `tools/realtime-foundation/realtime-foundation probe --mode agent` -> model visible.
- Synthetic fixture `/tmp/mtp_realtime_probe.wav` from macOS `say` sent with explicit consent flag:
  - transcription audio probe saw `conversation.item.input_audio_transcription.delta`.
  - translation audio probe saw `session.output_audio.delta`.
- App launch check saw `/Applications/MeetingTranslator.app/Contents/MacOS/MeetingTranslator` running.
- Skipped live mic/system capture because the user is asleep and ambient/system audio may be private.
