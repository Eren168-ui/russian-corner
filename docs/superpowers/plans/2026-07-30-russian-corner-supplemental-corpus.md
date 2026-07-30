# Russian Corner Supplemental Corpus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fail-closed, reviewed daily-Russian supplement to the existing corpus without changing the core corpus or admitting professional Russian.

**Architecture:** Keep the current core JSON files byte-for-byte unchanged and load a separate supplemental manifest at startup. Supplemental lexemes and sentences carry explicit layer and provenance metadata, merge by stable IDs and normalized lemmas, and are capped only when selecting fresh daily content; due reviews are never discarded. B1 prompts live in a separate speaking-challenge resource.

**Tech Stack:** Swift 6.3, SwiftUI, Foundation Codable, SwiftPM tests, JSON resources, Bash/Node.js verification scripts.

---

## File map

- Create `Sources/RussianCornerCore/SupplementalContent.swift`: supplemental manifest and speaking-challenge models.
- Modify `Sources/RussianCornerCore/Models.swift`: optional provenance, usage, and corpus-layer fields on `Lexeme` and `SentenceCard`.
- Modify `Sources/RussianCornerCore/ContentCatalog.swift`: fail-closed optional supplemental loading, merging, and validation.
- Modify `Sources/RussianCornerUI/PracticeViewModel.swift`: cap fresh supplemental sentences and words while preserving due reviews.
- Create `Sources/RussianCornerCore/Resources/supplemental-manifest.json`: source roots, source hashes, counts, and gate state.
- Create `Sources/RussianCornerCore/Resources/supplemental-lexemes.json`: reviewed A2→B1 vocabulary additions and enrichments.
- Create `Sources/RussianCornerCore/Resources/supplemental-sentences.json`: reviewed daily expressions linked to the supplemental vocabulary.
- Create `Sources/RussianCornerCore/Resources/speaking-challenges.json`: reviewed B1 prompt-only speaking challenges.
- Create `Scripts/audit-supplemental-corpus.mjs`: read-only candidate scan and exclusion report.
- Create `Scripts/verify-supplemental-content.sh`: independent resource and source-trace validation.
- Create `Scripts/baseline-knowledge-corpus.sh`: deterministic whole-knowledge-base SHA-256 inventory.
- Create `Verification/supplemental-source-baseline.txt`: pre-edit source inventory.
- Create `Verification/supplemental-corpus-audit.md`: user-readable audit counts and manual readback.
- Modify `Scripts/build-app.sh`: package and verify the four new resources.
- Create `Tests/RussianCornerCoreTests/SupplementalContentTests.swift`: decode, merge, isolation, and metadata tests.
- Modify `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`: fresh-content source-mix tests.

### Task 1: Capture and enforce the read-only source baseline

**Files:**
- Create: `Scripts/baseline-knowledge-corpus.sh`
- Create: `Verification/supplemental-source-baseline.txt`
- Test: `Tests/Content/supplemental-source-baseline.sh`

