#!/usr/bin/env bash

set -euo pipefail

VAULT_NAME="Documents"
SOURCE_FOLDER="20-语言学习与专业/大学知识库（俄语学习+专业）/01-按学期/大一下——莫斯科/口语Диалоги"
EXPECTED_FILE_COUNT="46"
EXPECTED_SHA256="89ca565d1fa8b3840e89e7262b867d61fe486ea95962f1746c109bf2a4478b0c"

if ! command -v obsidian >/dev/null 2>&1; then
  printf 'source_corpus=FAIL reason=obsidian_cli_unavailable\n' >&2
  exit 1
fi

file_count="$(
  obsidian files \
    vault="$VAULT_NAME" \
    folder="$SOURCE_FOLDER" \
    total
)"

corpus_sha256="$(
  obsidian files \
    vault="$VAULT_NAME" \
    folder="$SOURCE_FOLDER" \
    | LC_ALL=C sort \
    | while IFS= read -r note_path; do
        printf 'PATH:%s\n' "$note_path"
        obsidian read \
          vault="$VAULT_NAME" \
          path="$note_path" \
          < /dev/null
      done \
    | shasum -a 256 \
    | awk '{print $1}'
)"

if [[ "$file_count" != "$EXPECTED_FILE_COUNT" ]]; then
  printf \
    'source_corpus=FAIL expected_files=%s actual_files=%s\n' \
    "$EXPECTED_FILE_COUNT" \
    "$file_count" \
    >&2
  exit 1
fi

if [[ "$corpus_sha256" != "$EXPECTED_SHA256" ]]; then
  printf \
    'source_corpus=FAIL expected_sha256=%s actual_sha256=%s\n' \
    "$EXPECTED_SHA256" \
    "$corpus_sha256" \
    >&2
  exit 1
fi

printf \
  'source_corpus=PASS files=%s sha256=%s vault=%s\n' \
  "$file_count" \
  "$corpus_sha256" \
  "$VAULT_NAME"
