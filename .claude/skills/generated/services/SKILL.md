---
name: services
description: "Skill for the Services area of MeetingTranslatorPro. 51 symbols across 13 files."
---

# Services

51 symbols | 13 files | Cohesion: 79%

## When to Use

- Working with code in `Sources/`
- Understanding how setPhase, snapshot, runAndExit work
- Modifying services-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | CurrentProcessAudioExclusionProbeCapture, setPhase, snapshot, runAndExit, outputFileURL (+9) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | RealtimeTranslatedAudioPlayer, configure, enqueuePCM16, makeBuffer, finishSegment |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logGeminiLive, logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate, logOpenAIRealtimeAgent, addEntry |
| `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | updateAPIKey, performRequest, parseResultJSON, extractResult, isRepeatedCharacterHallucination |
| `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | makeStreamConfiguration, startCapturing, stopCapturing, drainRemainingAudio |
| `Sources/MeetingTranslator/Managers/AppState.swift` | setupOpenAIRealtimeCallbacks, handleOpenAIRealtimeEvent, persistRealtimeTranslatedAudioSafeOutputRouteFingerprint, saveSettings |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | whisperCost, translateCost, realtime2Cost, presented |
| `Sources/MeetingTranslator/Services/WhisperService.swift` | updateAPIKey, transcribeWAV, performRequest, appendFormField |
| `Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift` | transportTypeDescription, fourCCString |
| `Sources/MeetingTranslator/Views/ContentView.swift` | swapLanguages |

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
| `logGeminiLive` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 83 |
| `logOpenAIRealtimeWhisper` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 91 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `ProcessGeminiQualityLayer → IsRepeatedCharacterHallucination` | cross_community | 7 |
| `ProcessGeminiQualityLayer → GeminiResult` | cross_community | 7 |
| `HandleOpenAIRealtimeEvent → Disconnect` | cross_community | 6 |
| `ProcessGeminiFast → IsRepeatedCharacterHallucination` | cross_community | 6 |
| `ProcessGeminiFast → GeminiResult` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → Stop` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → ActiveAudioSources` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → ShowError` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → Disconnect` | cross_community | 6 |
| `ProcessFastLayer → AppendFormField` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| Managers | 17 calls |

## How to Explore

1. `gitnexus_context({name: "setPhase"})` — see callers and callees
2. `gitnexus_query({query: "services"})` — find related execution flows
3. Read key files listed above for implementation details
