---
name: voice-mode
description: Toggle voice mode on/off. When on, Claude answers in short spoken sentences and the final message of each turn is read aloud.
user-invocable: true
---

# Voice mode — toggle spoken replies

Run this command to toggle the mode:

```bash
if [ -f /tmp/claude-voice-mode ]; then
  rm /tmp/claude-voice-mode
  echo "off"
else
  touch /tmp/claude-voice-mode
  echo "on"
  echo "voice: $(cat ~/.config/voice-mode/voice 2>/dev/null || echo unset)"
fi
```

**If the result is "on":** read `rules.md` in this skill's folder now, and follow those rules for every reply until voice mode goes off. A hook prints the same rules again on each prompt. Then reply with three sentences:

1. Voice mode is on.
2. To cut the voice off, type `!hush` or send any new prompt.
3. Answers stay short by default; say "expand" or "more detail" for a longer answer of up to twenty sentences.

**If the result is "off":** confirm that voice mode is off. Go back to normal written formatting.

## Voice choice

The toggle prints `voice: male`, `voice: female` or `voice: unset`. Male is the default.

- If it prints `voice: unset`, end your reply by asking: "Do you prefer a male or a female voice?" Save the answer with the command below.
- If the user asks to change the voice at any time, save the new choice the same way. The next reply uses it.

```bash
mkdir -p ~/.config/voice-mode && echo female > ~/.config/voice-mode/voice   # or: echo male
```

To change how Claude speaks, edit `rules.md`. It is the only copy of the rules.
