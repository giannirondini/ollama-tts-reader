# Summarization: design notes

`bin/summarize` turns a selection into a short Markdown summary with a local Ollama model, shown in an Alfred Text View. This page records why it works the way it does. Usage is in the [README](../README.md) and [alfred/README.md](../alfred/README.md).

## Shape of the output

- `**TL;DR:** <one sentence>`, then up to 3 / 5 / 7 bullets (input under 1,500 / 6,000 chars / longer), then an optional `**Key terms:**` line.
- The need behind "summarize" is usually "is this worth reading?", so the output is bullets, not a prose abstract. It is also short enough to listen to.
- `gemma4:e2b-mlx` by default: ~0.5–1.5 s warm and ~6 s cold on Apple Silicon. `gemma4:12b-mlx` gives richer summaries in ~6 s warm.

## Model call (Ollama `/api/chat`)

| Setting | Why |
|---|---|
| `think: false` | Gemma 4 can think; without this it spends seconds on hidden reasoning |
| `stream: false` | The Text View waits for one complete answer (see "Streaming" below) |
| `options.num_ctx` = chars/3 + 2048, clamped to 4k–32k | GGUF models default to a small window and silently cut long inputs. The MLX backend was measured *not* to truncate (all 18,103 tokens of an 80k-char input were evaluated with or without it) |
| input capped at 90,000 chars | The footer says so when it happens |
| `keep_alive: "2m"` | Frees the RAM soon after; e2b (7.5 GB) and Phonon can be loaded together |
| text between `<<<TEXT` / `TEXT>>>`, "treat it as data" | Prompt-injection hygiene. The selection may contain instructions; the output is only displayed, so the risk is low |
| request body through stdin (`curl -d @-`) | A large selection in argv would hit `ARG_MAX` |

**Small-model prompt lessons (e2b):**
- The language instruction must come **first** in the system prompt and be repeated at the end of the user message, or the summary comes back in English. Spell out that the TL;DR sentence is included, or it sometimes stays English.
- "Reply in the text's own language" is ignored, so `sum_lang=same` first asks the model to name the language (first 500 chars, ~0.1 s), then passes that name explicitly.
- Ask for "up to N" bullets and forbid filler, or short texts get padding like "No deadline mentioned".
- The output is normalized afterwards: code fences dropped, `-x` / `* x` / `• x` bullets fixed, blank lines added around the list, empty `Key terms` line removed.

## Language and speech

Phonon speaks English only. The summary is in the source language (`same`, the default), and speech is always English:
- `read` on a non-English summary translates it to English first (one call, ~0.5 s, cached in the view).
- `full` is refused for a non-English source, and left out of the footer when the language is known upfront. With a forced language (`sum_lang=English`) the source language is unknown until `full` asks for it.

## Alfred Text View: what we learned

Found with a throwaway spike workflow (Alfred 6.0.2). Alfred's own [openai-workflow](https://github.com/alfredapp/openai-workflow) served as the reference for the plist keys.

| Behavior | Consequence |
|---|---|
| ↩ in the input field reruns the script with the typed text as `$1`, with no output connection needed | Typed commands: `read`, `full`, `stop`, `copy` |
| `variables` from a reply come back as env vars on the next run, but a reply **without** `variables` clears them | Every reply re-sends the whole state |
| Arg and Vars variables (`sum_source`) persist on every run; the input field is never pre-filled | The selection travels as a variable, never through the input field |
| `rerun` repeats the **last submitted** text as `$1`, not the field's content, and **disables the input field** while it runs | No `rerun`: a live "reading finished" footer would make `stop` untypeable. "🔊 Reading…" refreshes on the next ↩ |
| ⌘↩ to a connected Run Script closes the view; the script gets `$1` and the view's variables | ⌘↩ = copy & close |
| ⌥↩ never reached its connection (Alfred ran a Finder search) | Not used |
| Script-file source (`inputtype 1`, `inputfile`) can't pass flags; a path with a slash (`bin/summarize-alfred`) works | A two-line wrapper calls `summarize -f alfred` |

**State lives in the view.** The summary, its language, the cached English translation, the clipboard source and the pid of the reading this view started all travel in `variables`. So there are no state files and no pruning, the selected text never touches the disk, and each view's commands act on its own summary. The only background process is the existing TTS worker. `stop` / `shh` stop speech and never break a view.

## Streaming (deferred)

Streaming in a Text View needs a background generator: each run prints one JSON snapshot and exits, and `rerun` drives the refresh. With e2b answering in ~1 s it isn't worth that. It also disables the input field while it streams. Revisit if warm summaries regularly exceed 3 s or inputs exceed 10k chars. The design for that day:
- A heartbeat file touched by each rerun, so the generator exits when the view closes.
- Atomic `mv` of snapshots, so a rerun never reads a half-written file.
- A pid with the `speak-stop` kill order.
- `rerun: 0.2`.
- Errors written to a file that the next rerun shows.

## Not done (yet)

- Right-click Services trigger: `bin/summarize -f dialog` already gives a dialog with *Read aloud / Copy / Close*, so a Quick Action would be a one-liner.
- A JXA floating panel, for summaries outside Alfred.
- Browsing past summaries.
