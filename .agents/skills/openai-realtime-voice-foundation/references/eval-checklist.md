# Eval Checklist

Do not claim realtime completion without fresh evidence.

## Required Safe Checks

- `tools/realtime-foundation/realtime-foundation probe --mode transcription`
- `tools/realtime-foundation/realtime-foundation probe --mode translation`
- `tools/realtime-foundation/realtime-foundation probe --mode agent`
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

If the user is asleep or ambient audio may be private, skip live mic/system recording and record the exact reason.
