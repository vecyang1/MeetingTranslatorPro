#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p /tmp/mtp-swift-module-cache

MODE="${1:-all}"
if [[ "$MODE" != "all" && "$MODE" != "--local-only" ]]; then
  echo "usage: $0 [--local-only]" >&2
  exit 2
fi

if [[ -z "${OPENAI_API_KEY:-}" ]] && command -v defaults >/dev/null 2>&1; then
  APP_OPENAI_KEY="$(defaults read com.meetingtranslator.app com.meetingtranslator.apikey 2>/dev/null || true)"
  if [[ -n "$APP_OPENAI_KEY" ]]; then
    export OPENAI_API_KEY="$APP_OPENAI_KEY"
  fi
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

run_retry() {
  local label="$1"
  local attempts="$2"
  shift 2
  local status=1
  echo
  echo "==> $label"
  for attempt in $(seq 1 "$attempts"); do
    "$@"
    status=$?
    if [[ "$status" -eq 0 ]]; then
      echo "PASS: $label"
      return
    fi
    if [[ "$attempt" -lt "$attempts" ]]; then
      echo "Retrying $label after transient failure (attempt $attempt/$attempts)..." >&2
      sleep 2
    fi
  done
  echo "FAIL: $label (exit $status)" >&2
  failures=$((failures + 1))
}

run "git diff --check" git diff --check

run_shell "realtime core smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache -framework AVFoundation Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/*.swift tools/realtime-foundation/tests/realtime_core_smoke.swift -o /tmp/realtime_core_smoke && /tmp/realtime_core_smoke'

