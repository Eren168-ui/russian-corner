# Russian Corner MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local macOS menu-bar application that links reviewed Russian vocabulary to sentence prompts, schedules active recall, supports speech/recording/reminders, and diagnoses recognition-versus-production gaps.

**Architecture:** A Swift Package separates a pure `RussianCornerCore` library from the SwiftUI executable. Core owns immutable content records, scheduling, daily queue composition, diagnostic metrics, and validation; the app target owns SwiftData persistence, `MenuBarExtra`, a floating `NSPanel`, notifications, speech, audio recording, and settings. Reviewed derivative content is bundled as JSON resources; the Obsidian source remains read-only.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, SwiftData, AVFoundation, UserNotifications, XCTest/Swift Testing, Swift Package Manager, ad-hoc signed macOS `.app` bundle.

---

## File map

- `Package.swift`: library, executable, resources, and test targets.
- `Sources/RussianCornerCore/Models.swift`: content and review value types.
- `Sources/RussianCornerCore/Scheduler.swift`: spaced repetition and adaptive new-word limits.
- `Sources/RussianCornerCore/DailyQueue.swift`: due/new/random queue composition.
- `Sources/RussianCornerCore/Diagnostics.swift`: baseline and weekly bottleneck metrics.
- `Sources/RussianCornerCore/ContentCatalog.swift`: bundle loading and content validation.
- `Sources/RussianCornerApp/`: SwiftUI application, SwiftData adapter, panel, services, and views.
- `Sources/RussianCornerApp/Resources/lexemes.json`: reviewed daily vocabulary.
- `Sources/RussianCornerApp/Resources/sentences.json`: reviewed sentence/chunk cards.
- `Tests/RussianCornerCoreTests/`: behavior-first tests for all core rules.
- `Scripts/build-app.sh`: release build, `.app` assembly, Info.plist, and ad-hoc signing.

### Task 1: Core models and adaptive scheduler

**Files:**
- Create: `Package.swift`
- Create: `Sources/RussianCornerCore/Models.swift`
- Create: `Sources/RussianCornerCore/Scheduler.swift`
- Test: `Tests/RussianCornerCoreTests/SchedulerTests.swift`

- [ ] **Step 1: Create the package manifest and write failing scheduler tests**

Tests must assert:

```swift
@Test func againReturnsToLevelZeroAndIsDueTomorrow()
@Test func hardKeepsLevelAndUsesShortInterval()
@Test func easyAdvancesAcrossOneThreeSevenFourteenThirtyDayIntervals()
@Test func newWordLimitDropsToSixBelowSeventyFivePercent()
@Test func newWordLimitIsTenFromSeventyFiveThroughNinetyPercent()
@Test func newWordLimitRisesToTwelveAfterThreeStrongDaysWithoutBacklog()
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter SchedulerTests`

Expected: compilation failure because `ReviewScheduler` and domain types do not exist.

- [ ] **Step 3: Implement minimal domain types and scheduler**

Required API:

```swift
public enum ReviewGrade: String, Codable, Sendable { case again, hard, easy }
public struct ReviewState: Codable, Sendable, Equatable {
    public var masteryLevel: Int
    public var dueAt: Date
}
public struct ReviewScheduler: Sendable {
    public func next(state: ReviewState, grade: ReviewGrade, now: Date) -> ReviewState
    public func adaptiveNewWordLimit(
        previousRecallRate: Double,
        strongDayStreak: Int,
        overdueCount: Int
    ) -> Int
}
```

- [ ] **Step 4: Run all tests and verify GREEN**

Run: `swift test`

Expected: all scheduler tests pass.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/RussianCornerCore Tests/RussianCornerCoreTests
git commit -m "feat: add adaptive review scheduler"
```

### Task 2: Daily queue and linked content catalog

**Files:**
- Create: `Sources/RussianCornerCore/DailyQueue.swift`
- Create: `Sources/RussianCornerCore/ContentCatalog.swift`
- Create: `Sources/RussianCornerApp/Resources/lexemes.json`
- Create: `Sources/RussianCornerApp/Resources/sentences.json`
- Test: `Tests/RussianCornerCoreTests/DailyQueueTests.swift`
- Test: `Tests/RussianCornerCoreTests/ContentCatalogTests.swift`

- [ ] **Step 1: Write failing queue and catalog tests**

Tests must prove:

```swift
@Test func queuePrioritizesDueThenNewThenRandom()
@Test func failedItemMayRepeatButSuccessfulItemDoesNotDuplicate()
@Test func draftContentIsNeverServed()
@Test func everyServedLexemeHasCollocationAndLinkedSentence()
@Test func catalogContainsAtLeastThreeHundredFiftyLexemes()
@Test func catalogContainsBetweenSixtyAndEightySentenceCards()
@Test func professionalAndConflictSourcesAreExcluded()
```

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter DailyQueueTests && swift test --filter ContentCatalogTests`

Expected: compilation failure because queue and catalog APIs do not exist.

- [ ] **Step 3: Implement queue composition and catalog loader**

Required behavior:

```swift
public struct DailyQueueBuilder {
    public func build(
        due: [PracticeItem],
        new: [PracticeItem],
        randomReview: [PracticeItem],
        targetCount: Int,
        retryIDs: Set<String>
    ) -> [PracticeItem]
}

public struct ContentCatalog {
    public let lexemes: [Lexeme]
    public let sentences: [SentenceCard]
    public func validate() -> [CatalogIssue]
}
```

The default queue is 60% due/weak, 30% new, and 10% random review, while due work always takes precedence.

- [ ] **Step 4: Build derivative daily-language resources**

