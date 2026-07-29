# Russian Corner Learning History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add a card-level entry and a separate native learning-history window backed entirely by persisted local learning data.

**Architecture:** A pure `LearningHistoryBuilder` converts review events, mastery states, catalog topics, trial sessions, and the current target into one immutable snapshot. `AppRuntime` owns and refreshes that snapshot. A dedicated AppKit window controller presents the SwiftUI dashboard and is shared by the floating-card and menu-bar entry points.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, SwiftData, XCTest, Swift Package Manager.

---

## File structure

- Create `Sources/RussianCornerUI/LearningHistory.swift`: snapshot types and pure aggregation rules.
- Modify `Sources/RussianCornerUI/AppModel.swift`: load repository data and expose the history snapshot/status.
- Replace `Sources/RussianCornerUI/ProgressView.swift`: render the full history dashboard.
- Modify `Sources/RussianCornerUI/PracticeCardView.swift`: add the visible “记录” callback button.
- Modify `Sources/RussianCornerUI/FloatingPanelController.swift`: pass the open-history callback into the hosted card.
- Modify `Sources/RussianCornerApp/RussianCornerApp.swift`: own a reusable history window controller and route both entry points to it.
- Create `Tests/RussianCornerAppTests/LearningHistoryTests.swift`: aggregation regression tests.
- Modify `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`: runtime integration assertions.
- Modify `Tests/RussianCornerAppTests/FloatingPanelControllerTests.swift`: card entry contract assertion.
- Create `Verification/2026-07-29-learning-history-acceptance.md`: record local build and visual acceptance evidence.

### Task 1: Pure history aggregation

**Files:**
- Create: `Tests/RussianCornerAppTests/LearningHistoryTests.swift`
- Create: `Sources/RussianCornerUI/LearningHistory.swift`

- [x] **Step 1: Write failing tests**

Add tests that construct events across eight calendar days and assert:

```swift
XCTAssertEqual(snapshot.recentDays.count, 7)
XCTAssertEqual(snapshot.recentDays.map(\.day), expectedDays)
XCTAssertEqual(snapshot.recentDays[5].completedCount, 0)
XCTAssertEqual(snapshot.todayCompleted, 2)
XCTAssertEqual(snapshot.todayTarget, 10)
XCTAssertEqual(snapshot.todayCorrectCount, 2)
XCTAssertEqual(snapshot.todayAttemptCount, 3)
```

Add an independent streak test where today is empty but yesterday and the day before contain events:

```swift
XCTAssertEqual(snapshot.streakDays, 2)
XCTAssertTrue(snapshot.needsPracticeToday)
```

Add mastery and topic tests:

```swift
XCTAssertEqual(snapshot.masteredLexemeCount, 1)
XCTAssertEqual(snapshot.masteredSentenceCount, 1)
XCTAssertEqual(snapshot.coveredTopics.map(\.id), ["topic-1"])
```

- [x] **Step 2: Verify RED**

Run:

```bash
swift test --filter LearningHistoryTests
```

Expected: compilation fails because `LearningHistoryBuilder`, `LearningHistorySnapshot`, and `DailyLearningRecord` do not exist.

- [x] **Step 3: Implement the minimal immutable model and builder**

Implement:

```swift
public struct DailyLearningRecord: Identifiable, Equatable, Sendable {
  public var id: Date { day }
  public let day: Date
  public let completedCount: Int
  public let targetCount: Int
  public let correctCount: Int
  public let attemptCount: Int
  public let studyDurationSeconds: Int
}

public struct LearningHistorySnapshot: Equatable, Sendable {
  public let todayCompleted: Int
  public let todayTarget: Int
  public let streakDays: Int
  public let needsPracticeToday: Bool
  public let todayCorrectCount: Int
  public let todayAttemptCount: Int
  public let masteredLexemeCount: Int
  public let masteredSentenceCount: Int
  public let coveredTopics: [TopicDefinition]
  public let totalTopicCount: Int
  public let recentDays: [DailyLearningRecord]
}
```

`LearningHistoryBuilder.build(...)` must normalize all dates with the injected calendar, generate exactly seven ordered dates, count successful unique items, treat `.again` as incorrect, carry streak from yesterday when today is empty, and derive each day’s target from its earliest session.

- [x] **Step 4: Verify GREEN**

Run:

```bash
swift test --filter LearningHistoryTests
```

Expected: all `LearningHistoryTests` pass.

- [x] **Step 5: Commit**

```bash
git add Sources/RussianCornerUI/LearningHistory.swift Tests/RussianCornerAppTests/LearningHistoryTests.swift
git commit -m "feat: aggregate seven-day learning history"
```

### Task 2: Runtime integration and partial-history failure

