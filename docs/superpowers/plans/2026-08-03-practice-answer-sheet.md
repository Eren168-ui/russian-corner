# Practice Answer Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent top-anchored answer-sheet popover that supports stable question numbers, free jumping, missed-question recovery, read-only review, and explicit next-question navigation.

**Architecture:** Introduce a value-type `PracticeSessionNavigator` as the sole owner of per-entry session status while `PracticeViewModel` remains responsible for learning state and presentation state. Persist a dated, language-specific navigator snapshot in `UserDefaults`; reject snapshots whose queue signature does not match. Render navigation through a separate SwiftUI popover so the main practice card and word-detail layout remain unchanged.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation `Codable`/`UserDefaults`, XCTest, existing SwiftData review repository.

---

### Task 1: Session navigation model

**Files:**
- Create: `Sources/RussianCornerUI/PracticeSessionNavigator.swift`
- Create: `Tests/RussianCornerAppTests/PracticeSessionNavigatorTests.swift`

- [ ] **Step 1: Write failing tests for stable keys and navigation**

Cover these concrete cases:

```swift
func testJumpDoesNotCompleteSkippedItems()
func testNextPendingMovesForwardThenWrapsToEarlierMissedItem()
func testAssessedItemCanBeSelectedReadOnly()
func testAgainMarksOriginalAndAppendsDistinctRetryEntry()
func testAllAssessedReturnsNoNextPendingIndex()
```

Use queue entries with repeated `PracticeItemIdentity` values and assert that occurrence numbers keep retry entries distinct.

- [ ] **Step 2: Run the navigator tests and verify RED**

Run:

```bash
swift test --filter PracticeSessionNavigatorTests
```

Expected: compilation fails because `PracticeSessionNavigator` does not exist.

- [ ] **Step 3: Implement the model**

Create these concrete types:

```swift
public enum PracticeSessionItemStatus: String, Codable, Sendable {
  case unseen
  case openedUnassessed
  case assessed
  case needsRetry
}

public struct PracticeSessionEntryKey: Hashable, Codable, Sendable {
  public let kind: PracticeItemKind
  public let itemID: String
  public let occurrence: Int
}

public struct PracticeSessionNavigator: Equatable, Codable, Sendable {
  public private(set) var keys: [PracticeSessionEntryKey]
  public private(set) var statuses: [PracticeSessionItemStatus]

  public mutating func markOpened(at index: Int)
  public mutating func markAssessed(at index: Int, needsRetry: Bool)
  public mutating func synchronize(with queue: [PracticeQueueEntry])
  public func nextPendingIndex(after index: Int) -> Int?
  public func status(at index: Int) -> PracticeSessionItemStatus
}
```

`nextPendingIndex` scans `index + 1 ..< count`, then wraps through `0 ... index`; only `.unseen` and `.openedUnassessed` are pending. `synchronize` preserves matching keys and appends unseen states for new retry entries.

- [ ] **Step 4: Run navigator tests and verify GREEN**

Run `swift test --filter PracticeSessionNavigatorTests` and expect all tests to pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerUI/PracticeSessionNavigator.swift Tests/RussianCornerAppTests/PracticeSessionNavigatorTests.swift
git commit -m "feat: model answer sheet session navigation"
```

### Task 2: Dated local navigation snapshot

**Files:**
- Create: `Sources/RussianCornerUI/PracticeNavigationSnapshotStore.swift`
- Create: `Tests/RussianCornerAppTests/PracticeNavigationSnapshotStoreTests.swift`

- [ ] **Step 1: Write failing persistence tests**

Test same-day restoration, Russian/English key isolation, cross-day rejection, corrupt-data rejection, and queue-signature mismatch rejection using an isolated `UserDefaults(suiteName:)`.

- [ ] **Step 2: Run and verify RED**

Run `swift test --filter PracticeNavigationSnapshotStoreTests`; expect missing-type failures.

- [ ] **Step 3: Implement fail-closed persistence**

Implement:

```swift
public struct PracticeNavigationSnapshot: Codable, Equatable, Sendable {
  public let dayStart: Date
  public let language: StudyLanguage
  public let queueSignature: String
  public let currentIndex: Int
  public let navigator: PracticeSessionNavigator
}

public final class PracticeNavigationSnapshotStore: @unchecked Sendable {
  public func load(
    language: StudyLanguage,
    dayStart: Date,
    queue: [PracticeQueueEntry],
    calendar: Calendar
  ) -> PracticeNavigationSnapshot?

  public func save(
    navigator: PracticeSessionNavigator,
    currentIndex: Int,
    language: StudyLanguage,
    dayStart: Date,
    queue: [PracticeQueueEntry]
  )
}
```

Compute the signature from ordered entry keys using SHA-256 through CryptoKit. Never throw corrupted snapshot errors into the learning flow; return `nil` instead.

- [ ] **Step 4: Run persistence tests and verify GREEN**

Run `swift test --filter PracticeNavigationSnapshotStoreTests` and expect all tests to pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerUI/PracticeNavigationSnapshotStore.swift Tests/RussianCornerAppTests/PracticeNavigationSnapshotStoreTests.swift
git commit -m "feat: persist daily answer sheet state"
```

### Task 3: Integrate free navigation with the practice flow

