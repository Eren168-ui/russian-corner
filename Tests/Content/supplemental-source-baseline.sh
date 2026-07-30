#!/usr/bin/env bash

set -euo pipefail

repo_root="$(
  CDPATH= cd -- "$(dirname -- "$0")/../.."
  pwd -P
)"

output=$(
  "$repo_root/Scripts/baseline-knowledge-corpus.sh" \
    --verify \
    "$repo_root/Verification/supplemental-source-baseline.txt"
)

case "$output" in
  knowledge_corpus=PASS\ files=*)
    printf '%s\n' "$output"
    ;;
  *)
    printf 'unexpected baseline output: %s\n' "$output" >&2
    exit 1
    ;;
esac
