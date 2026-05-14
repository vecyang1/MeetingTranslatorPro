---
name: openairealtime
description: "Skill for the OpenAIRealtime area of MeetingTranslatorPro. 101 symbols across 15 files."
---

# OpenAIRealtime

101 symbols | 15 files | Cohesion: 79%

## When to Use

- Working with code in `Sources/`
- Understanding how logGeminiLive, logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate work
- Modifying openairealtime-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | canMerge, shouldDropUnstableShortFragment, mergedText, canDropNoNewContent, consolidateFinalEntries (+12) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | whisperCost, translateCost, realtime2Cost, presented, reset (+8) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | connect, disconnect, sendJSON, processServerEvent, handleDisconnectError (+6) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift` | connect, sendSessionUpdate, processServerEvent, finalTranscriptSegments, eventItemID (+4) |
| `Sources/MeetingTranslator/Managers/AppState.swift` | setupOpenAIRealtimeCallbacks, handleOpenAIRealtimeEvent, setRealtimeTranslatedAudioMuted, realtimeMergeCandidate, consolidateRecentRealtimeUtterances (+3) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift` | connect, commitAudio, sendSessionUpdate, processServerEvent, rotateTurnIDIfFallbackID (+3) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeEventReducer.swift` | reduce, expirePartials, updateItem, reducedEntry, key (+3) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeCoordinator.swift` | expirePartials, sendAudio, resetTranscriptionBoundaryContext, start, stop (+1) |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logGeminiLive, logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate, logOpenAIRealtimeAgent, addEntry |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift` | connect, processServerEvent, rotateTurnIDIfFallbackID, sendAudio, OpenAIRealtimeTranslationService |

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
| `OpenAIRealtimeWebSocketService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | 2 |
| `OpenAIRealtimeTranslationService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift` | 2 |
| `OpenAIRealtimeTranscriptionService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift` | 2 |
| `OpenAIRealtimeAgentService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift` | 2 |
| `logGeminiLive` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 83 |
| `logOpenAIRealtimeWhisper` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 91 |
| `logOpenAIRealtimeTranslate` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 97 |
| `logOpenAIRealtimeAgent` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 103 |
| `addEntry` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 113 |
| `setupOpenAIRealtimeCallbacks` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 479 |
| `handleOpenAIRealtimeEvent` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 684 |
| `setRealtimeTranslatedAudioMuted` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1330 |
| `finishSegment` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 123 |
| `setMuted` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 129 |
| `stop` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 150 |
| `whisperCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 18 |
| `translateCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 22 |
| `realtime2Cost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 26 |
| `presented` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 341 |
| `realtimeMergeCandidate` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 999 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `StartRealtimeTranslatedAudioOutputRouteObserver → IsLikelyHeadphones` | cross_community | 7 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → Disconnect` | cross_community | 7 |
| `ConsolidateRecentRealtimeUtterances → IsBoundary` | cross_community | 7 |
| `HandleOpenAIRealtimeEvent → Disconnect` | cross_community | 6 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → StringProperty` | cross_community | 6 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → Uint32Property` | cross_community | 6 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → RealtimeTranslatedAudioOutputRoute` | cross_community | 6 |
| `StartRealtimeTranslatedAudioOutputRouteObserver → Stop` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → Stop` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → ActiveAudioSources` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| Managers | 9 calls |
| Services | 2 calls |
| Realtime-foundation | 2 calls |

## How to Explore

1. `gitnexus_context({name: "logGeminiLive"})` — see callers and callees
2. `gitnexus_query({query: "openairealtime"})` — find related execution flows
3. Read key files listed above for implementation details
