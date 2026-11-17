# Voice mode for Claude Code

Talk to Claude Code hands-free. When voice mode is on, Claude answers in short spoken sentences and your Mac reads each reply aloud.

## What you get

- **One command to toggle.** `/voice-mode:voice-mode` turns it on and off.
- **Rules written for the ear.** Numbers and dates as a person says them, no file paths read aloud, one question at a time, failures first.
- **Code stays on screen.** Code blocks, tables and paths are shown but not spoken. The voice says "The details are on your screen" instead.
- **Short by default, long on request.** Up to seven sentences normally. Say "expand" or "more detail" for up to twenty.
- **Rules that do not fade.** They are sent to Claude on every prompt, so long sessions stay in voice style.

## Requirements

- macOS
- `jq` (`brew install jq`)
- Claude Code with plugin support
- Optional: a better voice engine (Kokoro, tiny-voca or your own). Without one, the built-in macOS voice is used, and nothing else needs setup.

## Install

In Claude Code:

```
/plugin marketplace add chris-enea/voice-mode-plugin
/plugin install voice-mode@voice-mode-plugin
```

Restart Claude Code, then run `/voice-mode:voice-mode`. Claude confirms aloud that voice mode is on.

No GitHub access? Get the folder another way (zip, AirDrop), then use its path instead:

```
/plugin marketplace add /path/to/voice-mode-plugin
/plugin install voice-mode@voice-mode-plugin
```

## Use it

1. Run `/voice-mode:voice-mode`. Claude says voice mode is on.
2. Talk or type as usual. Each reply is spoken when Claude finishes.
3. Say "expand" or "more detail" when you want a longer answer.
4. Run `/voice-mode:voice-mode` again to turn it off.

Pair it with a dictation tool (macOS Dictation, or Claude Code's own voice input) for a full hands-free loop.

## Male or female voice

The first time you turn voice mode on, Claude asks if you prefer a male or a female voice. Male is the default. To change it later, just say "switch to the female voice" (or male). The choice is saved in `~/.config/voice-mode/voice`.

With Kokoro, male is George (British) and female is Heart (American). With tiny-voca, they are M2 and F2. The built-in Mac voice ignores this choice; set `VOICE_MODE_SAY_VOICE` instead.

## Stop the voice mid-sentence

- Send any new prompt, or
- type `!hush` in the prompt.

## Choose a voice engine

Voice mode works with four engines. Set `VOICE_MODE_ENGINE` in your shell profile to pick one. If the chosen engine is not set up, the built-in Mac voice is used.

| Engine | `VOICE_MODE_ENGINE` | Good for | Setup |
|--------|---------------------|----------|-------|
| Built-in Mac voice | `say` | Zero setup | None |
| [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) | `kokoro` | Most natural local voice; starts speaking while it works | Install `kokoro-tts` and two model files |
| [tiny-voca](https://github.com/n4ze3m/tiny-voca) | `tiny-voca` | Very small (18 MB) and fast; two voices | Clone the project and download its weights |
| Your own command | `custom` | Any other engine, local or cloud | One command |

The default, `auto`, uses Kokoro when it is set up and the Mac voice otherwise.

### Kokoro

Install the `kokoro-tts` command (for example `uv tool install kokoro-tts`), download its two model files from the Kokoro project, then put them here:

```
~/.local/share/kokoro-tts/kokoro-v1.0.onnx
~/.local/share/kokoro-tts/voices-v1.0.bin
```

### tiny-voca

Follow the install steps in the tiny-voca README (clone, `pip install`, download weights into `weights/`). Then:

```
export VOICE_MODE_ENGINE=tiny-voca
export VOICE_MODE_TINY_VOCA_DIR=/path/to/tiny-voca
export VOICE_MODE_TINY_VOCA_PYTHON=/path/to/tiny-voca/.venv/bin/python
```

tiny-voca makes the whole sound file before it plays, so a long reply starts a moment later than with Kokoro.

### Your own command

The command gets the path of a text file as `$1` and must speak it:

```
export VOICE_MODE_ENGINE=custom
export VOICE_MODE_TTS_COMMAND='my-tts --input "$1" --play'
```

### All settings

| Variable | Meaning | Default |
|----------|---------|---------|
| `VOICE_MODE_ENGINE` | `auto`, `kokoro`, `tiny-voca`, `say` or `custom` | `auto` |
| `VOICE_MODE_KOKORO_MODEL` | Path to the Kokoro model file | the path above |
| `VOICE_MODE_KOKORO_VOICES` | Path to the Kokoro voices file | the path above |
| `VOICE_MODE_KOKORO_VOICE` | Kokoro voice name; overrides the male/female choice | `bm_george` (male), `af_heart` (female) |
| `VOICE_MODE_TINY_VOCA_DIR` | Folder of the tiny-voca clone | none |
| `VOICE_MODE_TINY_VOCA_PYTHON` | Python that has tiny-voca installed | `python3` |
| `VOICE_MODE_TINY_VOCA_VOICE` | `M2` or `F2`; overrides the male/female choice | `M2` (male), `F2` (female) |
| `VOICE_MODE_TTS_COMMAND` | Command for the `custom` engine | none |
| `VOICE_MODE_SAY_VOICE` | macOS voice name | system voice |

## Change how Claude speaks

Edit `skills/voice-mode/rules.md`. It is the only copy of the rules.

## How it works

| File | Function |
|------|----------|
| `skills/voice-mode/SKILL.md` | The toggle. Creates or removes the flag file `/tmp/claude-voice-mode`. |
| `skills/voice-mode/rules.md` | The speaking rules. |
| `hooks/voice-rules.sh` | Runs on every prompt. Sends the rules to Claude while the flag exists. |
| `hooks/voice-tts.sh` | Runs when Claude finishes. Removes code and tables, then speaks the rest. |
| `hooks/voice-stop.sh` | Stops speech. Runs on every prompt and before each new reply. |
| `bin/hush` | One-word wrapper for the stop script. |

The flag file is machine-wide: voice mode is on for every Claude Code session on the Mac until you toggle it off.

## Troubleshooting

| Problem | Check |
|---------|-------|
| No sound at all | Run the toggle again and confirm it says "on". Check that `jq` is installed. Restart Claude Code after install so the hooks load. |
| Built-in voice instead of the engine you chose | The engine is not fully set up. Check its command, folder and model files in "Choose a voice engine". |
| `!hush` is not found | Send any prompt instead; that also stops the voice. |
| Claude reads formatting or long answers | Open `skills/voice-mode/rules.md` and tighten the rule. |
| Voice is on in another session | Expected. The flag is machine-wide. Toggle it off. |

## Limits

- macOS only.
- Only the final message of a turn is spoken, not progress notes.
- Speech starts when Claude finishes the turn, not while it writes.

## Test

```
bash tests/voice.test.sh
```

## License

MIT. See `LICENSE`.
