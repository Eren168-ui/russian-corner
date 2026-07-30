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

for resource in \
  lexemes.json \
  sentences.json \
  trial-slice.json \
  topics.json \
  long-term-sentences.json \
  supplemental-manifest.json \
  supplemental-lexemes.json \
  supplemental-sentences.json \
  speaking-challenges.json
do
  cp "$SOURCE_RESOURCES/$resource" "$TEMP_DIR/$resource"
done

PROBE_OUTPUT="$("$PROBE" "$TEMP_DIR")"
if [[ "$PROBE_OUTPUT" != *"supplemental_lexemes=80"* ]] ||
  [[ "$PROBE_OUTPUT" != *"supplemental_sentences=60"* ]] ||
  [[ "$PROBE_OUTPUT" != *"speaking_challenges=24"* ]]; then
  echo "resource probe did not report supplemental counts: $PROBE_OUTPUT" >&2
  exit 1
fi

mv "$TEMP_DIR/supplemental-sentences.json" \
  "$TEMP_DIR/supplemental-sentences.missing"
set +e
PARTIAL_OUTPUT="$("$PROBE" "$TEMP_DIR" 2>&1)"
PARTIAL_STATUS=$?
set -e
mv "$TEMP_DIR/supplemental-sentences.missing" \
  "$TEMP_DIR/supplemental-sentences.json"
if [[ "$PARTIAL_STATUS" -eq 0 ]] ||
  [[ "$PARTIAL_OUTPUT" != *"补充语料资源不完整"* ]]; then
  echo "resource probe accepted partial supplemental resources: $PARTIAL_OUTPUT" >&2
  exit 1
fi

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