Create at least 350 reviewed lexemes and 60–80 reviewed sentence cards. Each lexeme must include a stressed display form, speech text, Chinese gloss, part of speech, one collocation, one usable example, and at least one valid sentence link. Keep general daily Russian only.

- [ ] **Step 5: Run tests and verify GREEN**

Run: `swift test`

Expected: all catalog and queue tests pass with zero validation issues.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerCore Sources/RussianCornerApp/Resources Tests/RussianCornerCoreTests
git commit -m "feat: add linked vocabulary and sentence catalog"
```

### Task 3: SwiftData progress and system services

**Files:**
- Create: `Sources/RussianCornerApp/Persistence.swift`
- Create: `Sources/RussianCornerApp/SpeechService.swift`
- Create: `Sources/RussianCornerApp/RecordingService.swift`
- Create: `Sources/RussianCornerApp/ReminderService.swift`
- Test: `Tests/RussianCornerCoreTests/ReviewSessionTests.swift`

- [ ] **Step 1: Write failing session-state tests**

Tests must assert that response latency is persisted in `ReviewEvent`, progress survives encode/decode, denied microphone access is representable without blocking review, and reminder times default to 11:30 and 17:30.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter ReviewSessionTests`

Expected: failure because session and settings types do not exist.

- [ ] **Step 3: Implement core session/settings types and app adapters**

Use SwiftData models only in the app target. Keep core types `Codable` and testable. `SpeechService` uses a `ru-RU` `AVSpeechSynthesisVoice` when present and a safe fallback otherwise. `RecordingService` records to a temporary file and deletes it unless the user explicitly saves. `ReminderService` schedules exactly two configurable local notifications.

- [ ] **Step 4: Run tests and build**

Run: `swift test && swift build`

Expected: tests pass and both targets compile.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerCore Sources/RussianCornerApp Tests/RussianCornerCoreTests
git commit -m "feat: add local progress and system services"
```

### Task 4: Menu-bar app and floating corner card

**Files:**
- Create: `Sources/RussianCornerApp/RussianCornerApp.swift`
- Create: `Sources/RussianCornerApp/AppModel.swift`
- Create: `Sources/RussianCornerApp/FloatingPanelController.swift`
- Create: `Sources/RussianCornerApp/PracticeCardView.swift`
- Create: `Sources/RussianCornerApp/SettingsView.swift`
- Create: `Sources/RussianCornerApp/ProgressView.swift`

- [ ] **Step 1: Write failing view-model tests**

Tests must cover reveal-answer state, a 3-second latency timer, grade actions, quiet/speaking mode, corner persistence, and promotion from Chinese prompts to Russian cues at higher mastery.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter PracticeViewModelTests`

Expected: failure because the view model does not exist.

- [ ] **Step 3: Implement the view model and SwiftUI surfaces**

Build `MenuBarExtra`, a settings window, progress view, and a non-activating floating `NSPanel`. Support four corners, opacity, font scale, next/reveal/speak/record actions, and collapse. Register app-scoped keyboard shortcuts and keep the panel from stealing focus.

- [ ] **Step 4: Run tests and build**

Run: `swift test && swift build`

Expected: all tests pass and the executable builds.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerApp Tests/RussianCornerCoreTests
git commit -m "feat: add menu bar and floating practice card"
```

### Task 5: Baseline diagnostics and progress metrics

**Files:**
- Create: `Sources/RussianCornerCore/Diagnostics.swift`
- Create: `Sources/RussianCornerApp/DiagnosticView.swift`
- Test: `Tests/RussianCornerCoreTests/DiagnosticsTests.swift`

- [ ] **Step 1: Write failing diagnostic tests**

Tests must classify recognition/production gaps, slow lexical retrieval, weak listening, collocation gaps, and high self-monitoring from explicit observations without claiming automated pronunciation accuracy.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter DiagnosticsTests`

Expected: failure because `DiagnosticEngine` does not exist.

- [ ] **Step 3: Implement diagnostics**

The onboarding flow samples recognition and active recall, records response time, presents ten listening prompts, and guides two 60-second recordings. Weekly reports compare the same metrics and explain likely bottlenecks as hypotheses.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `swift test`

Expected: all diagnostic tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerCore Sources/RussianCornerApp Tests/RussianCornerCoreTests
git commit -m "feat: add baseline diagnostics"
```

### Task 6: Packaging, documentation, and full verification

**Files:**
- Create: `Scripts/build-app.sh`
- Create: `Documentation/USAGE.md`
- Modify: `README.md`
- Verify: `Verification/source-corpus-baseline.txt`

- [ ] **Step 1: Add packaging script**

The script must run a release build, create `dist/Russian Corner.app`, write an Info.plist with menu-bar and microphone usage metadata, copy the executable and resources, and ad-hoc sign the bundle.

- [ ] **Step 2: Build and inspect the app**

Run:

```bash
swift test
./Scripts/build-app.sh
codesign --verify --deep --strict "dist/Russian Corner.app"
plutil -lint "dist/Russian Corner.app/Contents/Info.plist"
```

Expected: tests pass; build exits 0; signature and plist verification succeed.

- [ ] **Step 3: Launch smoke test**

Run:

```bash
open "dist/Russian Corner.app"
pgrep -fl RussianCornerApp
```

Expected: the application process is running without an immediate crash.

- [ ] **Step 4: Verify the source corpus is unchanged**

Recompute the sorted Obsidian CLI content hash. Expected:

```text
File count: 46
SHA-256: 89ca565d1fa8b3840e89e7262b867d61fe486ea95962f1746c109bf2a4478b0c
```

- [ ] **Step 5: Update documentation and commit**

```bash
git add README.md Documentation Scripts Verification docs
git commit -m "docs: add app packaging and verified usage guide"
```
