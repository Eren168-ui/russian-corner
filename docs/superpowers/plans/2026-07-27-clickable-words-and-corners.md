# Clickable Words and Corners Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Russian word in the 35 trial expressions clickable with local contextual analysis, add optional Wiktionary expansion, and make the floating card truly movable and persistent across all four screen corners.

**Architecture:** Keep the existing Core → UI → App dependency direction. Add a compact local word-analysis dictionary plus per-sentence token mappings to `TrialContentSlice`; resolve those into view-model values without adding basic words to the review queue. Add pure nearest-corner geometry and persist the chosen corner after dragging; expose the same state through a header menu.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, Codable JSON resources, XCTest, SwiftPM.

---

## File map

- Modify `Sources/RussianCornerCore/Models.swift`: word dictionary and sentence-token data types.
- Modify `Sources/RussianCornerCore/ContentCatalog.swift`: resolved word analyses and coverage validation.
- Modify `Sources/RussianCornerCore/Resources/trial-slice.json`: 97 local entries and 137 contextual token mappings.
- Modify `Sources/RussianCornerUI/PracticeViewModel.swift`: token selection, resolved details and reset behavior.
- Create `Sources/RussianCornerUI/InteractiveRussianText.swift`: wrapping attributed links for every word.
- Modify `Sources/RussianCornerUI/PracticeCardView.swift`: interactive answer and four-corner menu.
- Modify `Sources/RussianCornerUI/PracticeDetailSection.swift`: selected-word hierarchy and online lookup button.
- Create `Sources/RussianCornerUI/OnlineDictionary.swift`: allowlisted Wiktionary URL creation/opening.
- Modify `Sources/RussianCornerUI/FloatingPanelController.swift`: nearest-corner drag persistence.
- Modify `Scripts/verify-trial-content.sh`: every-word coverage checks.
- Modify relevant Core/App tests and documentation.

### Task 1: Lock the local word-analysis contract

**Files:**
- Modify: `Tests/RussianCornerCoreTests/ContentCatalogTests.swift`
- Modify: `Sources/RussianCornerCore/Models.swift`
- Modify: `Sources/RussianCornerCore/ContentCatalog.swift`

- [ ] **Step 1: Write failing bundle coverage tests**

Add tests asserting:

```swift
func testEveryTrialSentenceWordHasExactlyOneReviewedAnalysis() throws {
    let catalog = try ContentCatalog()
    for sentence in catalog.practiceSentences {
        let words = RussianWordTokenizer.words(in: sentence.practiceRu)
        let analyses = catalog.wordAnalyses(for: sentence.id)
        XCTAssertEqual(analyses.map(\.tokenIndex), Array(words.indices))
        XCTAssertEqual(analyses.map(\.surfaceText), words)
        XCTAssertTrue(analyses.allSatisfy {
            !$0.lemma.isEmpty
                && !$0.glossZh.isEmpty
                && !$0.partOfSpeech.isEmpty
                && !$0.morphology.isEmpty
                && [.reviewed, .verified].contains($0.reviewStatus)
        })
    }
}
```

Add negative fixture tests for a missing index, duplicate index, mismatched surface text,
draft analysis, nonexistent `lexemeID`, and unsafe source status.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
swift test --filter ContentCatalogTests/testEveryTrialSentenceWordHasExactlyOneReviewedAnalysis
```

Expected: compile failure because word-analysis types and APIs do not exist.

- [ ] **Step 3: Add minimal models and tokenizer**

Add:

```swift
public struct TrialWordEntry: Codable, Equatable, Sendable { ... }
public struct SentenceWordToken: Codable, Equatable, Sendable { ... }
public struct ResolvedWordAnalysis: Identifiable, Equatable, Sendable { ... }

