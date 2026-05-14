---
name: openairealtime
description: "Skill for the OpenAIRealtime area of MeetingTranslatorPro. 97 symbols across 15 files."
---

# OpenAIRealtime

97 symbols | 15 files | Cohesion: 78%

## When to Use

- Working with code in `Sources/`
- Understanding how logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate, logOpenAIRealtimeAgent work
- Modifying openairealtime-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | whisperCost, translateCost, realtime2Cost, presented, reset (+10) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | canMerge, shouldDropUnstableShortFragment, canDropNoNewContent, consolidateFinalEntries, mergedTextSequence (+8) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | connect, disconnect, sendJSON, processServerEvent, handleDisconnectError (+6) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift` | connect, sendSessionUpdate, processServerEvent, finalTranscriptSegments, eventItemID (+4) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift` | connect, commitAudio, sendSessionUpdate, processServerEvent, rotateTurnIDIfFallbackID (+3) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeEventReducer.swift` | reduce, expirePartials, updateItem, reducedEntry, key (+3) |
| `Sources/MeetingTranslator/Managers/AppState.swift` | setupOpenAIRealtimeCallbacks, handleOpenAIRealtimeEvent, setRealtimeTranslatedAudioMuted, realtimeMergeCandidate, consolidateRecentRealtimeUtterances (+2) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeCoordinator.swift` | sendAudio, sendTranslationContinuityAudio, resetTranscriptionBoundaryContext, expirePartials, start (+2) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift` | connect, processServerEvent, rotateTurnIDIfFallbackID, sendAudio, OpenAIRealtimeTranslationService |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | logOpenAIRealtimeWhisper, logOpenAIRealtimeTranslate, logOpenAIRealtimeAgent |

## Entry Points

Start here when exploring this area:

- **`logOpenAIRealtimeWhisper`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:91`
- **`logOpenAIRealtimeTranslate`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:97`
- **`logOpenAIRealtimeAgent`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:103`
- **`setupOpenAIRealtimeCallbacks`** (Function) — `Sources/MeetingTranslator/Managers/AppState.swift:485`
- **`handleOpenAIRealtimeEvent`** (Function) — `Sources/MeetingTranslator/Managers/AppState.swift:711`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `OpenAIRealtimeWebSocketService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | 2 |
| `OpenAIRealtimeTranslationService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift` | 2 |
| `OpenAIRealtimeTranscriptionService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift` | 2 |
| `OpenAIRealtimeAgentService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift` | 2 |
| `logOpenAIRealtimeWhisper` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 91 |
| `logOpenAIRealtimeTranslate` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 97 |
| `logOpenAIRealtimeAgent` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 103 |
| `setupOpenAIRealtimeCallbacks` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 485 |
| `handleOpenAIRealtimeEvent` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 711 |
| `setRealtimeTranslatedAudioMuted` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1399 |
| `finishSegment` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 123 |
| `setMuted` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 129 |
| `stop` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeTranslatedAudioPlayer.swift` | 150 |
| `whisperCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 18 |
| `translateCost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 22 |
| `realtime2Cost` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 26 |
| `presented` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 341 |
| `reset` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 273 |
| `connect` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | 27 |
| `disconnect` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | 52 |

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
| Managers | 10 calls |
| Services | 6 calls |
| Realtime-foundation | 2 calls |

## How to Explore

1. `gitnexus_context({name: "logOpenAIRealtimeWhisper"})` — see callers and callees
2. `gitnexus_query({query: "openairealtime"})` — find related execution flows
3. Read key files listed above for implementation details
