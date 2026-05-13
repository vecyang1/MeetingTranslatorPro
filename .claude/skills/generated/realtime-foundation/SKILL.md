---
name: realtime-foundation
description: "Skill for the Realtime-foundation area of MeetingTranslatorPro. 40 symbols across 3 files."
---

# Realtime-foundation

40 symbols | 3 files | Cohesion: 89%

## When to Use

- Working with code in `tools/`
- Understanding how lerp, mix, add_gradient work
- Modifying realtime-foundation-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `tools/realtime-foundation/realtime_foundation.py` | write_pcm16_wav, extract_agent_probe_text, extract_agent_probe_item_text, create_probe_websocket, websocket_audio_probe (+24) |
| `tools/realtime-foundation/generate_app_icon.py` | lerp, mix, add_gradient, rounded_mask, layer_shadow (+5) |
| `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | sendSetupAndWait |

## Entry Points

Start here when exploring this area:

- **`lerp`** (Function) — `tools/realtime-foundation/generate_app_icon.py:14`
- **`mix`** (Function) — `tools/realtime-foundation/generate_app_icon.py:18`
- **`add_gradient`** (Function) — `tools/realtime-foundation/generate_app_icon.py:22`
- **`rounded_mask`** (Function) — `tools/realtime-foundation/generate_app_icon.py:37`
- **`layer_shadow`** (Function) — `tools/realtime-foundation/generate_app_icon.py:48`

## Key Symbols

| Symbol | Type | File | Line |
|--------|------|------|------|
| `lerp` | Function | `tools/realtime-foundation/generate_app_icon.py` | 14 |
| `mix` | Function | `tools/realtime-foundation/generate_app_icon.py` | 18 |
| `add_gradient` | Function | `tools/realtime-foundation/generate_app_icon.py` | 22 |
| `rounded_mask` | Function | `tools/realtime-foundation/generate_app_icon.py` | 37 |
| `layer_shadow` | Function | `tools/realtime-foundation/generate_app_icon.py` | 48 |
| `draw_panel` | Function | `tools/realtime-foundation/generate_app_icon.py` | 56 |
| `draw_waveform` | Function | `tools/realtime-foundation/generate_app_icon.py` | 80 |
| `draw_translation_badge` | Function | `tools/realtime-foundation/generate_app_icon.py` | 98 |
| `draw_source_bubble` | Function | `tools/realtime-foundation/generate_app_icon.py` | 113 |
| `main` | Function | `tools/realtime-foundation/generate_app_icon.py` | 127 |
| `write_pcm16_wav` | Function | `tools/realtime-foundation/realtime_foundation.py` | 214 |
| `extract_agent_probe_text` | Function | `tools/realtime-foundation/realtime_foundation.py` | 270 |
| `extract_agent_probe_item_text` | Function | `tools/realtime-foundation/realtime_foundation.py` | 295 |
| `create_probe_websocket` | Function | `tools/realtime-foundation/realtime_foundation.py` | 481 |
| `websocket_audio_probe` | Function | `tools/realtime-foundation/realtime_foundation.py` | 491 |
| `wait_for_session_updated` | Function | `tools/realtime-foundation/realtime_foundation.py` | 839 |
| `sendSetupAndWait` | Function | `Sources/MeetingTranslator/Services/GeminiLiveService.swift` | 124 |
| `load_openai_key` | Function | `tools/realtime-foundation/realtime_foundation.py` | 70 |
| `curl_json` | Function | `tools/realtime-foundation/realtime_foundation.py` | 84 |
| `probe_model_lookup` | Function | `tools/realtime-foundation/realtime_foundation.py` | 183 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `SetupBindings → _send_frame` | cross_community | 7 |
| `UpdateTargetLanguage → _send_frame` | cross_community | 6 |
| `Command_probe → Clamp_pcm16` | cross_community | 5 |
| `Connect → _read_frame` | intra_community | 5 |
| `Connect → _send_frame` | cross_community | 5 |
| `Connect → _send_frame` | cross_community | 5 |
| `Connect → _send_frame` | cross_community | 5 |
| `SendAudio → _send_frame` | cross_community | 4 |
| `Main → Lerp` | intra_community | 4 |
| `SendAudio → _send_frame` | cross_community | 4 |

## How to Explore

1. `gitnexus_context({name: "lerp"})` — see callers and callees
2. `gitnexus_query({query: "realtime-foundation"})` — find related execution flows
3. Read key files listed above for implementation details
