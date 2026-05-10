#!/usr/bin/env python3
"""OpenAI Realtime foundation helper for Meeting Translator Pro agents."""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import wave
from pathlib import Path
from typing import Any

MODEL_ROUTES: dict[str, dict[str, str]] = {
    "transcription": {
        "model": "gpt-realtime-whisper",
        "endpoint": "/v1/realtime/transcription_sessions",
        "transport": "WebSocket for native/server raw PCM, WebRTC for browser audio",
        "purpose": "Live transcript deltas without assistant speech",
        "pricing": "$0.017/min realtime audio duration",
    },
    "translation": {
        "model": "gpt-realtime-translate",
        "endpoint": "/v1/realtime/translations",
        "transport": "Dedicated translation WebSocket/WebRTC session",
        "purpose": "Live speech-to-speech translation plus transcript deltas",
        "pricing": "$0.034/min realtime audio duration",
    },
    "agent": {
        "model": "gpt-realtime-2",
        "endpoint": "/v1/realtime",
        "transport": "Realtime conversation session",
        "purpose": "Voice assistant, tool calling, actions, and reasoning",
        "pricing": "$4/$24 text tokens; $32/$64 audio tokens per 1M input/output",
    },
}

TASK_ALIASES = {
    "captions": "transcription",
    "caption": "transcription",
    "transcribe": "transcription",
    "transcription": "transcription",
    "speech-to-text": "transcription",
    "live-translation": "translation",
    "translate": "translation",
    "translation": "translation",
    "interpreter": "translation",
    "assistant": "agent",
    "voice-agent": "agent",
    "agent": "agent",
    "tools": "agent",
    "actions": "agent",
}


