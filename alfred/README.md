# Alfred workflow: Speak with Phonon

Works with Alfred 5 and 6 (Powerpack required).

## Install
Download `Speak-with-Phonon-<version>.alfredworkflow` from [Releases](https://github.com/giannirondini/ollama-tts-reader/releases) and double-click it. Or build it from source:
```bash
alfred/build.sh                      # lints info.plist, bundles ../bin into the workflow
open alfred/dist/Speak-with-Phonon.alfredworkflow
```
The workflow is **self-contained**: it carries its own copy of `bin/`, because Alfred stores workflows in its own preferences folder, not in this repo. **Re-run `build.sh` and re-import after changing anything in `bin/`.** Publishing a release: [docs/DISTRIBUTION.md](../docs/DISTRIBUTION.md).

After importing, open the workflow, double-click the **Hotkey** trigger, and record a key (e.g. ⌃⌥S). **Check that *Argument* shows "Selection in macOS" and set it if not.** If it's wrong, the hotkey silently receives no text.

## What's inside
| Trigger | Does |
|---|---|
| **Hotkey** (Selection in macOS) | reads the selection; **press again to stop** (`speak-selection -t`) |
| **Universal Action** "Speak with Phonon" | on any text: selection, clipboard history, Alfred results |
| `speak <text>` | reads what you type |
| `voice` | lists Phonon voices (✓ marks the current one). ↩ saves the voice as default and confirms it out loud · **⌘↩ previews** it |
| `shh` | stops playback |

The voice is stored in `~/.config/phonon-reader/voice`, shared with the right-click Services item and the CLI. Speed: `echo 1.15 > ~/.config/phonon-reader/rate` (applied by afplay, since the API only allows speed 1).

## If the import fails or looks wrong
`info.plist` was written by hand from Alfred 5's schema and works on Alfred 5 and 6 as an installed workflow; a clean import of this plist on Alfred 6 is still untested. If an object comes in broken, rebuild it in Alfred's editor. Each object is tiny, and every Run Script uses **Language: /bin/bash**, *with input as argv*:

| Object | Settings | Script |
|---|---|---|
| Hotkey → Run Script | Argument: Selection in macOS | `printf '%s' "$1" \| ./bin/speak-selection -t` |
| Universal Action (Text) → Run Script | name "Speak with Phonon" | `printf '%s' "$1" \| ./bin/speak-selection` |
| Keyword `speak` (argument required) → same Run Script | | |
| Script Filter `voice` (argument optional, Alfred filters results) | | `./bin/phonon-voices --alfred` |
| → Run Script (↩) | | `./bin/speak-selection -s "$1" && ./bin/speak-selection -v "$1" "Voice set to $1."` |
| → Run Script (⌘ modifier) | | `./bin/speak-selection -v "$1" "Hi, I am $1."` |
| Keyword `shh` (no argument) → Run Script | | `./bin/speak-stop; exit 0` |

Then copy this repo's `bin/` folder into the workflow folder (right-click the workflow → *Open in Finder*).
