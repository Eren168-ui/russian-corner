#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

knowledge_root="$fixture_root/大学知识库（俄语学习+专业）"
allowed_root="$knowledge_root/01-按学期/大二上/基础俄语"
mkdir -p \
  "$allowed_root" \
  "$knowledge_root/01-按学期/大二上/专业俄语" \
  "$knowledge_root/01-按学期/大二上/俄语转录"

printf '%s\n' \
  '# 日常交流' \
  'Я обычно заранее составляю список необходимых вещей.' \
  '| Вопрос | Что вы обычно делаете перед поездкой? |' \
  > "$allowed_root/旅行.md"

printf '%s\n' \
  'Функция митохондрий заключается в выработке энергии.' \
  > "$knowledge_root/01-按学期/大二上/专业俄语/生物学.md"

printf '%s\n' \
  'Я э-э вчера ходил в магазин и потом ну вернулся.' \
  > "$knowledge_root/01-按学期/大二上/俄语转录/课堂转录.md"

printf '%s\n' \
  'Этот файл не должен участвовать в импорте.' \
  > "$allowed_root/旅行 conflict.md"

printf '%s\n' \
  'Сгенерируй идеальный ответ на каждый вопрос.' \
  > "$allowed_root/口语练习计划 AI生成版.md"

json_output="$fixture_root/candidates.json"
report_output="$fixture_root/audit.md"

node "$repo_root/Scripts/audit-supplemental-corpus.mjs" \
  --knowledge-root "$knowledge_root" \
  --json-output "$json_output" \
  --report-output "$report_output"

node - "$json_output" "$report_output" <<'NODE'
const fs = require("node:fs");
const [jsonPath, reportPath] = process.argv.slice(2);
const audit = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
const report = fs.readFileSync(reportPath, "utf8");

if (audit.candidates.length !== 2) {
  throw new Error(`expected 2 candidates, got ${audit.candidates.length}`);
}
if (!audit.candidates.every((item) =>
  item.sourcePath.endsWith("基础俄语/旅行.md") &&
  item.reviewStatus === "draft" &&
  item.qualityFlags.includes("needsNativeReview") &&
  item.sourceText.length > 0 &&
  /^[a-f0-9]{64}$/.test(item.sourceHash)
)) {
  throw new Error("allowed candidates lost source trace or draft safety fields");
}

const expectedExclusions = new Map([
  ["专业俄语/生物学.md", "professionalSource"],
  ["俄语转录/课堂转录.md", "transcriptSource"],
  ["旅行 conflict.md", "conflictCopy"],
  ["口语练习计划 AI生成版.md", "aiGeneratedPlan"],
]);

for (const [fragment, reason] of expectedExclusions) {
  const match = audit.excluded.find((item) => item.sourcePath.includes(fragment));
  if (!match) {
    throw new Error(`missing explicit exclusion for ${fragment}`);
  }
  if (match.reason !== reason) {
    throw new Error(`wrong reason for ${fragment}: ${match.reason}`);
  }
  if (!report.includes(fragment) || !report.includes(reason)) {
    throw new Error(`report does not explain ${fragment}`);
  }
}
NODE

echo "supplemental_audit=PASS"
