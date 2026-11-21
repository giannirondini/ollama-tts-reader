# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

macOS-only "select text → hear it" reader backed by Ollama's local Phonon TTS (`/v1/audio/speech`). It can also summarize the selection with a local Gemma model (`/api/chat`) in an Alfred Text View. Pure shell: zsh + perl + curl + jq + afplay + osascript. **No pip/brew dependencies — keep it that way.** Requires Ollama ≥ 0.40.9 and `ollama pull phonon`.

## Commands

There is no build system, linter, or test suite. Verify changes like this:

```bash
pbpaste | bin/speak-selection -n          # dry run: print cleaned chunks separated by ---
bin/unwrap-text < sample.txt              # test unwrap rules in isolation
bin/unwrap-text < sample.txt | bin/chunk-text 200 | tr '\0' '\n'   # chunking with a small MAX
bin/speak-selection "Hello."              # real playback (needs Ollama running)
bin/speak-stop                            # exit 0 = stopped something, 1 = nothing playing
tail ~/Library/Caches/phonon-reader/log   # worker stderr
bin/summarize < sample.txt                # Markdown summary (needs gemma4:e2b-mlx); -f text|dialog|alfred
sum_source="…" bin/summarize-alfred ""    # first Text View run: JSON with response/footer/variables
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
- `bin/lib/common.zsh` holds `URL`, `STATE`, `CONFIG`, `notify`, `read_setting`, `ensure_ollama`, sourced by `speak-selection` and `summarize` (`NOTIFY_TITLE` sets the notification title). `build.sh` bundles `bin/lib/` and `release.sh` drift-checks it.

### Summarizer (`bin/summarize`, design notes in `ideas/summarization.md`)

- **Blocking, no background process of its own:** one `/api/chat` call (`stream:false`, `think:false` is mandatory for Gemma 4, `num_ctx` sized from the input, body via stdin). It sits outside the single-reader invariant: `read`/`full` just pipe text into `speak-selection`, and `stop` is `speak-stop`.
- **Alfred Text View protocol** (`-f alfred`, via `bin/summarize-alfred` because a Script-file source can't pass flags): run 1 has no `sum_md` and summarizes `$sum_source` (clipboard if empty); later runs get the typed text as `$1` and treat it as a command. **All state travels in the reply's `variables` and must be re-sent on every reply** (omitting them clears them). Never add `rerun`: Alfred then repeats the last *submitted* text as `$1` and disables the input field, so `stop` becomes untypeable.
- **Language:** the summary is in the source language (`sum_lang=same`, default: a short detection call first, because e2b ignores "reply in the text's language"); speech is English only, so `read` translates a non-English summary (cached in `sum_md_en`) and `full` refuses a non-English source. With e2b, the language instruction must come first in the system prompt.
- Settings `PHONON_SUM_MODEL` / `sum_model` (default `gemma4:e2b-mlx`), `PHONON_SUM_LANG` / `sum_lang` (default `same`), same chain as voice/rate.

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
- `info.plist` is hand-written (Alfred 5 schema; Text View keys copied from Alfred's own openai-workflow, never guessed) and imports cleanly on Alfred 6.0.2. Check the Hotkeys' "Selection in macOS" argument after importing. Edit it as XML fragments (keep the comments and `<real>` coordinates): a `plutil` JSON round-trip drops both. `alfred/README.md` lists every object/script for manual reconstruction.
- The macOS Services / Quick Action (`macos/README-quick-action.md`) calls `bin/speak-selection` in place via an absolute path, so it does **not** need rebuilding.

## Docs map

- `ideas/text-cleanup.md` — unwrap and strip-markdown rules and accepted limitations (compound-word hyphens lost, code/tables flattened). Update it when changing `unwrap-text`/`chunk-text`/`strip-markdown`.
- `ideas/summarization.md` — summarizer design: model call settings, small-model prompt lessons, language rules, measured Alfred Text View behavior, deferred streaming.
- `ideas/roadmap.md` — planned v0.2 items (warm-up, pause/resume, rate keyword, wav export) and the v1 native-app direction.
- `research/` — API facts and prior art; treat as reference, not spec.
- `docs/DISTRIBUTION.md` — versioning and the GitHub release process.
- `docs/plans/` — local working notes, gitignored; never commit them.
