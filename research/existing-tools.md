# Existing tools (prior art), as of 2026-10-28

**Bottom line:** "select text → local neural voice" exists in several forms, but **nothing targets Ollama/Phonon**. The tools that accept a custom OpenAI-compatible server would probably hit Phonon's limits (no mp3, `speed` = 1 only, 4096-char input cap). I haven't tested that.

| Tool | Type | How it gets the selection | Engine | Custom endpoint? | Verdict |
|---|---|---|---|---|---|
| [SelectTTS](https://github.com/JakobMusik/SelectTTS) | Swift menu-bar app, MIT | Accessibility API (+ key-sending dependency) | system voice, BYO-key cloud, OpenAI-compatible local (Kokoro-FastAPI, AllTalk, Speaches, LocalAI) | **yes** | Closest match. Has a sentence chunker and streaming PCM. 1 star, so unproven. Best candidate to fork for a native app |
| [Narrateify](https://github.com/alirexa/Narrateify) | Swift menu-bar app, MIT | simulated ⌘C (overwrites the clipboard) | Apple, ElevenLabs, OpenAI, Kokoro, Chatterbox | no | Nice UX ideas: OCR a screen region, a playback overlay with 0.75–2× speed, global hotkeys ⌃⌥R / ⌃⌥Space / ⌃⌥X |
| [aloud-tts](https://pypi.org/project/aloud-tts) | Python menu-bar app | hotkey ⌃⌥S | Kokoro-82M via MLX | no | Same concept, different engine |
| [lugbara-tts](https://github.com/adrianhelvik/lugbara-tts) | menu-bar app | ⌥Esc | OpenAI cloud | no | Cloud only |
| [openai-chat-api-workflow](https://github.com/yohasebe/openai-chat-api-workflow) | **Alfred 5** workflow | Universal Action on the selection | OpenAI TTS (cloud) + MPV | unclear | Proves the Alfred UX. Sends mp3 requests, so it wouldn't work with Ollama as-is |
| [speak.awf](https://npmjs.com/package/speak.awf) | **Alfred** workflow | hotkey on the selection | macOS system voices | no | Older; system voices only |
| [Read AI](https://raycast.com/JungHoonGhae/read-ai), [AI Voice Studio](https://www.raycast.com/xianwei_zhang/ai-voice-studio) | Raycast extensions | selection / clipboard | OpenAI, Gemini, MiniMax cloud | no | Raycast is out of scope (this project targets Alfred) |
| [PopClip Say](https://pilotmoon.com/popclip/extensions/page/Say), [Azure TTS](https://github.com/willbchang/popclip-azure-text-to-speech) | PopClip extensions | PopClip bar | system voice / Azure | no | Would need PopClip |
| [Custom TTS Reader](https://addons.mozilla.org/addon/custom-tts-reader/) | Firefox add-on | page selection | any OpenAI-compatible server (built for Kokoro-FastAPI) | yes | Browser only |
| macOS Spoken Content (⌥Esc) | built-in | any app | Apple voices | no | Baseline to beat |
| [sheshbabu: system-wide summarization](https://www.sheshbabu.com/posts/system-wide-text-summarization-using-ollama-and-applescript/) | blog | Services / Quick Action | Ollama LLM | — | The pattern this project reuses |

## Ideas worth borrowing
- **Narrateify:** a playback overlay with a speed slider, OCR of a screen region (for PDFs and images where the text can't be selected), and a separate "narrate clipboard" hotkey.
- **SelectTTS:** read the selection through the Accessibility API first and fall back to ⌘C only when needed, so the clipboard is left alone.
- **Ollama CLI:** start speaking after the first sentence. `chunk-text` copies this by making chunk 1 a single sentence.
