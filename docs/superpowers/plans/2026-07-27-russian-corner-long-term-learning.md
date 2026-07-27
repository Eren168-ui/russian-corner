# Russian Corner Long-Term Learning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 35-sentence seven-day trial boundary with a safe long-term system that schedules all 32 notebook topics indefinitely and makes every Russian word clickable, including words without prebuilt analysis.

**Architecture:** Preserve the read-only Obsidian source and existing progress stores. Add a reviewed long-term content manifest, a universal token-resolution pipeline with explicit quality levels, a deterministic topic selector, and a read-only incremental source scanner whose new findings remain draft candidates. The existing trial slice remains only as a regression fixture; it no longer controls the production queue.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SwiftData, Foundation, Security/Keychain, Codable JSON, Node.js content audit scripts, XCTest, SwiftPM.

---

## File map

### Core

- Create `Sources/RussianCornerCore/LongTermContent.swift`: topic definitions, long-term manifest, universal word-resolution source and catalog summary models.
- Create `Sources/RussianCornerCore/TopicScheduler.swift`: daily primary-topic selection and 60-day deterministic rotation.
- Create `Sources/RussianCornerCore/Resources/topics.json`: the 32 real notebook topics.
- Create `Sources/RussianCornerCore/Resources/long-term-sentences.json`: at least 200 reviewed expressions from all 32 topics.
- Modify `Sources/RussianCornerCore/Models.swift`: add `topicID`, `sourceHash`, and word-analysis quality without changing existing IDs.
- Modify `Sources/RussianCornerCore/ContentCatalog.swift`: load long-term resources, stop serving from `trialSlice`, validate all topics and resolve every token.
- Modify `Sources/RussianCornerCore/DailyQueue.swift`: build due-first queues with primary-topic fresh expressions.
- Modify `Sources/RussianCornerCore/TrialReportBuilder.swift`: rename user-facing report to rolling learning report.

### Platform

- Create `Sources/RussianCornerPlatform/SourceCorpusScanner.swift`: read-only allowlisted scanner and incremental candidate extractor.
- Create `Sources/RussianCornerPlatform/CandidateCorpusStore.swift`: local JSON snapshot outside the original vault.
- Keep `Sources/RussianCornerPlatform/YandexDictionaryService.swift`: online fallback for unresolved surface forms.

### UI and app

- Modify `Sources/RussianCornerUI/InteractiveRussianText.swift`: link every token without requiring a prebuilt analysis.
- Modify `Sources/RussianCornerUI/PracticeViewModel.swift`: use long-term sentences, daily topic and universal fallback analysis.
- Modify `Sources/RussianCornerUI/PracticeDetailSection.swift`: label reviewed-context, reviewed-lexeme, online-unreviewed and unavailable states.
- Modify `Sources/RussianCornerUI/AppModel.swift`: run daily source scan, expose topic/content status, preserve existing progress.
- Modify `Sources/RussianCornerUI/SettingsView.swift`: show long-term corpus and sync status.
- Modify `Sources/RussianCornerUI/ProgressView.swift`: show 32-topic coverage and weakest topics.
- Modify `Sources/RussianCornerUI/TrialReportExporter.swift`: rolling seven-day learning report names.
- Modify `Sources/RussianCornerApp/RussianCornerApp.swift`: topic menu and non-trial wording.

### Content tooling and verification

- Create `Scripts/audit-long-term-corpus.mjs`: extract candidates, validate reviewed manifest and report exclusions.
- Create `Scripts/verify-long-term-content.sh`: enforce 32 topics, at least 200 expressions, per-topic floor and source integrity.
- Modify `Scripts/build-app.sh`: copy and probe the new resources.
- Modify `Sources/RussianCornerResourceProbe/main.swift`: validate long-term counts.
- Modify packaging tests and user documentation.

---

### Task 1: Universal clickable-token contract

