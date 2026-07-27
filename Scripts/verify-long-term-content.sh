#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
topics_file="$repo_root/Sources/RussianCornerCore/Resources/topics.json"
manifest_file="$repo_root/Sources/RussianCornerCore/Resources/long-term-sentences.json"
audit_file="$repo_root/Verification/long-term-corpus-candidates.json"
topic_range="${2:-}"

if [[ "${1:-}" != "" && "${1:-}" != "--topics" ]]; then
  printf 'long_term_content=FAIL reason=invalid_arguments\n' >&2
  exit 2
fi
if [[ "${1:-}" == "--topics" && ! "$topic_range" =~ ^[0-9]+-[0-9]+$ ]]; then
  printf 'long_term_content=FAIL reason=invalid_topic_range\n' >&2
  exit 2
fi

node - "$topics_file" "$manifest_file" "$audit_file" "$topic_range" <<'NODE'
const fs = require("fs");
const crypto = require("crypto");
const path = require("path");

const [topicsPath, manifestPath, auditPath, topicRange] =
  process.argv.slice(2);
const topics = JSON.parse(fs.readFileSync(topicsPath, "utf8"));
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const audit = JSON.parse(fs.readFileSync(auditPath, "utf8"));
const failures = [];
const hash = (data) => crypto
  .createHash("sha256").update(data).digest("hex");
const cleanSpeech = (text) =>
  typeof text === "string"
  && text.trim() !== ""
  && !/[\u3400-\u4DBF\u4E00-\u9FFF\[\]（）()/*_#`]/u.test(text);
const nonempty = (value) =>
  typeof value === "string" && value.trim() !== "";
const acute = "\u0301";
const russianWord =
  /[\p{Script=Cyrillic}\u0301]+(?:-[\p{Script=Cyrillic}\u0301]+)*/gu;
const vowel = /[АЕЁИОУЫЭЮЯаеёиоуыэюя]/gu;
const canonical = (value) => value
  .normalize("NFD")
  .replaceAll(acute, "")
  .replaceAll("ё", "е")
  .replaceAll("Ё", "Е");
const unstressedMultisyllabic = (value) =>
  [...value.matchAll(russianWord)]
    .map((match) => match[0])
    .filter((word) => {
      const vowelCount = [...word.matchAll(vowel)].length;
      return vowelCount > 1
        && !word.includes(acute)
        && !/[Ёё]/u.test(word);
    });
const topicIDs = new Set(topics.map((topic) => topic.id));
const topicPaths = new Set(topics.map((topic) => topic.sourcePath));
const sentenceIDs = new Set();
const counts = Object.fromEntries(
  topics.map((topic) => [topic.id, 0]),
);

if (topics.length !== 32
  || new Set(topics.map((topic) => topic.number)).size !== 32
  || Math.min(...topics.map((topic) => topic.number)) !== 1
  || Math.max(...topics.map((topic) => topic.number)) !== 32) {
  failures.push("topics_not_exactly_1_through_32");
}
if (topicIDs.size !== topics.length
  || topicPaths.size !== topics.length) {
  failures.push("duplicate_topic_id_or_path");
}
for (const sentence of manifest.sentences) {
  if (sentenceIDs.has(sentence.id)) failures.push(
    `duplicate_id:${sentence.id}`,
  );
  sentenceIDs.add(sentence.id);
  if (!topicIDs.has(sentence.topicID)) {
    failures.push(`unknown_topic:${sentence.id}`);
  } else {
    counts[sentence.topicID] += 1;
  }
  if (!["reviewed", "verified"].includes(sentence.reviewStatus)) {
    failures.push(`unreviewed:${sentence.id}`);
  }
  if (sentence.provenanceType === "aiGenerated"
    || /conflict|ai生成/iu.test(sentence.sourcePath)) {
    failures.push(`unsafe_source:${sentence.id}`);
  }
  if (!cleanSpeech(sentence.practiceRu)
    || !cleanSpeech(sentence.speechText)) {
    failures.push(`dirty_speech_text:${sentence.id}`);
  }
  if (!nonempty(sentence.stressedForm)) {
    failures.push(`missing_stressed_form:${sentence.id}`);
  } else {
    if (canonical(sentence.stressedForm)
      !== canonical(sentence.practiceRu)) {
      failures.push(`stress_changed_text:${sentence.id}`);
    }
    const missingStress = unstressedMultisyllabic(
      sentence.stressedForm,
    );
    if (missingStress.length > 0) {
      failures.push(
        `unstressed_multisyllabic:${sentence.id}:${missingStress.join(",")}`,
      );
    }
  }
  if (!nonempty(sentence.dialogueAct)
    || !nonempty(sentence.speakerRole)
    || !nonempty(sentence.register)
    || !nonempty(sentence.addressForm)
    || !nonempty(sentence.expectedReply)) {
    failures.push(`missing_pragmatic_metadata:${sentence.id}`);
  }
  if (!nonempty(sentence.sourcePath)
    || !nonempty(sentence.sourceText)
    || !nonempty(sentence.sourceHash)) {
    failures.push(`missing_source_trace:${sentence.id}`);
    continue;
  }
  const absolute = path.resolve(
    manifest.sourceRoot,
    sentence.sourcePath,
  );
  const relative = path.relative(manifest.sourceRoot, absolute);
  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    failures.push(`source_escape:${sentence.id}`);
    continue;
  }
  const metadata = fs.lstatSync(absolute);
  if (!metadata.isFile() || metadata.isSymbolicLink()) {
    failures.push(`unsafe_source_file:${sentence.id}`);
    continue;
  }
  const bytes = fs.readFileSync(absolute);
  const content = bytes.toString("utf8");
  if (hash(bytes) !== sentence.sourceHash
    || !content.split(/\r?\n/u).includes(sentence.sourceText)) {
    failures.push(`source_mismatch:${sentence.id}`);
  }
}

let requestedTopics = topics;
if (topicRange) {
  const [start, end] = topicRange.split("-").map(Number);
  requestedTopics = topics.filter(
    (topic) => topic.number >= start && topic.number <= end,
  );
}
for (const topic of requestedTopics) {
  if (counts[topic.id] < 4) {
    failures.push(`topic_floor:${topic.id}:${counts[topic.id]}`);
  }
}
if (!topicRange) {
  if (!manifest.contentGateClosed) {
    failures.push("content_gate_open");
  }
  if (manifest.sentences.length < 200) {
    failures.push(`sentence_floor:${manifest.sentences.length}`);
  }
}
if (failures.length > 0) {
  process.stderr.write(
    `long_term_content=FAIL ${failures.join(" ")}\n`,
  );
  process.exit(1);
}
const exclusionCounts = Object.groupBy(
  audit.excluded,
  (entry) => entry.reason,
);
process.stdout.write(
  `long_term_content=PASS topics=${topics.length} `
  + `sentences=${manifest.sentences.length} `
  + `minimum_per_topic=${Math.min(...Object.values(counts))} `
  + `candidates=${audit.candidates.length} `
  + `excluded=${audit.excluded.length} `
  + `exclusion_reasons=${Object.keys(exclusionCounts).sort().join(",")}\n`,
);
NODE