run_shell "realtime app e2e" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache -framework AVFoundation Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/*.swift tools/realtime-foundation/tests/realtime_app_e2e.swift -o /tmp/realtime_app_e2e && /tmp/realtime_app_e2e'

run_shell "system audio exclusion smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache -target arm64-apple-macosx14.0 -framework ScreenCaptureKit -framework AVFoundation -framework CoreGraphics -framework Combine Sources/MeetingTranslator/Managers/SystemAudioManager.swift tools/realtime-foundation/tests/system_audio_exclusion_smoke.swift -o /tmp/system_audio_exclusion_smoke && /tmp/system_audio_exclusion_smoke'

run_shell "translated audio output safety smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache -target arm64-apple-macosx14.0 -framework CoreAudio Sources/MeetingTranslator/Models/TranscriptionEntry.swift Sources/MeetingTranslator/Services/OpenAIRealtime/RealtimeModels.swift Sources/MeetingTranslator/Services/AudioOutputRouteInspector.swift tools/realtime-foundation/tests/translated_audio_output_safety_smoke.swift -o /tmp/translated_audio_output_safety_smoke && /tmp/translated_audio_output_safety_smoke'

run_shell "settings copy smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache Sources/MeetingTranslator/Models/AppSettings.swift tools/realtime-foundation/tests/settings_copy_smoke.swift -o /tmp/settings_copy_smoke && /tmp/settings_copy_smoke'

run_shell "settings input-filter smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache tools/realtime-foundation/tests/settings_noise_gate_ui_smoke.swift -o /tmp/settings_noise_gate_ui_smoke && /tmp/settings_noise_gate_ui_smoke'

run_shell "transcript follow smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache tools/realtime-foundation/tests/transcript_follow_ui_smoke.swift -o /tmp/transcript_follow_ui_smoke && /tmp/transcript_follow_ui_smoke'

run_shell "language detector smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache Sources/MeetingTranslator/Models/TranscriptionEntry.swift tools/realtime-foundation/tests/language_detector_smoke.swift -o /tmp/language_detector_smoke && /tmp/language_detector_smoke'

run_shell "app logo UI smoke" \
  'swiftc -module-cache-path /tmp/mtp-swift-module-cache tools/realtime-foundation/tests/app_logo_ui_smoke.swift -o /tmp/app_logo_ui_smoke && /tmp/app_logo_ui_smoke'

run "app icon visual smoke" python3 tools/realtime-foundation/tests/app_icon_visual_smoke.py

run "route gate: interpreter starts translate" \
  tools/realtime-foundation/realtime-foundation recommend --task interpreter --show-translations --no-same-language --pinned-source-language --interpreter-session

run "route gate: auto-detect stays transcription" \
  tools/realtime-foundation/realtime-foundation recommend --task interpreter --show-translations --no-same-language --no-pinned-source-language --interpreter-session

run "build, sign, and install app" ./build_app.sh

run_shell "installed app runtime inspection" \
  'open "/Applications/MeetingTranslator.app"; sleep 2; pgrep -fl "Meeting Translator|MeetingTranslator"; osascript -e '\''id of app "Meeting Translator"'\'' >/tmp/mtp_bundle_id.txt; grep -Fxq com.meetingtranslator.app /tmp/mtp_bundle_id.txt; /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/MeetingTranslator.app/Contents/Info.plist" | grep -Fxq 1.1.1; /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "/Applications/MeetingTranslator.app/Contents/Info.plist" | grep -Fxq 3; codesign -dv --verbose=4 "/Applications/MeetingTranslator.app" 2>&1 | grep -F "Identifier=com.meetingtranslator.app"; strings "/Applications/MeetingTranslator.app/Contents/MacOS/MeetingTranslator" | grep -F "Live Interpretation"'

run_shell "installed app current-process exclusion runtime probe" \
  'osascript -e '\''tell application id "com.meetingtranslator.app" to quit'\'' >/dev/null 2>&1 || true; sleep 1; PROBE_OUT=/tmp/mtp_system_audio_current_process_probe.txt; rm -f "$PROBE_OUT"; open -W "/Applications/MeetingTranslator.app" --args --run-system-audio-exclusion-probe --system-audio-exclusion-probe-output "$PROBE_OUT"; cat "$PROBE_OUT"; grep -F "system audio current-process exclusion runtime probe ok" "$PROBE_OUT"'

if [[ "$MODE" == "--local-only" ]]; then
  echo
  echo "Provider probes skipped in --local-only mode."
else
  run "generate synthetic provider audio" tools/realtime-foundation/generate_synthetic_probe_audio.sh
  run_retry "provider probe: realtime transcription synthetic audio" 3 \
    tools/realtime-foundation/realtime-foundation probe --mode transcription --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav --max-audio-seconds 12 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
  run_retry "provider probe: realtime translation en->zh synthetic audio" 3 \
    tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav --target zh --max-audio-seconds 12 --i-understand-audio-is-sent-to-openai --show-text --capture-output-audio /tmp/mtp_realtime_probe_audio/translated_audio_en_to_zh.wav --timeout 30
  run_retry "provider probe: realtime translation zh->en synthetic audio" 3 \
    tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_zh_to_en.wav --target en --max-audio-seconds 8 --i-understand-audio-is-sent-to-openai --show-text --capture-output-audio /tmp/mtp_realtime_probe_audio/translated_audio_zh_to_en.wav --timeout 30
  run_retry "provider probe: realtime translation code-switch synthetic audio" 3 \
    tools/realtime-foundation/realtime-foundation probe --mode translation --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_code_switch.wav --target zh --max-audio-seconds 10 --i-understand-audio-is-sent-to-openai --show-text --capture-output-audio /tmp/mtp_realtime_probe_audio/translated_audio_code_switch.wav --timeout 30
  run_retry "provider probe: realtime-2 agent synthetic audio" 3 \
    tools/realtime-foundation/realtime-foundation probe --mode agent --audio /tmp/mtp_realtime_probe_audio/mtp_realtime_translate_en_to_zh_long.wav --max-audio-seconds 8 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "Realtime mission verification passed."
  exit 0
fi

echo "Realtime mission verification failed: $failures failing check(s)." >&2
exit 1
