#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
source_root="$fixture_root/source"

mkdir -p "$source_root/具体场景对话"
printf '%s\n' \
  '1. Мне нужно уточнить время встречи. 我需要确认见面时间。' \
  > "$source_root/具体场景对话/Тема 1.md"
printf '%s\n' \
  '1. Я рад(а) вас видеть. 很高兴见到您。' \
  > "$source_root/具体场景对话/Тема 2.md"
printf '%s\n' \
  '### Диалоги' \
  '1. ' \
  > "$source_root/具体场景对话/Тема 3.md"
printf '%s\n' 'conflict body must not be read' \
  > "$source_root/具体场景对话/Тема 4 conflict.md"
printf '%s\n' 'AI body must not be read' \
  > "$source_root/口语练习计划 AI生成版.md"

topics_file="$fixture_root/topics.json"
output_file="$fixture_root/candidates.json"
report_file="$fixture_root/report.md"
printf '%s\n' \
  '[' \
  '  {"id":"topic-01","number":1,"titleRu":"О встрече","titleZh":"见面","sourcePath":"具体场景对话/Тема 1.md"},' \
  '  {"id":"topic-02","number":2,"titleRu":"Вариант","titleZh":"变体","sourcePath":"具体场景对话/Тема 2.md"},' \
  '  {"id":"topic-03","number":3,"titleRu":"Пусто","titleZh":"空对话","sourcePath":"具体场景对话/Тема 3.md"}' \
  ']' > "$topics_file"

node "$repo_root/Scripts/audit-long-term-corpus.mjs" \
  --source-root "$source_root" \
  --topics "$topics_file" \
  --output "$output_file" \
  --report "$report_file"

jq -e '.candidates | length == 1' "$output_file" >/dev/null
jq -e '
  [.excluded[].reason] | sort
  == ["aiGeneratedSource","conflictSource","emptyDialogue","variant"]
' "$output_file" >/dev/null
jq -e '
  .candidates[0].reviewStatus == "draft"
  and .candidates[0].sourceText
      == "1. Мне нужно уточнить время встречи. 我需要确认见面时间。"
' "$output_file" >/dev/null
