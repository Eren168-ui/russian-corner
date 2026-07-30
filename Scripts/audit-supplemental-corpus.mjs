#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const defaultKnowledgeRoot =
  "/Users/Openclawworkspace/Library/CloudStorage/OneDrive-个人/Documents/20-语言学习与专业/大学知识库（俄语学习+专业）";

const allowedRootSuffixes = [
  "01-按学期/大一下——莫斯科/基础俄语",
  "01-按学期/大二上/基础俄语",
  "01-按学期/！大二下/俄语",
];

function parseArguments(argv) {
  const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
  const repositoryRoot = path.resolve(scriptDirectory, "..");
  const values = {
    knowledgeRoot: defaultKnowledgeRoot,
    jsonOutput: path.join(
      repositoryRoot,
      "Verification/supplemental-corpus-candidates.json",
    ),
    reportOutput: path.join(
      repositoryRoot,
      "Verification/supplemental-corpus-audit.md",
    ),
  };

  for (let index = 0; index < argv.length; index += 1) {
    const option = argv[index];
    const value = argv[index + 1];
    if (!value) {
      throw new Error(`missing value for ${option}`);
    }
    if (option === "--knowledge-root") {
      values.knowledgeRoot = value;
    } else if (option === "--json-output") {
      values.jsonOutput = value;
    } else if (option === "--report-output") {
      values.reportOutput = value;
    } else {
      throw new Error(`unknown option: ${option}`);
    }
    index += 1;
  }
  return values;
}

function normalizedRelative(root, absolute) {
  return path.relative(root, absolute).split(path.sep).join("/");
}

function exclusionReason(relativePath) {
  if (/conflict/iu.test(relativePath)) {
    return "conflictCopy";
  }
  if (/(?:AI\s*生成|AI生成|口语练习计划\s*AI|aiGenerated)/iu.test(relativePath)) {
    return "aiGeneratedPlan";
  }
  if (/(?:俄语转录|课堂转录|转录稿|transcript)/iu.test(relativePath)) {
    return "transcriptSource";
  }
  if (/(?:双链|旧\s*AI\s*练习计划|报告)/iu.test(relativePath)) {
    return "generatedReport";
  }
  if (
    /(?:专业俄语|专业词汇|化学|生物|物理|组织学|遗传|解剖|医学|药理|病理|统计|数学|professional)/iu.test(
      relativePath,
    )
  ) {
    return "professionalSource";
  }
  return null;
}

function isInsideAllowedRoot(relativePath) {
  return allowedRootSuffixes.some(
    (root) => relativePath === root || relativePath.startsWith(`${root}/`),
  );
}

function collectMarkdownFiles(knowledgeRoot) {
  const files = [];
  const excluded = [];
  const pending = [knowledgeRoot];

  while (pending.length > 0) {
    const current = pending.pop();
    const metadata = fs.lstatSync(current);
    const relative = normalizedRelative(knowledgeRoot, current);

    if (metadata.isSymbolicLink()) {
      excluded.push({
        sourcePath: relative || ".",
        reason: "unsafeFile",
      });
      continue;
    }
    if (metadata.isDirectory()) {
      const children = fs
        .readdirSync(current)
        .sort((left, right) => right.localeCompare(left, "zh-Hans-CN"));
      for (const child of children) {
        pending.push(path.join(current, child));
      }
      continue;
    }
    if (!metadata.isFile() || path.extname(current).toLowerCase() !== ".md") {
      continue;
    }

    const reason = exclusionReason(relative);
    if (reason) {
      excluded.push({ sourcePath: relative, reason });
      continue;
    }
    if (!isInsideAllowedRoot(relative)) {
      excluded.push({ sourcePath: relative, reason: "outsideAllowlist" });
      continue;
    }
    files.push({ absolute: current, relative });
  }

  return {
    files: files.sort((left, right) =>
      left.relative.localeCompare(right.relative, "zh-Hans-CN")
    ),
    excluded: excluded.sort((left, right) =>
      left.sourcePath.localeCompare(right.sourcePath, "zh-Hans-CN")
    ),
  };
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

function candidateFragments(line) {
  const trimmed = line.trim();
  if (!trimmed || /^(?:#{1,6}\s*)?$/.test(trimmed)) {
    return [];
  }

  if (trimmed.startsWith("|") && trimmed.endsWith("|")) {
    return trimmed
      .slice(1, -1)
      .split("|")
      .map((cell) => cell.trim())
      .filter(Boolean);
  }

  return [
    trimmed
      .replace(/^(?:[-*+]>?|\d+[.)])\s+/, "")
      .replace(/^>\s*/, "")
      .trim(),
  ];
}

function isRussianCandidate(fragment) {
  const withoutMarkdown = fragment
    .replace(/[*_`~]/g, "")
    .replace(/\[\[|\]\]/g, "")
    .trim();
  const words = withoutMarkdown.match(/[А-ЯЁа-яё-]+/gu) ?? [];
  if (words.length < 3) {
    return false;
  }
  if (!/[А-ЯЁа-яё]/u.test(withoutMarkdown)) {
    return false;
  }
  if (/^(?:тема|урок|вопрос|ответ|слова)\b/iu.test(withoutMarkdown) &&
      words.length < 5) {
    return false;
  }
  return withoutMarkdown.length >= 18;
}

function inferQualityFlags(line, fragment) {
  const flags = ["needsNativeReview"];
  if (
    /[\u3400-\u9fff]/u.test(line) ||
    /(?:\[[^\]]+\]|\([^)]*(?:\/|或|、)[^)]*\)|[*_`])/u.test(line) ||
    fragment !== line.trim()
  ) {
    flags.push("mixedAnnotation");
  }
  return flags;
}

