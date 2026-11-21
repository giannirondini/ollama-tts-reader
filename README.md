# ollama-tts-reader

Select text in **any macOS app** → hear it read by **Ollama's local Phonon TTS** in the voice you chose. Hard line wraps (PDFs, emails, terminals) are joined first, so sentences flow naturally. Everything runs locally.

Inspired by [Ollama: speech models](https://ollama.com/blog/speech-models).

## Requirements

| What | Version |
|---|---|
| macOS | any recent version (uses only built-in zsh, perl, curl, jq, afplay, osascript) |
| [Ollama](https://ollama.com) | ≥ 0.40.9, with `ollama pull phonon` |
| [Alfred](https://www.alfredapp.com) + Powerpack | 5 or 6, only for the Alfred front-end |

No pip or brew installs.

## Install

**Alfred:** download `Speak-with-Phonon-<version>.alfredworkflow` from [Releases](https://github.com/giannirondini/ollama-tts-reader/releases), double-click it, then set the hotkey. Details: [alfred/README.md](alfred/README.md).

**CLI and right-click Services:** clone the repo and point the front-ends at its `bin/`:
```bash
git clone https://github.com/giannirondini/ollama-tts-reader.git
cd ollama-tts-reader
ollama pull phonon
bin/speak-selection "Hello from Phonon."
```

## Usage
```bash
bin/speak-selection "Hello from Phonon."          # text as argument
pbpaste | bin/speak-selection -v Hadley           # stdin, explicit voice
bin/speak-selection                               # no input => reads the clipboard
bin/speak-selection -n < some.txt                 # dry run: show cleaned chunks
bin/speak-selection -s Freya                      # save default voice
bin/speak-stop                                    # stop
```
Front-ends (pick one or both):
- **Alfred 5/6** (hotkey, Universal Action, `speak` / `voice` / `shh`): [alfred/README.md](alfred/README.md)
- **Right-click → Services → Speak with Phonon**: [macos/README-quick-action.md](macos/README-quick-action.md)

## How it works
```
selection ─► unwrap-text ─► chunk-text ─► [detached worker, own session]
                                            for each chunk:
                                              POST /v1/audio/speech (wav) ─► afplay -r RATE
                                              (chunk N+1 synthesizes while N plays)
```
- The first chunk is one sentence, so speech starts almost immediately. Later chunks are whole paragraphs of ≤ 3,500 chars (API cap: 4,096).
- The HTTP API is used rather than `ollama run` because the CLI writes WAV instead of playing when stdout isn't a TTY, which is the case under Automator and Alfred.
- If Ollama is down (local URL only), it launches Ollama.app hidden (`open -gj`, so no chat window pops over your text; falls back to `ollama serve`) and waits up to `$PHONON_START_TIMEOUT` s (default 10). If Ollama still isn't up, it says so out loud as well as in a notification, because `osascript` notifications are often hidden.
- Calling it again stops the current reading; `-t` toggles. State lives in `~/Library/Caches/phonon-reader/`, and the voice and rate settings in `~/.config/phonon-reader/`.

## Folder map
| Path | What |
|---|---|
| `bin/` | `speak-selection`, `speak-stop`, `unwrap-text`, `chunk-text`, `phonon-voices` |
| `alfred/` | workflow source (`info.plist`), `build.sh` (local build into `dist/`), `release.sh` |
| `macos/` | Services / Quick Action and Hammerspoon setup |
| `docs/DISTRIBUTION.md` | versioning and the GitHub release process |
| `research/ollama-phonon.md` | API facts, **verified limits** (no mp3, speed = 1 only, 4096-char cap), voices |
| `research/existing-tools.md` | prior art: SelectTTS, Narrateify, aloud-tts, Alfred/Raycast/PopClip options |
| `ideas/integration-approaches.md` | trigger options compared, with a recommendation |
| `ideas/text-cleanup.md` | unwrap and chunking rules, known limitations |
| `ideas/roadmap.md` | v0.2 polish → v1 native app |

## License

[MIT](LICENSE). The Phonon model is a separate download with its own license: `phonon` (English) is Apache-2.0, while the multilingual `phonon:40m-*` variants are **non-commercial** (see [research/ollama-phonon.md](research/ollama-phonon.md)).
