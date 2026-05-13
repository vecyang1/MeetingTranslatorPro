---
name: managers
description: "Skill for the Managers area of MeetingTranslatorPro. 114 symbols across 13 files."
---

# Managers

114 symbols | 13 files | Cohesion: 74%

## When to Use

- Working with code in `Sources/`
- Understanding how transcribe, createWAVData, translate work
- Modifying managers-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Managers/AppState.swift` | rmsEnergy, hasEnoughEnergy, isSameLanguage, extractContext, removeDuplicatePrefix (+65) |
| `Sources/MeetingTranslator/Managers/MicrophoneManager.swift` | stopCapturing, configureChunking, restartChunkTimerIfCapturing, startCapturing, processAudioData (+4) |
| `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | updateTargetLanguage, connect, disconnect, reconnect, startPingLoop (+3) |
| `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | checkAndRequestPermission, openScreenRecordingSettings, configureChunking, flushAccumulatedAudio, restartChunkTimerIfCapturing (+2) |
| `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | transcribeAndTranslate, buildRequestBody, buildTargetLangDescription, createWAVData |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logWhisperTranscription, logGPTTranslation, logGeminiFlash, resetSession |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | setMuted, stop, setVolume |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeConnectionRecoveryPolicy.swift` | shouldRetry, retryDelayNanoseconds, isRecoverableNetworkError |
| `Sources/MeetingTranslator/Services/WhisperService.swift` | transcribe, createWAVData |
| `Sources/MeetingTranslator/Services/TranslationService.swift` | translate |

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
| `AudioOutputRouteObserver` | Class | `Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift` | 152 |
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
| `rmsEnergy` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 348 |
| `hasEnoughEnergy` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 363 |
| `isSameLanguage` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 370 |
| `extractContext` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 377 |
| `removeDuplicatePrefix` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 383 |
| `trimEntriesIfNeeded` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 520 |
| `upsertRealtimePartial` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 775 |
| `confirmRealtimeEntry` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 836 |
| `removeRealtimeEntry` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1048 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `StartRealtimeTranslatedAudioOutputRouteObserver → IsLikelyHeadphones` | cross_community | 7 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → Disconnect` | cross_community | 7 |
| `SetupBindings → _send_frame` | cross_community | 7 |
| `SetupBindings → LiveResult` | cross_community | 7 |
| `ProcessGeminiQualityLayer → IsRepeatedCharacterHallucination` | cross_community | 7 |
| `ProcessGeminiQualityLayer → GeminiResult` | cross_community | 7 |
| `HandleOpenAIRealtimeEvent → Disconnect` | cross_community | 6 |
| `ProcessGeminiFast → IsRepeatedCharacterHallucination` | cross_community | 6 |
| `ProcessGeminiFast → GeminiResult` | cross_community | 6 |
| `SetupGeminiLiveCallbacks → ScalarHits` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| OpenAIRealtime | 11 calls |
| Services | 10 calls |
| Realtime-foundation | 2 calls |
| Models | 1 calls |

## How to Explore

1. `gitnexus_context({name: "transcribe"})` — see callers and callees
2. `gitnexus_query({query: "managers"})` — find related execution flows
3. Read key files listed above for implementation details
