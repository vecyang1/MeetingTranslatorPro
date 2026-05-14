---
name: services
description: "Skill for the Services area of MeetingTranslatorPro. 66 symbols across 12 files."
---

# Services

66 symbols | 12 files | Cohesion: 82%

## When to Use

- Working with code in `Sources/`
- Understanding how transcribe, transcribeWAV, performRequest work
- Modifying services-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Managers/AppState.swift` | hasEnoughEnergy, isSameLanguage, extractContext, removeDuplicatePrefix, trimEntriesIfNeeded (+12) |
| `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | CurrentProcessAudioExclusionProbeCapture, setPhase, snapshot, runAndExit, outputFileURL (+9) |
| `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | transcribeAndTranslate, buildRequestBody, buildTargetLangDescription, createWAVData, updateAPIKey (+4) |
| `Sources/MeetingTranslator/Services/WhisperService.swift` | transcribe, transcribeWAV, performRequest, appendFormField, createWAVData (+1) |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logWhisperTranscription, logGPTTranslation, logGeminiFlash, logGeminiLive, addEntry |
| `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | makeStreamConfiguration, startCapturing, stopCapturing, drainRemainingAudio |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | RealtimeTranslatedAudioPlayer, configure, enqueuePCM16, makeBuffer |
| `Sources/MeetingTranslator/Services/TranslationService.swift` | translate, updateAPIKey |
| `Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift` | transportTypeDescription, fourCCString |
| `Sources/MeetingTranslator/Views/ContentView.swift` | swapLanguages |

## Entry Points

Start here when exploring this area:

- **`transcribe`** (Function) — `Sources/MeetingTranslator/Services/WhisperService.swift:30`
- **`transcribeWAV`** (Function) — `Sources/MeetingTranslator/Services/WhisperService.swift:37`
- **`performRequest`** (Function) — `Sources/MeetingTranslator/Services/WhisperService.swift:90`
- **`appendFormField`** (Function) — `Sources/MeetingTranslator/Services/WhisperService.swift:164`
- **`createWAVData`** (Function) — `Sources/MeetingTranslator/Services/WhisperService.swift:171`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `CurrentProcessAudioExclusionProbeCapture` | Class | `Sources/MeetingTranslator/Services/SystemAudioCurrentProcessExclusionProbe.swift` | 6 |
| `RealtimeTranslatedAudioPlayer` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 3 |
| `transcribe` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 30 |
| `transcribeWAV` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 37 |
| `performRequest` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 90 |
| `appendFormField` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 164 |
| `createWAVData` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 171 |
| `translate` | Function | `Sources/MeetingTranslator/Services/TranslationService.swift` | 26 |
| `transcribeAndTranslate` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 28 |
| `buildRequestBody` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 91 |
| `buildTargetLangDescription` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 280 |
| `createWAVData` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 289 |
| `logWhisperTranscription` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 62 |
| `logGPTTranslation` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 68 |
| `logGeminiFlash` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 75 |
| `logGeminiLive` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 83 |
| `addEntry` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 113 |
| `hasEnoughEnergy` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 366 |
| `isSameLanguage` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 373 |
| `extractContext` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 380 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `ProcessGeminiQualityLayer → IsRepeatedCharacterHallucination` | cross_community | 7 |
| `ProcessGeminiQualityLayer → GeminiResult` | cross_community | 7 |
| `ProcessGeminiFast → IsRepeatedCharacterHallucination` | cross_community | 6 |
| `ProcessGeminiFast → GeminiResult` | cross_community | 6 |
| `SetupGeminiLiveCallbacks → ScalarHits` | cross_community | 6 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → IsSameLanguage` | cross_community | 6 |
| `ProcessFastLayer → AppendFormField` | intra_community | 6 |
| `ProcessFastLayer → WhisperResponse` | intra_community | 6 |
| `ProcessFastLayer → GeminiResult` | cross_community | 6 |
| `ToggleRecording → MakeTonePCM16` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| Managers | 14 calls |
| OpenAIRealtime | 1 calls |

## How to Explore

1. `gitnexus_context({name: "transcribe"})` — see callers and callees
2. `gitnexus_query({query: "services"})` — find related execution flows
3. Read key files listed above for implementation details
