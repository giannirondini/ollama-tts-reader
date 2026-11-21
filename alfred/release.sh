#!/bin/zsh
# release.sh — prepare the GitHub release files for the Alfred workflow.
#
# Usage: alfred/release.sh [version]
#   version   defaults to ../VERSION; must match it and the built workflow
#             (run alfred/build.sh <version> first)
#
# Writes to .build/release/<version>/ (gitignored):
#   Speak-with-Phonon-<version>.alfredworkflow
#   checksums.txt              SHA-256 of the workflow
#   RELEASE_NOTES.md           What's New (commit subjects since the last tag),
#                              install steps, requirements, checksum
#   UPLOAD_INSTRUCTIONS.md     the git and gh commands to publish, ready to paste
#
# Everything is built in a temporary folder and moved into place only when every
# step succeeded. A rerun (e.g. after tagging) keeps an existing RELEASE_NOTES.md
# (the fresh one is written as RELEASE_NOTES.new.md) and moves the previous
# workflow and checksums to previous-<timestamp>/.
#
# Nothing is committed, tagged, pushed or published: you review and run the
# commands in UPLOAD_INSTRUCTIONS.md yourself.
emulate -L zsh
set -e

HERE=${0:A:h}
ROOT=${HERE:h}
NAME="Speak with Phonon"
BUILT=$HERE/dist/Speak-with-Phonon.alfredworkflow

err()  { print -u2 -- "✗ $*" }
info() { print -- "  $*" }
ok()   { print -- "✓ $*" }
warn() { print -- "! $*" }

[[ -r $ROOT/VERSION ]] || { err "Missing $ROOT/VERSION"; exit 1 }
FILE_VERSION=$(<$ROOT/VERSION)
VERSION=${1:-$FILE_VERSION}
TAG=v$VERSION

