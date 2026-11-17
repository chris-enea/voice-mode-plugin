#!/bin/bash
# UserPromptSubmit hook: while voice mode is on, print the voice rules so
# Claude sees them on every prompt. Plain stdout from this hook is added to
# Claude's context. skills/voice-mode/rules.md is the only copy of the rules.

[ -f /tmp/claude-voice-mode ] || exit 0
cat "$(dirname "$0")/../skills/voice-mode/rules.md"
