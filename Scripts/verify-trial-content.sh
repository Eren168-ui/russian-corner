#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname -- "$0")"
  pwd -P
)
REPO_ROOT=$(
  CDPATH= cd -- "$SCRIPT_DIR/.."
  pwd -P
)
SLICE="$REPO_ROOT/Sources/RussianCornerCore/Resources/trial-slice.json"
SOURCE_ROOT="/Users/Openclawworkspace/Library/CloudStorage/OneDrive-个人/Documents/20-语言学习与专业/大学知识库（俄语学习+专业）/01-按学期/大一下——莫斯科/口语Диалоги"

if [ ! -f "$SLICE" ] || [ -L "$SLICE" ]; then
  printf 'trial_content=FAIL reason=missing_or_unsafe_slice\n' >&2
  exit 1
fi

declared_root=$(jq -r '.sourceRoot' "$SLICE")
sentence_count=$(jq '.sentences | length' "$SLICE")
lexeme_count=$(jq '.lexemeReviews | length' "$SLICE")
card_count=$((sentence_count + lexeme_count))
manual_count=$(jq '[.manualReviewSampleIDs[]] | unique | length' "$SLICE")

if [ "$declared_root" != "$SOURCE_ROOT" ] ||
  [ "$card_count" -lt 50 ] ||
  [ "$card_count" -gt 80 ] ||
  [ "$manual_count" -lt 30 ]; then
  printf \
    'trial_content=FAIL root_or_counts sentences=%s lexemes=%s manual=%s\n' \
    "$sentence_count" \
    "$lexeme_count" \
    "$manual_count" \
    >&2
  exit 1
fi

if jq -e '
  .sentences[]
  | select(
      (.reviewStatus != "reviewed" and .reviewStatus != "verified")
      or (.practiceRu | length == 0)
      or (.stressedForm | length == 0)
      or (.speechText | length == 0)
      or (.sourcePath | length == 0)
      or (.sourceText | length == 0)
      or (.dialogueAct | length == 0)
      or (.speakerRole | length == 0)
      or (.expectedReply | length == 0)
    )
' "$SLICE" >/dev/null; then
  printf 'trial_content=FAIL reason=incomplete_trial_card\n' >&2
  exit 1
fi

if jq -e '
  .sentences[]
  | select(
      (.speechText | test("[\\[\\]\\(\\)（）/*_#`]"))
      or (.practiceRu | test("[\\[\\]\\(\\)（）/*_#`]"))
      or (.speechText | test("[一-龥]"))
      or (.practiceRu | test("[一-龥]"))
    )
' "$SLICE" >/dev/null; then
  printf 'trial_content=FAIL reason=unsafe_speech_text\n' >&2
  exit 1
fi

word_entry_count=$(jq '.wordEntries | length' "$SLICE")
word_token_count=$(jq '.sentenceWordTokens | length' "$SLICE")
unique_word_entry_count=$(jq '[.wordEntries[].id] | unique | length' "$SLICE")

if [ "$word_entry_count" -eq 0 ] ||
  [ "$word_entry_count" -ne "$unique_word_entry_count" ]; then
  printf 'trial_content=FAIL reason=missing_or_duplicate_word_entries\n' >&2
  exit 1
fi

if jq -e '
  .wordEntries[]
  | select(
      (.reviewStatus != "reviewed" and .reviewStatus != "verified")
      or (.lookupForm | length == 0)
      or (.stressedForm | length == 0)
      or (.lemma | length == 0)
      or (.glossZh | length == 0)
      or (.partOfSpeech | length == 0)
      or (.usageNote | length == 0)
      or (.provenanceType == "aiGenerated")
      or (.qualityFlags | any(
        . == "typo"
        or . == "grammarSuspect"
        or . == "unnatural"
        or . == "incomplete"
        or . == "emptyDialogue"
        or . == "needsNativeReview"
      ))
    )
' "$SLICE" >/dev/null; then
  printf 'trial_content=FAIL reason=unsafe_word_entry\n' >&2
  exit 1
fi

node - "$SLICE" <<'NODE'
const fs = require("node:fs");
const slice = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const entries = new Map(slice.wordEntries.map((entry) => [entry.id, entry]));
const tokensByCard = new Map();
for (const token of slice.sentenceWordTokens) {
  if (!entries.has(token.wordEntryID) || !token.morphology?.trim()) {
    throw new Error(`invalid word token ${token.cardID}:${token.tokenIndex}`);
  }
  const list = tokensByCard.get(token.cardID) ?? [];
  list.push(token);
  tokensByCard.set(token.cardID, list);
}
const russianWords = (text) =>
  text.match(/[А-Яа-яЁё\u0301]+/gu) ?? [];
const normalized = (value) =>
  value.normalize("NFD").replace(/\u0301/gu, "").toLocaleLowerCase("ru");
for (const sentence of slice.sentences) {
  const words = russianWords(sentence.practiceRu);
  const tokens = (tokensByCard.get(sentence.id) ?? [])
    .sort((a, b) => a.tokenIndex - b.tokenIndex);
  if (tokens.length !== words.length) {
    throw new Error(`word coverage mismatch ${sentence.id}`);
  }
  tokens.forEach((token, index) => {
    if (
      token.tokenIndex !== index ||
      normalized(token.surfaceText) !== normalized(words[index])
    ) {
      throw new Error(`word order mismatch ${sentence.id}:${index}`);
    }
  });
}
NODE

while IFS=$'\t' read -r card_id source_path source_text; do
  case "$source_path" in
    具体场景对话/*)
      ;;
    *)
      printf 'trial_content=FAIL card=%s reason=source_outside_allowlist\n' \
        "$card_id" >&2
      exit 1
      ;;
  esac
  case "$source_path" in
    *conflict* | *AI生成* | *ai生成*)
      printf 'trial_content=FAIL card=%s reason=excluded_source\n' \
        "$card_id" >&2
      exit 1
      ;;
  esac
  source_file="$SOURCE_ROOT/$source_path"
  if [ ! -f "$source_file" ] || [ -L "$source_file" ]; then
    printf 'trial_content=FAIL card=%s reason=missing_source\n' \
      "$card_id" >&2
    exit 1
  fi
  if ! grep -Fq -- "$source_text" "$source_file"; then
    printf 'trial_content=FAIL card=%s reason=source_text_mismatch\n' \
      "$card_id" >&2
    exit 1
  fi
done < <(
  jq -r '.sentences[] | [.id,.sourcePath,.sourceText] | @tsv' "$SLICE"
)

printf \
  'trial_content=PASS cards=%s sentences=%s lexemes=%s manual_readback=%s word_entries=%s word_tokens=%s\n' \
  "$card_count" \
  "$sentence_count" \
  "$lexeme_count" \
  "$manual_count" \
  "$word_entry_count" \
  "$word_token_count"
