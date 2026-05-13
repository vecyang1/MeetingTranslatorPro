# Eval Checklist

Do not claim realtime completion without fresh evidence.

## Required Safe Checks

- `tools/realtime-foundation/realtime-foundation probe --mode transcription`
- `tools/realtime-foundation/realtime-foundation probe --mode translation`
- `tools/realtime-foundation/realtime-foundation probe --mode agent`
- `tools/realtime-foundation/realtime-foundation recommend --task interpreter --show-translations --no-same-language --pinned-source-language --interpreter-session`
- `tools/realtime-foundation/run_realtime_mission_verification.sh --local-only`
- Audio probes require `--i-understand-audio-is-sent-to-openai`; use generated or non-private fixtures only. Generate local macOS fixtures with `tools/realtime-foundation/generate_synthetic_probe_audio.sh`, then use `probe --max-audio-seconds 8` or higher for long-utterance translation checks.
- Run `tools/realtime-foundation/run_realtime_mission_verification.sh` without `--local-only` only when a valid `OPENAI_API_KEY` is available, because it sends generated synthetic audio to OpenAI. The probe harness should work without optional Python WebSocket/audio packages by using its standard-library fallback.
- 2026-05-13 final provider gate passed for `gpt-realtime-whisper`, `gpt-realtime-translate` EN->ZH, `gpt-realtime-translate` ZH->EN, `gpt-realtime-translate` code-switch, and `gpt-realtime-2` agent text with generated fixtures.
- Diarization probes require generated/non-private multi-speaker audio and a valid key with `gpt-4o-transcribe-diarize` access.
- `./build_app.sh`
- `/Applications/MeetingTranslator.app` exists and launches
- Translation off does not start translation sessions
- Same-language mode does not start translation sessions
- Existing engines remain selectable

## Runtime Checks When Safe

- Microphone realtime captions.
- System-audio realtime captions from synthetic or non-private playback.
- At least two translation language pairs.
- Forced disconnect fallback.
- Cost display update.
- Speaker recognition off by default, and delayed labels only update finalized system-audio rows.

If the user is asleep, ambient audio may be private, or no valid OpenAI key is available, skip live mic/system/provider recording and record the exact reason.