def load_openai_key() -> str:
    key = os.environ.get("OPENAI_API_KEY", "").strip()
    if key:
        return key
    try:
        return subprocess.check_output(
            ["defaults", "read", "com.meetingtranslator.app", "com.meetingtranslator.apikey"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return ""


def curl_json(url: str, key: str) -> tuple[int, dict[str, Any]]:
    result = subprocess.run(
        [
            "curl",
            "-sS",
            "-w",
            "\n%{http_code}",
            "-H",
            f"Authorization: Bearer {key}",
            url,
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return 0, {"error": {"message": result.stderr.strip() or "curl failed"}}
    body, _, code_text = result.stdout.rpartition("\n")
    try:
        status = int(code_text)
    except ValueError:
        status = 0
    try:
        payload = json.loads(body) if body else {}
    except json.JSONDecodeError:
        payload = {"raw": body[:500]}
    return status, payload


def print_model_table() -> None:
    for mode, info in MODEL_ROUTES.items():
        print(f"{mode}: {info['model']}")
        print(f"  purpose: {info['purpose']}")
        print(f"  endpoint: {info['endpoint']}")
        print(f"  transport: {info['transport']}")
        print(f"  pricing: {info['pricing']}")


def choose_mode(task: str, client: str, show_translations: bool, same_language: bool) -> str:
    normalized_task = task.strip().lower()
    normalized_client = client.strip().lower()
    if not show_translations or same_language:
        return "transcription"
    if normalized_task in TASK_ALIASES:
        return TASK_ALIASES[normalized_task]
    if "browser" in normalized_client and "translate" in normalized_task:
        return "translation"
    if "tool" in normalized_task or "action" in normalized_task or "assistant" in normalized_task:
        return "agent"
    return "transcription"


def command_recommend(args: argparse.Namespace) -> int:
    mode = choose_mode(args.task, args.client, args.show_translations, args.same_language)
    info = MODEL_ROUTES[mode]
    print(f"mode: {mode}")
    print(f"model: {info['model']}")
    print(f"endpoint: {info['endpoint']}")
    print(f"transport: {info['transport']}")
    if mode == "translation":
        print("gate: start this session only when !sameLanguage && showTranslations")
    elif mode == "agent":
        print("gate: keep actions approval-gated; do not use for pure captions/translation")
    else:
        print("gate: safe default when translations are hidden or same-language")
    return 0


def command_models(args: argparse.Namespace) -> int:
    if args.json:
        print(json.dumps(MODEL_ROUTES, indent=2, sort_keys=True))
    else:
        print_model_table()
    return 0


def probe_model_lookup(mode: str, key: str) -> int:
    model = MODEL_ROUTES[mode]["model"]
    status, payload = curl_json(f"https://api.openai.com/v1/models/{model}", key)
    if status == 200 and payload.get("id") == model:
        print(f"{model}: HTTP 200 model visible")
        return 0
    message = payload.get("error", {}).get("message") or payload.get("raw") or payload
    print(f"{model}: HTTP {status} {message}")
    return 1


def load_wav_pcm16(path: Path, target_rate: int = 24000, max_seconds: float = 4.0) -> bytes:
    import audioop

    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        width = wav.getsampwidth()
        rate = wav.getframerate()
        frame_count = min(wav.getnframes(), int(rate * max_seconds))
        pcm = wav.readframes(frame_count)

    if width != 2:
        pcm = audioop.lin2lin(pcm, width, 2)
    if channels != 1:
        pcm = audioop.tomono(pcm, 2, 0.5, 0.5)
    if rate != target_rate:
        pcm, _ = audioop.ratecv(pcm, 2, 1, rate, target_rate, None)
    return pcm


def websocket_audio_probe(mode: str, key: str, audio_path: Path, target: str, timeout: float) -> int:
    try:
        import websocket
    except Exception:
        print("audio probe needs the optional websocket-client Python package")
        return 2

    pcm = load_wav_pcm16(audio_path)
    if not pcm:
        print(f"{audio_path}: no PCM audio loaded")
        return 2

    model = MODEL_ROUTES[mode]["model"]
    if mode == "translation":
        url = "wss://api.openai.com/v1/realtime/translations?model=gpt-realtime-translate"
    else:
        url = f"wss://api.openai.com/v1/realtime?model={model}"

    ws = websocket.WebSocket()
    ws.settimeout(timeout)
    ws.connect(url, header=[f"Authorization: Bearer {key}", "OpenAI-Safety-Identifier: meeting-translator-pro-local-probe"])

    try:
        if mode == "translation":
            ws.send(json.dumps({"type": "session.update", "session": {"audio": {"output": {"language": target}}}}))
            ws.send(json.dumps({"type": "session.input_audio_buffer.append", "audio": base64.b64encode(pcm).decode("ascii")}))
            wanted = {"session.output_transcript.delta", "session.input_transcript.delta", "session.output_audio.delta"}
        elif mode == "transcription":
            ws.send(
                json.dumps(
                    {
                        "type": "session.update",
                        "session": {
                            "type": "transcription",
                            "audio": {
                                "input": {
                                    "format": {"type": "audio/pcm", "rate": 24000},
                                    "transcription": {"model": "gpt-realtime-whisper"},
                                    "turn_detection": None,
                                }
                            },
                        },
                    }
                )
            )
            ws.send(json.dumps({"type": "input_audio_buffer.append", "audio": base64.b64encode(pcm).decode("ascii")}))
            ws.send(json.dumps({"type": "input_audio_buffer.commit"}))
            wanted = {
                "conversation.item.input_audio_transcription.delta",
                "conversation.item.input_audio_transcription.completed",
            }
        else:
            ws.send(json.dumps({"type": "session.update", "session": {"type": "realtime", "reasoning": {"effort": "low"}}}))
            print("agent websocket connected and session.update sent")
            return 0

        deadline = time.time() + timeout
        seen: list[str] = []
        while time.time() < deadline:
            try:
                event = json.loads(ws.recv())
            except TimeoutError:
                break
            event_type = event.get("type", "")
            seen.append(event_type)
            if event_type in wanted:
                text = event.get("delta") or event.get("transcript") or "<audio delta>"
                print(f"{mode} audio probe event: {event_type} {str(text)[:120]}")
                return 0
        print(f"{mode} audio probe timed out; events seen: {', '.join(seen[-8:]) or 'none'}")
        return 1
    finally:
        ws.close()


def command_probe(args: argparse.Namespace) -> int:
    key = load_openai_key()
    if not key:
        print("OpenAI API key not found in OPENAI_API_KEY or Meeting Translator UserDefaults.")
        return 2
    mode = args.mode
    if not args.audio:
        return probe_model_lookup(mode, key)
    audio_path = Path(args.audio).expanduser()
    if not audio_path.exists():
        print(f"audio file not found: {audio_path}")
        return 2
    return websocket_audio_probe(mode, key, audio_path, args.target, args.timeout)


SWIFT_SERVICE_TEMPLATE = """// OpenAI Realtime service scaffold.
// Keep protocol parsing here, not in AppState.
final class OpenAIRealtimeTranscriptionService {
    // 1. Connect: wss://api.openai.com/v1/realtime?model=gpt-realtime-whisper
    // 2. Send session.update with type=transcription and 24 kHz PCM input format.
    // 3. Send input_audio_buffer.append and optional input_audio_buffer.commit.
    // 4. Emit app-level partial/final events keyed by item_id.
}
"""


def command_scaffold(args: argparse.Namespace) -> int:
    if args.target != "swift-service":
        print(f"unsupported scaffold target: {args.target}")
        return 2
    if args.dry_run:
        print(SWIFT_SERVICE_TEMPLATE.rstrip())
        return 0
    output = Path(args.output or "Sources/MeetingTranslator/Services/OpenAIRealtime/OpenAIRealtimeTranscriptionService.swift")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and not args.force:
        print(f"refusing to overwrite existing file: {output}")
        return 1
    output.write_text(SWIFT_SERVICE_TEMPLATE, encoding="utf-8")
    print(f"wrote {output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="realtime-foundation")
    sub = parser.add_subparsers(dest="command", required=True)

    models = sub.add_parser("models", help="List recommended OpenAI realtime model routes")
    models.add_argument("--json", action="store_true")
    models.set_defaults(func=command_models)

    recommend = sub.add_parser("recommend", help="Recommend a realtime route")
    recommend.add_argument("--task", required=True)
    recommend.add_argument("--client", default="native-macos")
    recommend.add_argument("--show-translations", action=argparse.BooleanOptionalAction, default=True)
    recommend.add_argument("--same-language", action=argparse.BooleanOptionalAction, default=False)
    recommend.set_defaults(func=command_recommend)

    probe = sub.add_parser("probe", help="Probe model access or an explicit WAV audio file")
    probe.add_argument("--mode", choices=sorted(MODEL_ROUTES), default="transcription")
    probe.add_argument("--audio", help="Optional WAV file. Sends up to 4 seconds, so use non-private fixtures only.")
    probe.add_argument("--target", default="ja", help="Translation output language code for translation probes")
    probe.add_argument("--timeout", type=float, default=20.0)
    probe.set_defaults(func=command_probe)

    scaffold = sub.add_parser("scaffold", help="Print or write starter code")
    scaffold.add_argument("--target", required=True, choices=["swift-service"])
    scaffold.add_argument("--dry-run", action="store_true")
    scaffold.add_argument("--output")
    scaffold.add_argument("--force", action="store_true")
    scaffold.set_defaults(func=command_scaffold)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