[[ $VERSION =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { err "Invalid version: $VERSION (expected MAJOR.MINOR.PATCH)"; exit 1 }
if [[ $VERSION != $FILE_VERSION ]]; then
  err "VERSION says $FILE_VERSION, not $VERSION"
  info "Run alfred/build.sh $VERSION first"
  exit 1
fi
[[ -f $BUILT ]] || { err "No built workflow at $BUILT"; info "Run alfred/build.sh $VERSION first"; exit 1 }

WORK=$(mktemp -d)
trap 'rm -rf $WORK' EXIT

# The built workflow must be this version and carry the current bin/ and info.plist.
mkdir $WORK/unzipped
unzip -q $BUILT -d $WORK/unzipped
BUILT_VERSION=$(plutil -extract version raw $WORK/unzipped/info.plist)
if [[ $BUILT_VERSION != $VERSION ]]; then
  err "The built workflow is version $BUILT_VERSION, not $VERSION"
  info "Run alfred/build.sh $VERSION first"
  exit 1
fi
for f in $ROOT/bin/*(.); do
  cmp -s $f $WORK/unzipped/bin/${f:t} || { err "The built workflow's bin/${f:t} differs from bin/${f:t}"; info "Run alfred/build.sh first"; exit 1 }
done
cp $HERE/info.plist $WORK/source.plist
plutil -replace version -string $VERSION $WORK/source.plist
cmp -s $WORK/source.plist $WORK/unzipped/info.plist || { err "The built info.plist differs from alfred/info.plist"; info "Run alfred/build.sh first"; exit 1 }

BUNDLE_ID=$(plutil -extract bundleid raw $HERE/info.plist)
REPO_URL=$(plutil -extract webaddress raw $HERE/info.plist)
[[ -n $REPO_URL ]] || { err "info.plist has no webaddress (the repo URL)"; exit 1 }

ARTIFACT=Speak-with-Phonon-$VERSION.alfredworkflow
RELEASE_DIR=$ROOT/.build/release/$VERSION
cp $BUILT $WORK/$ARTIFACT
CHECKSUM=$(shasum -a 256 $WORK/$ARTIFACT | cut -d' ' -f1)
ok "Workflow verified: $ARTIFACT"

# What's New: commit subjects since the previous tag (none yet: first release).
PREVIOUS_TAG=$(git -C $ROOT describe --tags --abbrev=0 2>/dev/null || true)
if [[ $PREVIOUS_TAG == $TAG ]]; then
  # Rerun after tagging this version: compare with the tag before it.
  PREVIOUS_TAG=$(git -C $ROOT describe --tags --abbrev=0 "$TAG^" 2>/dev/null || true)
fi
if [[ -n $PREVIOUS_TAG ]]; then
  LAST_COMMIT=$(git -C $ROOT rev-parse -q --verify "$TAG^{commit}" 2>/dev/null || echo HEAD)
  WHATS_NEW=$(git -C $ROOT log "$PREVIOUS_TAG..$LAST_COMMIT" --no-merges --format='- %s' | grep -v '^- chore(release)' || true)
  WHATS_NEW_SOURCE="commits since $PREVIOUS_TAG"
else
  WHATS_NEW="- First release."
  WHATS_NEW_SOURCE="no previous tag"
fi
[[ -n $WHATS_NEW ]] || WHATS_NEW="- "

cat > $WORK/RELEASE_NOTES.md <<NOTES
## What's New

$WHATS_NEW

## Installation

1. Install [Ollama](https://ollama.com) 0.40.9 or later, then pull the voice model:
   \`\`\`bash
   ollama pull phonon
   \`\`\`
2. Download \`$ARTIFACT\` and double-click it to import it into Alfred.
3. In Alfred Preferences → Workflows → **$NAME**, double-click the **Hotkey** trigger and record a key (e.g. ⌃⌥S). Check that *Argument* shows "Selection in macOS" and set it if not.
4. Select text in any app and press the hotkey. Press it again to stop.

Keywords: \`speak <text>\`, \`voice\` (pick and preview a voice), \`shh\` (stop). The voice and speed live in \`~/.config/phonon-reader/\`.

**Updating:** import the new workflow and let Alfred replace the existing one (same bundle id, \`$BUNDLE_ID\`). Your saved voice and rate are kept (they live in \`~/.config/phonon-reader/\`); Alfred should keep your hotkey too.

**If nothing is spoken after the import**, macOS may have quarantined the downloaded scripts: right-click the workflow in Alfred → *Open in Finder*, then run \`xattr -dr com.apple.quarantine\` on that folder.

## Requirements

- macOS with Alfred 5 or 6 and the Powerpack
- Ollama 0.40.9 or later, with \`phonon\` pulled
- No other installs: zsh, perl, curl, jq and afplay ship with macOS

## Checksum

\`\`\`
$CHECKSUM  $ARTIFACT
\`\`\`
NOTES
ok "Release notes created ($WHATS_NEW_SOURCE)"

BRANCH=$(git -C $ROOT branch --show-current 2>/dev/null || echo main)

cat > $WORK/UPLOAD_INSTRUCTIONS.md <<STEPS
# Publishing $NAME $VERSION

Run these from the repository root. Nothing has been committed, tagged or pushed yet.

## 1. Review

- Edit \`$RELEASE_DIR/RELEASE_NOTES.md\` (What's New lists the $WHATS_NEW_SOURCE). Its checksum must be \`$CHECKSUM\`.
- Test the workflow: \`open "$RELEASE_DIR/$ARTIFACT"\`, import it, trigger the hotkey.

## 2. Commit the version

\`\`\`bash
git add VERSION
git commit -m "chore(release): $TAG"
\`\`\`

(Skip if \`git status\` shows nothing to commit.)

## 3. Tag and push

\`\`\`bash
git tag -a $TAG -m "$NAME $VERSION"
git push origin $BRANCH $TAG
\`\`\`

Releases normally come from \`main\`; you're on \`$BRANCH\`.

## 4. Publish

\`\`\`bash
gh release create $TAG \\
  "$RELEASE_DIR/$ARTIFACT" \\
  "$RELEASE_DIR/checksums.txt" \\
  --verify-tag \\
  --title "$NAME $VERSION" \\
  --notes-file "$RELEASE_DIR/RELEASE_NOTES.md"
\`\`\`

Add \`--draft\` to review the release page before publishing it (\`gh release edit $TAG --draft=false\` publishes it).

Or by hand: $REPO_URL/releases/new → tag \`$TAG\` → title "$NAME $VERSION" → paste RELEASE_NOTES.md → attach the workflow and checksums.txt → Publish.

## 5. Check

- The release page shows the notes and both files: $REPO_URL/releases/tag/$TAG
- Download the workflow, import it into Alfred, trigger the hotkey on a selection.
STEPS

mkdir -p $RELEASE_DIR

# A rerun replaces the workflow (a new build has a new checksum): keep the previous one.
PREVIOUS_DIR=
if [[ -f $RELEASE_DIR/$ARTIFACT ]]; then
  OLD_CHECKSUM=$(shasum -a 256 $RELEASE_DIR/$ARTIFACT | cut -d' ' -f1)
  if [[ $OLD_CHECKSUM != $CHECKSUM ]]; then
    PREVIOUS_DIR=$RELEASE_DIR/previous-$(date -u +%Y%m%dT%H%M%SZ)
    mkdir -p $PREVIOUS_DIR
    mv $RELEASE_DIR/$ARTIFACT $PREVIOUS_DIR/
    [[ -f $RELEASE_DIR/checksums.txt ]] && mv $RELEASE_DIR/checksums.txt $PREVIOUS_DIR/
  fi
fi
mv $WORK/$ARTIFACT $RELEASE_DIR/$ARTIFACT
print -r -- "$CHECKSUM  $ARTIFACT" > $RELEASE_DIR/checksums.txt
mv $WORK/UPLOAD_INSTRUCTIONS.md $RELEASE_DIR/UPLOAD_INSTRUCTIONS.md

# Never overwrite notes you may have edited.
NOTES_PATH=$RELEASE_DIR/RELEASE_NOTES.md
NOTES_STALE=false
if [[ -f $NOTES_PATH ]]; then
  if cmp -s $WORK/RELEASE_NOTES.md $NOTES_PATH; then
    rm -f $RELEASE_DIR/RELEASE_NOTES.new.md
  else
    mv $WORK/RELEASE_NOTES.md $RELEASE_DIR/RELEASE_NOTES.new.md
    grep -qF $CHECKSUM $NOTES_PATH || NOTES_STALE=true
  fi
else
  mv $WORK/RELEASE_NOTES.md $NOTES_PATH
fi

print
ok "Release files ready: $NAME $VERSION"
info "Workflow:            $RELEASE_DIR/$ARTIFACT"
info "SHA-256:             $CHECKSUM"
info "Release notes:       $NOTES_PATH"
info "Checksums:           $RELEASE_DIR/checksums.txt"
info "Upload instructions: $RELEASE_DIR/UPLOAD_INSTRUCTIONS.md"
[[ -n $PREVIOUS_DIR ]] && warn "The previous workflow and checksums.txt are in $PREVIOUS_DIR (checksum $OLD_CHECKSUM)"
[[ -f $RELEASE_DIR/RELEASE_NOTES.new.md ]] && warn "RELEASE_NOTES.md was kept; the freshly generated notes are RELEASE_NOTES.new.md"
[[ $NOTES_STALE == true ]] && warn "RELEASE_NOTES.md doesn't contain this workflow's checksum: replace it with $CHECKSUM"
print
print "Next steps:"
print "  1. Test the workflow: open \"$RELEASE_DIR/$ARTIFACT\""
print "  2. Edit the notes:    $NOTES_PATH"
print "  3. Publish:           follow $RELEASE_DIR/UPLOAD_INSTRUCTIONS.md"
