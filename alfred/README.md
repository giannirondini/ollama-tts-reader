# Alfred workflow: Speak with Phonon

Works with Alfred 5 and 6 (Powerpack required). Summarize uses a Text View, which needs Alfred 5.5 or later.

## Install
Download `Speak-with-Phonon-<version>.alfredworkflow` from [Releases](https://github.com/giannirondini/ollama-tts-reader/releases) and double-click it. Or build it from source:
```bash
alfred/build.sh                      # lints info.plist, bundles ../bin into the workflow
open alfred/dist/Speak-with-Phonon.alfredworkflow
```
The workflow is **self-contained**: it carries its own copy of `bin/`, because Alfred stores workflows in its own preferences folder, not in this repo. **Re-run `build.sh` and re-import after changing anything in `bin/`.** Publishing a release: [docs/DISTRIBUTION.md](../docs/DISTRIBUTION.md).

After importing, open the workflow, double-click the **Hotkey** triggers, and record a key for each (e.g. ⌃⌥S to speak, ⌃⌥⇧S to summarize). **Check that *Argument* shows "Selection in macOS" and set it if not.** If it's wrong, the hotkey silently receives no text.

## What's inside
| Trigger | Does |
|---|---|
| **Hotkey** (Selection in macOS) | reads the selection; **press again to stop** (`speak-selection -t`) |
| **Universal Action** "Speak with Phonon" | on any text: selection, clipboard history, Alfred results |
| `speak <text>` | reads what you type |
| `voice` | lists Phonon voices (✓ marks the current one). ↩ saves the voice as default and confirms it out loud · **⌘↩ previews** it |
| `shh` | stops playback |
| **Hotkey** (Selection in macOS) · Universal Action **"Summarize with Gemma"** · `sum [text]` | summarizes the selection / text (`sum` alone: the clipboard) in a **Text View**. Needs `ollama pull gemma4:e2b-mlx` |

In the summary view, type a command and press ↩ (the footer lists them):

| Command | Does |
|---|---|
| `read` (`r`) | reads the summary aloud, in English: a non-English summary is translated first, the view keeps the original |
| `full` (`f`) | reads the original text (English sources only; Phonon is English-only) |
| `stop` (`s`) | stops the reading |
| `copy` (`c`) | copies the summary as Markdown |
| **⌘↩** | copies the summary and closes the view (a reading keeps going; `shh` stops it) |

"🔊 Reading…" in the footer updates on your next ↩: the view doesn't refresh itself, because Alfred would disable the input field (and `stop`) while it does.

The voice is stored in `~/.config/phonon-reader/voice`, shared with the right-click Services item and the CLI. Speed: `echo 1.15 > ~/.config/phonon-reader/rate` (applied by afplay, since the API only allows speed 1).

## If the import fails or looks wrong
`info.plist` is written by hand (Alfred 5 schema, Text View keys taken from Alfred's own openai-workflow) and imports cleanly on Alfred 6.0.2. If an object comes in broken, rebuild it in Alfred's editor. Each object is tiny, and every Run Script uses **Language: /bin/bash**, *with input as argv*:

| Object | Settings | Script |
|---|---|---|
| Hotkey → Run Script | Argument: Selection in macOS | `printf '%s' "$1" \| ./bin/speak-selection -t` |
| Universal Action (Text) → Run Script | name "Speak with Phonon" | `printf '%s' "$1" \| ./bin/speak-selection` |
| Keyword `speak` (argument required) → same Run Script | | |
| Script Filter `voice` (argument optional, Alfred filters results) | | `./bin/phonon-voices --alfred` |
| → Run Script (↩) | | `./bin/speak-selection -s "$1" && ./bin/speak-selection -v "$1" "Voice set to $1."` |
| → Run Script (⌘ modifier) | | `./bin/speak-selection -v "$1" "Hi, I am $1."` |
| Keyword `shh` (no argument) → Run Script | | `./bin/speak-stop; exit 0` |
| Hotkey (Selection in macOS) · Universal Action (Text, "Summarize with Gemma") · Keyword `sum` (argument optional) → Arg and Vars | Argument: *empty*; variable `sum_source` = `{query}` | |
| → Text View | Source: **Script file** `bin/summarize-alfred`, with input field; Markdown output; Loading Text "Summarizing… (the first summary also loads the model)" | |
| → Run Script (⌘ modifier, from the Text View) | | `[ -n "$sum_md" ] && printf %s "$sum_md" \| pbcopy; exit 0` |

Then copy this repo's `bin/` folder into the workflow folder (right-click the workflow → *Open in Finder*).
