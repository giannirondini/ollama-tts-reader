# Ollama Phonon: facts, limits and gotchas

Sources: [Ollama blog: speech models](https://ollama.com/blog/speech-models) · [docs.ollama.com/capabilities/speech](https://docs.ollama.com/capabilities/speech) · local tests on 2026-10-28 (Ollama 0.40.12, Apple Silicon).

## What it is
- **Phonon** is a family of small TTS models from **Gradium**. It's Ollama's first speech model and runs on Apple Silicon via MLX. It's macOS-only for now; Windows and Linux are "coming soon".
- Requires Ollama ≥ 0.40.9. The local model is `phonon:latest`: 43.5 M params, bf16, 112 MB.

| Tag | Language | License |
|---|---|---|
| `phonon` | English | Apache-2.0 |
| `phonon:40m-fr` / `-de` / `-es` / `-pt` | FR / DE / ES / PT | **CC BY-NC 4.0** (non-commercial) |
| `phonon:40m-multilingual` | all 5 | CC BY-NC 4.0 |

Italian and Japanese aren't supported.

## Interfaces
**CLI**
```bash
ollama run phonon "Hello"                 # speaks (via afplay)
ollama run phonon --voice Hadley "Hello"
echo "text" | ollama run phonon           # piped: streams sentence by sentence
ollama run phonon "Hello" > out.wav       # stdout not a TTY => writes WAV instead of playing
ollama show phonon                        # lists voices
```

**HTTP (OpenAI-style)**: `POST http://localhost:11434/v1/audio/speech`
```json
{ "model": "phonon", "voice": "Zoey", "input": "Hello", "response_format": "wav" }
```
- Output is 24 kHz, mono, 16-bit. `wav` is the default; `pcm` is raw s16le.
- Streams as it generates. The WAV header has `0xFFFFFFFF` size fields, which afplay handles fine.
- Voice list: `POST /api/show {"model":"phonon"}` returns a top-level `voices` array, so you don't need the CLI.

## Verified limits (local tests)
| Request | Result | Consequence |
|---|---|---|
| `speed: 1.0` | 200 | — |
| `speed: 1.3` | **400** `only speed 1 is supported` | change speed at playback instead (`afplay -r 1.3 -q 1`) |
| `response_format: "mp3"` | **400** | only `wav` / `pcm` |
| `input` > 4096 chars | **400** | the client must chunk; only the CLI chunks automatically |
| unknown voice | **400** with the list of available voices | handy for error messages |
| cold start | ~2.4 s to first byte | warm: ~20 ms |
| throughput | 1,536 chars → 87 s of audio in 1.3 s | ~65× realtime; chunking is cheap |

**Gotcha 1:** "OpenAI-compatible" is only partly true. Most OpenAI TTS clients (Raycast and Alfred extensions, browser add-ons) default to mp3 and/or send `speed`, so they'll get a 400 here.

**Gotcha 2:** the CLI decides whether to play or write a WAV based on whether stdout is a TTY. Under Automator or Alfred, stdout isn't a TTY, so `ollama run phonon` writes WAV to nowhere and stays silent. That's why `bin/speak-selection` uses the HTTP API plus `afplay` instead.

**Gotcha 3:** afplay has about 0.3 s of startup and 0.6 s of teardown. Each chunk boundary costs about 1 s of silence, so put chunk boundaries on paragraph breaks.

## Voices (38, English model)
Alfie, Azgorath, Bryony, Captain Silas Blackwater, default, Delia, Easton, Edwin, Elodie-Rose, Everly, Fairy Godmother, Fennick the Young Elf, Freya, Grub the Ogre, Hadley, Harper, Hugh, Imogen, Juniper, Lottie, Maeve, Master Aldric, Micah, Miles, Morwenna of the Deep, Old Mortlake, Pippa, Preston, Russell, Sir Bramwell, Spencer, Teddy, The Snow Queen, The Thing Under the Stairs, Toby, Trevor, Vyrmathrax the Ancient, Zoey.

Voice names are case-insensitive. The catalog is at `gradium/phonon-voices` on Hugging Face. The character voices (Ogre, Snow Queen, …) are fun but tiring over long text; Zoey, Hadley, Freya and Easton suit reading.

## Text handling (from the docs)
- Numbers, prices, symbols, emails and URLs are spoken in full. Numeric dates and times are read as written.
- Emoji, bullet characters and markdown markers are skipped.
