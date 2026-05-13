---
name: services
description: "Skill for the Services area of MeetingTranslatorPro. 29 symbols across 6 files."
---

# Services

29 symbols | 6 files | Cohesion: 72%

## When to Use

- Working with code in `Sources/`
- Understanding how logGeminiLive, logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate work
- Modifying services-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | transcribeAndTranslate, buildRequestBody, buildTargetLangDescription, createWAVData, performRequest (+3) |
| `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | updateTargetLanguage, connect, disconnect, reconnect, startPingLoop (+2) |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logGeminiLive, logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate, logOpenAIRealtimeAgent, addEntry |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | whisperCost, translateCost, realtime2Cost, presented |
| `Sources/MeetingTranslator/Services/WhisperService.swift` | transcribeWAV, performRequest, appendFormField |
| `Sources/MeetingTranslator/Managers/AppState.swift` | setupOpenAIRealtimeCallbacks, handleOpenAIRealtimeEvent |

## Entry Points

Start here when exploring this area:

- **`logGeminiLive`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:83`
- **`logOpenAIRealtimeWhisper`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:91`
- **`logOpenAIRealtimeTranslate`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:97`
- **`logOpenAIRealtimeAgent`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:103`
- **`addEntry`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:113`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `logGeminiLive` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 83 |
| `logOpenAIRealtimeWhisper` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 91 |
| `logOpenAIRealtimeTranslate` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 97 |
| `logOpenAIRealtimeAgent` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 103 |
| `addEntry` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 113 |
| `setupOpenAIRealtimeCallbacks` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 454 |
| `handleOpenAIRealtimeEvent` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 652 |
| `whisperCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 18 |
| `translateCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 22 |
| `realtime2Cost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 26 |
| `presented` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 163 |
| `updateTargetLanguage` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 55 |
| `connect` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 65 |
| `disconnect` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 100 |
| `reconnect` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 114 |
| `startPingLoop` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 169 |
| `receiveLoop` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 214 |
| `processServerMessage` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 241 |
| `transcribeAndTranslate` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 28 |
| `buildRequestBody` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 91 |

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
| Managers | 4 calls |
| Realtime-foundation | 1 calls |
| OpenAIRealtime | 1 calls |

## How to Explore

1. `gitnexus_context({name: "logGeminiLive"})` — see callers and callees
2. `gitnexus_query({query: "services"})` — find related execution flows
3. Read key files listed above for implementation details
