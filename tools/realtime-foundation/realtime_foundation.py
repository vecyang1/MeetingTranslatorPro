#!/usr/bin/env python3
"""OpenAI Realtime foundation helper for Meeting Translator Pro agents."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import secrets
import ssl
import socket
import struct
import subprocess
import sys
import time
import wave
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

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
        "purpose": "Live speech-to-speech translation; pair with realtime Whisper for proven source caption deltas",
        "pricing": "$0.034/min translation plus $0.017/min source captions when paired with realtime Whisper",
    },
    "agent": {
        "model": "gpt-realtime-2",
        "endpoint": "/v1/realtime",
        "transport": "Realtime conversation session",
        "purpose": "Dialog understanding plus future voice assistant actions",
        "pricing": "$4/$24 text tokens; $32/$64 audio tokens per 1M input/output",
    },
}

TASK_ALIASES = {
    "captions": "transcription",
    "caption": "transcription",
    "meeting-captions": "transcription",
    "dialog": "agent",
    "conversation": "agent",
    "transcribe": "transcription",
    "transcription": "transcription",
    "stt": "transcription",
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


def choose_mode(
    task: str,
    client: str,
    show_translations: bool,
    same_language: bool,
    pinned_source_language: bool,
    interpreter_session: bool,
) -> str:
    normalized_task = task.strip().lower()
    normalized_client = client.strip().lower()
    if normalized_task in TASK_ALIASES:
        mode = TASK_ALIASES[normalized_task]
        if mode == "translation" and (
            not show_translations
            or same_language
            or not pinned_source_language
            or not interpreter_session
        ):
            return "transcription"
        return mode
    if not show_translations or same_language or not pinned_source_language:
        return "transcription"
    if "browser" in normalized_client and "translate" in normalized_task and interpreter_session:
        return "translation"
    if "tool" in normalized_task or "action" in normalized_task or "assistant" in normalized_task:
        return "agent"
    return "transcription"


def command_recommend(args: argparse.Namespace) -> int:
    mode = choose_mode(
        args.task,
        args.client,
        args.show_translations,
        args.same_language,
        args.pinned_source_language,
        args.interpreter_session or args.translated_audio,
    )
    info = MODEL_ROUTES[mode]
    print(f"mode: {mode}")
    print(f"model: {info['model']}")
    print(f"endpoint: {info['endpoint']}")
    print(f"transport: {info['transport']}")
    if mode == "translation":
        print("gate: start only when showTranslations && one pinned non-same source && explicit interpreter-session mode")
    elif mode == "agent":
        print("gate: use only for dialog/assistant behavior, not caption-only or cost-efficient translation")
    else:
        print("gate: M6 caption-first default for live transcript deltas while speech is still active")
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
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        width = wav.getsampwidth()
        rate = wav.getframerate()
        frame_count = min(wav.getnframes(), int(rate * max_seconds))
        pcm = wav.readframes(frame_count)

    if channels == 1 and width == 2 and rate == target_rate:
        return pcm

    samples = decode_wav_samples(pcm, width, channels)
    if rate != target_rate:
        samples = resample_pcm16_samples(samples, rate, target_rate)
    output = bytearray()
    for sample in samples:
        output.extend(clamp_pcm16(sample).to_bytes(2, "little", signed=True))
    return bytes(output)


def decode_wav_samples(pcm: bytes, width: int, channels: int) -> list[int]:
    if width not in {1, 2, 3, 4}:
        raise ValueError(f"unsupported WAV sample width: {width}")
    if channels <= 0:
        raise ValueError(f"unsupported WAV channel count: {channels}")

    frame_size = width * channels
    samples: list[int] = []
    for frame_start in range(0, len(pcm) - frame_size + 1, frame_size):
        channel_values: list[int] = []
        for channel_index in range(channels):
            start = frame_start + channel_index * width
            raw = pcm[start : start + width]
            if width == 1:
                value = (raw[0] - 128) << 8
            elif width == 2:
                value = int.from_bytes(raw, "little", signed=True)
            elif width == 3:
                sign = b"\xff" if raw[2] & 0x80 else b"\x00"
                value = int.from_bytes(raw + sign, "little", signed=True) >> 8
            else:
                value = int.from_bytes(raw, "little", signed=True) >> 16
            channel_values.append(value)
        samples.append(clamp_pcm16(round(sum(channel_values) / len(channel_values))))
    return samples


def resample_pcm16_samples(samples: list[int], source_rate: int, target_rate: int) -> list[int]:
    if not samples or source_rate <= 0 or target_rate <= 0 or source_rate == target_rate:
        return samples
    output_count = max(1, round(len(samples) * target_rate / source_rate))
    step = source_rate / target_rate
    output: list[int] = []
    for index in range(output_count):
        position = index * step
        left = int(position)
        right = min(left + 1, len(samples) - 1)
        fraction = position - left
        output.append(clamp_pcm16(round(samples[left] * (1.0 - fraction) + samples[right] * fraction)))
    return output


def clamp_pcm16(value: int) -> int:
    return max(-32768, min(32767, value))



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


class WebSocketTimeoutException(TimeoutError):
    """Compatibility timeout name used by websocket-client and the stdlib fallback."""


class StdlibWebSocket:
    """Small RFC 6455 client for local provider probes without third-party packages."""

    def __init__(self, ssl_options: dict[str, Any]) -> None:
        self.ssl_options = ssl_options
        self.timeout: float | None = None
        self.sock: socket.socket | None = None
        self._fragmented_text: list[bytes] = []

    def settimeout(self, timeout: float) -> None:
        self.timeout = timeout
        if self.sock:
            self.sock.settimeout(timeout)

    def connect(self, url: str, header: list[str] | None = None) -> None:
        parsed = urlparse(url)
        if parsed.scheme not in {"ws", "wss"} or not parsed.hostname:
            raise ValueError(f"unsupported WebSocket URL: {url}")
        port = parsed.port or (443 if parsed.scheme == "wss" else 80)
        host_header = parsed.hostname if parsed.port in (None, 443, 80) else f"{parsed.hostname}:{port}"
        path = parsed.path or "/"
        if parsed.query:
            path = f"{path}?{parsed.query}"

        raw_sock = socket.create_connection((parsed.hostname, port), timeout=self.timeout)
        if parsed.scheme == "wss":
            ca_certs = self.ssl_options.get("ca_certs")
            context = ssl.create_default_context(cafile=ca_certs) if ca_certs else ssl.create_default_context()
            if self.ssl_options.get("cert_reqs") == ssl.CERT_NONE:
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
            self.sock = context.wrap_socket(raw_sock, server_hostname=parsed.hostname)
        else:
            self.sock = raw_sock
        if self.timeout is not None:
            self.sock.settimeout(self.timeout)

        key = base64.b64encode(secrets.token_bytes(16)).decode("ascii")
        request_headers = [
            f"GET {path} HTTP/1.1",
            f"Host: {host_header}",
            "Upgrade: websocket",
            "Connection: Upgrade",
            f"Sec-WebSocket-Key: {key}",
            "Sec-WebSocket-Version: 13",
        ]
        request_headers.extend(header or [])
        self.sock.sendall(("\r\n".join(request_headers) + "\r\n\r\n").encode("ascii"))

        response = self._read_until_headers_complete()
        status_line, _, header_blob = response.partition(b"\r\n")
        if b" 101 " not in status_line:
            raise RuntimeError(f"websocket handshake failed: {status_line.decode('utf-8', 'replace')}")

        response_headers: dict[str, str] = {}
        for line in header_blob.split(b"\r\n"):
            if b":" not in line:
                continue
            name, value = line.split(b":", 1)
            response_headers[name.decode("ascii", "ignore").lower()] = value.decode("ascii", "ignore").strip()
        accept = response_headers.get("sec-websocket-accept")
        expected = base64.b64encode(
            hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")).digest()
        ).decode("ascii")
        if accept != expected:
            raise RuntimeError("websocket handshake failed: invalid Sec-WebSocket-Accept")

    def send(self, message: str) -> None:
        self._send_frame(0x1, message.encode("utf-8"))

    def recv(self) -> str:
        while True:
            opcode, fin, payload = self._read_frame()
            if opcode == 0x1:
                if fin:
                    return payload.decode("utf-8")
                self._fragmented_text = [payload]
                continue
            if opcode == 0x0:
                if not self._fragmented_text:
                    continue
                self._fragmented_text.append(payload)
                if fin:
                    message = b"".join(self._fragmented_text).decode("utf-8")
                    self._fragmented_text = []
                    return message
                continue
            if opcode == 0x8:
                raise RuntimeError("websocket closed by server")
            if opcode == 0x9:
                self._send_frame(0xA, payload)
                continue
            if opcode == 0xA:
                continue

    def close(self) -> None:
        if not self.sock:
            return
        try:
            self._send_frame(0x8, b"")
        except Exception:
            pass
        try:
            self.sock.close()
        finally:
            self.sock = None

    def _read_until_headers_complete(self) -> bytes:
        chunks: list[bytes] = []
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = self._read_exact(1)
            chunks.append(chunk)
            data = b"".join(chunks)
            if len(data) > 65536:
                raise RuntimeError("websocket handshake response too large")
        return data

    def _read_frame(self) -> tuple[int, bool, bytes]:
        header = self._read_exact(2)
        first, second = header[0], header[1]
        fin = bool(first & 0x80)
        opcode = first & 0x0F
        masked = bool(second & 0x80)
        length = second & 0x7F
        if length == 126:
            length = struct.unpack("!H", self._read_exact(2))[0]
        elif length == 127:
            length = struct.unpack("!Q", self._read_exact(8))[0]
        mask = self._read_exact(4) if masked else b""
        payload = self._read_exact(length) if length else b""
        if masked:
            payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        return opcode, fin, payload

    def _send_frame(self, opcode: int, payload: bytes) -> None:
        if not self.sock:
            raise RuntimeError("websocket is not connected")
        first = 0x80 | opcode
        mask = secrets.token_bytes(4)
        length = len(payload)
        if length <= 125:
            header = bytes([first, 0x80 | length])
        elif length <= 65535:
            header = bytes([first, 0x80 | 126]) + struct.pack("!H", length)
        else:
            header = bytes([first, 0x80 | 127]) + struct.pack("!Q", length)
        masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        self.sock.sendall(header + mask + masked)

    def _read_exact(self, count: int) -> bytes:
        if not self.sock:
            raise RuntimeError("websocket is not connected")
        chunks: list[bytes] = []
        remaining = count
        while remaining > 0:
            try:
                chunk = self.sock.recv(remaining)
            except socket.timeout as exc:
                raise WebSocketTimeoutException() from exc
            if not chunk:
                raise RuntimeError("websocket closed")
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)


def create_probe_websocket(ssl_options: dict[str, Any]) -> Any:
    try:
        import websocket

        return websocket.WebSocket(sslopt=ssl_options)
    except Exception:
        print("websocket-client not available; using stdlib WebSocket probe transport")
        return StdlibWebSocket(ssl_options)


def websocket_audio_probe(
    mode: str,
    key: str,
    audio_path: Path,
    target: str,
    timeout: float,
    show_text: bool,
    max_audio_seconds: float,
) -> int:
    pcm = load_wav_pcm16(audio_path, max_seconds=max_audio_seconds)
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

    ws = create_probe_websocket(ssl_options)
    ws.settimeout(min(timeout, 10.0))
    try:
        ws.connect(
            url,
            header=[f"Authorization: Bearer {key}", "OpenAI-Safety-Identifier: meeting-translator-pro-local-probe"],
        )
    except Exception as exc:
        print(f"{mode} audio probe connect failed: {exc}")
        return 1
    ws.settimeout(min(timeout, 2.0))

    try:
        if mode == "translation":
            caption_url = "wss://api.openai.com/v1/realtime?intent=transcription"
            caption_ws = create_probe_websocket(ssl_options)
            caption_ws.settimeout(min(timeout, 10.0))
            try:
                caption_ws.connect(
                    caption_url,
                    header=[
                        f"Authorization: Bearer {key}",
                        "OpenAI-Safety-Identifier: meeting-translator-pro-local-probe",
                    ],
                )
            except Exception as exc:
                print(f"{mode} source caption probe connect failed: {exc}")
                return 1
            caption_ws.settimeout(min(timeout, 2.0))
            try:
                caption_ws.send(
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
                caption_ready_seen = wait_for_session_updated(caption_ws, timeout)
                if not caption_ready_seen:
                    print("translation audio probe failed before source caption session.updated")
                    return 1
                ws.send(json.dumps({"type": "session.update", "session": {"audio": {"output": {"language": target}}}}))
                ready_seen = wait_for_session_updated(ws, timeout)
                if not ready_seen:
                    print("translation audio probe failed before session.updated")
                    return 1
                encoded_audio = base64.b64encode(pcm).decode("ascii")
                caption_ws.send(json.dumps({"type": "input_audio_buffer.append", "audio": encoded_audio}))
                caption_ws.send(json.dumps({"type": "input_audio_buffer.commit"}))
                ws.send(json.dumps({"type": "session.input_audio_buffer.append", "audio": encoded_audio}))
                wanted = {
                    "session.output_transcript.delta",
                    "session.output_transcript.done",
                    "session.output_transcript.completed",
                    "session.output_audio.delta",
                }
                source_caption_wanted = {
                    "conversation.item.input_audio_transcription.delta",
                    "conversation.item.input_audio_transcription.completed",
                }
            finally:
                pass
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
        source_caption_seen: list[str] = []
        agent_delta_text = ""
        translation_input_text = ""
        translation_output_text = ""
        translation_audio_seen = False
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
                    event = {}
                else:
                    print(f"{mode} audio probe receive failed: {exc.__class__.__name__}")
                    break
            if mode == "translation":
                try:
                    caption_event = json.loads(caption_ws.recv())
                except Exception as exc:
                    if exc.__class__.__name__ == "WebSocketTimeoutException":
                        caption_event = {}
                    else:
                        print(f"{mode} source caption probe receive failed: {exc.__class__.__name__}")
                        break
                caption_event_type = caption_event.get("type", "")
                if caption_event_type:
                    source_caption_seen.append(caption_event_type)
                if caption_event_type in source_caption_wanted:
                    text = (
                        caption_event.get("delta")
                        or caption_event.get("transcript")
                        or caption_event.get("text")
                        or ""
                    )
                    if isinstance(text, str):
                        translation_input_text += text
                if not event:
                    if translation_input_text.strip() and translation_output_text.strip():
                        if show_text:
                            print(
                                "translation audio probe transcript events: "
                                f"input={translation_input_text.strip()[:80]} "
                                f"output={translation_output_text.strip()[:80]}"
                            )
                        else:
                            print("translation audio probe transcript events")
                        return 0
                    continue
            event_type = event.get("type", "")
            seen.append(event_type)
            if event_type in wanted:
                if mode == "translation":
                    if event_type == "session.output_audio.delta":
                        translation_audio_seen = True
                        continue
                    text = event.get("delta") or event.get("transcript") or event.get("text") or ""
                    if event_type.startswith("session.input_transcript.") and isinstance(text, str):
                        translation_input_text += text
                    elif event_type.startswith("session.output_transcript.") and isinstance(text, str):
                        translation_output_text += text
                    if translation_input_text.strip() and translation_output_text.strip():
                        if show_text:
                            print(
                                "translation audio probe transcript events: "
                                f"input={translation_input_text.strip()[:80]} "
                                f"output={translation_output_text.strip()[:80]}"
                            )
                        else:
                            print("translation audio probe transcript events")
                        return 0
                    continue
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
        if mode == "translation":
            audio_note = " and output audio" if translation_audio_seen else ""
            print(
                f"{mode} audio probe timed out before both transcript directions; "
                f"saw input={bool(translation_input_text.strip())}, "
                f"output={bool(translation_output_text.strip())}{audio_note}; "
                f"translate events seen: {', '.join(seen[-8:]) or 'none'}; "
                f"source caption events seen: {', '.join(source_caption_seen[-8:]) or 'none'}"
            )
            return 1
        print(f"{mode} audio probe timed out; events seen: {', '.join(seen[-8:]) or 'none'}")
        return 1
    finally:
        if mode == "translation":
            try:
                caption_ws.close()
            except Exception:
                pass
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
    if args.max_audio_seconds <= 0:
        print("--max-audio-seconds must be greater than zero")
        return 2
    return websocket_audio_probe(
        mode,
        key,
        audio_path,
        args.target,
        args.timeout,
        args.show_text,
        args.max_audio_seconds,
    )


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
    recommend.add_argument(
        "--pinned-source-language",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Whether exactly one source language is pinned. Required for live interpretation.",
    )
    recommend.add_argument(
        "--interpreter-session",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Explicit paid live-interpreter session gate. Required for gpt-realtime-translate.",
    )
    recommend.add_argument(
        "--translated-audio",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Deprecated alias for explicit live-interpreter session mode; playback remains a separate app gate.",
    )
    recommend.set_defaults(func=command_recommend)

    probe = sub.add_parser("probe", help="Probe model access or an explicit WAV audio file")
    probe.add_argument("--mode", choices=sorted(MODEL_ROUTES), default="transcription")
    probe.add_argument("--audio", help="Optional WAV file. Use non-private fixtures only.")
    probe.add_argument("--i-understand-audio-is-sent-to-openai", action="store_true")
    probe.add_argument("--show-text", action="store_true", help="Print transcript snippets from the probe fixture")
    probe.add_argument("--target", default="ja", help="Translation output language code for translation probes")
    probe.add_argument("--timeout", type=float, default=20.0)
    probe.add_argument(
        "--max-audio-seconds",
        type=float,
        default=4.0,
        help="Maximum seconds of WAV audio to send; increase for long-utterance synthetic probes.",
    )
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