function extractCandidates(file) {
  const bytes = fs.readFileSync(file.absolute);
  const text = bytes.toString("utf8");
  const sourceHash = sha256(bytes);
  const candidates = [];

  for (const [lineIndex, sourceText] of text.split(/\r?\n/u).entries()) {
    for (const fragment of candidateFragments(sourceText)) {
      if (!isRussianCandidate(fragment)) {
        continue;
      }
      candidates.push({
        candidateText: fragment,
        reviewStatus: "draft",
        sourcePath: file.relative,
        sourceText,
        sourceLine: lineIndex + 1,
        sourceHash,
        provenanceType: "userNote",
        qualityFlags: inferQualityFlags(sourceText, fragment),
      });
    }
  }

  return { candidates, sourceHash };
}

function markdownEscape(value) {
  return String(value).replaceAll("|", "\\|").replaceAll("\n", " ");
}

function createReport(audit) {
  const reasonCounts = new Map();
  for (const item of audit.excluded) {
    reasonCounts.set(item.reason, (reasonCounts.get(item.reason) ?? 0) + 1);
  }

  const lines = [
    "# 俄语补充语料只读审查",
    "",
    `- 审查根目录：\`${audit.knowledgeRoot}\``,
    `- 允许来源文件：${audit.scannedFiles.length}`,
    `- 草稿候选：${audit.candidates.length}`,
    `- 排除文件：${audit.excluded.length}`,
    "- 所有候选均保持 `draft`，不会直接进入学习队列。",
    "",
    "## 允许来源",
    "",
    ...audit.allowedSourceRoots.map((root) => `- \`${root}\``),
    "",
    "## 排除统计",
    "",
    "| 原因 | 文件数 |",
    "| --- | ---: |",
    ...[...reasonCounts.entries()]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([reason, count]) => `| ${reason} | ${count} |`),
    "",
    "## 逐文件排除记录",
    "",
    "| 路径 | 原因 |",
    "| --- | --- |",
    ...audit.excluded.map(
      (item) =>
        `| ${markdownEscape(item.sourcePath)} | ${markdownEscape(item.reason)} |`,
    ),
    "",
  ];
  return `${lines.join("\n")}\n`;
}

function writeFileSafely(outputPath, content) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, content);
}

function main() {
  const options = parseArguments(process.argv.slice(2));
  const knowledgeRoot = path.resolve(options.knowledgeRoot);
  const rootMetadata = fs.lstatSync(knowledgeRoot);
  if (!rootMetadata.isDirectory() || rootMetadata.isSymbolicLink()) {
    throw new Error(`unsafe knowledge root: ${knowledgeRoot}`);
  }

  const collected = collectMarkdownFiles(knowledgeRoot);
  const candidates = [];
  const sourceHashes = {};
  for (const file of collected.files) {
    const extracted = extractCandidates(file);
    candidates.push(...extracted.candidates);
    sourceHashes[file.relative] = extracted.sourceHash;
  }

  const audit = {
    schemaVersion: 1,
    knowledgeRoot,
    allowedSourceRoots: allowedRootSuffixes,
    scannedFiles: collected.files.map((file) => file.relative),
    sourceHashes,
    candidates,
    excluded: collected.excluded,
  };

  writeFileSafely(
    path.resolve(options.jsonOutput),
    `${JSON.stringify(audit, null, 2)}\n`,
  );
  writeFileSafely(
    path.resolve(options.reportOutput),
    createReport(audit),
  );
  process.stdout.write(
    `supplemental_candidates=${candidates.length} excluded=${collected.excluded.length}\n`,
  );
}

try {
  main();
} catch (error) {
  process.stderr.write(`supplemental_audit=FAIL ${error.message}\n`);
  process.exitCode = 1;
}