public enum RussianWordTokenizer {
    public static func words(in text: String) -> [String]
}
```

Extend `TrialContentSlice` with backward-compatible `wordEntries` and
`sentenceWordTokens` arrays. The tokenizer recognizes Cyrillic letters plus `ё`
and ignores punctuation.

- [ ] **Step 4: Add fail-closed catalog validation**

Validate exact coverage, unique indices, surface equality after accent-insensitive
normalization, required fields, allowed statuses, valid card/lexeme references and
non-AI provenance. Expose:

```swift
public func wordAnalyses(for cardID: String) -> [ResolvedWordAnalysis]
```

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```bash
swift test --filter ContentCatalogTests
```

Expected: fixture tests pass; bundled coverage remains failing until Task 2 data is added.

### Task 2: Curate complete trial word coverage

**Files:**
- Modify: `Sources/RussianCornerCore/Resources/trial-slice.json`
- Modify: `Scripts/verify-trial-content.sh`

- [ ] **Step 1: Add 97 reviewed local word entries**

For every unique word form in the 35 `practiceRu` expressions, add an entry with:

```json
{
  "id": "word-...",
  "lookupForm": "...",
  "stressedForm": "...",
  "lemma": "...",
  "glossZh": "...",
  "partOfSpeech": "...",
  "aspectPair": null,
  "government": null,
  "collocations": ["..."],
  "usageNote": "...",
  "lexemeID": null,
  "reviewStatus": "reviewed",
  "provenanceType": "derived",
  "qualityFlags": []
}
```

Reuse existing lexeme IDs where applicable. Function words show grammatical usage;
content words show at least one natural collocation. Do not mark any entry `verified`.

- [ ] **Step 2: Add all 137 contextual mappings**

For every sentence word index add:

```json
{
  "cardID": "trial-...",
  "tokenIndex": 0,
  "surfaceText": "...",
  "wordEntryID": "word-...",
  "morphology": "当前句中的词形说明"
}
```

Distinguish context for repeated ambiguous forms such as `вас` and `это`.

- [ ] **Step 3: Expand the shell gate**

Make `verify-trial-content.sh` fail when:

- token count differs from mapping count;
- indices are missing or duplicated;
- surface text differs;
- an entry lacks core fields;
- a token references a missing word entry;
- any analysis is draft or AI-generated.

Print:

```text
word_analysis=PASS sentences=35 tokens=137 unique_entries=97
```

- [ ] **Step 4: Run data and catalog verification**

Run:

```bash
jq empty Sources/RussianCornerCore/Resources/trial-slice.json
bash Scripts/verify-trial-content.sh
swift test --filter ContentCatalogTests
```

Expected: all pass.

### Task 3: Add selection behavior with TDD

**Files:**
- Modify: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`

- [ ] **Step 1: Write failing selection tests**

Cover:

```swift
func testRevealedSentenceExposesEveryInteractiveWord()
func testSelectingAnotherWordReplacesSelection()
func testSelectingCurrentWordTogglesItClosed()
func testNextGradeAndCollapseDetailsClearSelectedWord()
func testLexemeCardBehaviorRemainsUnchanged()
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --filter PracticeViewModelTests/testRevealedSentenceExposesEveryInteractiveWord
```

Expected: compile failure for missing interactive-word API.

- [ ] **Step 3: Implement minimal selection state**

Add:

```swift
public private(set) var selectedWordAnalysis: ResolvedWordAnalysis?
public var currentSentenceWords: [ResolvedWordAnalysis] { ... }
public func toggleWordAnalysis(tokenIndex: Int)
public func clearWordAnalysis()
```

Selection opens details; closing details, advancing, grading and queue reload clear it.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run:

```bash
swift test --filter PracticeViewModelTests
```

Expected: all pass.

### Task 4: Render every word as a natural wrapping link

**Files:**
- Create: `Sources/RussianCornerUI/InteractiveRussianText.swift`
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`
- Modify: `Sources/RussianCornerUI/PracticeDetailSection.swift`
- Create: `Sources/RussianCornerUI/OnlineDictionary.swift`
- Modify: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`

- [ ] **Step 1: Write failing URL and attributed-token tests**

Test that:

