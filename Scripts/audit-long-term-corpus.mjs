#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function parseArguments(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith("--") || !value) {
      throw new Error(`Invalid argument near ${key ?? "<end>"}`);
    }
    values.set(key.slice(2), value);
  }
  for (const required of ["source-root", "topics", "output", "report"]) {
    if (!values.has(required)) {
      throw new Error(`Missing --${required}`);
    }
  }
  return Object.fromEntries(values);
}

function sha256(data) {
  return crypto.createHash("sha256").update(data).digest("hex");
}

function normalizedPath(value) {
  return value.normalize("NFC").toLocaleLowerCase("ru");
}

function isInside(child, parent) {
  const relative = path.relative(parent, child);
  return relative !== "" && !relative.startsWith(`..${path.sep}`)
    && relative !== ".." && !path.isAbsolute(relative);
}

function listFiles(root) {
  const results = [];
  const pending = [root];
  while (pending.length > 0) {
    const current = pending.pop();
    for (const name of fs.readdirSync(current)) {
      const absolute = path.join(current, name);
      const metadata = fs.lstatSync(absolute);
      if (metadata.isSymbolicLink()) {
        throw new Error(`Symbolic link source rejected: ${absolute}`);
      }
      if (metadata.isDirectory()) {
        pending.push(absolute);
      } else if (metadata.isFile()) {
        results.push(absolute);
      }
    }
  }
  return results;
}

function splitExpression(line) {
  const numbered = line.match(/^\s*(\d+)[.)]\s*(.*)$/u);
  if (!numbered) return null;
  const body = numbered[2];
  const chineseIndex = body.search(/[\u3400-\u4DBF\u4E00-\u9FFF]/u);
  if (chineseIndex < 0) return null;
  const russianRaw = body.slice(0, chineseIndex).trim();
  const chineseRaw = body.slice(chineseIndex).trim();
  if (!/[А-Яа-яЁё]/u.test(russianRaw)) return null;
  return {
    number: Number(numbered[1]),
    russianRaw,
    chineseRaw,
  };
}

function cleanRussian(value) {
  return value
    .replaceAll("**", "")
    .replaceAll("__", "")
    .replaceAll("`", "")
    .trim();
}

function cleanChinese(value) {
  return value
    .replaceAll("**", "")
    .replaceAll("__", "")
    .replaceAll("`", "")
    .trim();
}

