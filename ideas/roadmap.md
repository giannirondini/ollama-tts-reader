# Roadmap

## v0.1: prototype ✅ (this folder)
- `bin/speak-selection`: cleanup → chunk → synthesize ahead → `afplay`, detached, with toggle/stop/restart, voice and rate settings, error notifications.
- Alfred 5/6 workflow (`alfred/`, published on GitHub Releases).
- Right-click Services menu (manual Automator setup, `macos/README-quick-action.md`).

## v0.2: polish once you've used it for a while
- [ ] **Warm-up:** `curl …/v1/audio/speech -d '{"model":"phonon","input":"."}' -o /dev/null` at login (launchd), or set `OLLAMA_KEEP_ALIVE` so the first read doesn't pay the 2.4 s cold start.
- [ ] **Language auto-pick:** detect FR/DE/ES/PT and switch to `phonon:40m-*` (non-commercial license). Italian isn't covered yet.
- [ ] **Rate in Alfred:** a `rate` keyword (Script Filter with 0.9 / 1.0 / 1.15 / 1.3).
- [ ] **Pause/resume:** `kill -STOP` / `-CONT` on the worker and afplay. Cheap, and good enough.
- [ ] **Read-later:** a `-o file.wav` export, i.e. "turn this article into audio".

## v1: native app (only if v0.x proves itself)
- Swift menu-bar app, or a SelectTTS fork:
  - selection via the Accessibility API (no clipboard), ⌘C fallback
  - one `AVAudioEngine` player fed continuous PCM → no gaps between chunks, and real pause and seek
  - small overlay: current sentence highlighted, speed slider, voice menu
- Distribution: needs signing and notarization, plus the Accessibility permission prompt.

## Open questions
- Does sentence-level chunking (like the CLI) sound better than paragraph chunks? A/B it.
- Can Phonon handle SSML-like hints or pauses? Nothing in the docs so far.
- Whether to support Linux/Windows once Ollama ships speech there. The shell core is macOS-specific (afplay, osascript).