- [ ] **Step 1: Write the failing baseline verification test**

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
"$repo_root/Scripts/baseline-knowledge-corpus.sh" --verify \
  "$repo_root/Verification/supplemental-source-baseline.txt"
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
bash Tests/Content/supplemental-source-baseline.sh
```

Expected: FAIL because `baseline-knowledge-corpus.sh` does not exist.

- [ ] **Step 3: Implement deterministic read-only hashing**

The script must reject symlinked roots and hash every regular file using relative
paths:

```bash
knowledge_root="/Users/Openclawworkspace/Library/CloudStorage/OneDrive-个人/Documents/20-语言学习与专业/大学知识库（俄语学习+专业）"
find "$knowledge_root" -type f -print0 |
  LC_ALL=C sort -z |
  while IFS= read -r -d '' file; do
    relative=${file#"$knowledge_root/"}
    printf '%s  %s\n' "$(shasum -a 256 "$file" | awk '{print $1}')" "$relative"
  done
```

`--write PATH` writes a new baseline only when `PATH` does not exist.
`--verify PATH` produces a temporary inventory and uses `cmp`.

- [ ] **Step 4: Generate and verify the baseline**

Run:

```bash
Scripts/baseline-knowledge-corpus.sh --write \
  Verification/supplemental-source-baseline.txt
bash Tests/Content/supplemental-source-baseline.sh
```

Expected: `knowledge_corpus=PASS files=1515`.

- [ ] **Step 5: Commit**

```bash
git add Scripts/baseline-knowledge-corpus.sh \
  Tests/Content/supplemental-source-baseline.sh \
  Verification/supplemental-source-baseline.txt
git commit -m "test: protect supplemental source corpus"
```

### Task 2: Add backward-compatible supplemental models

**Files:**
- Create: `Sources/RussianCornerCore/SupplementalContent.swift`
- Modify: `Sources/RussianCornerCore/Models.swift`
- Test: `Tests/RussianCornerCoreTests/SupplementalContentTests.swift`

- [ ] **Step 1: Write failing model decode tests**

```swift
func testLegacyLexemeDecodesWithoutSupplementalFields() throws {
    let lexeme = try JSONDecoder().decode(
        Lexeme.self,
        from: Data(legacyLexemeJSON.utf8)
    )
    XCTAssertEqual(lexeme.corpusLayer, .core)
    XCTAssertEqual(lexeme.sourcePaths, [])
}

func testSupplementalManifestCarriesClosedGateAndAllowlist() throws {
    let manifest = try JSONDecoder().decode(
        SupplementalContentManifest.self,
        from: Data(supplementalFixtureJSON.utf8)
    )
    XCTAssertTrue(manifest.contentGateClosed)
    XCTAssertEqual(manifest.allowedSourceRoots.count, 3)
}
```

- [ ] **Step 2: Run the focused tests**

Run:

```bash
swift test --filter SupplementalContentTests
```

Expected: compile failure because the supplemental types and fields do not exist.

- [ ] **Step 3: Add models**

```swift
public enum CorpusLayer: String, Codable, Equatable, Sendable {
    case core
    case dailySupplement
    case speakingChallenge
}

public struct SupplementalContentManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let contentGateClosed: Bool
    public let allowedSourceRoots: [String]
    public let sourceHashes: [String: String]
    public let candidateCount: Int
    public let reviewedSentenceCount: Int
    public let reviewedLexemeCount: Int
    public let excludedCount: Int
}

public struct SpeakingChallenge: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let promptRu: String
    public let promptZh: String
    public let structureHintsZh: [String]
    public let replacementSlots: [String]
    public let lexemeIDs: [String]
    public let sourcePath: String
    public let sourceText: String
    public let sourceHash: String
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let qualityFlags: [ContentQualityFlag]
}
```

Add optional coding keys to `Lexeme` and `SentenceCard`; decode missing
`corpusLayer` as `.core`.

- [ ] **Step 4: Run focused tests**

Run:

```bash
swift test --filter SupplementalContentTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerCore/Models.swift \
  Sources/RussianCornerCore/SupplementalContent.swift \
  Tests/RussianCornerCoreTests/SupplementalContentTests.swift
git commit -m "feat: model layered supplemental content"
```

### Task 3: Load supplemental resources fail-closed

**Files:**
- Modify: `Sources/RussianCornerCore/ContentCatalog.swift`
- Modify: `Sources/RussianCornerCore/SupplementalContent.swift`
- Test: `Tests/RussianCornerCoreTests/SupplementalContentTests.swift`

- [ ] **Step 1: Write failing merge and isolation tests**

```swift
func testClosedSupplementMergesReviewedItemsWithoutChangingCore() throws {
    let catalog = try ContentCatalog(resourceDirectory: fixtureURL)
    XCTAssertEqual(catalog.coreSentences.map(\.id), ["core-sentence"])
    XCTAssertEqual(catalog.supplementalSentences.map(\.id), ["supplement-1"])
    XCTAssertEqual(catalog.practiceSentences.count, 2)
}

func testInvalidSupplementFailsClosedToCore() throws {
    let catalog = try ContentCatalog(resourceDirectory: invalidFixtureURL)
    XCTAssertEqual(catalog.practiceSentences.map(\.id), ["core-sentence"])
    XCTAssertNotNil(catalog.supplementalLoadIssue)
}