**Files:**
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Modify: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`

- [x] **Step 1: Write failing runtime tests**

Use in-memory `ProgressRepository` and a `TrialDataStoring` fixture. Assert:

```swift
try runtime.refreshLearningHistory(now: now, calendar: calendar)
XCTAssertEqual(runtime.learningHistory.todayTarget, runtime.practice?.totalCount)
XCTAssertEqual(runtime.learningHistory.recentDays.count, 7)
```

Add a throwing trial store and assert the method still returns core summary data while setting a nonfatal history status.

- [x] **Step 2: Verify RED**

Run:

```bash
swift test --filter AppModelTests/testRuntimeLearningHistory
```

Expected: compilation fails because `learningHistory` and `refreshLearningHistory` do not exist.

- [x] **Step 3: Integrate the builder**

Add:

```swift
public private(set) var learningHistory = LearningHistorySnapshot()
public private(set) var learningHistoryStatus: String?
```

Implement `refreshLearningHistory(now:calendar:)` to read core events/mastery, fetch the seven-day trial snapshot when available, fall back to `.empty` on trial failure, and call `LearningHistoryBuilder`. Keep `refreshProgress` as a compatibility wrapper populated from the new snapshot until callers are migrated.

- [x] **Step 4: Verify GREEN**

Run:

```bash
swift test --filter AppModelTests
```

Expected: all `AppModelTests` pass.

- [x] **Step 5: Commit**

```bash
git add Sources/RussianCornerUI/AppModel.swift Tests/RussianCornerAppTests/PracticeViewModelTests.swift
git commit -m "feat: expose persisted learning history in runtime"
```

### Task 3: Visible card entry and reusable separate window

**Files:**
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`
- Modify: `Sources/RussianCornerUI/FloatingPanelController.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`
- Modify: `Tests/RussianCornerAppTests/FloatingPanelControllerTests.swift`

- [x] **Step 1: Write the failing entry contract test**

Assert the card presentation contract includes a text entry with a comfortable hit target:

```swift
XCTAssertEqual(PracticeCardMetrics.historyActionTitle, "记录")
XCTAssertGreaterThanOrEqual(PracticeCardMetrics.historyActionHitHeight, 28)
```

- [x] **Step 2: Verify RED**

Run:

```bash
swift test --filter PracticePanelPresentationTests
```

Expected: compilation fails because the history action metrics do not exist.

- [x] **Step 3: Add the callback and window controller**

Add `onOpenLearningHistory: () -> Void` to `PracticeCardView` and render:

```swift
Button(action: onOpenLearningHistory) {
  Label("记录", systemImage: "chart.bar.xaxis")
}
.accessibilityLabel("打开学习记录")
```

Pass the callback through `FloatingPanelController`. In the app target, create one `LearningHistoryWindowController` using `NSHostingController(rootView: RussianCornerProgressView(runtime: runtime))`. Route both the card and menu action through its `show()` method; refresh data before presenting and call `NSApplication.shared.activate(ignoringOtherApps: true)`.

- [x] **Step 4: Verify GREEN**

Run:

```bash
swift test --filter PracticePanelPresentationTests
swift build
```

Expected: tests and compilation pass.

- [x] **Step 5: Commit**

```bash
git add Sources/RussianCornerUI/PracticeCardView.swift Sources/RussianCornerUI/FloatingPanelController.swift Sources/RussianCornerApp/RussianCornerApp.swift Tests/RussianCornerAppTests/FloatingPanelControllerTests.swift
git commit -m "feat: open learning history from practice card"
```

### Task 4: Full native history dashboard

**Files:**
- Modify: `Sources/RussianCornerUI/ProgressView.swift`

- [x] **Step 1: Write a failing formatting test**

Add pure display helpers to `LearningHistory.swift` and tests for:

```swift
XCTAssertEqual(snapshot.todayAccuracyText, "67%")
XCTAssertEqual(snapshot.todayProgressText, "8 / 10")
XCTAssertEqual(empty.todayAccuracyText, "—")
```

- [x] **Step 2: Verify RED**

Run:

```bash
swift test --filter LearningHistoryTests/testDisplay
```

Expected: compilation fails because the display helpers do not exist.

- [x] **Step 3: Build the dashboard**

Replace the fixed summary-only view with a scrollable 820 × 720 dashboard containing:

- title and refresh control;
- summary cards for completion, streak, accuracy, and mastery split;
- `ProgressView(value:total:)` for today;
- a seven-column bar trend using `GeometryReader` and actual ratios;
- a seven-row daily report with date, completed/target, correct/attempts, accuracy, and duration;
- topic chips using `coveredTopics`;
- real empty and partial-data status text.

Use only SwiftUI primitives and existing palette conventions. All metric values must come from `runtime.learningHistory`.

- [x] **Step 4: Verify GREEN**

Run:

```bash
swift test --filter LearningHistoryTests
swift build
```

Expected: tests and build pass.

- [x] **Step 5: Commit**

```bash
git add Sources/RussianCornerUI/LearningHistory.swift Sources/RussianCornerUI/ProgressView.swift Tests/RussianCornerAppTests/LearningHistoryTests.swift
git commit -m "feat: render learning history dashboard"
```

### Task 5: Full verification, local app build, and visual acceptance

**Files:**
- Create: `Verification/2026-07-29-learning-history-acceptance.md`

- [x] **Step 1: Run the complete test suite**

```bash
swift test
```

Expected: zero failures; opt-in live dictionary test may remain skipped.

- [x] **Step 2: Build the local application**

```bash
Scripts/build-app.sh
```

Expected: exit 0 and a locally runnable `.app` artifact. Do not deploy or publish.

- [x] **Step 3: Launch and visually inspect**

Open the locally built app, click the practice-card “记录” button, and verify:

- a separate window opens;
- all six requested data areas are visible;
- the seven-day trend and daily rows are not clipped;
- mastered units are split correctly;
- topic names are readable;
- empty or partial history is honest;
- the floating practice card remains usable.

Save a screenshot under `Verification/`.

- [x] **Step 4: Record acceptance evidence**

Write exact test counts, build artifact path, screenshot path, and checklist results to `Verification/2026-07-29-learning-history-acceptance.md`.

- [x] **Step 5: Commit**

```bash
git add Verification/2026-07-29-learning-history-acceptance.md Verification/2026-07-29-learning-history.png
git commit -m "test: verify learning history experience"
```

