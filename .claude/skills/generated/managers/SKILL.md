---
name: managers
description: "Skill for the Managers area of MeetingTranslatorPro. 106 symbols across 12 files."
---

# Managers

106 symbols | 12 files | Cohesion: 69%

## When to Use

- Working with code in `Sources/`
- Understanding how updateTargetLanguage, connect, disconnect work
- Modifying managers-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Managers/AppState.swift` | attemptGeminiLiveReconnect, setupGeminiLiveCallbacks, cancelOpenAIRealtimeRecovery, checkPermissions, toggleRecording (+53) |
| `Sources/MeetingTranslator/Managers/MicrophoneManager.swift` | refreshDevices, loadInputDevices, startCapturing, processAudioData, calculateEnergyDB (+9) |
| `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | updateTargetLanguage, connect, disconnect, reconnect, startPingLoop (+3) |
| `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | checkAndRequestPermission, openScreenRecordingSettings, configureChunking, flushAccumulatedAudio, restartChunkTimerIfCapturing (+2) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | mergedText, applyMergedFinal, shouldInsertSpace, isLeadingPunctuation, isTrailingPunctuation |
| `Sources/MeetingTranslator/Models/AppSettings.swift` | resolvedDeviceID, selectedDevice, displayName, normalizedID, apply |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeConnectionRecoveryPolicy.swift` | shouldRetry, retryDelayNanoseconds, isRecoverableNetworkError |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | mayEnable, plan |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | resetSession |
| `Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift` | AudioOutputRouteObserver |

## Entry Points

Start here when exploring this area:

- **`updateTargetLanguage`** (Function) — `Sources/MeetingTranslator/Services/GeminiLiveService.swift:55`
- **`connect`** (Function) — `Sources/MeetingTranslator/Services/GeminiLiveService.swift:65`
- **`disconnect`** (Function) — `Sources/MeetingTranslator/Services/GeminiLiveService.swift:100`
- **`reconnect`** (Function) — `Sources/MeetingTranslator/Services/GeminiLiveService.swift:114`
- **`startPingLoop`** (Function) — `Sources/MeetingTranslator/Services/GeminiLiveService.swift:169`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `AudioOutputRouteObserver` | Class | `Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift` | 152 |
| `updateTargetLanguage` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 55 |
| `connect` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 65 |
| `disconnect` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 100 |
| `reconnect` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 114 |
| `startPingLoop` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 169 |
| `receiveLoop` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 214 |
| `processServerMessage` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 241 |
| `resetSession` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 48 |
| `checkAndRequestPermission` | Function | `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | 86 |
| `openScreenRecordingSettings` | Function | `Sources/MeetingTranslator/Managers/SystemAudioManager.swift` | 100 |
| `attemptGeminiLiveReconnect` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 539 |
| `setupGeminiLiveCallbacks` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 560 |
| `cancelOpenAIRealtimeRecovery` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 583 |
| `checkPermissions` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1246 |
| `toggleRecording` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1442 |
| `startRecording` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1446 |
| `stopRecording` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1513 |
| `clearEntries` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1571 |
| `startRecordingTimer` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1600 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `StartRealtimeTranslatedAudioOutputRouteObserver → IsLikelyHeadphones` | cross_community | 7 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → Disconnect` | cross_community | 7 |
| `SetupBindings → _send_frame` | cross_community | 7 |
| `SetupBindings → LiveResult` | cross_community | 7 |
| `ProcessGeminiQualityLayer → IsRepeatedCharacterHallucination` | cross_community | 7 |
| `ProcessGeminiQualityLayer → GeminiResult` | cross_community | 7 |
| `ConsolidateRecentRealtimeUtterances → IsBoundary` | cross_community | 7 |
| `HandleOpenAIRealtimeEvent → Disconnect` | cross_community | 6 |
| `SetupGeminiLiveCallbacks → ScalarHits` | cross_community | 6 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → StringProperty` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| Services | 21 calls |
| OpenAIRealtime | 16 calls |
| Realtime-foundation | 2 calls |
| Models | 1 calls |

## How to Explore

1. `gitnexus_context({name: "updateTargetLanguage"})` — see callers and callees
2. `gitnexus_query({query: "managers"})` — find related execution flows
3. Read key files listed above for implementation details
