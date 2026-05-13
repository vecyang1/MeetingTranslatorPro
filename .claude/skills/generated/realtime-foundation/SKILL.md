---
name: realtime-foundation
description: "Skill for the Realtime-foundation area of MeetingTranslatorPro. 25 symbols across 2 files."
---

# Realtime-foundation

25 symbols | 2 files | Cohesion: 95%

## When to Use

- Working with code in `tools/`
- Understanding how lerp, mix, add_gradient work
- Modifying realtime-foundation-related functionality

## Key Files

| File | Symbols |
|------|---------|
| `tools/realtime-foundation/realtime_foundation.py` | load_wav_pcm16, extract_agent_probe_text, extract_agent_probe_item_text, websocket_audio_probe, wait_for_session_updated (+10) |
| `tools/realtime-foundation/generate_app_icon.py` | lerp, mix, add_gradient, rounded_mask, layer_shadow (+5) |

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
| `load_wav_pcm16` | Function | `tools/realtime-foundation/realtime_foundation.py` | 183 |
| `extract_agent_probe_text` | Function | `tools/realtime-foundation/realtime_foundation.py` | 204 |
| `extract_agent_probe_item_text` | Function | `tools/realtime-foundation/realtime_foundation.py` | 229 |
| `websocket_audio_probe` | Function | `tools/realtime-foundation/realtime_foundation.py` | 244 |
| `wait_for_session_updated` | Function | `tools/realtime-foundation/realtime_foundation.py` | 532 |
| `load_openai_key` | Function | `tools/realtime-foundation/realtime_foundation.py` | 66 |
| `curl_json` | Function | `tools/realtime-foundation/realtime_foundation.py` | 80 |
| `probe_model_lookup` | Function | `tools/realtime-foundation/realtime_foundation.py` | 172 |
| `command_probe` | Function | `tools/realtime-foundation/realtime_foundation.py` | 551 |
| `print_model_table` | Function | `tools/realtime-foundation/realtime_foundation.py` | 110 |

## Execution Flows

| Flow | Type | Steps |
|------|------|-------|
| `Main → Lerp` | intra_community | 4 |
| `Command_probe → Extract_agent_probe_item_text` | cross_community | 4 |
| `Main → Layer_shadow` | intra_community | 3 |
| `Command_probe → Curl_json` | intra_community | 3 |
| `Command_probe → Load_wav_pcm16` | cross_community | 3 |
| `Command_probe → Wait_for_session_updated` | cross_community | 3 |

## How to Explore

1. `gitnexus_context({name: "lerp"})` — see callers and callees
2. `gitnexus_query({query: "realtime-foundation"})` — find related execution flows
3. Read key files listed above for implementation details
