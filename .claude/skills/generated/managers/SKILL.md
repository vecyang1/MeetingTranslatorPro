---
name: managers
description: "Skill for the Managers area of MeetingTranslatorPro. 103 symbols across 11 files."
---

# Managers

103 symbols | 11 files | Cohesion: 75%

## When to Use

- Working with code in `Sources/`
- Understanding how transcribe, createWAVData, translate work
- Modifying managers-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Managers/AppState.swift` | rmsEnergy, hasEnoughEnergy, isSameLanguage, extractContext, removeDuplicatePrefix (+55) |
| `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | checkAndRequestPermission, openScreenRecordingSettings, stopCapturing, drainRemainingAudio, configureChunking (+5) |
| `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | updateTargetLanguage, connect, disconnect, reconnect, startPingLoop (+3) |
| `Sources/MeetingTranslator/Managers/MicrophoneManager.swift` | configureChunking, startCapturing, processAudioData, flushAccumulatedAudio, restartChunkTimerIfCapturing (+3) |
| `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | transcribeAndTranslate, buildRequestBody, buildTargetLangDescription, createWAVData, updateAPIKey |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logWhisperTranscription, logGPTTranslation, logGeminiFlash, resetSession |
| `Sources/MeetingTranslator/Services/WhisperService.swift` | transcribe, createWAVData, updateAPIKey |
| `Sources/MeetingTranslator/Services/TranslationService.swift` | translate, updateAPIKey |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | applyMergedFinal |
| `Sources/MeetingTranslator/Views/ContentView.swift` | swapLanguages |

## Entry Points

Start here when exploring this area:

- **`transcribe`** (Function) — `Sources/MeetingTranslator/Services/WhisperService.swift:30`
- **`createWAVData`** (Function) — `Sources/MeetingTranslator/Services/WhisperService.swift:171`
- **`translate`** (Function) — `Sources/MeetingTranslator/Services/TranslationService.swift:26`
- **`transcribeAndTranslate`** (Function) — `Sources/MeetingTranslator/Services/GeminiFlashService.swift:28`
- **`buildRequestBody`** (Function) — `Sources/MeetingTranslator/Services/GeminiFlashService.swift:91`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `transcribe` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 30 |
| `createWAVData` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 171 |
| `translate` | Function | `Sources/MeetingTranslator/Services/TranslationService.swift` | 26 |
| `transcribeAndTranslate` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 28 |
| `buildRequestBody` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 91 |
| `buildTargetLangDescription` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 280 |
| `createWAVData` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 289 |
| `logWhisperTranscription` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 62 |
| `logGPTTranslation` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 68 |
| `logGeminiFlash` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 75 |
| `rmsEnergy` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 335 |
| `hasEnoughEnergy` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 350 |
| `isSameLanguage` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 357 |
| `extractContext` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 364 |
| `removeDuplicatePrefix` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 370 |
| `trimEntriesIfNeeded` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 495 |
| `upsertRealtimePartial` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 703 |
| `confirmRealtimeEntry` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 764 |
| `removeRealtimeEntry` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 976 |
| `removeRealtimeEntries` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 980 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `SetupOpenAIRealtimeCallbacks → Disconnect` | cross_community | 7 |
| `SetupOpenAIRealtimeCallbacks → Reset` | cross_community | 7 |
| `SetupBindings → _send_frame` | cross_community | 7 |
| `SetupBindings → LiveResult` | cross_community | 7 |
| `ProcessGeminiQualityLayer → IsRepeatedCharacterHallucination` | cross_community | 7 |
| `ProcessGeminiQualityLayer → GeminiResult` | cross_community | 7 |
| `ProcessGeminiFast → IsRepeatedCharacterHallucination` | cross_community | 6 |
| `ProcessGeminiFast → GeminiResult` | cross_community | 6 |
| `HandleOpenAIRealtimeEvent → IsSameLanguage` | cross_community | 6 |
| `HandleOpenAIRealtimeEvent → FlushAccumulatedAudio` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| OpenAIRealtime | 9 calls |
| Services | 6 calls |
| Realtime-foundation | 2 calls |
| Models | 1 calls |

## How to Explore

1. `gitnexus_context({name: "transcribe"})` — see callers and callees
2. `gitnexus_query({query: "managers"})` — find related execution flows
3. Read key files listed above for implementation details
