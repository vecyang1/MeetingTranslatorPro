# PRD: Realtime Settings and Runtime Clarity

**Version:** 1.0
**Date:** 2026-05-13
**Status:** Goal-ready
**Stage:** M7 support
**Primary goal:** make Settings reflect the actual Realtime runtime without misleading Whisper-era controls
**Depends on:** `docs/prd_feat_openai_realtime_translate_interpreter.md`

---

## 1. Executive Decision

Settings should be organized around user intent, not model plumbing.

For `OpenAI Realtime (Recommended)`, the panel should answer five questions:

1. What audio is captured?
2. How sensitive is the shared input filter?
3. What live caption latency do I want?
4. Am I running live interpretation, and are all prerequisites met?
5. Should the timeline follow new captions?

Legacy Whisper + GPT timing controls must live only under the legacy fallback engine. They do not configure `gpt-realtime-whisper` or `gpt-realtime-translate`.

---

## 2. Problem Statement

The current Settings panel has improved, but it still risks confusing users because:

- `Engine Controls` includes realtime controls, translation gates, and disabled translated audio copy in one block;
- the app has both "Show translations" and "Live translation session" concepts;
- Whisper-era terms can make users think Realtime is still using the old fast/stitch pipeline;
- translated audio playback is visible but not truly ready;
- user-visible status should explain why live interpretation is waiting.

This PRD makes Settings a reliable control surface for the M7 interpreter route.

---

## 3. Goals

### G1. Intent-First Grouping

Settings should use plain sections: Capture, Audio Input Filter, Realtime Captions, Live Interpretation, Display Behavior, Cost.

### G2. Realtime-Specific Accuracy

When Realtime is selected, show only controls that affect Realtime. Hide or move legacy fast/stitch intervals.

### G3. Prerequisite Visibility

If live interpretation is waiting, the user should know exactly why: translations off, source language not pinned, same language selected, interpreter off, missing key, or model unavailable.

### G4. Safe Defaults

Fresh installs should default to caption-first Realtime, translations visible, interpreter session off, translated audio playback off, automatic fallback on, follow latest captions on.

---

## 4. Non-Goals

- Do not redesign the whole app window.
- Do not add translated audio playback.
- Do not expose raw model endpoint URLs to normal users.
- Do not remove fallback engines.
- Do not move shared audio input filtering into an engine-specific panel.

---

## 5. User Stories

### US-SET-001: I Know What Realtime Is Doing

As a user, I want Settings to tell me whether the app is captioning or interpreting.

Acceptance criteria:

- [x] Realtime section labels caption mode and interpreter mode separately.
- [x] The interpreter model is described as `gpt-realtime-translate` in advanced detail, not as Whisper.
- [x] Whisper is described only as source captions / audit trail in interpreter mode.

### US-SET-002: I Know Why Interpreter Mode Is Waiting

As a user, I want one actionable reason when live interpretation cannot start.

Acceptance criteria:

- [x] Missing OpenAI key shows key setup reason.
- [x] Auto-detect input shows "pin one source language."
- [x] Same language shows "source and output are the same."
- [x] Translations off shows "turn on translations."
- [x] Interpreter off shows "turn on live interpreter session."

### US-SET-003: I Do Not See Controls That Do Nothing

As a user, I should not see fast/stitch intervals under Realtime if they affect only the fallback engine.

Acceptance criteria:

- [x] `fastInterval` and `stitchInterval` appear only when `OpenAI Whisper + GPT` is selected.
- [x] Gemini quality interval appears only when `Gemini 2.5 Flash` is selected.
- [x] Realtime latency uses the Realtime caption preset only.

### US-SET-004: Display Behavior Is Separate

As a user reading earlier transcript text, I want a clear follow-latest option that does not restart the realtime session.

Acceptance criteria:

- [x] `Follow latest captions` appears under Display Behavior.
- [x] Toggling it persists only the display preference.
- [x] Toggling it does not call the full `saveSettings()` path or restart sessions.

---

## 6. Functional Requirements