- every token receives `russian-corner-word://<index>`;
- punctuation remains visible and is not linked;
- selected token receives the selected style;
- `OnlineDictionary.url(for:)` percent-encodes and allowlists only
  `https://ru.wiktionary.org/wiki/`.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --filter InteractiveRussianTextTests
```

Expected: compile failure because renderer and dictionary URL builder are absent.

- [ ] **Step 3: Implement interactive attributed text**

Create a wrapping `Text(AttributedString)` that intercepts the internal word URL
through `OpenURLAction`, calls `toggleWordAnalysis`, and never opens internal URLs
in the browser.

- [ ] **Step 4: Implement selected-word details**

When a word is selected, `PracticeDetailSection` shows its stressed form, lemma,
Chinese gloss, part of speech, contextual morphology and only applicable fields.
The online button calls `NSWorkspace.shared.open` with the allowlisted URL and
reports a Chinese non-blocking failure.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```bash
swift test --filter InteractiveRussianTextTests
swift test --filter PracticeViewModelTests
```

Expected: all pass.

### Task 5: Make four-corner movement real

**Files:**
- Modify: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`
- Modify: `Tests/RussianCornerAppTests/TransactionalInteractionTests.swift`
- Modify: `Sources/RussianCornerUI/FloatingPanelController.swift`
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`

- [ ] **Step 1: Write failing geometry tests**

Add pure tests for:

```swift
FloatingPanelController.nearestCorner(
    panelFrame:visibleFrame:
)
```

Cover four quadrants, nonzero screen origins, resized panels and boundary equality.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
swift test --filter FloatingPanelControllerTests
```

Expected: compile failure for missing `nearestCorner`.

- [ ] **Step 3: Implement geometry and drag persistence**

On debounced `windowDidMove`, determine the panel screen, compute nearest corner,
persist both screen identifier and corner, then snap once. Do not recurse through
`windowDidMove` while snapping.

- [ ] **Step 4: Add the header corner menu**

Add a `Menu` with four `FloatingCorner.allCases` choices, current checkmark and
system icon `square.grid.2x2`. Updating `appModel.corner` triggers existing layout
observation immediately.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```bash
swift test --filter FloatingPanelControllerTests
swift test --filter AppModelTests/testCornerAndDisplayPreferencesPersist
```

Expected: all pass.

### Task 6: Documentation and complete regression

**Files:**
- Modify: `Documentation/USAGE.md`
- Modify: `README.md`
- Create: `Verification/clickable-words-and-corners-acceptance.md`

- [ ] **Step 1: Document interaction and privacy**

Document word clicking, field hierarchy, optional Wiktionary lookup, query privacy,
drag-to-nearest-corner and header menu.

- [ ] **Step 2: Run all automated verification**

Run:

```bash
swift test -Xswiftc -warnings-as-errors
for test_script in Tests/Packaging/*.sh; do bash "$test_script"; done
bash Scripts/verify-trial-content.sh
bash Scripts/verify-source-corpus.sh
bash Scripts/build-app.sh
codesign --verify --deep --strict "dist/Russian Corner.app"
git diff --check
```

Expected: all commands pass, 225 or more Swift tests pass, source hash remains
`89ca565d1fa8b3840e89e7262b867d61fe486ea95962f1746c109bf2a4478b0c`.

- [ ] **Step 3: Perform application-level interaction verification**

Launch the release app and verify all four header choices, drag snapping, restart
persistence, word selection across at least five scenes, field relevance, online
lookup and offline local details. Record any hardware/UI limitation honestly.

- [ ] **Step 4: Write the requirement matrix**

Record every item from section 9 of the design as PASS, FAIL or NOT VERIFIED with
the exact test, code path or manual evidence. Do not announce completion while any
in-scope item is FAIL.

- [ ] **Step 5: Commit final implementation**

```bash
git add Sources Tests Scripts Documentation README.md Verification
git commit -m "feat: add clickable word analysis and four-corner movement"
```
