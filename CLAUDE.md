# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

macOS-only "select text → hear it" reader backed by Ollama's local Phonon TTS (`/v1/audio/speech`). Pure shell: zsh + perl + curl + jq + afplay + osascript. **No pip/brew dependencies — keep it that way.** Requires Ollama ≥ 0.40.9 and `ollama pull phonon`.

## Commands

There is no build system, linter, or test suite. Verify changes like this:

```bash
pbpaste | bin/speak-selection -n          # dry run: print cleaned chunks separated by ---
bin/unwrap-text < sample.txt              # test unwrap rules in isolation
bin/unwrap-text < sample.txt | bin/chunk-text 200 | tr '\0' '\n'   # chunking with a small MAX
bin/speak-selection "Hello."              # real playback (needs Ollama running)
bin/speak-stop                            # exit 0 = stopped something, 1 = nothing playing
tail ~/Library/Caches/phonon-reader/log   # worker stderr
alfred/build.sh                           # plutil -lint info.plist + bundle bin/ into dist/ (version from VERSION)
```

**Never run `alfred/release.sh`**: the user runs it, then the commands it writes to `.build/release/<version>/UPLOAD_INSTRUCTIONS.md`. Versioning and releases: `docs/DISTRIBUTION.md`.

## Architecture

Pipeline: `text → unwrap-text → chunk-text (NUL-separated) → detached worker → synth chunk i → afplay`, with chunk N+1 synthesized while N plays.

- **`bin/speak-selection` is both front-end and worker.** The front-end resolves text (args → stdin → clipboard), writes chunks to `~/Library/Caches/phonon-reader/run.XXXXXX/{0,1,…}.txt`, then re-execs *itself* with the internal `-W <rundir>` flag under `POSIX::setsid()` (via perl) so Alfred/Automator can't kill the player when they exit. The front-end blocks (≤ ~2 s) until the worker writes `$STATE/pid`, then returns.
- **Single-reader invariant:** `$STATE/pid` holds the active worker. Every new reading calls `speak-stop` first; `-t` (toggle) exits after stopping if something was playing. `speak-stop` does `kill -STOP` → `pkill -P` (children, i.e. afplay) → `kill -KILL`, then wipes `run.*`. Preserve that ordering, or the worker can spawn the next afplay mid-kill.
- **Chunking strategy is deliberate** (`bin/chunk-text`): chunk 1 = first sentence only (fast first audio); later chunks pack whole paragraphs up to 3,500 chars (API hard cap 4,096) so the ~1 s inter-chunk gap lands on paragraph breaks; oversized paragraphs fall back to sentence, then word splits.
- **Settings resolution** (voice/rate): flag → env (`PHONON_VOICE`, `PHONON_RATE`) → file in `${XDG_CONFIG_HOME:-~/.config}/phonon-reader/{voice,rate}` → default (`Zoey`, `1.0`). Also `PHONON_MODEL`, `PHONON_URL`, `PHONON_START_TIMEOUT` (seconds to wait after auto-launching Ollama, default 10). The config dir is shared by CLI, Alfred, and Services.
- **Errors surface via `osascript` notifications**, not stderr — callers (Alfred, Automator) have no visible terminal. Those notifications are often hidden, so a fatal "Ollama down" error also goes through `say`. The worker auto-launches Ollama (`ensure_ollama`, via `open -gj`: `-j` is what suppresses the chat window, `-g` alone does not) after writing its pid, so `speak-stop`/toggle can cancel the wait.
- `speak-selection` resets `PATH` to system dirs first because Alfred/Automator run with a bare environment; use absolute or system tools only.

## Phonon API constraints (verified; see `research/ollama-phonon.md`)

| Constraint | Consequence in code |
|---|---|
| Only `speed: 1` accepted (400 otherwise) | rate is applied by `afplay -r`, never sent to the API |
| Only `wav` / `pcm` (no mp3) | `response_format: "wav"` |
| `input` > 4096 chars → 400 | client-side chunking is mandatory |
| `ollama run` writes WAV instead of playing when stdout isn't a TTY | always use the HTTP API, not the CLI |
| Voices via `POST /api/show` → top-level `voices[]`; names case-insensitive | used by `bin/phonon-voices` |

## Alfred workflow gotchas

- The built workflow embeds a **copy** of `bin/` (Alfred stores workflows in its own prefs folder, not this repo). It is **not committed**: `alfred/dist/` and `.build/` are gitignored, and releases ship it as a GitHub Release asset. After any change to `bin/` or `alfred/info.plist`, re-run `alfred/build.sh` to test; `release.sh` refuses a stale build.
- `VERSION` is the single source of truth for the version; `build.sh` injects it into the *staged* `info.plist`, so don't edit the plist's `version` by hand. `bundleid` is `io.github.giannirondini.speak-with-phonon` — changing it makes Alfred treat a release as a new workflow.
- `info.plist` was hand-written from Alfred 5's schema; the installed workflow works on Alfred 5 and 6, but a clean import of this plist is still untested (check the Hotkey's "Selection in macOS" argument after importing). `alfred/README.md` lists every object/script for manual reconstruction.
- The macOS Services / Quick Action (`macos/README-quick-action.md`) calls `bin/speak-selection` in place via an absolute path, so it does **not** need rebuilding.

## Docs map

- `ideas/text-cleanup.md` — unwrap rules and accepted limitations (compound-word hyphens lost, code/tables flattened). Update it when changing `unwrap-text`/`chunk-text`.
- `ideas/roadmap.md` — planned v0.2 items (warm-up, pause/resume, rate keyword, wav export) and the v1 native-app direction.
- `research/` — API facts and prior art; treat as reference, not spec.
- `docs/DISTRIBUTION.md` — versioning and the GitHub release process.
- `docs/plans/` — local working notes, gitignored; never commit them.
