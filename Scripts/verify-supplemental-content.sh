#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
knowledge_root="/Users/Openclawworkspace/Library/CloudStorage/OneDrive-个人/Documents/20-语言学习与专业/大学知识库（俄语学习+专业）"
resource_root="$repo_root/Sources/RussianCornerCore/Resources"

node - "$knowledge_root" "$resource_root" "$repo_root/Verification/supplemental-corpus-audit.md" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const [knowledgeRoot, resourceRoot, auditPath] = process.argv.slice(2);
const resourcePaths = {
  manifest: path.join(resourceRoot, "supplemental-manifest.json"),
  lexemes: path.join(resourceRoot, "supplemental-lexemes.json"),
  sentences: path.join(resourceRoot, "supplemental-sentences.json"),
  challenges: path.join(resourceRoot, "speaking-challenges.json"),
};
const failures = [];
for (const [name, resourcePath] of Object.entries(resourcePaths)) {
  if (!fs.existsSync(resourcePath)) {
    failures.push(`missing_resource:${name}`);
  }
}
if (failures.length > 0) {
  throw new Error(failures.join(","));
}

const readJSON = (value) => JSON.parse(fs.readFileSync(value, "utf8"));
const manifest = readJSON(resourcePaths.manifest);
const lexemes = readJSON(resourcePaths.lexemes);
const sentences = readJSON(resourcePaths.sentences);
const challenges = readJSON(resourcePaths.challenges);
const coreLexemes = readJSON(path.join(resourceRoot, "lexemes.json"));
const topics = readJSON(path.join(resourceRoot, "topics.json"));

const sha256 = (bytes) =>
  crypto.createHash("sha256").update(bytes).digest("hex");
const normalize = (value) =>
  value.normalize("NFD").replace(/\p{M}/gu, "").toLocaleLowerCase("ru-RU");
const isAllowedPath = (value) =>
  manifest.allowedSourceRoots.some(
    (root) => value === root || value.startsWith(`${root}/`),
  );
const excludedPath =
  /(?:专业俄语|俄语转录|conflict|双链|ai生成|化学|生物|物理|组织学|遗传|数学|统计|professional)/iu;
