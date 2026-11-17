#!/bin/bash
# Tests for the voice hooks. Stubs kokoro-tts and say, so nothing is spoken.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0
OUT=$(mktemp -d)

STUB_DIR=$(mktemp -d)
for cmd in kokoro-tts say; do
  cat > "$STUB_DIR/$cmd" <<EOF
#!/bin/bash
for a in "\$@"; do [ -f "\$a" ] && cp "\$a" "$OUT/spoken.txt"; done
echo $cmd > "$OUT/engine"
EOF
  chmod +x "$STUB_DIR/$cmd"
done
export PATH="$STUB_DIR:$PATH"
# Point Kokoro at files that do not exist, so the fallback voice is used
export VOICE_MODE_PREF_FILE="$OUT/pref"
export VOICE_MODE_KOKORO_MODEL="$OUT/none.onnx" VOICE_MODE_KOKORO_VOICES="$OUT/none.bin"

PRE=0; [ -f /tmp/claude-voice-mode ] && PRE=1
check() { if eval "$2"; then echo "ok: $1"; else echo "FAIL: $1"; FAILURES=$((FAILURES+1)); fi; }
reset() { rm -f /tmp/claude-voice-mode "$OUT/spoken.txt" "$OUT/engine"; }

MSG=$'Done.\n```bash\nrm secret\n```\n| a | b |\n**Bye.**'
INPUT=$(jq -n --arg m "$MSG" '{last_assistant_message:$m}')

# Off: nothing is spoken and no rules are printed
reset
echo "$INPUT" | "$ROOT/hooks/voice-tts.sh" > "$OUT/hook.out"; sleep 0.3
check "off: nothing spoken"        "[ ! -f $OUT/spoken.txt ]"
check "off: no hook output"        "[ ! -s $OUT/hook.out ]"
check "off: no rules"              "[ -z \"\$($ROOT/hooks/voice-rules.sh)\" ]"

# On, Kokoro files missing: the fallback voice speaks, code and tables dropped
touch /tmp/claude-voice-mode
echo "$INPUT" | "$ROOT/hooks/voice-tts.sh" > "$OUT/hook.out"; sleep 0.5
check "on: fallback voice used"    "[ \"\$(cat $OUT/engine 2>/dev/null)\" = say ]"
check "on: no hook output"         "[ ! -s $OUT/hook.out ]"
check "on: code not spoken"        "! grep -q secret $OUT/spoken.txt"
check "on: table not spoken"       "! grep -q '| a' $OUT/spoken.txt"
check "on: stand-in line spoken"   "grep -q 'on your screen' $OUT/spoken.txt"
check "on: text kept, stars gone"  "grep -q '^Bye\\.\$' $OUT/spoken.txt && grep -q 'Done\\.' $OUT/spoken.txt"
check "on: rules printed"          "$ROOT/hooks/voice-rules.sh | grep -q 'VOICE MODE IS ON'"

# On, Kokoro files present: Kokoro is used
touch "$OUT/none.onnx" "$OUT/none.bin"; rm -f "$OUT/engine"
echo "$INPUT" | "$ROOT/hooks/voice-tts.sh" > /dev/null; sleep 0.5
check "on: kokoro used when set up" "[ \"\$(cat $OUT/engine 2>/dev/null)\" = kokoro-tts ]"

# Engine "custom": your own command gets the text file
rm -f "$OUT/engine" "$OUT/custom.txt"
echo "$INPUT" | VOICE_MODE_ENGINE=custom VOICE_MODE_TTS_COMMAND="cp \"\$1\" $OUT/custom.txt" "$ROOT/hooks/voice-tts.sh" > /dev/null; sleep 0.5
check "custom: command got the text" "grep -q 'Done\\.' $OUT/custom.txt"

# Engine "tiny-voca": runs its Python module, then plays the sound file
mkdir -p "$OUT/tv/weights"; touch "$OUT/tv/weights/tiny-voca.pt"
printf '#!/bin/bash\necho "$@" > %s/tv-args\n' "$OUT" > "$STUB_DIR/fakepy"
printf '#!/bin/bash\necho afplay > %s/engine\n' "$OUT" > "$STUB_DIR/afplay"
chmod +x "$STUB_DIR/fakepy" "$STUB_DIR/afplay"; rm -f "$OUT/engine"
echo "$INPUT" | VOICE_MODE_ENGINE=tiny-voca VOICE_MODE_TINY_VOCA_DIR="$OUT/tv" VOICE_MODE_TINY_VOCA_PYTHON=fakepy "$ROOT/hooks/voice-tts.sh" > /dev/null; sleep 0.5
check "tiny-voca: model called"    "grep -q 'tiny_voca.infer.*--voice M2.*--text-file' $OUT/tv-args"
check "tiny-voca: sound played"    "[ \"\$(cat $OUT/engine 2>/dev/null)\" = afplay ]"

echo female > "$OUT/pref"
echo "$INPUT" | VOICE_MODE_ENGINE=tiny-voca VOICE_MODE_TINY_VOCA_DIR="$OUT/tv" VOICE_MODE_TINY_VOCA_PYTHON=fakepy "$ROOT/hooks/voice-tts.sh" > /dev/null; sleep 0.5
check "female preference: F2 used"  "grep -q -- '--voice F2' $OUT/tv-args"
rm -f "$OUT/pref"

# Engine chosen but not set up: falls back to the built-in voice
rm -f "$OUT/engine"
echo "$INPUT" | VOICE_MODE_ENGINE=tiny-voca "$ROOT/hooks/voice-tts.sh" > /dev/null; sleep 0.5
check "tiny-voca missing: say used" "[ \"\$(cat $OUT/engine 2>/dev/null)\" = say ]"

# Stop script is safe and clears its files
"$ROOT/hooks/voice-stop.sh"; "$ROOT/bin/hush"
check "stop: pid file cleared"     "[ ! -f /tmp/claude-voice-tts.pid ]"

reset; rm -rf "$STUB_DIR" "$OUT"
[ $PRE -eq 1 ] && touch /tmp/claude-voice-mode
echo; [ $FAILURES -eq 0 ] && echo "ALL PASS" || echo "$FAILURES FAILURES"
exit $FAILURES
