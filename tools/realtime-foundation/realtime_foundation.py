#!/usr/bin/env python3
"""OpenAI Realtime foundation helper for Meeting Translator Pro agents."""

from __future__ import annotations

import argparse
import base64
import json
import os
import ssl
import subprocess
import sys
import time
import warnings
import wave
from pathlib import Path
from typing import Any

MODEL_ROUTES: dict[str, dict[str, str]] = {
    "transcription": {
        "model": "gpt-realtime-whisper",
        "endpoint": "/v1/realtime?intent=transcription",
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
        "purpose": "Default live captions/dialog understanding plus future voice assistant actions",
        "pricing": "$4/$24 text tokens; $32/$64 audio tokens per 1M input/output",
    },
}

TASK_ALIASES = {
    "captions": "agent",
    "caption": "agent",
    "meeting-captions": "agent",
    "dialog": "agent",
    "conversation": "agent",
    "transcribe": "agent",
    "transcription": "agent",
    "speech-to-text": "transcription",
    "whisper": "transcription",
    "whisper-transcription": "transcription",
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
    curl_config = f'header = "Authorization: Bearer {key}"\nurl = "{url}"\n'
    result = subprocess.run(
        [
            "curl",
            "-sS",
            "-w",
            "\n%{http_code}",
            "--config",
            "-",
        ],
        input=curl_config,
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
    if normalized_task in TASK_ALIASES:
        mode = TASK_ALIASES[normalized_task]
        if mode == "translation" and (not show_translations or same_language):
            return "agent"
        return mode
    if not show_translations or same_language:
        return "agent"
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
        print("gate: default captions path; keep actions approval-gated and translate only after language gate")
    else:
        print("gate: specialized raw STT fallback when exact transcript deltas are required")
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
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", DeprecationWarning)
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


def extract_agent_probe_text(event: dict[str, Any]) -> str:
    direct = event.get("text") or event.get("transcript") or event.get("delta")
    if isinstance(direct, str) and direct.strip():
        return direct.strip()
    item = event.get("item")
    if isinstance(item, dict):
        text = extract_agent_probe_item_text(item)
        if text:
            return text
    response = event.get("response")
    if isinstance(response, dict):
        output = response.get("output")
        if isinstance(output, list):
            chunks = [
                text
                for item in output
                if isinstance(item, dict)
                for text in [extract_agent_probe_item_text(item)]
                if text
            ]
            if chunks:
                return " ".join(chunks).strip()
    return ""


def extract_agent_probe_item_text(item: dict[str, Any]) -> str:
    content = item.get("content")
    if isinstance(content, list):
        chunks: list[str] = []
        for part in content:
            if not isinstance(part, dict):
                continue
            text = part.get("text") or part.get("transcript")
            if isinstance(text, str) and text.strip():
                chunks.append(text.strip())
        return " ".join(chunks).strip()
    text = item.get("text") or item.get("transcript")
    return text.strip() if isinstance(text, str) else ""


def websocket_audio_probe(
    mode: str,
    key: str,
    audio_path: Path,
    target: str,
    timeout: float,
    show_text: bool,
) -> int:
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
    elif mode == "transcription":
        url = "wss://api.openai.com/v1/realtime?intent=transcription"
    else:
        url = f"wss://api.openai.com/v1/realtime?model={model}"

    ssl_options: dict[str, Any] = {"cert_reqs": ssl.CERT_REQUIRED}
    try:
        import certifi

        ssl_options["ca_certs"] = certifi.where()
    except ImportError:
        print("certifi not available; using platform default CA store for websocket probe")

    ws = websocket.WebSocket(sslopt=ssl_options)
    ws.settimeout(min(timeout, 2.0))
    ws.connect(
        url,
        header=[f"Authorization: Bearer {key}", "OpenAI-Safety-Identifier: meeting-translator-pro-local-probe"],
    )

    try:
        if mode == "translation":
            ws.send(json.dumps({"type": "session.update", "session": {"audio": {"output": {"language": target}}}}))
            ready_seen = wait_for_session_updated(ws, timeout)
            if not ready_seen:
                print("translation audio probe failed before session.updated")
                return 1
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
            ready_seen = wait_for_session_updated(ws, timeout)
            if not ready_seen:
                print("transcription audio probe failed before session.updated")
                return 1
            ws.send(json.dumps({"type": "input_audio_buffer.append", "audio": base64.b64encode(pcm).decode("ascii")}))
            ws.send(json.dumps({"type": "input_audio_buffer.commit"}))
            wanted = {
                "conversation.item.input_audio_transcription.delta",
                "conversation.item.input_audio_transcription.completed",
            }
        else:
            ws.send(
                json.dumps(
                    {
                        "type": "session.update",
                        "session": {
                            "type": "realtime",
                            "output_modalities": ["text"],
                            "reasoning": {"effort": "low"},
                            "instructions": (
                                "You are a faithful live caption engine. "
                                "Output only the transcript of the user's speech. "
                                "Do not answer, summarize, or add labels."
                            ),
                            "audio": {
                                "input": {
                                    "format": {"type": "audio/pcm", "rate": 24000},
                                    "turn_detection": None,
                                }
                            },
                        },
                    }
                )
            )
            ready_seen = wait_for_session_updated(ws, timeout)
            if not ready_seen:
                print("agent audio probe failed before session.updated")
                return 1
            ws.send(json.dumps({"type": "input_audio_buffer.append", "audio": base64.b64encode(pcm).decode("ascii")}))
            ws.send(json.dumps({"type": "input_audio_buffer.commit"}))
            ws.send(json.dumps({"type": "response.create", "response": {"output_modalities": ["text"]}}))
            wanted = {
                "response.output_text.delta",
                "response.output_text.done",
                "response.text.delta",
                "response.text.done",
                "response.output_item.done",
                "response.done",
            }

        deadline = time.time() + timeout
        seen: list[str] = []
        agent_delta_text = ""
        agent_final_events = {
            "response.output_text.done",
            "response.text.done",
            "response.output_item.done",
            "response.done",
        }
        while time.time() < deadline:
            try:
                event = json.loads(ws.recv())
            except Exception as exc:
                if exc.__class__.__name__ == "WebSocketTimeoutException":
                    continue
                else:
                    print(f"{mode} audio probe receive failed: {exc.__class__.__name__}")
                    break
            event_type = event.get("type", "")
            seen.append(event_type)
            if event_type in wanted:
                if mode == "agent":
                    text = extract_agent_probe_text(event)
                    if text and event_type not in agent_final_events:
                        agent_delta_text = text
                        continue
                    if text and event_type in agent_final_events:
                        if show_text:
                            print(f"{mode} audio probe final event: {event_type} {text[:120]}")
                        else:
                            print(f"{mode} audio probe final event: {event_type}")
                        return 0
                    continue
                if show_text:
                    text = event.get("delta") or event.get("transcript") or "<audio delta>"
                    print(f"{mode} audio probe event: {event_type} {str(text)[:120]}")
                else:
                    print(f"{mode} audio probe event: {event_type}")
                return 0
        if mode == "agent" and agent_delta_text:
            print(
                f"{mode} audio probe saw delta text but no final text; "
                f"last delta: {agent_delta_text[:120]}; events seen: {', '.join(seen[-8:]) or 'none'}"
            )
            return 1
        print(f"{mode} audio probe timed out; events seen: {', '.join(seen[-8:]) or 'none'}")
        return 1
    finally:
        ws.close()


def wait_for_session_updated(ws: Any, timeout: float) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            event = json.loads(ws.recv())
        except Exception as exc:
            if exc.__class__.__name__ == "WebSocketTimeoutException":
                continue
            return False
        event_type = event.get("type", "")
        if event_type == "session.updated":
            return True
        if event_type == "error":
            message = event.get("error", {}).get("message") or "OpenAI realtime session error"
            print(f"session update error: {message}")
            return False
    return False


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
    if not args.i_understand_audio_is_sent_to_openai:
        print("Refusing audio probe without --i-understand-audio-is-sent-to-openai. Use only non-private fixtures.")
        return 2
    return websocket_audio_probe(mode, key, audio_path, args.target, args.timeout, args.show_text)


SWIFT_SERVICE_TEMPLATE = """// OpenAI Realtime service scaffold.
// Keep protocol parsing here, not in AppState.
final class OpenAIRealtimeTranscriptionService {
    // 1. Connect: wss://api.openai.com/v1/realtime?intent=transcription
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
    probe.add_argument("--i-understand-audio-is-sent-to-openai", action="store_true")
    probe.add_argument("--show-text", action="store_true", help="Print transcript snippets from the probe fixture")
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
