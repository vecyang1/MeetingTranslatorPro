#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

MODE="${1:-all}"
if [[ "$MODE" != "all" && "$MODE" != "--local-only" ]]; then
  echo "usage: $0 [--local-only]" >&2
  exit 2
fi

failures=0

run() {
  local label="$1"
  shift
  echo
  echo "==> $label"
  if "$@"; then
    echo "PASS: $label"
  else
    local status=$?
    echo "FAIL: $label (exit $status)" >&2
    failures=$((failures + 1))
  fi
}

run_shell() {
  local label="$1"
  local command="$2"
  run "$label" bash -lc "$command"
}

run "git diff --check" git diff --check

run_shell "realtime core smoke" \
  'swiftc Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/*.swift tools/realtime-foundation/tests/realtime_core_smoke.swift -o /tmp/realtime_core_smoke && /tmp/realtime_core_smoke'

run_shell "realtime app e2e" \
  'swiftc Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/*.swift tools/realtime-foundation/tests/realtime_app_e2e.swift -o /tmp/realtime_app_e2e && /tmp/realtime_app_e2e'

run_shell "settings copy smoke" \
  'swiftc Sources/MeetingTranslator/Models/AppSettings.swift tools/realtime-foundation/tests/settings_copy_smoke.swift -o /tmp/settings_copy_smoke && /tmp/settings_copy_smoke'

run_shell "settings input-filter smoke" \
  'swiftc tools/realtime-foundation/tests/settings_noise_gate_ui_smoke.swift -o /tmp/settings_noise_gate_ui_smoke && /tmp/settings_noise_gate_ui_smoke'

run_shell "transcript follow smoke" \
  'swiftc tools/realtime-foundation/tests/transcript_follow_ui_smoke.swift -o /tmp/transcript_follow_ui_smoke && /tmp/transcript_follow_ui_smoke'

run_shell "language detector smoke" \
  'swiftc Sources/MeetingTranslator/Models/TranscriptionEntry.swift tools/realtime-foundation/tests/language_detector_smoke.swift -o /tmp/language_detector_smoke && /tmp/language_detector_smoke'

run_shell "app logo UI smoke" \
  'swiftc tools/realtime-foundation/tests/app_logo_ui_smoke.swift -o /tmp/app_logo_ui_smoke && /tmp/app_logo_ui_smoke'

run "app icon visual smoke" python3 tools/realtime-foundation/tests/app_icon_visual_smoke.py

run "route gate: interpreter starts translate" \
  tools/realtime-foundation/realtime-foundation recommend --task interpreter --show-translations --no-same-language --pinned-source-language --interpreter-session

run "route gate: auto-detect stays transcription" \
  tools/realtime-foundation/realtime-foundation recommend --task interpreter --show-translations --no-same-language --no-pinned-source-language --interpreter-session

run "build, sign, and install app" ./build_app.sh

run_shell "installed app runtime inspection" \
  'open "/Applications/MeetingTranslator.app"; sleep 2; pgrep -fl "Meeting Translator|MeetingTranslator"; osascript -e '\''id of app "Meeting Translator"'\'' >/tmp/mtp_bundle_id.txt; grep -Fxq com.meetingtranslator.app /tmp/mtp_bundle_id.txt; codesign -dv --verbose=4 "/Applications/MeetingTranslator.app" 2>&1 | grep -F "Identifier=com.meetingtranslator.app"; strings "/Applications/MeetingTranslator.app/Contents/MacOS/MeetingTranslator" | grep -F "Live Interpretation"'

if [[ "$MODE" == "--local-only" ]]; then
  echo
  echo "Provider probes skipped in --local-only mode."
else
  run "generate synthetic provider audio" tools/realtime-foundation/generate_synthetic_probe_audio.sh
  run "provider probe: realtime transcription synthetic audio" \
    tools/realtime-foundation/realtime-foundation probe --mode transcription --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav --max-audio-seconds 12 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
  run "provider probe: realtime translation en->zh synthetic audio" \
    tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav --target zh --max-audio-seconds 12 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
  run "provider probe: realtime translation zh->en synthetic audio" \
    tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_zh_to_en.wav --target en --max-audio-seconds 8 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
  run "provider probe: realtime translation code-switch synthetic audio" \
    tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_code_switch.wav --target zh --max-audio-seconds 10 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
  run "provider probe: realtime-2 agent synthetic audio" \
    tools/realtime-foundation/realtime-foundation probe --mode agent --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav --max-audio-seconds 8 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Realtime mission verification passed."
  exit 0
fi

echo "Realtime mission verification failed: $failures failing check(s)." >&2
exit 1