**Files:**
- Modify: `Sources/RussianCornerCore/Models.swift`
- Modify: `Sources/RussianCornerCore/ContentCatalog.swift`
- Modify: `Sources/RussianCornerUI/InteractiveRussianText.swift`
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`
- Modify: `Sources/RussianCornerUI/PracticeDetailSection.swift`
- Test: `Tests/RussianCornerCoreTests/UniversalWordResolutionTests.swift`
- Test: `Tests/RussianCornerAppTests/InteractiveRussianTextTests.swift`

- [ ] **Step 1: Write failing tests for an unmapped sentence**

Add a sentence that is not in `trial-slice.json`:

```swift
func testUnknownSentenceStillResolvesEveryRussianToken() throws {
    let sentence = SentenceCard(
        id: "future-sentence",
        promptZh: "说明计划改变了。",
        practiceRu: "Наши планы неожиданно изменились.",
        speechText: "Наши планы неожиданно изменились.",
        theme: "future",
        lexemeIDs: [],
        sourcePath: "future/source.md",
        sourceText: "Наши планы неожиданно изменились.",
        reviewStatus: .reviewed
    )
    let catalog = ContentCatalog(lexemes: [], sentences: [sentence])

    let analyses = catalog.wordAnalyses(for: sentence)

    XCTAssertEqual(analyses.count, 4)
    XCTAssertEqual(analyses.map(\.surfaceText), [
        "Наши", "планы", "неожиданно", "изменились",
    ])
    XCTAssertTrue(analyses.allSatisfy { $0.source == .unavailable })
}
```

Extend the attributed-text test:

```swift
func testBuilderLinksWordsEvenWhenAnalysesAreEmpty() {
    let value = InteractiveRussianTextBuilder.make(
        text: "Новый разговор.",
        analyses: [],
        selectedTokenIndex: nil
    )
    XCTAssertEqual(value.runs.compactMap(\.link).count, 2)
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
swift test --filter 'UniversalWordResolutionTests|InteractiveRussianTextTests/testBuilderLinksWordsEvenWhenAnalysesAreEmpty'
```

Expected: compile failure for `ResolvedWordAnalysis.source` and `wordAnalyses(for: SentenceCard)`, plus a link-count failure because the builder currently checks `byIndex[index] != nil`.

- [ ] **Step 3: Add explicit analysis-source states**

Add to `Models.swift`:

```swift
public enum WordAnalysisSource: String, Codable, Equatable, Sendable {
    case reviewedContext
    case reviewedLexeme
    case onlineUnreviewed
    case unavailable
}
```

Add `source: WordAnalysisSource` to `ResolvedWordAnalysis`, defaulting to `.reviewedContext` in its initializer so existing call sites remain source-compatible.

- [ ] **Step 4: Make the attributed builder link every Russian word**

In `InteractiveRussianTextBuilder.make`, remove the analysis-presence guard:

```swift
func linked(_ value: String, index: Int) -> AttributedString {
    var result = AttributedString(value)
    if let url = URL(string: "\(scheme)://\(host)/\(index)") {
        result.link = url
        result.underlineStyle = .single
        if selectedTokenIndex == index {
            result.inlinePresentationIntent = .stronglyEmphasized
        }
    }
    return result
}
```

The builder must not synthesize links for punctuation or Chinese text.

- [ ] **Step 5: Resolve every token with a safe fallback**

Add `ContentCatalog.wordAnalyses(for sentence: SentenceCard)`:

```swift
public func wordAnalyses(
    for sentence: SentenceCard
) -> [ResolvedWordAnalysis] {
    let exact = exactWordAnalysesByCardID[sentence.id] ?? [:]
    return RussianWordTokenizer.words(in: sentence.practiceRu)
        .enumerated()
        .map { index, surface in
            if let value = exact[index] {
                return value
            }
            if let lexeme = matchingLexeme(for: surface) {
                return ResolvedWordAnalysis(
                    cardID: sentence.id,
                    tokenIndex: index,
                    surfaceText: surface,
                    stressedForm: lexeme.stressedForm,
                    lemma: lexeme.lemma,
                    glossZh: lexeme.glossZh,
                    partOfSpeech: lexeme.partOfSpeech,
                    morphology: "当前词形：\(surface)",
                    aspectPair: lexeme.aspectPair,
                    government: lexeme.government,
                    collocations: lexeme.collocations,
                    usageNote: "通用审核词条；本句词形尚无人工语境解析",
                    lexemeID: lexeme.id,
                    reviewStatus: lexeme.reviewStatus,
                    source: .reviewedLexeme
                )
            }
            return ResolvedWordAnalysis(
                cardID: sentence.id,
                tokenIndex: index,
                surfaceText: surface,
                stressedForm: surface,
                lemma: Self.normalizedForm(surface),
                glossZh: "本地暂无审核释义",
                partOfSpeech: "待查询",
                morphology: "当前词形：\(surface)",
                usageNote: "可查询在线词典；在线结果不会自动标记为已审核",
                reviewStatus: .draft,
                source: .unavailable
            )
        }
}
```

Build `exactWordAnalysesByCardID` once during catalog initialization by grouping
the existing reviewed `ResolvedWordAnalysis` records by `cardID` and
`tokenIndex`. Build `matchingLexeme` from normalized lemmas and explicitly
declared surface forms. Do not guess declensions or aspect pairs.

- [ ] **Step 6: Let the view model select fallback tokens**

Build `wordAnalysesByCardID` with `catalog.wordAnalyses(for: sentence)`. When a fallback is selected, query Yandex using `surfaceText`, not the unverified normalized lemma. Keep the local fallback visible while loading.

- [ ] **Step 7: Label quality in the detail view**

Render:

```swift
switch word.source {
case .reviewedContext:
    Text("本句人工审核")
case .reviewedLexeme:
    Text("本地审核词条 · 本句词形未专项审核")
case .onlineUnreviewed:
    Text("在线词典结果 · 未人工审核")
case .unavailable:
    Text("本地暂无审核解析")
}
```

Online lookup results remain in `OnlineWordLookupState.result`; they do not mutate the local `reviewStatus`.

- [ ] **Step 8: Run focused and full tests**

Run:

```bash
swift test --filter 'UniversalWordResolutionTests|InteractiveRussianTextTests|PracticeViewModelTests'
swift test -Xswiftc -warnings-as-errors
```

Expected: all tests pass, and every temporary unknown Russian token has a clickable link.

- [ ] **Step 9: Commit**

```bash
git add Sources/RussianCornerCore Sources/RussianCornerUI Tests
git commit -m "feat: make every Russian word universally clickable"
```

---

### Task 2: Long-term topic and content models

**Files:**
- Create: `Sources/RussianCornerCore/LongTermContent.swift`
- Create: `Sources/RussianCornerCore/Resources/topics.json`
- Create: `Sources/RussianCornerCore/Resources/long-term-sentences.json`
- Modify: `Sources/RussianCornerCore/Models.swift`
- Modify: `Sources/RussianCornerCore/ContentCatalog.swift`
- Test: `Tests/RussianCornerCoreTests/LongTermContentTests.swift`

- [ ] **Step 1: Write failing resource-contract tests**

```swift
func testLongTermManifestCoversAllThirtyTwoTopics() throws {
    let catalog = try ContentCatalog(
        resourceDirectory: sourceResourceDirectory
    )
    XCTAssertEqual(catalog.topics.count, 32)
    XCTAssertEqual(Set(catalog.topics.map(\.number)), Set(1...32))
}

func testTrialSliceNoLongerControlsPracticeContent() throws {
    let catalog = try ContentCatalog(
        resourceDirectory: sourceResourceDirectory
    )
    XCTAssertEqual(catalog.practiceSentences, catalog.longTermSentences)
    XCTAssertEqual(catalog.practiceSentences.count, 35)
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
swift test --filter LongTermContentTests
```

Expected: compile failure because `topics`, `longTermSentences`, and `SentenceCard.topicID` do not exist.

- [ ] **Step 3: Add topic and manifest types**

Create:

```swift
public struct TopicDefinition:
    Identifiable, Codable, Equatable, Sendable
{
    public let id: String
    public let number: Int
    public let titleRu: String
    public let titleZh: String
    public let sourcePath: String
}

public struct LongTermContentManifest:
    Codable, Equatable, Sendable
{
    public let schemaVersion: Int
    public let sourceRoot: String
    public let sourceCorpusSHA256: String
    public let contentGateClosed: Bool
    public let sentences: [SentenceCard]
}
```

Add optional `topicID` and `sourceHash` to `SentenceCard` decoding. Existing 72 resource sentences decode with `topicID == nil`; long-term sentences require both fields during manifest validation.

- [ ] **Step 4: Create the exact 32-topic resource**

`topics.json` contains topic numbers 1 through 32 exactly once, with the source paths returned by:

```bash
obsidian files vault="Documents" \
  folder="20-语言学习与专业/大学知识库（俄语学习+专业）/01-按学期/大一下——莫斯科/口语Диалоги/具体场景对话"
```

Exclude `Диалоги(тема 1-8).md` as a topic source.

- [ ] **Step 5: Load long-term resources without deleting legacy resources**

`ContentCatalog` decodes:

```swift
let topics = try Self.decode(
    [TopicDefinition].self,
    resource: "topics",
    resourceDirectory: resourceDirectory,
    decoder: decoder
)
let longTermManifest = try Self.decode(
    LongTermContentManifest.self,
    resource: "long-term-sentences",
    resourceDirectory: resourceDirectory,
    decoder: decoder
)
let longTermSentences = longTermManifest.sentences
```

Set:

```swift
public var practiceSentences: [SentenceCard] {
    longTermSentences.filter {
        $0.reviewStatus == .reviewed || $0.reviewStatus == .verified
    }
}

public var practiceLexemes: [Lexeme] {
    lexemes
}
```

Keep `trialSlice` loaded only for regression and source-audit fixtures.

- [ ] **Step 6: Add fail-closed validation**

Validate:

- topic numbers are exactly `1...32`;
- topic IDs and source paths are unique;
- every long-term sentence references a known topic;
- if the manifest declares `contentGateClosed == true`, every topic has at
  least four reviewed sentences and the total is at least 200;
- `sourcePath`, `sourceText`, `sourceHash`, pragmatic metadata and clean Russian text are nonempty;
- disqualifying quality flags and unsafe provenance are rejected;
- stable IDs are unique and preserve the existing 35 trial IDs.

- [ ] **Step 7: Seed the manifest with the existing 35 reviewed sentences**

Copy the existing trial sentences without changing their IDs. Add correct
`topicID` and `sourceHash`, and declare `contentGateClosed == false`. The model
tests must pass with this explicit staging state; production queue construction
must reject a staging manifest until Task 7 closes the gate.

- [ ] **Step 8: Run model tests**

Run:

```bash
swift test --filter LongTermContentTests
```

Expected: all model tests pass and the manifest reports an explicit staging
state without being eligible for production scheduling.

- [ ] **Step 9: Commit**

```bash
git add Sources/RussianCornerCore Tests/RussianCornerCoreTests
git commit -m "feat: add long-term topic content model"
```

---

### Task 3: Read-only corpus audit and candidate extraction

**Files:**
- Create: `Scripts/audit-long-term-corpus.mjs`
- Create: `Scripts/verify-long-term-content.sh`
- Create: `Verification/long-term-corpus-candidates.json`
- Create: `Verification/long-term-corpus-audit.md`
- Modify: `Scripts/verify-source-corpus.sh`
- Test: `Tests/Content/audit-long-term-corpus.sh`

- [ ] **Step 1: Write a failing fixture test**

Create a temporary corpus with:

- one clean numbered bilingual expression;
- one `рад(а)` variant;
- one empty dialogue section;
- one `conflict` filename;
- one AI plan filename.

Assert the JSON report contains one candidate and four excluded records with exact reasons:

```text
variant
emptyDialogue
conflictSource
aiGeneratedSource
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
bash Tests/Content/audit-long-term-corpus.sh
```

Expected: failure because `Scripts/audit-long-term-corpus.mjs` does not exist.

- [ ] **Step 3: Implement the read-only audit**

The script accepts:

```bash
node Scripts/audit-long-term-corpus.mjs \
  --source-root "$SOURCE_ROOT" \
  --topics Sources/RussianCornerCore/Resources/topics.json \
  --output Verification/long-term-corpus-candidates.json \
  --report Verification/long-term-corpus-audit.md
```

It must:

- call `lstat` and reject symlink sources;
- read only the 32 allowlisted source paths;
- hash every source before extraction;
- retain `sourceText` byte-for-byte;
- split display, practice and speech text;
- mark all extracted items `draft`;
- never write inside `SOURCE_ROOT`;
- print candidate and exclusion totals without printing private source bodies.

- [ ] **Step 4: Run the real audit**

Run the script against the real OneDrive folder, then run:

```bash
bash Scripts/verify-source-corpus.sh
jq empty Verification/long-term-corpus-candidates.json
```

Expected: original file count and aggregate SHA-256 remain unchanged.

- [ ] **Step 5: Manually read back at least 60 candidates**

Record candidate IDs in `Verification/long-term-corpus-audit.md` under:

```markdown
## Manual readback

- reviewedCount: 60
- accepted: [...]
- rejected: [...]
- rejectionReasons:
  - grammarSuspect: N
  - unnatural: N
  - ambiguousTranslation: N
  - incomplete: N
```

Manual readback changes only the derived review file, never the source notes.

- [ ] **Step 6: Implement the incremental content validator**

`Scripts/verify-long-term-content.sh` accepts either `--topics 1-8` style
partial validation or no flag for the final gate. Partial validation enforces:

```text
requested_topics_present=all
minimum_per_requested_topic>=4
unknown_topic_references=0
unsafe_sources=0
dirty_speech_text=0
missing_pragmatic_metadata=0
source_mismatches=0
duplicate_ids=0
```

With no `--topics` flag it additionally requires 32 topics, at least 200
reviewed expressions and `contentGateClosed == true`.

- [ ] **Step 7: Run fixture and source-integrity tests**

```bash
bash Tests/Content/audit-long-term-corpus.sh
bash Scripts/verify-source-corpus.sh
```

Expected: both pass.

- [ ] **Step 8: Commit**

```bash
git add Scripts Tests/Content Verification
git commit -m "feat: audit long-term Russian source corpus"
```

---

### Task 4: Curate topics 1–8

**Files:**
- Modify: `Sources/RussianCornerCore/Resources/long-term-sentences.json`
- Modify: `Verification/long-term-corpus-audit.md`
- Test: `Scripts/verify-long-term-content.sh`

- [ ] **Step 1: Select reviewed expressions**

For each topic 1–8, select every candidate that has:

- one complete natural `practiceRu`;
- clean `speechText`;
- a Chinese intent prompt;
- a definite speaker role and address form;
- a natural expected reply;
- traceable `sourcePath`, `sourceText`, and `sourceHash`.

Split `ты/вы`, gender and formal/informal variants into independent cards.

- [ ] **Step 2: Add cards with stable IDs**

Use:

```text
longterm-t01-<source-line-hash-8>
...
longterm-t08-<source-line-hash-8>
```

Preserve the IDs of any existing trial sentences. Mark accepted cards `reviewed`, never `verified`.

- [ ] **Step 3: Run per-topic verification**

```bash
bash Scripts/verify-long-term-content.sh --topics 1-8
```

Expected: eight topics present, each with at least four reviewed expressions, no unsafe text, and every source quote found in its original file.

- [ ] **Step 4: Commit**

```bash
git add Sources/RussianCornerCore/Resources/long-term-sentences.json Verification
git commit -m "content: curate long-term topics 1 through 8"
```

---

### Task 5: Curate topics 9–16

**Files:**
- Modify: `Sources/RussianCornerCore/Resources/long-term-sentences.json`
- Modify: `Verification/long-term-corpus-audit.md`

- [ ] **Step 1: Review and add topics 9–16**

For every accepted expression in topics 9–16, require a complete natural
`practiceRu`, clean `speechText`, Chinese intent, definite speaker role,
address form, natural expected reply, and traceable `sourcePath`, `sourceText`
and `sourceHash`. Split `ты/вы`, gender, and formal/informal variants into
independent cards. Prioritize daily routine, shopping, telephone, services,
visiting, leisure, celebrations and hobbies.

- [ ] **Step 2: Run per-topic verification**

```bash
bash Scripts/verify-long-term-content.sh --topics 9-16
```

Expected: eight additional topics, each with at least four reviewed expressions.

- [ ] **Step 3: Commit**

```bash
git add Sources/RussianCornerCore/Resources/long-term-sentences.json Verification
git commit -m "content: curate long-term topics 9 through 16"
```

---

### Task 6: Curate topics 17–24

**Files:**
- Modify: `Sources/RussianCornerCore/Resources/long-term-sentences.json`
- Modify: `Verification/long-term-corpus-audit.md`

- [ ] **Step 1: Review and add topics 17–24**

For every accepted expression in topics 17–24, require a complete natural
`practiceRu`, clean `speechText`, Chinese intent, definite speaker role,
address form, natural expected reply, and traceable `sourcePath`, `sourceText`
and `sourceHash`. Split `ты/вы`, gender, and formal/informal variants into
independent cards. Prioritize city navigation, travel, hotel, trip impressions,
university, classes/exams, classmates and international contacts.

- [ ] **Step 2: Run per-topic verification**

```bash
bash Scripts/verify-long-term-content.sh --topics 17-24
```

Expected: eight additional topics, each with at least four reviewed expressions.

- [ ] **Step 3: Commit**

```bash
git add Sources/RussianCornerCore/Resources/long-term-sentences.json Verification
git commit -m "content: curate long-term topics 17 through 24"
```

---

### Task 7: Curate topics 25–32 and close the content gate

**Files:**
- Modify: `Sources/RussianCornerCore/Resources/long-term-sentences.json`
- Modify: `Scripts/verify-long-term-content.sh`
- Modify: `Verification/long-term-corpus-audit.md`
- Test: `Tests/RussianCornerCoreTests/LongTermContentTests.swift`

- [ ] **Step 1: Review and add topics 25–32**

For every accepted expression in topics 25–32, require a complete natural
`practiceRu`, clean `speechText`, Chinese intent, definite speaker role,
address form, natural expected reply, and traceable `sourcePath`, `sourceText`
and `sourceHash`. Split `ты/вы`, gender, and formal/informal variants into
independent cards. Prioritize health, hospital, doctor/pharmacy, healthy
habits, groceries, café/fast food, Russian restaurant and Chinese cuisine.

- [ ] **Step 2: Implement the final shell gate**

The script must fail unless:

```text
topics=32
reviewed_sentences>=200
minimum_per_topic>=4
unknown_topic_references=0
unsafe_sources=0
dirty_speech_text=0
missing_pragmatic_metadata=0
source_mismatches=0
duplicate_ids=0
```

Set `contentGateClosed == true` only after these checks pass. The script also
prints accepted and exclusion counts from the audit report.

Add the final threshold test at this point:

```swift
func testClosedManifestMeetsLongTermContentGate() throws {
    let catalog = try ContentCatalog(
        resourceDirectory: sourceResourceDirectory
    )
    XCTAssertTrue(catalog.longTermManifest.contentGateClosed)
    XCTAssertGreaterThanOrEqual(catalog.longTermSentences.count, 200)
    for topic in catalog.topics {
        XCTAssertGreaterThanOrEqual(
            catalog.longTermSentences.filter {
                $0.topicID == topic.id
            }.count,
            4,
            topic.id
        )
    }
}
```

- [ ] **Step 3: Run the full content gate**

```bash
jq empty Sources/RussianCornerCore/Resources/topics.json
jq empty Sources/RussianCornerCore/Resources/long-term-sentences.json
bash Scripts/verify-source-corpus.sh
bash Scripts/verify-long-term-content.sh
swift test --filter LongTermContentTests
```

Expected: all pass. If the reliable corpus cannot reach 200 without unsafe material, stop and report the exact per-topic deficit rather than weakening validation.

- [ ] **Step 4: Commit**

```bash
git add Sources/RussianCornerCore/Resources Scripts Tests Verification
git commit -m "content: complete 32-topic long-term corpus"
```

---

### Task 8: Long-term topic selector and queue

**Files:**
- Create: `Sources/RussianCornerCore/TopicScheduler.swift`
- Modify: `Sources/RussianCornerCore/DailyQueue.swift`
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`
- Test: `Tests/RussianCornerCoreTests/TopicSchedulerTests.swift`
- Test: `Tests/RussianCornerAppTests/LongTermQueueTests.swift`

- [ ] **Step 1: Write 60-day scheduler tests**

```swift
func testSixtyDayRotationCoversAllTopicsWithoutImmediateRepeat() {
    let topics = (1...32).map { topic(number: $0) }
    let selector = TopicSelector()
    var selected: [String] = []

    for offset in 0..<60 {
        selected.append(
            selector.select(
                dayIndex: 20_000 + offset,
                topics: topics,
                recentTopicIDs: Array(selected.suffix(14)),
                weaknessByTopic: [:],
                manualTopicID: nil
            ).id
        )
    }

    XCTAssertEqual(Set(selected), Set(topics.map(\.id)))
    XCTAssertFalse(zip(selected, selected.dropFirst()).contains {
        $0 == $1
    })
}
```

Add tests proving manual selection wins for new cards while due cards from other topics remain first.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter 'TopicSchedulerTests|LongTermQueueTests'
```

Expected: compile failure for `TopicSelector`.

- [ ] **Step 3: Implement deterministic topic selection**

```swift
public struct TopicSelector: Sendable {
    public func select(
        dayIndex: Int,
        topics: [TopicDefinition],
        recentTopicIDs: [String],
        weaknessByTopic: [String: Double],
        manualTopicID: String?
    ) -> TopicDefinition {
        if let manualTopicID,
           let manual = topics.first(where: { $0.id == manualTopicID }) {
            return manual
        }
        let recent = Set(recentTopicIDs.suffix(14))
        let unseen = topics.filter { !recent.contains($0.id) }
        let pool = unseen.isEmpty ? topics : unseen
        return pool.sorted {
            let left = weaknessByTopic[$0.id, default: 0]
            let right = weaknessByTopic[$1.id, default: 0]
            return left == right ? $0.number < $1.number : left > right
        }[positiveModulo(dayIndex, pool.count)]
    }
}
```

Define empty-topic behavior as `nil` through a separate `selectIfAvailable` wrapper; production validation guarantees 32 topics.

- [ ] **Step 4: Build due-first long-term queues**

The queue order is:

```swift
retry + dueAllTopics + freshPrimaryTopic + learnedPrimaryTopic
```

Cap sentence cards at the configured 5–10. Never filter due review by the current topic.

- [ ] **Step 5: Remove trial-slice queue branching**

Delete:

```swift
queue = catalog.trialSlice == nil
  ? lexemeEntries + sentenceEntries
  : sentenceEntries + lexemeEntries
```

Replace it with the stable long-term composition and pass the selected topic into `PracticeViewModel`.

- [ ] **Step 6: Simulate days 8, 30 and 60**

Use in-memory repositories and fixed clocks. Assert each day creates a nonempty queue, preserves earlier review states and does not reset progress.

- [ ] **Step 7: Run tests and commit**

```bash
swift test --filter 'TopicSchedulerTests|LongTermQueueTests|PracticeViewModelTests'
git add Sources Tests
git commit -m "feat: schedule indefinite daily topic practice"
```

---

### Task 9: Read-only daily source synchronization

**Files:**
- Create: `Sources/RussianCornerPlatform/SourceCorpusScanner.swift`
- Create: `Sources/RussianCornerPlatform/CandidateCorpusStore.swift`
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Test: `Tests/RussianCornerPlatformTests/SourceCorpusScannerTests.swift`
- Test: `Tests/RussianCornerAppTests/SourceSyncRuntimeTests.swift`

- [ ] **Step 1: Write scanner tests with temporary directories**

Test:

- first scan finds candidates;
- unchanged hashes produce no reparse;
- one changed file reparses only that file;
- conflict and AI files are excluded;
- symlinks are rejected;
- missing/OneDrive-offline source returns `.unavailableUsingBundledCorpus`;
- source bytes are unchanged after scanning.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter 'SourceCorpusScannerTests|SourceSyncRuntimeTests'
```

Expected: compile failure for scanner and candidate-store types.

- [ ] **Step 3: Implement scanner values**

```swift
public struct SourceFileSnapshot: Codable, Equatable, Sendable {
    public let relativePath: String
    public let sha256: String
    public let modifiedAt: Date
}

public struct CandidateExpression: Codable, Equatable, Sendable {
    public let id: String
    public let topicID: String
    public let sourcePath: String
    public let sourceText: String
    public let practiceRu: String
    public let status: ReviewStatus
    public let qualityFlags: [ContentQualityFlag]
}

public enum SourceSyncResult: Equatable, Sendable {
    case unchanged
    case updated(candidateCount: Int, changedFileCount: Int)
    case unavailableUsingBundledCorpus(String)
}
```

Use CryptoKit SHA-256. Never follow symbolic links and never call write APIs on the source root.

- [ ] **Step 4: Persist candidates outside the vault**

Write atomically to:

```text
~/Library/Application Support/com.openclaw.russiancorner/CandidateCorpus.json
```

Use a temporary sibling file followed by `FileManager.replaceItemAt`. The store holds snapshots and draft candidates only.

- [ ] **Step 5: Trigger sync on launch and day change**

`AppRuntime` starts sync after core practice loads. A failure updates a nonblocking status and leaves the bundled long-term corpus active.

- [ ] **Step 6: Verify source integrity and commit**

```bash
swift test --filter 'SourceCorpusScannerTests|SourceSyncRuntimeTests'
bash Scripts/verify-source-corpus.sh
git add Sources Tests
git commit -m "feat: sync notebook changes into isolated candidates"
```

---

### Task 10: Long-term UI, manual topic choice and rolling report

**Files:**
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Modify: `Sources/RussianCornerUI/SettingsView.swift`
- Modify: `Sources/RussianCornerUI/ProgressView.swift`
- Modify: `Sources/RussianCornerUI/TrialReportExporter.swift`
- Modify: `Sources/RussianCornerCore/TrialReportBuilder.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`
- Test: `Tests/RussianCornerAppTests/AppModelTests.swift`
- Test: `Tests/RussianCornerCoreTests/TrialReportBuilderTests.swift`

- [ ] **Step 1: Write failing naming and topic-choice tests**

Assert:

```swift
XCTAssertTrue(report.contains("# 俄语角落卡｜最近 7 天学习报告"))
XCTAssertFalse(report.contains("试用"))
```

Test that choosing topic 19 persists only for the current calendar day and reloads the queue without deleting review events.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter 'TrialReportBuilderTests|AppModelTests'
```

Expected: report naming failure and missing topic-preference APIs.

- [ ] **Step 3: Add daily topic preference**

Persist:

```swift
public var preferredTopicID: String?
public var preferredTopicDay: Date?
```

At a day boundary, expire the manual preference. Do not use the preference to filter overdue review items.

- [ ] **Step 4: Add menu and status UI**

MenuBarExtra adds:

```swift
Menu("今天的话题") {
    ForEach(runtime.topics) { topic in
        Button("\(topic.number). \(topic.titleZh)") {
            runtime.selectTopicForToday(topic.id)
        }
    }
}
```

Settings shows:

```text
长期表达：N
话题覆盖：32 / 32
最近同步：YYYY-MM-DD HH:mm
待审核候选：N
```

Progress shows completed/mastery counts grouped by topic and the three weakest topics.

- [ ] **Step 5: Rename only user-facing trial text**

Change:

```text
导出 7 天试用报告… → 导出最近 7 天学习报告…
7 天试用报告已导出 → 最近 7 天学习报告已导出
```

Keep internal store and type names where renaming would risk migration. No user-facing screen may call the product a trial.

- [ ] **Step 6: Run UI and report tests**

```bash
swift test --filter 'TrialReportBuilderTests|AppModelTests|TrialReportExporterTests'
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Sources Tests
git commit -m "feat: expose long-term topics and rolling reports"
```

---

### Task 11: Packaging, documentation and complete acceptance

**Files:**
- Modify: `Sources/RussianCornerResourceProbe/main.swift`
- Modify: `Scripts/build-app.sh`
- Modify: `Tests/Packaging/resource-probe-validation.sh`
- Modify: `Tests/Packaging/build-app-atomicity.sh`
- Modify: `README.md`
- Modify: `Documentation/USAGE.md`
- Create: `Verification/long-term-learning-acceptance.md`

- [ ] **Step 1: Extend resource probes**

The probe exits successfully only when:

```text
lexemes>=350
legacy_sentences>=60
long_term_sentences>=200
topics=32
trial_fixture=50
```

The build script copies `topics.json` and `long-term-sentences.json`, compares SHA-256 before publication, and maintains the existing atomic-dist safety.

- [ ] **Step 2: Update documentation**

Document:

- indefinite use;
- daily primary-topic selection;
- due-review priority;
- universal click behavior and quality labels;
- read-only daily notebook sync;
- candidate isolation;
- rolling seven-day report;
- source and Keychain privacy;
- existing hide/collapse/four-corner controls.

Remove claims that the formal queue is limited to 50 cards.

- [ ] **Step 3: Run complete automated verification**

```bash
swift test -Xswiftc -warnings-as-errors
bash Scripts/verify-source-corpus.sh
bash Scripts/verify-long-term-content.sh
bash Scripts/verify-trial-content.sh
bash Tests/Packaging/resource-probe-validation.sh
bash Tests/Packaging/build-app-safety.sh
bash Tests/Packaging/build-app-atomicity.sh
bash Scripts/build-app.sh
codesign --verify --deep --strict "dist/Russian Corner.app"
```

Expected: every command exits 0.

- [ ] **Step 4: Run secret and source-write scans**

```bash
! rg -n --hidden --glob '!.git/**' --glob '!.build/**' \
  'dict\\.1\\.1\\.' .
git diff --exit-code -- "$SOURCE_ROOT"
```

Also run the Obsidian aggregate hash gate after the app-level source sync test.

- [ ] **Step 5: Perform real app interaction**

Using the built `.app`:

1. select four different daily topics;
2. verify the queue changes only fresh content;
3. reveal a long-term sentence outside the original 35;
4. click a reviewed-context word;
5. click a reviewed-lexeme word;
6. click an unknown word and see online-unreviewed or offline fallback;
7. simulate/relaunch on day 8 and verify a nonempty queue;
8. export a report and verify no “试用” wording;
9. hide, restore, move to every corner and restart;
10. deny/unavailable network and confirm core study still works.

- [ ] **Step 6: Write the acceptance matrix**

`Verification/long-term-learning-acceptance.md` records:

- all spec requirements;
- exact test/build outputs;
- 32-topic and sentence counts;
- candidate/exclusion counts;
- original source hash;
- app artifact path, size and modification time;
- any reliable-corpus deficit without weakening the gate.

- [ ] **Step 7: Commit**

```bash
git add Sources Scripts Tests README.md Documentation Verification
git commit -m "docs: verify long-term Russian learning release"
```

- [ ] **Step 8: Finish the branch**

Invoke `superpowers:verification-before-completion`, then `superpowers:finishing-a-development-branch`. Merge locally only after tests pass on both the feature branch and merged `main`.
