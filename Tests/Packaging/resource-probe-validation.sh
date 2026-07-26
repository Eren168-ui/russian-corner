#!/bin/bash
set -euo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1
  pwd
)"
PROBE="$ROOT_DIR/.build/release/RussianCornerResourceProbe"
SOURCE_RESOURCES="$ROOT_DIR/Sources/RussianCornerCore/Resources"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

swift build \
  --package-path "$ROOT_DIR" \
  -c release \
  --product RussianCornerResourceProbe

cp "$SOURCE_RESOURCES/lexemes.json" "$TEMP_DIR/lexemes.json"
cp "$SOURCE_RESOURCES/sentences.json" "$TEMP_DIR/sentences.json"
cp "$SOURCE_RESOURCES/trial-slice.json" "$TEMP_DIR/trial-slice.json"

"$PROBE" "$TEMP_DIR" >/dev/null

/usr/bin/perl -0pi -e \
  's/"lexeme-emergencies-помочь"/"lexeme-does-not-exist"/' \
  "$TEMP_DIR/sentences.json"

set +e
OUTPUT="$("$PROBE" "$TEMP_DIR" 2>&1)"
STATUS=$?
set -e

if [[ "$STATUS" -eq 0 ]]; then
  echo "resource probe accepted a semantically invalid catalog" >&2
  exit 1
fi

if [[ "$OUTPUT" != *"lexeme-does-not-exist"* ]]; then
  echo "resource probe did not report the broken link: $OUTPUT" >&2
  exit 1
fi

echo "resource_probe_validation=PASS"
