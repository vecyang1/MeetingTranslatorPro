---
name: views
description: "Skill for the Views area of MeetingTranslatorPro. 3 symbols across 3 files."
---

# Views

3 symbols | 3 files | Cohesion: 100%

## When to Use

- Working with code in `Sources/`
- Understanding how exportTranscript, exportLog, exportTranscript work
- Modifying views-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Views/ContentView.swift` | exportTranscript |
| `Sources/MeetingTranslator/Services/CostTracker.swift` | exportLog |
| `Sources/MeetingTranslator/Managers/AppState.swift` | exportTranscript |

## Entry Points

Start here when exploring this area:

- **`exportTranscript`** (Function) — `Sources/MeetingTranslator/Views/ContentView.swift:611`
- **`exportLog`** (Function) — `Sources/MeetingTranslator/Services/CostTracker.swift:139`
- **`exportTranscript`** (Function) — `Sources/MeetingTranslator/Managers/AppState.swift:1250`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `exportTranscript` | Function | `Sources/MeetingTranslator/Views/ContentView.swift` | 611 |
| `exportLog` | Function | `Sources/MeetingTranslator/Services/CostTracker.swift` | 139 |
| `exportTranscript` | Function | `Sources/MeetingTranslator/Managers/AppState.swift` | 1250 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `ExportTranscript → ExportLog` | intra_community | 3 |

## How to Explore

1. `gitnexus_context({name: "exportTranscript"})` — see callers and callees
2. `gitnexus_query({query: "views"})` — find related execution flows
3. Read key files listed above for implementation details
