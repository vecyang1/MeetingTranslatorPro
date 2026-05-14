---
name: openai-realtime-voice-foundation
description: Use when building or auditing OpenAI Realtime voice features for Meeting Translator Pro, native/server raw-audio pipelines, realtime transcription, live translation, voice-agent routing, or agent handoff docs that must preserve cost gates and runtime proof.
---

# OpenAI Realtime Voice Foundation

## Core Rule

Choose the realtime model by product outcome and UX promise:

| Outcome | Model | Endpoint |
|---|---|---|
| Caption-first live text while user is speaking | `gpt-realtime-whisper` | transcription session |
| Dialog understanding / assistant actions | `gpt-realtime-2` | `/v1/realtime` |
| Live translation / interpreter | `gpt-realtime-translate` plus `gpt-realtime-whisper` source captions | `/v1/realtime/translations` plus transcription session |
| Assistant, tools, actions, reasoning | `gpt-realtime-2` | `/v1/realtime` |

For Meeting Translator Pro M6, the user-facing `OpenAI Realtime (Recommended)` path should be caption-first and led by `gpt-realtime-whisper` because the product goal is visible transcript deltas while the user is still speaking. Keep `gpt-realtime-2` for dialog understanding and future approval-gated assistant actions. Keep `gpt-realtime-translate` as the M7 live translation stage after caption streaming is proven.

Cost and product-positioning rule:

| Use case | Preferred model | Current price | Approx. per hour per source |
|---|---|---:|---:|
| Realtime captions / STT | `gpt-realtime-whisper` | `$0.017/min` | `$1.02/hour` |
| Realtime interpretation / subtitles | `gpt-realtime-translate` | `$0.034/min` | `$2.04/hour` |
| Separate captions plus translation sessions | `gpt-realtime-whisper` + `gpt-realtime-translate` | `$0.051/min` | `$3.06/hour` |
| Voice agent that can reason, speak, summarize, or call tools | `gpt-realtime-2` | token-based: audio in `$32/1M`, audio out `$64/1M` | about `$5.76/hour` for full-duplex 1h in + 1h out |

For a same-time translation MVP, use `gpt-realtime-translate` for translated output. If source captions must be shown and audited, pair it with `gpt-realtime-whisper`; this is still the Realtime series and should be preferred over legacy Whisper-only/two-step OpenAI. Do not default to `gpt-realtime-2` for translation; it is heavier and belongs to voice-agent or meeting-assistant flows where reasoning, interruption, summarization, explanation, or tool calls are the product.

Current canonical product PRDs:

- `docs/prd_feat_openai_realtime_translate_interpreter.md`: true simultaneous interpretation, with `gpt-realtime-translate` as the interpreter model and `gpt-realtime-whisper` only as source-caption sidecar.
- `docs/prd_feat_realtime_translated_audio_playback.md`: M8 safe translated audio playback from `gpt-realtime-translate` output audio; playback is implemented as off-by-default safe preview and remains gated by interpreter readiness, explicit opt-in, ScreenCaptureKit exclusion, and route-aware headphone/non-speaker output safety.
- `docs/prd_feat_realtime_settings_runtime_clarity.md`: Settings must separate caption controls from live interpretation controls and must not show legacy Whisper + GPT fast/stitch timing under Realtime.
- `docs/prd_feat_realtime_speaker_recognition_sidecar.md`: future delayed speaker recognition must be a sidecar, not part of the realtime translation core.

## Meeting Translator Invariants

