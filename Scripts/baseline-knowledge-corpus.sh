#!/usr/bin/env bash

set -euo pipefail

knowledge_root="/Users/Openclawworkspace/Library/CloudStorage/OneDrive-个人/Documents/20-语言学习与专业/大学知识库（俄语学习+专业）"
mode="${1:-}"
baseline_path="${2:-}"

if [[ "$mode" != "--write" && "$mode" != "--verify" ]] ||
  [[ -z "$baseline_path" ]]; then
  printf 'usage: %s --write|--verify BASELINE_PATH\n' "$0" >&2
  exit 2
fi

if [[ -L "$knowledge_root" || ! -d "$knowledge_root" ]]; then
  printf 'knowledge_corpus=FAIL reason=unsafe_or_missing_root\n' >&2
  exit 1
fi

temporary_inventory="$(mktemp /tmp/russian-corner-knowledge.XXXXXX)"
cleanup() {
  rm -f -- "$temporary_inventory"
}
trap cleanup EXIT

file_count=0
while IFS= read -r -d '' file; do
  if [[ -L "$file" || ! -f "$file" ]]; then
    printf 'knowledge_corpus=FAIL reason=unsafe_file path=%s\n' \
      "$file" >&2
    exit 1
  fi
  relative_path="${file#"$knowledge_root"/}"
  digest="$(shasum -a 256 "$file" | awk '{print $1}')"
  printf '%s  %s\n' "$digest" "$relative_path" >>"$temporary_inventory"
  file_count=$((file_count + 1))
done < <(
  find "$knowledge_root" -type f -print0 |
    LC_ALL=C sort -z
)

if [[ "$mode" == "--write" ]]; then
  if [[ -e "$baseline_path" || -L "$baseline_path" ]]; then
    printf 'knowledge_corpus=FAIL reason=baseline_already_exists\n' >&2
    exit 1
  fi
  if [[ ! -d "$(dirname -- "$baseline_path")" ]]; then
    printf 'knowledge_corpus=FAIL reason=missing_baseline_parent\n' >&2
    exit 1
  fi
  cp "$temporary_inventory" "$baseline_path"
else
  if [[ -L "$baseline_path" || ! -f "$baseline_path" ]]; then
    printf 'knowledge_corpus=FAIL reason=missing_or_unsafe_baseline\n' >&2
    exit 1
  fi
  if ! cmp -s "$temporary_inventory" "$baseline_path"; then
    printf 'knowledge_corpus=FAIL reason=source_changed\n' >&2
    diff -u "$baseline_path" "$temporary_inventory" >&2 || true
    exit 1
  fi
fi

printf 'knowledge_corpus=PASS files=%d\n' "$file_count"
