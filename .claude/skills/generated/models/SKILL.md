---
name: models
description: "Skill for the Models area of MeetingTranslatorPro. 8 symbols across 1 files."
---

# Models

8 symbols | 1 files | Cohesion: 93%

## When to Use

- Working with code in `Sources/`
- Understanding how apply, timestamp, textSimilarity work
- Modifying models-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | apply, timestamp, textSimilarity, tokenSet, detect (+3) |

## Entry Points

Start here when exploring this area:

- **`apply`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:175`
- **`timestamp`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:220`
- **`textSimilarity`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:229`
- **`tokenSet`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:237`
- **`detect`** (Function) — `Sources/MeetingTranslator/Models/TranscriptionEntry.swift:276`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `apply` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 175 |
| `timestamp` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 220 |
| `textSimilarity` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 229 |
| `tokenSet` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 237 |
| `detect` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 276 |
| `dominant` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 335 |
| `detectLatinScriptLanguage` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 339 |
| `scalarHits` | Function | `Sources/MeetingTranslator/Models/TranscriptionEntry.swift` | 392 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `SetupGeminiLiveCallbacks → ScalarHits` | cross_community | 6 |
| `SetupGeminiLiveCallbacks → Dominant` | cross_community | 5 |
| `Apply → TokenSet` | intra_community | 3 |

## How to Explore

1. `gitnexus_context({name: "apply"})` — see callers and callees
2. `gitnexus_query({query: "models"})` — find related execution flows
3. Read key files listed above for implementation details