- Do not alter bundle ID, signing identity, entitlements, permission behavior, or `build_app.sh` install path.
- Never start or maintain a translation session unless `showTranslations`, `!sameLanguage`, exactly one source language is pinned, and an explicit realtime interpreter/session gate is enabled.
- Translation-off, same-language, and auto-detect-with-unknown-source modes should stay on the caption-first `gpt-realtime-whisper` transcription path, not a translation session.
- Realtime translation is M7; do not add hidden translation-session spend while implementing M6 caption streaming. In M7, the explicit interpreter route sends accepted audio to `gpt-realtime-translate` and a paired `gpt-realtime-whisper` source-caption session, so cost is Translate + Whisper. Translated audio playback is a separate off-by-default output gate.
- Preserve separate microphone and system-audio source labels.
- Partial transcript rows update in place by `(source, itemID)`; final rows still pass empty, hallucination, overlap, echo dedup, language, and translation gates.
- Translation output may arrive before the paired Whisper source caption. Reducer logic should attach Translate output to the latest same-source source-caption item once available and remove the superseded temporary translation-only row, not create duplicate/chopped translation-only rows.
- Provider final items may be transport chunks, not user dialog turns. Merge nearby same-source/same-language final chunks into readable utterance rows before display/export, and only drop tail-only duplicate chunks after the same source, language, finalized-row, and short time-window gates pass.
- User-facing rows should be semantic-ish utterances, not one row per low-level audio commit. Keep useful partials live, but consolidate nearby same-source `gpt-realtime-whisper` finals, preserve discourse fragments such as Mandarin "就是" when they connect thoughts, and drop unstable tiny fragments such as single-character fillers, short Japanese/Korean hallucination tails, or known bad English mishears from synthetic probes.
- Rolling realtime row consolidation should compare the next provider final against the latest merged chunk timestamp (`realtimeLastMergedAt`), not only the row's first visible timestamp, so a continuous thought can remain one readable row.
- Do not manually inject newlines into CJK transcript text in the row UI. Let SwiftUI wrap naturally so one sentence/paragraph remains readable.
- Automatic transcript scrolling must be gated by the user-visible `Follow latest captions` display preference, and the scroll action should not be animated. Persisting that display preference must not call the full `saveSettings()` path or refresh Realtime sessions. Grey live draft text should disable implicit text/layout animation so it grows downward without shaking nearby rows before final consolidation.
- After confirming a final row, run a same-source consolidation pass; system-audio chunks can finalize out of order or without partial rows, so relying only on a pre-insert merge candidate leaves chopped UI rows.
- Do not run final-row consolidation in `gpt-realtime-translate` translation mode; transcript and translation finals may arrive separately for the same item ID and must keep their row mapping until both attach.
- Realtime-2 text may arrive as `response.output_text.*`, `response.output_item.done`, or `response.done`; future agents must parse nested final response containers before declaring "no caption output." For nested finals, reconcile by inner `item.id` / `response.output[].id` so existing partial rows finalize in place.
- ScreenCaptureKit system audio may stop delivering buffers immediately after short sounds; append a small silence tail on the system-audio Realtime-2 path so server VAD can close the turn. Do not add that tail to microphone audio.
- Keep existing OpenAI Whisper+GPT, Gemini Flash, and Gemini Live engines selectable as fallbacks. Deprioritize legacy Whisper-only/two-step OpenAI for new realtime work; `gpt-realtime-whisper` is part of the new Realtime series and remains the M6 caption route.
- Settings must not show the legacy Whisper + GPT fast/stitch pipeline while `OpenAI Realtime (Recommended)` is selected. Realtime controls should be split into `Realtime Captions`, `Live Interpretation`, `Display Behavior`, `Audio Input Filter`, and `Speaker Recognition`. The shared noise gate belongs in `Audio Input Filter` because it gates captured audio before every engine route.
- Speaker recognition is a delayed, off-by-default sidecar. Use `gpt-4o-transcribe-diarize` only through `/v1/audio/transcriptions` with `response_format=diarized_json` and `chunking_strategy=auto`; do not put diarization in the Realtime API path, block captions/translation, or rewrite transcript text by default.
- Translated audio playback is M8 safe-preview only. Do not pass a saved true value into runtime merely because an old pre-M8 preference exists. Playback may pass `translatedAudioPlaybackEnabled: true` only when the M7 interpreter gates, explicit M8 opt-in, `SCStreamConfiguration.excludesCurrentProcessAudio`, and microphone/output safety gate are all ready. It must use the existing `gpt-realtime-translate` output audio, never `gpt-realtime-2`, legacy TTS, speech generation, Whisper, or Whisper+GPT as a playback engine. The installed app has a hidden `--run-system-audio-exclusion-probe` runtime check that uses synthetic audio to prove app-local playback is not recaptured by ScreenCaptureKit. ScreenCaptureKit exclusion does not prevent physical speaker-to-microphone bleed: when mic capture is active, CoreAudio output-route inspection must block likely speakers, display audio, HDMI/DisplayPort, AirPlay, aggregate/multi-output routes, and unrecognized outputs even if stale playback opt-in or safe-output confirmation exists; confirmation is bound to the exact output-route fingerprint and may unlock only positive headphone-like routes. Watch default-output route changes and stop/reroute active translated playback immediately when the new route is unsafe. Keep a main-window headphones activation control visible when the interpreter route is eligible, because the purple speaker meter is system-audio capture input, not translated-audio output; that one explicit click may confirm the current headphone route and enable playback if all gates pass.
- Headphones as output do not prove the headset microphone is the right input. AirPods can become both default output and default input, which may make local speech look silent or quiet. Keep microphone input configurable under `Audio Sources`, show the active mic input beside the green mic meter, and prefer Mac microphone input plus headphone output when avoiding feedback. Changing mic input during recording should restart only the microphone tap and should not flush stale buffered audio into Realtime.
- In M7 translation mode, the UI may show both source-caption progress and translation-output progress because the runtime intentionally uses `gpt-realtime-translate` plus a `gpt-realtime-whisper` source-caption sidecar. Avoid copy that looks like a second legacy translation/TTS engine: label source drafts `live caption` and pending translation as `Waiting for live translation...`.
- If a realtime provider omits a language code, use the shared `LanguageDetector` fallback. Do not label every Latin-script transcript as English; Vietnamese, Turkish, Spanish, and other high-signal Latin-script languages must keep their own labels when detectable.
- Transient TLS/WebSocket startup failures should be handled by `RealtimeConnectionRecoveryPolicy` plus `AppState` bounded retries. Legacy fallback is separate and should happen only after retry exhaustion when enabled. Do not retry permanent auth, quota, billing, permission, or model-access failures.
- Do not log raw audio or full private transcripts in debug output.

