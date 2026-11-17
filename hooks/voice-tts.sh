#!/bin/bash
# Stop hook: speaks Claude's final message when voice mode is on.
# Engines: Kokoro TTS, tiny-voca, your own command, or the built-in macOS voice.
#
# Optional settings (environment variables):
#   VOICE_MODE_ENGINE            auto (default) | kokoro | tiny-voca | say | custom
#                                auto = Kokoro when it is set up, otherwise say
#   VOICE_MODE_KOKORO_MODEL      path to kokoro-v1.0.onnx
#   VOICE_MODE_KOKORO_VOICES     path to voices-v1.0.bin
#   VOICE_MODE_KOKORO_VOICE      Kokoro voice name (default: bm_george for male, af_heart for female)
#   VOICE_MODE_TINY_VOCA_DIR     folder of the tiny-voca clone (holds weights/)
#   VOICE_MODE_TINY_VOCA_PYTHON  Python that has tiny-voca installed (default: python3)
#   VOICE_MODE_TINY_VOCA_VOICE   M2 or F2 (default: M2 for male, F2 for female)
#   VOICE_MODE_TTS_COMMAND       for engine "custom": a command; gets the text file as $1
#   VOICE_MODE_SAY_VOICE         macOS voice name (default: system voice)

[ -f /tmp/claude-voice-mode ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
[ -z "$MESSAGE" ] && exit 0

# Drop fenced blocks (code, paths, links, commands) and table rows: they must
# be seen, not heard. Claude uses a fenced block on purpose to show a path.
MESSAGE=$(printf '%s\n' "$MESSAGE" | awk '
  /^[[:space:]]*```/ { f = !f; if (f) print "The details are on your screen."; next }
  f { next }
  /^[[:space:]]*\|/ { next }
  { print }
')

# Strip markdown so the voice doesn't read formatting characters aloud
MESSAGE=$(printf '%s\n' "$MESSAGE" | sed -E '
  s/`//g
  s/\[([^]]*)\]\([^)]*\)/\1/g
  s/\*//g
  s/\\//g
  s/^#{1,6}[[:space:]]+//
  s/^[[:space:]]*[-•][[:space:]]+//
  s/__//g
  s/(^|[[:space:]])_([^_]+)_/\1\2/g
')

# Stop any speech still playing from the previous turn
"$(dirname "$0")/voice-stop.sh" >/dev/null 2>&1

TMPFILE=$(mktemp /tmp/claude-voice-msg-XXXXXX)
printf '%s\n' "$MESSAGE" > "$TMPFILE"
echo "$TMPFILE" > /tmp/claude-voice-tts.tmpfile

# Voice preference: "male" (default) or "female", saved by the voice-mode skill.
PREF=$(cat "${VOICE_MODE_PREF_FILE:-$HOME/.config/voice-mode/voice}" 2>/dev/null)
if [ "$PREF" = female ]; then KOKORO_DEFAULT=af_heart; TV_DEFAULT=F2; else KOKORO_DEFAULT=bm_george; TV_DEFAULT=M2; fi
ENGINE="${VOICE_MODE_ENGINE:-auto}"
KOKORO_MODEL="${VOICE_MODE_KOKORO_MODEL:-$HOME/.local/share/kokoro-tts/kokoro-v1.0.onnx}"
KOKORO_VOICES="${VOICE_MODE_KOKORO_VOICES:-$HOME/.local/share/kokoro-tts/voices-v1.0.bin}"
KOKORO_VOICE="${VOICE_MODE_KOKORO_VOICE:-$KOKORO_DEFAULT}"
TV_DIR="${VOICE_MODE_TINY_VOCA_DIR:-}"
TV_PY="${VOICE_MODE_TINY_VOCA_PYTHON:-python3}"
TV_VOICE="${VOICE_MODE_TINY_VOCA_VOICE:-$TV_DEFAULT}"
WAV="$TMPFILE.wav"

kokoro_ready() { command -v kokoro-tts >/dev/null 2>&1 && [ -f "$KOKORO_MODEL" ] && [ -f "$KOKORO_VOICES" ]; }
tiny_ready()   { [ -n "$TV_DIR" ] && [ -f "$TV_DIR/weights/tiny-voca.pt" ] && command -v afplay >/dev/null 2>&1; }

# Pick the engine. A chosen engine that is not set up falls back to `say`.
case "$ENGINE" in
  auto)      kokoro_ready && USE=kokoro || USE=say ;;
  kokoro)    kokoro_ready && USE=kokoro || USE=say ;;
  tiny-voca) tiny_ready && USE=tiny-voca || USE=say ;;
  custom)    [ -n "${VOICE_MODE_TTS_COMMAND:-}" ] && USE=custom || USE=say ;;
  *)         USE=say ;;
esac
if [ "$USE" = say ] && ! command -v say >/dev/null 2>&1; then
  rm -f "$TMPFILE" /tmp/claude-voice-tts.tmpfile
  exit 0
fi

speak() {
  case "$USE" in
    kokoro)
      kokoro-tts "$TMPFILE" --model "$KOKORO_MODEL" --voices "$KOKORO_VOICES" --voice "$KOKORO_VOICE" --stream ;;
    tiny-voca)
      # tiny-voca writes a sound file; it has no streaming, so play it after.
      (cd "$TV_DIR" && DIZIONE_DATA="${DIZIONE_DATA:-weights/phonemizer}" "$TV_PY" -m tiny_voca.infer \
        --checkpoint weights/tiny-voca.pt --voice "$TV_VOICE" --text-file "$TMPFILE" --output "$WAV") \
        && afplay "$WAV" ;;
    custom)
      # Your own command. It gets the path of the text file as $1.
      sh -c "$VOICE_MODE_TTS_COMMAND" voice-mode "$TMPFILE" ;;
    say)
      if [ -n "${VOICE_MODE_SAY_VOICE:-}" ]; then say -v "$VOICE_MODE_SAY_VOICE" -f "$TMPFILE"; else say -f "$TMPFILE"; fi ;;
  esac
}

# Speak in the background and clean up the temp files after.
# `set -m` puts the job in its own process group so voice-stop.sh can kill
# the speech program and its audio player together.
set -m
(speak >/dev/null 2>&1; rm -f "$TMPFILE" "$WAV") &
echo $! > /tmp/claude-voice-tts.pid
set +m
exit 0