func testProfessionalSourceNeverMerges() throws {
    let catalog = try ContentCatalog(resourceDirectory: professionalFixtureURL)
    XCTAssertTrue(catalog.supplementalSentences.isEmpty)
}
```

- [ ] **Step 2: Run focused tests**

Run:

```bash
swift test --filter SupplementalContentTests
```

Expected: FAIL because `ContentCatalog` does not load supplemental resources.

- [ ] **Step 3: Implement optional decode and validation**

Load all four supplemental files only when they are all present. Validate the
manifest, source allowlist, IDs, normalized lemmas, review statuses, metadata,
source hashes, and professional-source fragments. On any supplemental failure,
store a nonfatal `supplementalLoadIssue` and expose only core items.

```swift
private static func loadSupplement(
    from directory: URL,
    decoder: JSONDecoder
) throws -> SupplementalBundle? {
    let names = [
        "supplemental-manifest",
        "supplemental-lexemes",
        "supplemental-sentences",
        "speaking-challenges",
    ]
    let urls = names.map {
        directory.appendingPathComponent("\($0).json")
    }
    guard urls.allSatisfy({
        FileManager.default.fileExists(atPath: $0.path)
    }) else {
        return nil
    }
    let bundle = try SupplementalBundle(
        manifest: decoder.decode(
            SupplementalContentManifest.self,
            from: Data(contentsOf: urls[0])
        ),
        lexemes: decoder.decode(
            [Lexeme].self,
            from: Data(contentsOf: urls[1])
        ),
        sentences: decoder.decode(
            [SentenceCard].self,
            from: Data(contentsOf: urls[2])
        ),
        speakingChallenges: decoder.decode(
            [SpeakingChallenge].self,
            from: Data(contentsOf: urls[3])
        )
    )
    let issues = bundle.validate()
    guard issues.isEmpty else {
        throw SupplementalContentError.validationFailed(issues)
    }
    return bundle
}
```

- [ ] **Step 4: Run focused and catalog tests**

Run:

```bash
swift test --filter SupplementalContentTests
swift test --filter ContentCatalogTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerCore/ContentCatalog.swift \
  Sources/RussianCornerCore/SupplementalContent.swift \
  Tests/RussianCornerCoreTests/SupplementalContentTests.swift
git commit -m "feat: load supplemental corpus fail closed"
```

### Task 4: Build the read-only candidate audit

**Files:**
- Create: `Scripts/audit-supplemental-corpus.mjs`
- Create: `Verification/supplemental-corpus-candidates.json`
- Create: `Verification/supplemental-corpus-audit.md`
- Test: `Tests/Content/audit-supplemental-corpus.sh`

- [ ] **Step 1: Write the failing audit test**

The fixture test must include one allowed basic-Russian note, one professional
note, one transcript, one conflict copy, and one AI plan. Assert that only the
basic note produces draft candidates and every excluded path has an explicit
reason.

- [ ] **Step 2: Run the audit test**

Run:

```bash
bash Tests/Content/audit-supplemental-corpus.sh
```

Expected: FAIL because the audit script does not exist.

- [ ] **Step 3: Implement the scanner**

Use exact allowlisted roots and reject symlinks. Extract Russian table cells,
question/answer blocks, and complete example lines. Every candidate must be:

```json
{
  "reviewStatus": "draft",
  "sourcePath": "relative/path.md",
  "sourceText": "exact original line",
  "sourceHash": "sha256",
  "provenanceType": "userNote",
  "qualityFlags": ["needsNativeReview"]
}
```

The path gate must run before opening file contents:

```javascript
const excludedPath = (relative) =>
  /(?:conflict|双链|ai生成|专业俄语|俄语转录|化学|生物|物理|组织学|遗传|数学|统计)/iu
    .test(relative);

for (const root of allowedRoots) {
  for (const absolute of walkMarkdown(root)) {
    const relative = path.relative(knowledgeRoot, absolute);
    if (excludedPath(relative)) {
      excluded.push({ sourcePath: relative, reason: "excludedSource" });
      continue;
    }
    const metadata = fs.lstatSync(absolute);
    if (!metadata.isFile() || metadata.isSymbolicLink()) {
      excluded.push({ sourcePath: relative, reason: "unsafeFile" });
      continue;
    }
    extractCandidates(fs.readFileSync(absolute, "utf8"), relative);
  }
}
```

- [ ] **Step 4: Run the real audit**

Run:

```bash
node Scripts/audit-supplemental-corpus.mjs
bash Tests/Content/audit-supplemental-corpus.sh
```

Expected: PASS, with zero candidates from professional, transcript, conflict,
double-link report, or AI-plan sources.

- [ ] **Step 5: Commit**

```bash
git add Scripts/audit-supplemental-corpus.mjs \
  Tests/Content/audit-supplemental-corpus.sh \
  Verification/supplemental-corpus-candidates.json \
  Verification/supplemental-corpus-audit.md
