# Cross-app integration approaches (macOS)

The core problem has two halves:
1. **Get the selected text** from whatever app is focused.
2. **Hand it to a speaker process** that outlives the trigger, can be stopped, and doesn't block the UI.

Half 2 is solved once in `bin/speak-selection`, so every front-end below is a thin shim.

| Approach | Effort | Trigger | Gets the selection via | Clipboard safe? | Gaps |
|---|---|---|---|---|---|
| **Services / Quick Action** | none (Automator) | **right-click → Services → "Speak with Phonon"**, optional hotkey | NSServices (text passed on stdin) | ✅ | Apps without NSServices support (some Electron apps, some terminals) don't show it |
| **Alfred 5/6 workflow** ✅ built | low | hotkey (*Selection in macOS*), Universal Action, `speak` / `voice` / `shh` keywords | Alfred (simulated ⌘C, then restores the clipboard) | ≈ ✅ | Needs the Powerpack |
| Hammerspoon | low | any hotkey | `hs.uielement` AX selection or ⌘C | AX ✅ / ⌘C ❌ | One more daemon to run |
| PopClip extension | low | floating bar on select | PopClip | ✅ | Paid app; one more tool to install |
| Native Swift menu-bar app | high | anything | AX `kAXSelectedTextAttribute`, ⌘C fallback | ✅ | Most work. Best UX: overlay, pause and seek, voice menu |
| Fork SelectTTS | medium | hotkey | AX | ✅ | Must patch for wav/pcm, no `speed`, 4 KB chunks |

## Recommendation
- **Now:** **Alfred hotkey as the main trigger, plus the Services item in the right-click menu.** Both call the same script, share the same saved voice, and stop each other. Alfred covers almost every app because it uses ⌘C. The right-click item gives a mouse-only path that doesn't touch the clipboard.
- **Later:** if the tool sticks, build a Swift menu-bar app, or fork SelectTTS for its Accessibility-API selection and playback UI. Do it only after a couple of weeks of real use show which features you actually miss. Building it now would be guessing.

## Assumptions to check
- That the ~1 s gap at chunk boundaries isn't annoying in practice. If it is, replace `afplay` with one persistent player fed a continuous PCM stream (a Swift `AVAudioEngine` helper, or `ffplay -f s16le -ar 24000 -ac 1 -`).
- That the CLI's sentence splitting doesn't do better prosody than our paragraph chunks. A/B it on the same text.
