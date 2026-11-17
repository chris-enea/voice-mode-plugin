#!/bin/bash
# Stops voice playback that is still running. Safe to run at any time.
# Used by: the `hush` command, the UserPromptSubmit hook, and voice-tts.sh
# (which calls it before it starts a new message).

PIDFILE=/tmp/claude-voice-tts.pid
TMPREF=/tmp/claude-voice-tts.tmpfile

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null)
  rm -f "$PIDFILE"
  if [ -n "$PID" ]; then
    # The job runs in its own process group, so kill the group first.
    # This gets the speech program and any audio player it started.
    kill -TERM -"$PID" 2>/dev/null || kill -TERM "$PID" 2>/dev/null
    pkill -TERM -P "$PID" 2>/dev/null
  fi
fi

# Remove the text file that the killed job could not clean up itself.
if [ -f "$TMPREF" ]; then
  TMPFILE=$(cat "$TMPREF" 2>/dev/null)
  rm -f "$TMPREF"
  case "$TMPFILE" in
    /tmp/claude-voice-msg-*) rm -f "$TMPFILE" "$TMPFILE.wav" ;;
  esac
fi

exit 0