**Files:**
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Modify: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`
- Modify: `Tests/RussianCornerAppTests/AppModelTests.swift`

- [ ] **Step 1: Write failing flow tests**

Add tests proving:

```swift
func testJumpToFifthKeepsFirstFourPending()
func testExplicitNextMovesFromFifthToSixth()
func testEndOfQueueWrapsToFirstMissedItem()
func testJumpingAwayFromRevealedItemMarksItUnassessed()
func testAssessedItemReopensReadOnlyWithoutDuplicateReviewEvent()
func testAgainAppendsRetryToAnswerSheet()
func testAllItemsFinishOnlyAfterExplicitNext()
func testRuntimeRestoresSameDayAnswerSheetSnapshot()
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
swift test --filter PracticeViewModelTests
swift test --filter AppModelTests
```

Expected failures: no jump API, linear advance skips missed items, and no snapshot restoration.

- [ ] **Step 3: Wire navigation into `PracticeViewModel`**

Add:

```swift
public private(set) var sessionNavigator: PracticeSessionNavigator
public var answerSheetItems: [PracticeAnswerSheetItem]
public func jumpToQuestion(at index: Int)
```

On `reveal()`, mark the current entry `.openedUnassessed`. On successful `persistGrade`, mark it `.assessed` or `.needsRetry`, synchronize an appended retry, and save. Change `next()` to use `nextPendingIndex`; set `currentIndex = queue.count` only when no pending entry remains. `jumpToQuestion` cancels speech and online lookup, saves an opened-unassessed state, resets transient detail/transfer state, and opens assessed entries with `isRevealed = true` plus `isAssessmentComplete = true`.

- [ ] **Step 4: Restore and save through `AppRuntime`**

Construct `PracticeNavigationSnapshotStore(defaults: defaults)` once in `AppRuntime`, pass it into every new `PracticeViewModel`, and persist after reveal, jump, assessment, retry append and explicit next.

- [ ] **Step 5: Run flow tests and verify GREEN**

Run the two filtered suites and expect zero failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerUI/PracticeViewModel.swift Sources/RussianCornerUI/AppModel.swift Tests/RussianCornerAppTests/PracticeViewModelTests.swift Tests/RussianCornerAppTests/AppModelTests.swift
git commit -m "feat: support free question navigation"
```

### Task 4: Answer-sheet popover UI

**Files:**
- Create: `Sources/RussianCornerUI/PracticeAnswerSheetView.swift`
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`
- Modify: `Tests/RussianCornerAppTests/FloatingPanelControllerTests.swift`

- [ ] **Step 1: Write failing UI-contract tests**

Assert that the progress action has at least a 30×30 hit target, answer-sheet status labels are stable, and opening the answer sheet does not select a larger `PracticePanelPresentation`.

- [ ] **Step 2: Run tests and verify RED**

Run `swift test --filter FloatingPanelControllerTests`; expect missing answer-sheet metrics and status labels.

- [ ] **Step 3: Implement `PracticeAnswerSheetView`**

Use a five-column `LazyVGrid`, a compact legend, and a 300-point fixed width. Each numbered button receives `PracticeAnswerSheetItem` and calls `onSelect(index)`. Apply status styling from a dedicated palette helper; provide complete accessibility labels such as “第 5 题，已看答案但未评估，当前题”.

- [ ] **Step 4: Attach the popover to the header**

Replace plain progress text with a button:

```swift
Button {
  isAnswerSheetPresented.toggle()
} label: {
  Label(progressText, systemImage: "square.grid.3x3")
}
.popover(isPresented: $isAnswerSheetPresented) {
  PracticeAnswerSheetView(items: practice.answerSheetItems) { index in
    practice.jumpToQuestion(at: index)
    isAnswerSheetPresented = false
    onLayoutChanged()
  }
}
```

Keep the popover outside `PracticePanelPresentation.resolve`; it must not resize the main card.

- [ ] **Step 5: Run UI-contract and model tests**

Run:

```bash
swift test --filter FloatingPanelControllerTests
swift test --filter PracticeViewModelTests
```

Expected: zero failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerUI/PracticeAnswerSheetView.swift Sources/RussianCornerUI/PracticeCardView.swift Tests/RussianCornerAppTests/FloatingPanelControllerTests.swift
git commit -m "feat: add practice answer sheet popover"
```

### Task 5: Full verification, packaging, and installation

**Files:**
- Verify only: `Scripts/build-app.sh`
- Verify only: `/Applications/Russian Corner.app`

- [ ] **Step 1: Run all tests**

```bash
swift test
```

Expected: every test passes; the existing microphone-dependent test may remain skipped.

- [ ] **Step 2: Build and validate the release bundle**

```bash
./Scripts/build-app.sh
codesign --verify --deep --strict "dist/Russian Corner.app"
```

Expected: resource probes, resource hashes, permissions and signature all report PASS.

- [ ] **Step 3: Install recoverably**

Quit the running app, move `/Applications/Russian Corner.app` into a unique `/tmp/russian-corner-answer-sheet-backup.XXXXXX` directory, copy the new app with `ditto`, verify executable hashes, and reopen it.

- [ ] **Step 4: Run final business checks**

Verify the answer-sheet unit tests again against the installed source commit, confirm the installed process is running, and run `git status --short` to ensure unrelated user files remain untouched.

- [ ] **Step 5: Commit any verification-only test adjustments**

Only if verification exposed an expectation that legitimately changed; otherwise do not create an empty commit.
