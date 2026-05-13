---
name: services
description: "Skill for the Services area of MeetingTranslatorPro. 21 symbols across 5 files."
---

# Services

21 symbols | 5 files | Cohesion: 74%

## When to Use

- Working with code in `Sources/`
- Understanding how logGeminiLive, logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate work
- Modifying services-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | transcribeAndTranslate, buildRequestBody, buildTargetLangDescription, createWAVData, performRequest (+3) |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logGeminiLive, logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate, logOpenAIRealtimeAgent, addEntry |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | whisperCost, translateCost, realtime2Cost |
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
| `setupOpenAIRealtimeCallbacks` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 450 |
| `handleOpenAIRealtimeEvent` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 647 |
| `whisperCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 18 |
| `translateCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 22 |
| `realtime2Cost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 26 |
| `transcribeAndTranslate` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 28 |
| `buildRequestBody` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 91 |
| `buildTargetLangDescription` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 280 |
| `createWAVData` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 289 |
| `performRequest` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 185 |
| `parseResultJSON` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 224 |
| `extractResult` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 248 |
| `isRepeatedCharacterHallucination` | Function | `Sources/MeetingTranslator/Services/GeminiFlashService.swift` | 263 |
| `transcribeWAV` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 37 |
| `performRequest` | Function | `Sources/MeetingTranslator/Services/WhisperService.swift` | 90 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `SetupOpenAIRealtimeCallbacks → Disconnect` | cross_community | 7 |
| `ProcessGeminiQualityLayer → IsRepeatedCharacterHallucination` | cross_community | 7 |
| `ProcessGeminiQualityLayer → GeminiResult` | cross_community | 7 |
| `ProcessGeminiFast → IsRepeatedCharacterHallucination` | cross_community | 6 |
| `ProcessGeminiFast → GeminiResult` | cross_community | 6 |
| `HandleOpenAIRealtimeEvent → Reset` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → ActiveAudioSources` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → ShowError` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → Reset` | cross_community | 6 |
| `ProcessFastLayer → AppendFormField` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| Managers | 4 calls |
| OpenAIRealtime | 1 calls |

## How to Explore

1. `gitnexus_context({name: "logGeminiLive"})` — see callers and callees
2. `gitnexus_query({query: "services"})` — find related execution flows
3. Read key files listed above for implementation details
