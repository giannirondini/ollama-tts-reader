# Right-click → "Speak with Phonon" (macOS Services)

Adds **Speak with Phonon** to the context menu of selected text in any app that supports Services (Safari, Mail, Notes, Preview, TextEdit, Pages, most native apps). The text is passed on stdin, so the **clipboard isn't touched**.

## Setup (≈ 2 minutes, Automator)
1. Open **Automator** → *New Document* → **Quick Action**.
2. At the top, set:
   - *Workflow receives current* **text** in **any application**
   - leave *Output replaces selected text* **unchecked**
   - *Image*: pick a speaker icon if you like (shown in the Touch Bar / Services menu)
3. Drag in **Run Shell Script** (from Library → Utilities) and set:
   - *Shell*: `/bin/zsh`
   - *Pass input*: **to stdin**
   - Script:
     ```zsh
     "/path/to/ollama-tts-reader/bin/speak-selection"
     ```
     Replace `/path/to/ollama-tts-reader` with where you cloned the repo.
4. ⌘S → name it **Speak with Phonon**. It's saved to `~/Library/Services/`.

**Use:** select text → right-click → **Services → Speak with Phonon**. Some apps list it at the top level of the menu. Selecting again and re-running replaces the current reading.

### Optional: a "Stop" item
Repeat the steps with *Workflow receives* **no input** and the script `"/path/to/ollama-tts-reader/bin/speak-stop"`. Name it **Stop Phonon**.

### Optional: keyboard shortcut
System Settings → Keyboard → **Keyboard Shortcuts…** → **Services** → *Text* → **Speak with Phonon** → double-click to assign a shortcut (e.g. ⌃⌥S). Avoid ⌥Esc, which macOS's own Spoken Content uses.

> If you use the Alfred workflow's hotkey, you don't need this shortcut. Keep the right-click item for mouse use.

## Alternative: Shortcuts.app
New Shortcut → ⓘ → enable **Use as Quick Action** + **Services Menu** → *Receive* **Text** from Quick Actions → **Run Shell Script** (input: *Shortcut Input*, pass *to stdin*). The first run asks you to allow running scripts (Shortcuts → Settings → Advanced → *Allow Running Scripts*). It works, but Automator starts faster and asks for fewer permissions.

## Troubleshooting
| Symptom | Fix |
|---|---|
| Item missing from the menu | System Settings → Keyboard → Keyboard Shortcuts → Services → make sure it's ticked. Some Electron apps and terminals don't support Services; use the Alfred hotkey there |
| Nothing is spoken | `tail ~/Library/Caches/phonon-reader/log`. Check Ollama is running: `curl localhost:11434/api/version` |
| "Ollama is not reachable" notification | start Ollama.app |
| First reading is slow | cold model load (~2.4 s); later reads start immediately |

## Hammerspoon fallback (for apps without Services)
```lua
-- ~/.hammerspoon/init.lua : ⌃⌥S reads the selection (AX first, clipboard copy as fallback)
local speak = "/path/to/ollama-tts-reader/bin/speak-selection"   -- where you cloned the repo
hs.hotkey.bind({"ctrl", "alt"}, "S", function()
  local el = hs.uielement.focusedElement()
  local text = el and el:selectedText()
  if not text or text == "" then
    local saved = hs.pasteboard.getContents()
    hs.eventtap.keyStroke({"cmd"}, "c")
    hs.timer.usleep(150000)
    text = hs.pasteboard.getContents()
    hs.pasteboard.setContents(saved or "")
  end
  if text and text ~= "" then
    hs.task.new(speak, nil, {"-t", text}):start()
  end
end)
```
