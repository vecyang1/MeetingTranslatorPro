---
name: openairealtime
description: "Skill for the OpenAIRealtime area of MeetingTranslatorPro. 83 symbols across 13 files."
---

# OpenAIRealtime

83 symbols | 13 files | Cohesion: 83%

## When to Use

- Working with code in `Sources/`
- Understanding how realtimeMergeCandidate, consolidateRecentRealtimeUtterances, mergeTranslations work
- Modifying openairealtime-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | canMerge, shouldDropUnstableShortFragment, mergedText, canDropNoNewContent, consolidateFinalEntries (+12) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | connect, disconnect, sendJSON, processServerEvent, handleDisconnectError (+6) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift` | connect, sendSessionUpdate, OpenAIRealtimeAgentService, processServerEvent, finalTranscriptSegments (+4) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift` | connect, commitAudio, sendSessionUpdate, OpenAIRealtimeTranscriptionService, processServerEvent (+3) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeEventReducer.swift` | reset, reduce, expirePartials, updateItem, reducedEntry (+3) |
| `Sources/MeetingTranslator/Managers/AppState.swift` | realtimeMergeCandidate, consolidateRecentRealtimeUtterances, mergeTranslations, scheduleOpenAIRealtimeRecoveryIfNeeded, restartOpenAIRealtimeAfterRecoverableError (+1) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeCoordinator.swift` | start, stop, wire, expirePartials, sendAudio (+1) |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | reset, contextualizedAudio, tailData, updateTail, reset |
| `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift` | connect, OpenAIRealtimeTranslationService, processServerEvent, rotateTurnIDIfFallbackID, sendAudio |
| `tools/realtime-foundation/tests/realtime_app_e2e.swift` | apply, runSyntheticCaptionE2E, runSyntheticTranslationE2E |

## Entry Points

Start here when exploring this area:

- **`realtimeMergeCandidate`** (Function) — `Sources/MeetingTranslator/Managers/AppState.swift:927`
- **`consolidateRecentRealtimeUtterances`** (Function) — `Sources/MeetingTranslator/Managers/AppState.swift:953`
- **`mergeTranslations`** (Function) — `Sources/MeetingTranslator/Managers/AppState.swift:966`
- **`canMerge`** (Function) — `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift:3`
- **`shouldDropUnstableShortFragment`** (Function) — `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift:32`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `OpenAIRealtimeWebSocketService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeWebSocketService.swift` | 2 |
| `OpenAIRealtimeTranslationService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranslationService.swift` | 2 |
| `OpenAIRealtimeTranscriptionService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift` | 2 |
| `OpenAIRealtimeAgentService` | Class | `Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeAgentService.swift` | 2 |
| `realtimeMergeCandidate` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 927 |
| `consolidateRecentRealtimeUtterances` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 953 |
| `mergeTranslations` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 966 |
| `canMerge` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 3 |
| `shouldDropUnstableShortFragment` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 32 |
| `mergedText` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 69 |
| `canDropNoNewContent` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 97 |
| `consolidateFinalEntries` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 128 |
| `mergedTextSequence` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 232 |
| `mergedOptionalText` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 265 |
| `mergeComparisonTimestamp` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 284 |
| `shouldInsertSpace` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 316 |
| `endsWithTerminalPunctuation` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 324 |
| `isLeadingPunctuation` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 348 |
| `isTrailingPunctuation` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeUtteranceMerger.swift` | 352 |
| `reset` | Function | `Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift` | 95 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `SetupOpenAIRealtimeCallbacks → Disconnect` | cross_community | 7 |
| `SetupOpenAIRealtimeCallbacks → Reset` | cross_community | 7 |
| `ConsolidateRecentRealtimeUtterances → IsBoundary` | cross_community | 7 |
| `HandleOpenAIRealtimeEvent → IsSameLanguage` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → ActiveAudioSources` | cross_community | 6 |
| `SetupOpenAIRealtimeCallbacks → ShowError` | cross_community | 6 |
| `ScheduleOpenAIRealtimeRecoveryIfNeeded → Disconnect` | cross_community | 6 |
| `ScheduleOpenAIRealtimeRecoveryIfNeeded → Reset` | cross_community | 6 |
| `SetupBindings → Reset` | cross_community | 6 |
| `RealtimeMergeCandidate → IsBoundary` | cross_community | 6 |

## Connected Areas

| Area | Connections |
|------|-------------|
| Managers | 3 calls |
| Realtime-foundation | 2 calls |
| Services | 1 calls |

## How to Explore

1. `gitnexus_context({name: "realtimeMergeCandidate"})` — see callers and callees
2. `gitnexus_query({query: "openairealtime"})` — find related execution flows
3. Read key files listed above for implementation details
