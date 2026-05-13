# Eval Checklist

Do not claim realtime completion without fresh evidence.

## Required Safe Checks

- `tools/realtime-foundation/realtime-foundation probe --mode transcription`
- `tools/realtime-foundation/realtime-foundation probe --mode translation`
- `tools/realtime-foundation/realtime-foundation probe --mode agent`
- `tools/realtime-foundation/realtime-foundation recommend --task interpreter --show-translations --no-same-language --pinned-source-language --interpreter-session`
- Audio probes require `--i-understand-audio-is-sent-to-openai`; use generated or non-private fixtures only.
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