## Workflow

1. Refresh current OpenAI docs before model/API decisions.
2. Run `tools/realtime-foundation/realtime-foundation models` and `recommend`; interpreter recommendations require `--pinned-source-language` and `--interpreter-session`.
3. Probe model visibility with `probe --mode transcription`, `probe --mode translation`, and `probe --mode agent`.
4. For full provider proof, run `tools/realtime-foundation/run_realtime_mission_verification.sh` with generated fixtures and a valid transient `OPENAI_API_KEY`; this passed on 2026-05-13 for Whisper captions, Translate EN->ZH/ZH->EN/code-switch, and Realtime-2 agent text.
5. For M8 playback, keep `docs/prd_feat_realtime_translated_audio_playback.md` current, run provider probes with `--capture-output-audio` on synthetic fixtures, and keep playback unavailable if ScreenCaptureKit exclusion or microphone/output safety cannot be verified safely.
6. For native macOS/server raw audio, prefer WebSocket and 24 kHz PCM16 at the realtime service boundary.
7. For browser/mobile audio, prefer WebRTC and ephemeral/client secrets.
8. Keep protocol parsing inside `OpenAIRealtime*Service` files and reducer logic inside `RealtimeEventReducer`; keep `AppState` orchestration-only.
9. Before claiming completion, run build, model probes, synthetic audio probes where possible, app launch, and safe runtime checks.

## Read These References

- Model routing: `references/model-routing.md`
- Swift integration boundaries: `references/swift-native-integration.md`
- Verification gates: `references/eval-checklist.md`
- Video/media research reuse: `references/read-media-gemini-integration.md`

## Common Mistakes

- Keeping `gpt-realtime-2` as the caption-only path when it waits for server VAD pauses; M6 requires text during speech.
- Using `gpt-realtime-2` to start a hidden translation spend path when translations are off, same-language, or source language is still unknown.
- Hiding translation UI while leaving a translation session connected.
- Flipping `translatedAudioPlaybackEnabled` to true without all M7/M8 gates, mute/stop behavior, output-format checks, and feedback-loop verification.
- Mixing mic and system audio into one realtime stream without preserving source identity.
- Treating partial deltas as permanent transcript entries.
- Testing only clean synthetic audio, then claiming meeting-readiness.