### FR-SET-001: Section Order

Preferred Settings order:

1. API Keys and Engine
2. Capture Sources
3. Audio Input Filter
4. Realtime Captions
5. Live Interpretation
6. Display Behavior
7. API Cost Tracking
8. Legacy Engine Controls, shown only for selected fallback engines

### FR-SET-002: Realtime Captions Section

Show when selected engine is Realtime:

- caption latency segmented control: Aggressive, Balanced, Accuracy;
- automatic fallback toggle;
- short detail line: "Source captions stream with Realtime transcription."

Do not show legacy fast/stitch timing.

### FR-SET-003: Live Interpretation Section

Show when selected engine is Realtime:

- `Show translations` toggle;
- source-language prerequisite status;
- `Live interpreter session` toggle;
- detail line: "Uses `gpt-realtime-translate`; source captions use `gpt-realtime-whisper` for audit.";
- disabled translated audio playback row with "coming later" copy until `docs/prd_feat_realtime_translated_audio_playback.md` ships safe playback.

The "Live interpreter session" toggle should be enabled only when enough prerequisites exist to make the choice meaningful. If the UI allows toggling early, status must still prevent runtime spend until gates are true.

### FR-SET-004: Prerequisite Status Function

Add or preserve a pure status builder that can be tested without UI:

```swift
enum RealtimeInterpreterReadiness {
    case ready
    case missingOpenAIKey
    case translationsHidden
    case sourceLanguageNotPinned
    case sameLanguage
    case interpreterDisabled
    case modelUnavailable(String)
}
```

The implementation may use a simpler existing type if it produces equivalent testable copy.

### FR-SET-005: Copy Rules

Use these exact concepts:

- "Live interpretation" for same-time translation.
- "Source captions" for original-language text.
- "Fallback Whisper + GPT" for legacy non-realtime path.
- "Translated audio playback" remains disabled.
- Future enabled wording must follow `docs/prd_feat_realtime_translated_audio_playback.md` and show safety status, mute, and volume controls only after feedback behavior is proven.

Avoid these misleading phrases in the Realtime section:

- "fast draft";
- "stitch pass";
- "Whisper translation";
- "Realtime audio playback ready";
- "AI assistant" unless assistant mode exists.

---

## 7. UX Requirements

### 7.1 Visual Density

This is a macOS utility app, not a landing page. Settings should be compact, scannable, and stable:

- no nested cards inside cards;
- no oversized explanatory blocks;
- no theme-only decoration;
- icons only where they clarify the section;
- disabled controls must have concise reason text.

### 7.2 Runtime Alignment

Changing route-affecting settings during recording should either:

- restart the Realtime route safely through route-aware setters; or
- show that changes apply next session.

The UI must not visually toggle interpreter mode on while runtime remains caption-only without saying why.

---

## 8. Test and Verification Plan

Required smoke tests:

- Settings copy smoke for forbidden phrases under Realtime.
- Readiness status tests for each blocked state.
- Toggle tests for `setShowTranslations(_:)` and `setRealtimeInterpreterSessionEnabled(_:)`.
- Follow latest persistence test confirms no full settings refresh.
- Screenshot or visual inspection of Settings with:
  - Realtime caption-only;
  - Realtime interpreter ready;
  - Realtime waiting because source language is auto-detect;
  - legacy Whisper + GPT selected.

---

## 9. Done Means

- [x] Realtime Settings no longer mixes legacy timing controls with realtime route controls.
- [x] Live interpretation clearly names `gpt-realtime-translate` as the interpreter model.
- [x] Whisper is presented only as source-caption sidecar in interpreter mode.
- [x] All interpreter prerequisites are visible and testable.
- [x] Translated audio playback remains disabled and honest.
- [x] Display follow behavior is separate and does not restart sessions.
- [x] Smoke tests and installed-app Settings inspection pass.

---

## 10. Revision History

| Date | Version | Change |
|---|---:|---|
| 2026-05-13 | 1.0 | Goal-ready Settings PRD aligned to Realtime Translate interpreter route. |
