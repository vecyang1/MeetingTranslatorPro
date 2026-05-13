#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-/tmp/mtp_realtime_probe_audio}"
mkdir -p "$OUT_DIR"

if ! command -v say >/dev/null 2>&1; then
  echo "missing macOS say command" >&2
  exit 2
fi

if ! command -v afconvert >/dev/null 2>&1; then
  echo "missing macOS afconvert command" >&2
  exit 2
fi

voice_exists() {
  say -v '?' | awk '{print $1}' | grep -Fxq "$1"
}

pick_voice() {
  for voice in "$@"; do
    if voice_exists "$voice"; then
      echo "$voice"
      return 0
    fi
  done
  echo ""
}

make_fixture() {
  local name="$1"
  local voice="$2"
  local text="$3"
  local aiff="$OUT_DIR/$name.aiff"
  local wav="$OUT_DIR/$name.wav"

  if [[ -n "$voice" ]]; then
    say -v "$voice" -r 145 -o "$aiff" "$text"
  else
    say -r 145 -o "$aiff" "$text"
  fi
  afconvert -f WAVE -d LEI16@24000 -c 1 "$aiff" "$wav"
  rm -f "$aiff"
  echo "$wav"
}

EN_VOICE="$(pick_voice Samantha Daniel Alex)"
ZH_VOICE="$(pick_voice Tingting Mei-Jia Sin-ji Eddy Flo)"

make_fixture \
  "mtp_realtime_translate_en_to_zh_long" \
  "$EN_VOICE" \
  "This is a synthetic Meeting Translator Pro provider probe. The speaker keeps talking for several seconds so the realtime translation session can emit partial translated text before the utterance is complete. No private meeting audio is used."

make_fixture \
  "mtp_realtime_translate_zh_to_en" \
  "$ZH_VOICE" \
  "这是 Meeting Translator Pro 的合成测试音频。说话人会持续说几秒钟，用来验证实时翻译和源语言字幕。这里没有任何私人会议内容。"

make_fixture \
  "mtp_realtime_translate_code_switch" \
  "$EN_VOICE" \
  "This is a synthetic code switching probe for Meeting Translator Pro. I will say hello in English, then say ni hao, then continue with realtime translation verification."

cat <<EOF
Synthetic probe audio written to:
$OUT_DIR

Suggested provider probes after installing a valid OPENAI_API_KEY:

tools/realtime-foundation/realtime-foundation probe --mode transcription --audio "$OUT_DIR/mtp_realtime_translate_en_to_zh_long.wav" --max-audio-seconds 12 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
tools/realtime-foundation/realtime-foundation probe --mode translation --audio "$OUT_DIR/mtp_realtime_translate_en_to_zh_long.wav" --target zh --max-audio-seconds 12 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
tools/realtime-foundation/realtime-foundation probe --mode translation --audio "$OUT_DIR/mtp_realtime_translate_zh_to_en.wav" --target en --max-audio-seconds 8 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
tools/realtime-foundation/realtime-foundation probe --mode translation --audio "$OUT_DIR/mtp_realtime_translate_code_switch.wav" --target zh --max-audio-seconds 10 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
tools/realtime-foundation/realtime-foundation probe --mode agent --audio "$OUT_DIR/mtp_realtime_translate_en_to_zh_long.wav" --max-audio-seconds 8 --i-understand-audio-is-sent-to-openai --show-text --timeout 30
EOF