git commit -m "feat: audit daily Russian supplement candidates"
```

### Task 5: Curate the first reviewed supplemental slice

**Files:**
- Create: `Sources/RussianCornerCore/Resources/supplemental-manifest.json`
- Create: `Sources/RussianCornerCore/Resources/supplemental-lexemes.json`
- Create: `Sources/RussianCornerCore/Resources/supplemental-sentences.json`
- Create: `Sources/RussianCornerCore/Resources/speaking-challenges.json`
- Modify: `Verification/supplemental-corpus-audit.md`
- Test: `Scripts/verify-supplemental-content.sh`

- [ ] **Step 1: Write the failing independent validator**

Validate:

- 60–100 reviewed supplemental sentences;
- 80–150 supplemental or enriched lexeme records;
- at least 20 reviewed speaking challenges;
- source path and hash match;
- no professional or excluded source fragments;
- no draft item is served;
- every lexeme has a collocation and linked scene;
- every sentence has clean speech, stress, role/act, and a core topic ID;
- no normalized duplicate lemma or sentence exists across core and supplement.

- [ ] **Step 2: Run the validator**

Run:

```bash
bash Scripts/verify-supplemental-content.sh
```

Expected: FAIL because the curated resources do not exist.

- [ ] **Step 3: Curate content**

Use the candidate audit to select daily-life material from:

- B1 oral questions for speaking challenges;
- `Ситуация 总结.md`;
- `酒店主题.md`;
- `口语提问题目俄语.md`;
- `Трудности ехать、доехать、 проехать.md`;
- `верить в + Acc.md`;
- `Суффиксы -то, -нибудь и приставка кое- — 速查笔记.md`;
- reviewed music, sport, travel, friendship, and university-life notes.

Reject questionable generated answers rather than silently correcting them.
Record every accepted and rejected candidate in the audit report.

Each accepted sentence must match this complete shape:

```json
{
  "id": "supplement-travel-prepare-01",
  "promptZh": "建议朋友提前准备旅行所需的东西。",
  "cueRu": "Что посоветуете сделать перед поездкой?",
  "practiceRu": "Лучше заранее составить список необходимых вещей.",
  "stressedForm": "Лу́чше зара́нее соста́вить спи́сок необходи́мых веще́й.",
  "speechText": "Лучше заранее составить список необходимых вещей.",
  "theme": "travel",
  "lexemeIDs": ["supplement-lexeme-составить"],
  "sourcePath": "01-按学期/大二上/基础俄语/口语提问题目俄语.md",
  "sourceText": "Что нужно сделать, чтобы подготовиться к путешествию? Составьте план.",
  "reviewStatus": "reviewed",
  "provenanceType": "derived",
  "qualityFlags": [],
  "dialogueAct": "advice",
  "register": "neutral",
  "speakerRole": "朋友",
  "addressForm": "ты",
  "expectedReply": "Хорошая идея, так я ничего не забуду.",
  "alternativeReplyIDs": [],
  "topicID": "topic-18",
  "sourceHash": "<exact file sha256>",
  "corpusLayer": "dailySupplement"
}
```

- [ ] **Step 4: Add stress and source trace**

Use the existing local stress workflow, then manually read back at least 30
sentences and 30 lexemes. Record corrections in the audit report.

- [ ] **Step 5: Run content verification**

Run:

```bash
bash Scripts/verify-supplemental-content.sh
swift test --filter SupplementalContentTests
```

Expected: PASS with the final accepted and excluded counts.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerCore/Resources/supplemental-*.json \
  Sources/RussianCornerCore/Resources/speaking-challenges.json \
  Scripts/verify-supplemental-content.sh \
  Verification/supplemental-corpus-audit.md
git commit -m "feat: add reviewed daily Russian supplement"
```

### Task 6: Enforce fresh-content layer ratios

**Files:**
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`
- Test: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`