function extractionForTopic(topic, sourceRoot) {
  const absolute = path.resolve(sourceRoot, topic.sourcePath);
  if (!isInside(absolute, sourceRoot)) {
    throw new Error(`Topic path escapes source root: ${topic.sourcePath}`);
  }
  const metadata = fs.lstatSync(absolute);
  if (metadata.isSymbolicLink() || !metadata.isFile()) {
    throw new Error(`Unsafe topic source: ${topic.sourcePath}`);
  }
  const bytes = fs.readFileSync(absolute);
  const content = bytes.toString("utf8");
  const lines = content.split(/\r?\n/u);
  const candidates = [];
  const excluded = [];
  let inDialogue = false;
  let dialogueHasContent = false;

  for (let index = 0; index < lines.length; index += 1) {
    const sourceText = lines[index];
    if (/^#{1,6}\s+.*Диалоги/iu.test(sourceText)) {
      inDialogue = true;
      dialogueHasContent = false;
      continue;
    }
    if (inDialogue && (/^#{1,6}\s+/u.test(sourceText)
      || /^##\s*关联笔记/u.test(sourceText))) {
      if (!dialogueHasContent) {
        excluded.push({
          topicID: topic.id,
          sourcePath: topic.sourcePath,
          lineNumber: index + 1,
          reason: "emptyDialogue",
        });
      }
      inDialogue = false;
    }
    if (inDialogue && /^\s*\d+[.)]\s*\S/u.test(sourceText)) {
      dialogueHasContent = true;
    }

    const expression = splitExpression(sourceText);
    if (!expression) continue;
    const russian = cleanRussian(expression.russianRaw);
    if (/[()[\]（）]/u.test(russian)
      || /(?:-лся\/-лась|-ла|-ла\/-ли|ты\/вы)/iu.test(russian)) {
      excluded.push({
        topicID: topic.id,
        sourcePath: topic.sourcePath,
        lineNumber: index + 1,
        reason: "variant",
      });
      continue;
    }
    if (/[[\]]/u.test(russian)
      || /[А-Яа-яЁё]\s*[（(][^)]*[）)]/u.test(russian)) {
      excluded.push({
        topicID: topic.id,
        sourcePath: topic.sourcePath,
        lineNumber: index + 1,
        reason: "mixedAnnotation",
      });
      continue;
    }
    const idHash = sha256(
      `${topic.id}\0${index + 1}\0${sourceText}`,
    ).slice(0, 12);
    candidates.push({
      id: `candidate-${topic.id}-${idHash}`,
      topicID: topic.id,
      sourcePath: topic.sourcePath,
      sourceText,
      sourceHash: sha256(bytes),
      lineNumber: index + 1,
      promptZh: cleanChinese(expression.chineseRaw),
      practiceRu: russian,
      speechText: russian,
      reviewStatus: "draft",
      provenanceType: "courseMaterial",
      qualityFlags: ["mixedAnnotation"],
    });
  }
  if (inDialogue && !dialogueHasContent) {
    excluded.push({
      topicID: topic.id,
      sourcePath: topic.sourcePath,
      lineNumber: lines.length,
      reason: "emptyDialogue",
    });
  }
  return {
    snapshot: {
      topicID: topic.id,
      sourcePath: topic.sourcePath,
      sha256: sha256(bytes),
      byteCount: bytes.length,
    },
    candidates,
    excluded,
  };
}

function writeReport(destination, result) {
  const reasonCounts = Object.groupBy(
    result.excluded,
    (entry) => entry.reason,
  );
  const lines = [
    "# 长期俄语语料只读审查报告",
    "",
    `- topicsRead: ${result.snapshots.length}`,
    `- candidates: ${result.candidates.length}`,
    `- excluded: ${result.excluded.length}`,
    "",
    "## Exclusion counts",
    "",
  ];
  for (const reason of Object.keys(reasonCounts).sort()) {
    lines.push(`- ${reason}: ${reasonCounts[reason].length}`);
  }
  lines.push(
    "",
    "## Manual readback",
    "",
    "- reviewedCount: 0",
    "- accepted: []",
    "- rejected: []",
    "",
    "所有候选均保持 draft；本报告不改写原始笔记。",
    "",
  );
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, lines.join("\n"));
}

const args = parseArguments(process.argv.slice(2));
const sourceRoot = path.resolve(args["source-root"]);
const output = path.resolve(args.output);
const report = path.resolve(args.report);
if (output === sourceRoot || report === sourceRoot
  || isInside(output, sourceRoot) || isInside(report, sourceRoot)) {
  throw new Error("Derived outputs must stay outside the source root");
}
const topics = JSON.parse(fs.readFileSync(args.topics, "utf8"));
const allFiles = listFiles(sourceRoot);
const excluded = [];
for (const absolute of allFiles) {
  const relative = path.relative(sourceRoot, absolute);
  const key = normalizedPath(relative);
  if (key.includes("conflict")) {
    excluded.push({ sourcePath: relative, reason: "conflictSource" });
  } else if (key.includes("ai生成") || key.includes("ai generated")) {
    excluded.push({ sourcePath: relative, reason: "aiGeneratedSource" });
  }
}

const snapshots = [];
const candidates = [];
for (const topic of topics) {
  const extraction = extractionForTopic(topic, sourceRoot);
  snapshots.push(extraction.snapshot);
  candidates.push(...extraction.candidates);
  excluded.push(...extraction.excluded);
}
const result = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  sourceRoot,
  snapshots,
  candidates,
  excluded,
};
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`);
writeReport(report, result);
process.stdout.write(
  `topics=${snapshots.length} candidates=${candidates.length} `
  + `excluded=${excluded.length}\n`,
);
