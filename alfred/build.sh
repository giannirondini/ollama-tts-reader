#!/bin/zsh
# build.sh — package the Alfred workflow as a self-contained .alfredworkflow
# (info.plist + a copy of ../bin). Double-click the result to import it.
#
# Usage: alfred/build.sh [version]
#   version   MAJOR.MINOR.PATCH; written to ../VERSION. Without it, VERSION is used as is.
# The version is injected into the staged info.plist (the source file isn't touched).
# Output: alfred/dist/Speak-with-Phonon.alfredworkflow (gitignored; releases go
# through alfred/release.sh, see docs/DISTRIBUTION.md).
emulate -L zsh
set -e

HERE=${0:A:h}
ROOT=${HERE:h}
OUT=$HERE/dist
WORKFLOW=Speak-with-Phonon.alfredworkflow

if (( $# )); then
  [[ $1 =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { print -u2 "Invalid version: $1 (expected MAJOR.MINOR.PATCH, e.g. 0.2.0)"; exit 1 }
  print -r -- $1 > $ROOT/VERSION
fi
[[ -r $ROOT/VERSION ]] || { print -u2 "Missing $ROOT/VERSION"; exit 1 }
VERSION=$(<$ROOT/VERSION)

STAGE=$(mktemp -d)
trap 'rm -rf $STAGE' EXIT

plutil -lint $HERE/info.plist
cp $HERE/info.plist $STAGE/
plutil -replace version -string $VERSION $STAGE/info.plist
mkdir $STAGE/bin
cp $ROOT/bin/*(.) $STAGE/bin/
chmod +x $STAGE/bin/*

mkdir -p $OUT
rm -f $OUT/$WORKFLOW
(cd $STAGE && zip -qrX $OUT/$WORKFLOW .)
print "Built $OUT/$WORKFLOW ($VERSION)"