const cleanSpeechReject =
  /(?:[\u3400-\u9fff]|[*_`]|\[[^\]]*\]|\b(?:ты|вы)\s*\(|\([^)]*(?:\/|或|、)[^)]*\))/u;
const statuses = new Set(["reviewed", "verified"]);

if (manifest.schemaVersion !== 1 || manifest.contentGateClosed !== true) {
  failures.push("manifest_gate");
}
if (lexemes.length < 80 || lexemes.length > 150) {
  failures.push(`lexeme_count:${lexemes.length}`);
}
if (sentences.length < 60 || sentences.length > 100) {
  failures.push(`sentence_count:${sentences.length}`);
}
if (challenges.length < 20) {
  failures.push(`challenge_count:${challenges.length}`);
}
if (
  manifest.reviewedLexemeCount !== lexemes.length ||
  manifest.reviewedSentenceCount !== sentences.length
) {
  failures.push("manifest_count_mismatch");
}

const idsAreUnique = (items) =>
  new Set(items.map((item) => item.id)).size === items.length;
if (!idsAreUnique(lexemes)) failures.push("duplicate_lexeme_id");
if (!idsAreUnique(sentences)) failures.push("duplicate_sentence_id");
if (!idsAreUnique(challenges)) failures.push("duplicate_challenge_id");

const topicsByID = new Set(topics.map((item) => item.id));
const coreByLemma = new Map(coreLexemes.map((item) => [normalize(item.lemma), item.id]));
const coreByID = new Map(coreLexemes.map((item) => [item.id, item]));
const sentenceByID = new Map(sentences.map((item) => [item.id, item]));
const knownLexemeIDs = new Set([
  ...coreLexemes.map((item) => item.id),
  ...lexemes.map((item) => item.id),
]);
const sourceCache = new Map();

function validateSource(sourcePath, sourceHash, sourceText, itemID) {
  if (!isAllowedPath(sourcePath) || excludedPath.test(sourcePath)) {
    failures.push(`unsafe_source:${itemID}`);
    return;
  }
  const absolute = path.join(knowledgeRoot, sourcePath);
  if (!fs.existsSync(absolute) || fs.lstatSync(absolute).isSymbolicLink()) {
    failures.push(`missing_source:${itemID}`);
    return;
  }
  if (!sourceCache.has(sourcePath)) {
    const bytes = fs.readFileSync(absolute);
    sourceCache.set(sourcePath, {
      hash: sha256(bytes),
      text: bytes.toString("utf8"),
    });
  }
  const source = sourceCache.get(sourcePath);
  if (
    source.hash !== sourceHash ||
    manifest.sourceHashes[sourcePath] !== sourceHash
  ) {
    failures.push(`source_hash:${itemID}`);
  }
  if (!sourceText || !source.text.includes(sourceText)) {
    failures.push(`source_text:${itemID}`);
  }
}

for (const item of lexemes) {
  if (
    !statuses.has(item.reviewStatus) ||
    item.corpusLayer !== "dailySupplement" ||
    item.qualityFlags.length !== 0 ||
    item.provenanceTypes.includes("aiGenerated")
  ) {
    failures.push(`unsafe_lexeme:${item.id}`);
  }
  if (
    !item.lemma ||
    !item.stressedForm ||
    !item.speechText ||
    !item.glossZh ||
    !item.partOfSpeech ||
    item.collocations.length === 0 ||
    !item.example ||
    item.sentenceIDs.length === 0 ||
    item.sourcePaths.length === 0 ||
    item.sourcePaths.length !== item.sourceTexts.length
  ) {
    failures.push(`incomplete_lexeme:${item.id}`);
  }
  const learningForms = [item.lemma, ...item.surfaceForms].map(normalize);
  if (!learningForms.some((form) => normalize(item.example).includes(form))) {
    failures.push(`example_missing_form:${item.id}`);
  }
  if (!item.collocations.every((collocation) =>
    learningForms.some((form) => normalize(collocation).includes(form))
  )) {
    failures.push(`collocation_missing_form:${item.id}`);
  }
  if (
    item.partOfSpeech === "noun" &&
    !item.grammaticalGender
  ) {
    failures.push(`noun_gender:${item.id}`);
  }
  if (
    item.partOfSpeech === "verb" &&
    (
      !item.aspect ||
      (!item.aspectPair && !item.aspectPairNote) ||
      !item.government
    )
  ) {
    failures.push(`verb_grammar:${item.id}`);
  }
  const vowelCount = (item.lemma.match(/[аеёиоуыэюя]/giu) ?? []).length;
  if (
    vowelCount > 1 &&
    !item.stressedForm.includes("\u0301") &&
    !/[ёЁ]/u.test(item.stressedForm)
  ) {
    failures.push(`lexeme_stress:${item.id}`);
  }
  const coreID = coreByLemma.get(normalize(item.lemma));
  if (coreID && coreID !== item.id) {
    failures.push(`duplicate_core_lemma:${item.id}`);
  }
  if (coreByID.has(item.id) &&
      normalize(coreByID.get(item.id).lemma) !== normalize(item.lemma)) {
    failures.push(`changed_core_lemma:${item.id}`);
  }
  for (const sentenceID of item.sentenceIDs) {
    if (!sentenceByID.has(sentenceID)) {
      failures.push(`missing_lexeme_sentence:${item.id}`);
    }
  }
  for (let index = 0; index < item.sourcePaths.length; index += 1) {
    validateSource(
      item.sourcePaths[index],
      manifest.sourceHashes[item.sourcePaths[index]],
      item.sourceTexts[index],
      item.id,
    );
  }
}

for (const item of sentences) {
  if (
    !statuses.has(item.reviewStatus) ||
    item.corpusLayer !== "dailySupplement" ||
    item.provenanceType === "aiGenerated" ||
    item.qualityFlags.length !== 0
  ) {
    failures.push(`unsafe_sentence:${item.id}`);
  }
  if (
    !item.promptZh ||
    !item.cueRu ||
    !item.practiceRu ||
    !item.stressedForm ||
    !item.speechText ||
    item.practiceRu !== item.speechText ||
    cleanSpeechReject.test(item.speechText) ||
    cleanSpeechReject.test(item.stressedForm) ||
    !/[\u0301ёЁ]/u.test(item.stressedForm) ||
    !item.dialogueAct ||
    !item.register ||
    !item.speakerRole ||
    !item.addressForm ||
    !item.expectedReply ||
    item.lexemeIDs.length === 0 ||
    !topicsByID.has(item.topicID)
  ) {
    failures.push(`incomplete_sentence:${item.id}`);
  }
  if (!item.lexemeIDs.every((id) => knownLexemeIDs.has(id))) {
    failures.push(`missing_sentence_lexeme:${item.id}`);
  }
  validateSource(item.sourcePath, item.sourceHash, item.sourceText, item.id);
}

for (const item of challenges) {
  if (
    !statuses.has(item.reviewStatus) ||
    item.provenanceType === "aiGenerated" ||
    item.qualityFlags.length !== 0 ||
    !item.promptRu ||
    !item.promptZh ||
    item.structureHintsZh.length === 0 ||
    !item.lexemeIDs.every((id) => knownLexemeIDs.has(id))
  ) {
    failures.push(`incomplete_challenge:${item.id}`);
  }
  validateSource(item.sourcePath, item.sourceHash, item.sourceText, item.id);
}

const audit = fs.existsSync(auditPath)
  ? fs.readFileSync(auditPath, "utf8")
  : "";
if (
  !audit.includes("人工回读") ||
  !audit.includes("句子：30") ||
  !audit.includes("词条：30")
) {
  failures.push("manual_readback_missing");
}

if (failures.length > 0) {
  const preview = failures.slice(0, 30).join(",");
  throw new Error(
    `${preview}${failures.length > 30 ? ` (+${failures.length - 30})` : ""}`,
  );
}

console.log(
  `supplemental_content=PASS lexemes=${lexemes.length} ` +
  `sentences=${sentences.length} challenges=${challenges.length} ` +
  `sources=${sourceCache.size}`,
);
NODE
