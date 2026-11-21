# Distribution Guide

How to version, package and publish the **Speak with Phonon** Alfred workflow.

The workflow is distributed through [GitHub Releases](https://github.com/giannirondini/ollama-tts-reader/releases). The built `.alfredworkflow` isn't committed (`alfred/dist/` and `.build/` are gitignored).

## Version management

`VERSION` in the repo root is the source of truth ([Semantic Versioning](https://semver.org/)).

`alfred/build.sh <version>` writes it (`alfred/build.sh` alone uses it as is) and injects it into the staged copy of `info.plist`, so the source `alfred/info.plist` never needs a version edit.

## Releasing

Run the two steps below yourself, then the publishing commands they print:

```bash
alfred/build.sh 0.2.0      # writes VERSION, builds alfred/dist/Speak-with-Phonon.alfredworkflow
alfred/release.sh 0.2.0    # .build/release/0.2.0/: workflow, notes, checksums, upload instructions
```

`release.sh`:

1. Checks the built workflow is that version and carries the current `bin/` and `info.plist`. A stale build (you changed `bin/` and forgot `build.sh`) is refused.
2. Copies it to `Speak-with-Phonon-<version>.alfredworkflow` and writes `checksums.txt` (SHA-256).
3. Writes `RELEASE_NOTES.md`: What's New (the commit subjects since the previous tag, or "First release." without one; `chore(release)` commits are skipped), install steps, requirements and the checksum.
4. Writes `UPLOAD_INSTRUCTIONS.md`: commit `VERSION`, tag `v<version>`, push, and `gh release create … --notes-file RELEASE_NOTES.md` (or the web form).
5. Builds everything in a temporary folder and moves it into `.build/release/<version>/` only when every step succeeded. A rerun keeps an existing `RELEASE_NOTES.md` (the fresh notes become `RELEASE_NOTES.new.md`, with a warning if the kept notes lack the new checksum) and moves the previous workflow and `checksums.txt` to `previous-<timestamp>/`.

Nothing is committed, tagged, pushed or published by the scripts.

There's no code signing: a `.alfredworkflow` is a plain zip that Alfred unpacks into its preferences folder.

## Installing (for users)

1. Install Ollama ≥ 0.40.9 and run `ollama pull phonon`.
2. Download `Speak-with-Phonon-<version>.alfredworkflow` from Releases and double-click it.
3. Set the hotkey in Alfred Preferences → Workflows → Speak with Phonon.

To update, import the new release. Alfred replaces the workflow with the same bundle id (`io.github.giannirondini.speak-with-phonon`). Voice and rate live in `~/.config/phonon-reader/` and are kept.

## Build artifacts

```
alfred/dist/
└── Speak-with-Phonon.alfredworkflow   (local build, for testing)
.build/
└── release/
    └── <version>/
        ├── Speak-with-Phonon-<version>.alfredworkflow
        ├── RELEASE_NOTES.md
        ├── checksums.txt
        ├── UPLOAD_INSTRUCTIONS.md
        ├── RELEASE_NOTES.new.md      (rerun with edited notes only)
        └── previous-<timestamp>/     (rerun only: the replaced workflow and checksums)
```

## Troubleshooting

| Problem | Fix |
|---|---|
| "VERSION says X, not Y" / "The built workflow is version X" | `alfred/build.sh Y` first |
| "The built workflow's bin/… differs" / "The built info.plist differs" | `alfred/build.sh` (the build is stale) |
| "info.plist has no webaddress" | Set `webaddress` in `alfred/info.plist` to the repo URL |
| Nothing is spoken after importing a downloaded release | macOS may have quarantined the scripts: Alfred → right-click the workflow → *Open in Finder*, then `xattr -dr com.apple.quarantine` on that folder |