- [ ] **Step 1: Write failing queue tests**

```swift
func testFreshSentenceQueueCapsSupplementAtTwentyPercent() throws {
    let model = try makeModel(coreSentenceCount: 20, supplementCount: 20)
    let fresh = model.queue.filter { $0.origin == .todayNew }
    XCTAssertLessThanOrEqual(
        fresh.filter(\.isDailySupplement).count,
        max(1, fresh.count / 5)
    )
}

func testDueSupplementIsNeverDroppedByFreshCap() throws {
    let model = try makeModelWithDueSupplement()
    XCTAssertTrue(model.queue.contains { $0.id == "supplement-due" })
}
```

- [ ] **Step 2: Run focused tests**

Run:

```bash
swift test --filter 'PracticeViewModelTests/testFreshSentenceQueueCapsSupplement|PracticeViewModelTests/testDueSupplement'
```

Expected: FAIL because fresh candidates are not layer-aware.

- [ ] **Step 3: Implement layer-aware fresh ordering**

Keep retry, carryover, and due order unchanged. Split only fresh candidates into
core and supplement, reserve at most 20% of fresh sentence slots for supplement,
and backfill unused supplement slots with core.

Apply the same rule to standalone supplemental lexemes with a maximum of one
fresh supplemental word per ten-item mixed queue; due words remain uncapped.

```swift
private static func cappedFreshSentences(
    core: [SentenceCard],
    supplement: [SentenceCard],
    slotCount: Int
) -> [SentenceCard] {
    guard slotCount > 0 else { return [] }
    let supplementLimit = min(
        supplement.count,
        max(1, slotCount / 5)
    )
    var result = Array(supplement.prefix(supplementLimit))
    result.append(
        contentsOf: core.prefix(max(0, slotCount - result.count))
    )
    if result.count < slotCount {
        result.append(
            contentsOf: supplement
                .dropFirst(supplementLimit)
                .prefix(slotCount - result.count)
        )
    }
    return result
}
```

- [ ] **Step 4: Run practice tests**

Run:

```bash
swift test --filter PracticeViewModelTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerUI/PracticeViewModel.swift \
  Tests/RussianCornerAppTests/PracticeViewModelTests.swift
git commit -m "feat: preserve core priority in daily queues"
```

### Task 7: Package resources and complete acceptance

**Files:**
- Modify: `Scripts/build-app.sh`
- Modify: `README.md`
- Modify: `Documentation/USAGE.md`
- Test: `Tests/Packaging/resource-probe-validation.sh`

- [ ] **Step 1: Extend packaging tests**

The built app must contain all supplemental JSON files, and the resource probe
must report the core and supplemental counts separately.

- [ ] **Step 2: Run packaging test and verify failure**

Run:

```bash
bash Tests/Packaging/resource-probe-validation.sh
```

Expected: FAIL because the new resources are not copied.

- [ ] **Step 3: Copy and verify supplemental resources**

Extend the packaging resource loop with:

```bash
supplemental-manifest.json
supplemental-lexemes.json
supplemental-sentences.json
speaking-challenges.json
```

Run the independent supplemental validator before publishing `dist`.

- [ ] **Step 4: Run final acceptance**

Run:

```bash
Scripts/baseline-knowledge-corpus.sh --verify \
  Verification/supplemental-source-baseline.txt
Scripts/verify-source-corpus.sh
bash Scripts/verify-long-term-content.sh
bash Scripts/verify-supplemental-content.sh
swift test
./Scripts/build-app.sh
codesign --verify --deep --strict "dist/Russian Corner.app"
```

Expected:

- full knowledge corpus PASS;
- original core corpus PASS with unchanged SHA-256;
- long-term core content PASS;
- supplemental content PASS;
- all tests pass except the existing opt-in live dictionary skip;
- app signature verification passes.

- [ ] **Step 5: Install safely**

Stop the running app, move the current `/Applications/Russian Corner.app` into
a unique `/tmp` backup directory, copy the new app with `ditto`, compare the
installed executable and resources against `dist`, and reopen it.

- [ ] **Step 6: Commit**

```bash
git add Scripts/build-app.sh README.md Documentation/USAGE.md \
  Tests/Packaging/resource-probe-validation.sh
git commit -m "build: package supplemental Russian corpus"
```
