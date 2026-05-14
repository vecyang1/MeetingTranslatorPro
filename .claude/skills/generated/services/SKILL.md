---
name: services
description: "Skill for the Services area of MeetingTranslatorPro. 28 symbols across 5 files."
---

# Services

28 symbols | 5 files | Cohesion: 90%

## When to Use

- Working with code in `Sources/`
- Understanding how setPhase, snapshot, runAndExit work
- Modifying services-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | CurrentProcessAudioExclusionProbeCapture, setPhase, snapshot, runAndExit, outputFileURL (+9) |
| `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | makeStreamConfiguration, startCapturing, stopCapturing, drainRemainingAudio |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | RealtimeTranslatedAudioPlayer, configure, enqueuePCM16, makeBuffer |
| `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | performRequest, parseResultJSON, extractResult, isRepeatedCharacterHallucination |
| `Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift` | transportTypeDescription, fourCCString |

## Entry Points

Start here when exploring this area:

- **`setPhase`** (Function) — `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift:39`
- **`snapshot`** (Function) — `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift:45`
- **`runAndExit`** (Function) — `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift:155`
- **`outputFileURL`** (Function) — `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift:175`
- **`report`** (Function) — `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift:190`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `CurrentProcessAudioExclusionProbeCapture` | Class | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 6 |
| `RealtimeTranslatedAudioPlayer` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 3 |
| `setPhase` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 39 |
| `snapshot` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 45 |
| `runAndExit` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 155 |
| `outputFileURL` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 175 |
| `report` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 190 |
| `run` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 201 |
| `makeTonePCM16` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 269 |
| `writeToneWAV` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 285 |
| `appendLE` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 316 |
| `makeStreamConfiguration` | Function | `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | 56 |
| `startCapturing` | Function | `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | 107 |
| `stopCapturing` | Function | `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | 159 |
| `drainRemainingAudio` | Function | `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | 315 |
| `configure` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 34 |
| `enqueuePCM16` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 77 |
| `makeBuffer` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 160 |
| `stream` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 58 |
| `calculateRMS` | Function | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 92 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `ProcessGeminiQualityLayer → IsRepeatedCharacterHallucination` | cross_community | 7 |
| `ProcessGeminiQualityLayer → GeminiResult` | cross_community | 7 |
| `ProcessGeminiFast → IsRepeatedCharacterHallucination` | cross_community | 6 |
| `ProcessGeminiFast → GeminiResult` | cross_community | 6 |
| `ToggleRecording → MakeTonePCM16` | cross_community | 6 |
| `ToggleRecording → AppendLE` | cross_community | 6 |
| `ToggleRecording → MakeStreamConfiguration` | cross_community | 5 |
| `ToggleRecording → CurrentProcessAudioExclusionProbeCapture` | cross_community | 5 |
| `ToggleRecording → SetPhase` | cross_community | 5 |
| `RunAndExit → MakeTonePCM16` | intra_community | 4 |

## Connected Areas

| Area | Connections |
|------|-------------|
| OpenAIRealtime | 1 calls |
| Managers | 1 calls |

## How to Explore

1. `gitnexus_context({name: "setPhase"})` — see callers and callees
2. `gitnexus_query({query: "services"})` — find related execution flows
3. Read key files listed above for implementation details
