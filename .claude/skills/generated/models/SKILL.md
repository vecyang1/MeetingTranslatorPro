---
name: models
description: "Skill for the Models area of MeetingTranslatorPro. 4 symbols across 1 files."
---

# Models

4 symbols | 1 files | Cohesion: 86%

## When to Use

- Working with code in `Sources/`
- Understanding how detect, dominant, detectLatinScriptLanguage work
- Modifying models-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | detect, dominant, detectLatinScriptLanguage, scalarHits |

## Entry Points

Start here when exploring this area:

- **`detect`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:136`
- **`dominant`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:195`
- **`detectLatinScriptLanguage`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:199`
- **`scalarHits`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:252`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `detect` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 136 |
| `dominant` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 195 |
| `detectLatinScriptLanguage` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 199 |
| `scalarHits` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 252 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `SetupGeminiLiveCallbacks → ScalarHits` | cross_community | 6 |
| `SetupGeminiLiveCallbacks → Dominant` | cross_community | 5 |

## How to Explore

1. `gitnexus_context({name: "detect"})` — see callers and callees
2. `gitnexus_query({query: "models"})` — find related execution flows
3. Read key files listed above for implementation details
