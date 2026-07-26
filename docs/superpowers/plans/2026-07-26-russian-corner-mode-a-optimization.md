# Russian Corner Mode A Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把现有俄语角落卡升级为适合 7 天真实试用的紧凑碎片化训练产品：保留已验证的复习调度，采用 AIM 风格的轻量视觉语言，记录不干扰核心进度的试用数据，生成用户可读的 Markdown 报告，并把鸡肋的录音回放改成不保存音频的 60 秒口述活动检测。

**Architecture:** 保持 `RussianCornerCore → RussianCornerPlatform → RussianCornerUI → RussianCornerApp` 单向依赖。核心学习进度继续写入 `RussianCorner.store`；试用会话、交互、每日反馈和口述活动摘要写入独立的 `RussianCornerTrial.store`，任何试用统计失败都只能显示非阻塞提示，不能回滚评分。角落卡默认 360×240，详情原位展开到 430×386；诊断只读取麦克风电平，不录制、不保存、不回放音频。

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, Observation, SwiftData, AVFoundation (`AVAudioEngine` only for speech activity), XCTest, Swift Package Manager, macOS 14+.

---

## File map

### Create

- `Sources/RussianCornerCore/TrialModels.swift`: 试用会话、交互、反馈、口述摘要和报告输入值类型。
- `Sources/RussianCornerCore/TrialReportBuilder.swift`: 纯函数式 Markdown 报告生成器。
- `Sources/RussianCornerPlatform/TrialPersistence.swift`: 独立 `RussianCornerTrial.store` 的 SwiftData schema 与 repository。
- `Sources/RussianCornerPlatform/SpeechActivityMonitor.swift`: 只分析实时音量、不写音频文件的麦克风活动检测。
- `Sources/RussianCornerUI/CardTheme.swift`: AIM 风格的浅色/深色语义颜色与字体。
- `Sources/RussianCornerUI/PracticeDetailSection.swift`: 搭配、语法和场景的按需展开区。
- `Sources/RussianCornerUI/TrialSessionCoordinator.swift`: 3 分钟空闲切分、跨日和关闭原因管理。
- `Sources/RussianCornerUI/DailyReflectionView.swift`: 每日一次的轻量反馈表单。
- `Sources/RussianCornerUI/DailyReflectionViewModel.swift`: 反馈读取、保存和当天去重。
- `Sources/RussianCornerUI/TrialReportExporter.swift`: `NSSavePanel` 导出用户可读 Markdown。
- `Tests/RussianCornerCoreTests/TrialReportBuilderTests.swift`
- `Tests/RussianCornerPlatformTests/TrialPersistenceTests.swift`
- `Tests/RussianCornerPlatformTests/SpeechActivityMonitorTests.swift`
- `Tests/RussianCornerAppTests/TrialSessionCoordinatorTests.swift`
- `Tests/RussianCornerAppTests/DailyReflectionViewModelTests.swift`

### Modify

- `Sources/RussianCornerUI/PracticeViewModel.swift`: 移除日常录音依赖，增加详情状态与试用交互埋点。
- `Sources/RussianCornerUI/PracticeCardView.swift`: 改为 360×240 紧凑卡、答案后仅显示一条搭配、详情按需展开。
- `Sources/RussianCornerUI/FloatingPanelController.swift`: 支持折叠/紧凑/详情三种尺寸，并准确结束试用会话。
- `Sources/RussianCornerUI/DiagnosticViewModel.swift`: 录音步骤改为 60 秒口述活动检测。
- `Sources/RussianCornerUI/DiagnosticView.swift`: 删除录音/回放语义，显示口述计时、说话时长和停顿摘要。
- `Sources/RussianCornerUI/GlobalHotKeyService.swift`: 删除录音快捷键，保留显示/隐藏和收起/展开。
- `Sources/RussianCornerUI/AppModel.swift`: 增加每日反馈展示状态和非阻塞试用状态。
- `Sources/RussianCornerApp/RussianCornerApp.swift`: 组装独立试用仓、反馈窗口、报告导出和退出会话收口。
- `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`
- `Tests/RussianCornerAppTests/TransactionalInteractionTests.swift`
- `Tests/RussianCornerAppTests/SpeechLifecycleTests.swift`
- `Tests/RussianCornerAppTests/DiagnosticViewModelTests.swift`
- `Documentation/USAGE.md`
- `README.md`

### Keep unchanged

- `Sources/RussianCornerCore/Scheduler.swift`: 继续使用现有 Again/Hard/Easy 和 6/10/12 新词调度。
- `Sources/RussianCornerPlatform/Persistence.swift`: 核心学习进度 schema 和 `RussianCorner.store` 不迁移、不改名。
- `Sources/RussianCornerCore/Resources/*.json`: 本轮不扩充语料、不改原始 Obsidian。
- 原始 OneDrive 俄语资料：继续只读。

## Approved scope amendment: A2-to-B1 vocabulary floor

The learner clarified during implementation that A1/A2 material is already
known and must not consume new-word slots. The default profile is therefore
`A2 已完成、正在冲 B1`:

- absolute beginner lemmas such as `привет`, `здравствуйте`, `спасибо`,
  `понимать`, `знать`, basic family/home/food/time words are suppressed as
  standalone vocabulary cards;
- suppressed words may remain inside natural example sentences and dialogues;
- higher-value A2-to-B1 bridge verbs, collocations, government, aspect pairs,
  connectors and scenario expressions remain eligible;
- diagnostics use the same profile so a repaired baseline does not test known
  greeting vocabulary;
- at least 250 reviewed standalone lexemes must remain eligible;
- the original JSON and Obsidian sources remain unchanged.

Implementation files:

- `Sources/RussianCornerCore/LearnerVocabularyProfile.swift`
- `Tests/RussianCornerCoreTests/VocabularyProfileTests.swift`
- `Sources/RussianCornerUI/PracticeViewModel.swift`
- `Sources/RussianCornerUI/DiagnosticViewModel.swift`
- `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`

- [x] Write failing profile and queue tests.
- [x] Add the A2-to-B1 standalone-word suppression profile.
- [x] Apply it to daily practice and diagnostics.
- [x] Verify at least 250 reviewed words remain eligible.

## Data and behavior contracts

```swift
public enum TrialInteractionKind: String, Codable, Sendable {
  case reveal, grade, speak, detailsOpened, next
}

public enum TrialPromptDirection: String, Codable, Sendable {
  case recognition, production, sentenceProduction
}

public enum TrialPromptLevel: String, Codable, Sendable {
  case chinese, russian, scene
}

public enum TrialSessionEndReason: String, Codable, Sendable {
  case completed, hidden, quit, dayChanged, idle
}
```

- “正确”只按评分计算：`Again = failure`，`Hard/Easy = success`。
- 反应时间只统计已经揭示答案并提交评分的项目。
- 中文→俄语、俄语→中文、句子输出必须分方向汇总，不能混成一个正确率。
- 每张卡的 `detailsOpened` 和 `speak` 标记在进入下一张时重置。
- 核心评分先提交；试用埋点后提交且 fail-open。
- 会话从第一次有意义交互开始；3 分钟无交互、完成、隐藏、退出或跨日时结束。
- 全天悬浮但未交互的时间不得计入学习时长。
- 每日反馈每天最多一条，可修改当天条目，不得重复新增。
- 报告只导出 Markdown；不自动写入 OneDrive/Obsidian，不导出音频和本机隐私路径。

### Task 1: Add trial domain models

**Files:**
- Create: `Sources/RussianCornerCore/TrialModels.swift`
- Test: `Tests/RussianCornerCoreTests/TrialReportBuilderTests.swift`

- [ ] **Step 1: Write failing value-type tests**

先建立 `TrialReportBuilderTests.swift`，只测试模型的 Codable round-trip 和评分语义：

```swift
func testAgainIsFailureAndHardEasyAreSuccess() throws {
  XCTAssertFalse(TrialGradeOutcome(grade: .again).isSuccess)
  XCTAssertTrue(TrialGradeOutcome(grade: .hard).isSuccess)
  XCTAssertTrue(TrialGradeOutcome(grade: .easy).isSuccess)
}

func testTrialInteractionRoundTripsWithoutLocalPaths() throws {
  let value = TrialInteraction(
    sessionID: UUID(),
    itemType: .lexeme,
    itemID: "lex-001",
    kind: .grade,
    direction: .production,
    promptLevel: .chinese,
    grade: .hard,
    responseTimeMs: 2_900,
    usedSpeech: true,
    openedDetails: false,
    practiceMode: .speaking,
    createdAt: Date(timeIntervalSince1970: 100)
  )
  XCTAssertEqual(
    try JSONDecoder().decode(
      TrialInteraction.self,
      from: JSONEncoder().encode(value)
    ),
    value
  )
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter TrialReportBuilderTests
```

Expected: compilation fails because the trial types do not exist.

- [ ] **Step 3: Implement immutable, Sendable trial values**

Implement these public types in `TrialModels.swift`:

```swift
public struct TrialGradeOutcome: Equatable, Sendable {
  public let grade: ReviewGrade
  public var isSuccess: Bool { grade != .again }
}

public struct TrialInteraction: Codable, Equatable, Sendable {
  public let sessionID: UUID
  public let itemType: PracticeItemKind
  public let itemID: String
  public let kind: TrialInteractionKind
  public let direction: TrialPromptDirection
  public let promptLevel: TrialPromptLevel
  public let grade: ReviewGrade?
  public let responseTimeMs: Int?
  public let usedSpeech: Bool
  public let openedDetails: Bool
  public let practiceMode: PracticeMode
  public let createdAt: Date
}

public struct TrialSession: Codable, Equatable, Sendable {
  public let id: UUID
  public let startedAt: Date
  public let endedAt: Date
  public let endReason: TrialSessionEndReason
  public let startQueueCount: Int
  public let endQueueCount: Int
  public let completedLexemeCount: Int
  public let completedSentenceCount: Int
  public let newItemCount: Int
  public let reviewItemCount: Int
  public let remainingBacklogCount: Int
  public let exitItemType: PracticeItemKind?
  public let exitQueuePosition: Int?
  public var durationMs: Int {
    max(0, Int(endedAt.timeIntervalSince(startedAt) * 1_000))
  }
}

public struct DailyReflection: Codable, Equatable, Sendable {
  public let day: Date
  public let mostBlocked: String
  public let spokeNaturally: Bool?
  public let spokeNaturallyNote: String
  public let completionReason: DailyCompletionReason
  public let completionReasonNote: String
  public let updatedAt: Date
}

public struct OralActivityAttempt: Codable, Equatable, Sendable {
  public let topic: String
  public let attemptedAt: Date
  public let elapsedMs: Int
  public let estimatedSpeakingMs: Int?
  public let longPauseCount: Int?
  public let selfRating: Int
  public let usedMicrophoneMeter: Bool
}

public struct TrialReportSnapshot: Equatable, Sendable {
  public let sessions: [TrialSession]
  public let interactions: [TrialInteraction]
  public let reflections: [DailyReflection]
  public let oralAttempts: [OralActivityAttempt]
}
```

Define `DailyCompletionReason` as a closed enum with
`completed / time / fatigue / tooHard / interrupted / other`. Trim free text and
cap each free-text field at 200 characters. Store day values with
`Calendar.startOfDay(for:)` at the repository boundary.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
swift test --filter TrialReportBuilderTests
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerCore/TrialModels.swift Tests/RussianCornerCoreTests/TrialReportBuilderTests.swift
git commit -m "feat: add mode a trial domain models"
```

### Task 2: Persist trial data in a separate fail-open store

**Files:**
- Create: `Sources/RussianCornerPlatform/TrialPersistence.swift`
- Create: `Tests/RussianCornerPlatformTests/TrialPersistenceTests.swift`

- [ ] **Step 1: Write failing repository isolation tests**

Tests must prove:

```swift
func testTrialContainerUsesDifferentStoreFromCoreProgress()
func testSessionAndInteractionsSurviveRepositoryReopen()
func testDailyReflectionUpsertsOneRecordPerCalendarDay()
func testFetchRangeExcludesRowsOutsideSevenDayWindow()
func testOralAttemptStoresNumbersButNeverAudioURL()
```

For the on-disk test, create a unique temporary directory with
`FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)`,
then delete only that exact directory in `tearDown`.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --filter TrialPersistenceTests
```

Expected: compilation fails because `TrialRepository` does not exist.

- [ ] **Step 3: Implement a dedicated SwiftData schema**

Create four `@Model` records:

```swift
@Model final class TrialSessionRecord { /* timestamps, end reason, queue and exit snapshot */ }
@Model final class TrialInteractionRecord { /* all TrialInteraction scalar fields */ }
@Model final class DailyReflectionRecord { /* dayKey is unique */ }
@Model final class OralActivityAttemptRecord { /* numeric summary only */ }
```

Expose a protocol that can be faked by UI tests:

```swift
@MainActor
public protocol TrialDataStoring: AnyObject {
  func save(session: TrialSession) throws
  func save(interaction: TrialInteraction) throws
  func upsert(reflection: DailyReflection, calendar: Calendar) throws
  func save(oralAttempt: OralActivityAttempt) throws
  func fetchSnapshot(from start: Date, through end: Date) throws
    -> TrialReportSnapshot
  func reflection(on day: Date, calendar: Calendar) throws
    -> DailyReflection?
}
```

`TrialRepository.makeContainer(...)` must use:

```swift
let storeURL = appDirectory.appendingPathComponent("RussianCornerTrial.store")
let configuration = ModelConfiguration(
  "RussianCornerTrial",
  schema: schema,
  url: storeURL,
  cloudKitDatabase: .none
)
```

Do not add these records to `ProgressRepository.makeContainer`.

- [ ] **Step 4: Make multi-field writes transactional**

Each save/upsert method uses one `ModelContext`, calls `context.save()` once, and
calls `context.rollback()` on failure. `fetchSnapshot` sorts by timestamp so the
report is deterministic.

- [ ] **Step 5: Run platform tests and verify GREEN**

Run:

```bash
swift test --filter TrialPersistenceTests
swift test --filter RussianCornerPlatformTests
```

Expected: all platform tests pass and the isolation assertion sees both
`RussianCorner.store` and `RussianCornerTrial.store` as distinct paths.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerPlatform/TrialPersistence.swift Tests/RussianCornerPlatformTests/TrialPersistenceTests.swift
git commit -m "feat: persist trial analytics in isolated store"
```

### Task 3: Track real interactions and split sessions correctly

**Files:**
- Create: `Sources/RussianCornerUI/TrialSessionCoordinator.swift`
- Create: `Tests/RussianCornerAppTests/TrialSessionCoordinatorTests.swift`
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`
- Modify: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`
- Modify: `Tests/RussianCornerAppTests/TransactionalInteractionTests.swift`

- [ ] **Step 1: Write failing session lifecycle tests**

Tests must cover:

```swift
func testSessionStartsOnFirstMeaningfulInteractionNotViewAppearance()
func testThreeMinutesOfInactivityClosesSessionAtLastInteraction()
func testInteractionBeforeThreeMinutesKeepsSameSession()
func testHiddenCompletedQuitAndDayChangePersistTheirOwnEndReason()
func testCardFlagsResetAfterAdvance()
func testTrialWriteFailureDoesNotUndoCommittedReview()
func testRecognitionAndProductionDirectionsAreRecordedSeparately()
```

Use injected `now: () -> Date`; do not sleep for three minutes. Expose
`expireIdleSession(at:)` for deterministic tests.

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift test --filter TrialSessionCoordinatorTests
swift test --filter PracticeViewModelTests
```

Expected: failures because no coordinator/tracker exists.

- [ ] **Step 3: Implement a non-throwing tracking boundary**

```swift
@MainActor
public protocol PracticeTrialTracking: AnyObject {
  func record(
    kind: TrialInteractionKind,
    context: TrialInteractionContext
  )
  func close(reason: TrialSessionEndReason)
}

@MainActor
@Observable
public final class TrialSessionCoordinator: PracticeTrialTracking {
  public private(set) var lastIssue: String?
  // All repository errors are caught here and surfaced through lastIssue.
}
```

Coordinator rules:

- `reveal`, `grade`, `speak`, `detailsOpened`, `next` all count as meaningful.
- New session starts when there is no open session.
- Every interaction reschedules a cancellable 3-minute idle `Task`.
- Idle session ends at `lastInteractionAt`, not at the timer callback time.
- A calendar-day change closes the old session with `.dayChanged` before starting
  a new session.
- `close(reason:)` is idempotent.
- The first and last interaction contexts supply queue counts, card-type counts,
  new/review counts, remaining backlog, exit item type and queue position for the
  persisted `TrialSession`.

- [ ] **Step 4: Integrate tracking into PracticeViewModel**

Add:

```swift
public private(set) var isDetailExpanded = false
private let trialTracker: (any PracticeTrialTracking)?
private var usedSpeechOnCurrentItem = false
private var openedDetailsOnCurrentItem = false

public func toggleDetails() {
  isDetailExpanded.toggle()
  if isDetailExpanded {
    openedDetailsOnCurrentItem = true
    trialTracker?.record(kind: .detailsOpened, context: trialContext())
  }
}
```

Record response time only on grade after reveal. Preserve the transaction order:

```swift
try repository.commitReview(...)
trialTracker?.record(kind: .grade, context: trialContext(grade: grade))
advance(...)
```

Do not let a trial error throw from `grade(_:)`. Reset detail/speech flags in the
same method that advances `currentIndex`.

- [ ] **Step 5: Run focused and regression tests**

Run:

```bash
swift test --filter TrialSessionCoordinatorTests
swift test --filter TransactionalInteractionTests
swift test --filter PracticeViewModelTests
```

Expected: all tests pass; the existing “failed core commit does not advance”
behavior remains unchanged.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerUI/TrialSessionCoordinator.swift Sources/RussianCornerUI/PracticeViewModel.swift Tests/RussianCornerAppTests
git commit -m "feat: track mode a practice sessions"
```

### Task 4: Remove daily recording and its global shortcut

**Files:**
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`
- Modify: `Sources/RussianCornerUI/GlobalHotKeyService.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`
- Modify: `Tests/RussianCornerAppTests/TransactionalInteractionTests.swift`
- Modify: `Tests/RussianCornerAppTests/SpeechLifecycleTests.swift`
- Modify: `Documentation/USAGE.md`

- [ ] **Step 1: Replace recording-focused tests with the intended boundary**

Delete tests and fakes that only validate daily:

- start/stop recording;
- playback;
- save into `Recordings`;
- discard on next/disappear;
- `.toggleRecording` hotkey.

Add assertions:

```swift
func testPracticeViewModelHasNoRecordingDependency()
func testDisappearStopsSpeechOnly()
func testDefaultHotKeysContainEightActionsAndNoRecordingAction()
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
swift test --filter SpeechLifecycleTests
swift test --filter TransactionalInteractionTests
```

Expected: the new API assertions fail while recording APIs still exist.

- [ ] **Step 3: Remove recording from daily practice**

From `PracticeViewModel`, remove:

- `RecordingManaging`, `RecordingPlaying`, `recordingsDirectory`;
- `isRecording`, `hasRecording`, `isPlayingRecording`;
- `toggleRecording`, `playRecording`, `saveRecording`, `discardRecording`;
- all cleanup calls tied to grading, next and disappearance.

Keep `SpeechService.stop()` in `next()` and `handleDisappear()`.

From `PracticeCardView`, remove recording/play/save/discard controls. Keep
“朗读” because it is input support and is now tracked as `speak`.

- [ ] **Step 4: Remove the recording shortcut without renumbering collapse**

Delete `.toggleRecording = 8`. Keep:

```swift
case toggleCollapsed = 9
```

The gap is intentional and harmless; preserving `9` avoids silently changing an
existing hotkey action identifier. Remove the registration closure and update
the usage document to eight shortcuts.

Do not delete `RecordingService.swift` or `RecordingPlaybackService.swift` in
this task: diagnostic migration happens later, and deleting them early would
make the change unnecessarily broad.

- [ ] **Step 5: Run full tests and verify GREEN**

Run:

```bash
swift test
```

Expected: all tests pass and `rg -n "toggleRecording|saveRecording|playRecording" Sources/RussianCornerUI Sources/RussianCornerApp` returns no matches.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerUI Sources/RussianCornerApp Tests/RussianCornerAppTests Documentation/USAGE.md
git commit -m "refactor: remove daily practice recording"
```

### Task 5: Build the compact AIM-style corner card

**Files:**
- Create: `Sources/RussianCornerUI/CardTheme.swift`
- Create: `Sources/RussianCornerUI/PracticeDetailSection.swift`
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`
- Modify: `Sources/RussianCornerUI/FloatingPanelController.swift`
- Modify: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`
- Modify: `Tests/RussianCornerAppTests/TransactionalInteractionTests.swift`

- [ ] **Step 1: Write failing layout-state tests**

Extract a pure sizing helper and test:

```swift
func testCollapsedPanelIs58By58()
func testCompactPanelIs360By240()
func testDetailsPanelIs430By386()
func testAdvancingCardReturnsFromDetailsToCompact()
func testCollapseTakesPriorityOverDetailsExpansion()
```

Required helper:

```swift
public enum PracticePanelPresentation: Equatable {
  case collapsed, compact, details

  public var size: CGSize {
    switch self {
    case .collapsed: CGSize(width: 58, height: 58)
    case .compact: CGSize(width: 360, height: 240)
    case .details: CGSize(width: 430, height: 386)
    }
  }
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift test --filter TransactionalInteractionTests
swift test --filter PracticeViewModelTests
```

Expected: failures because three-state presentation is not implemented.

- [ ] **Step 3: Implement semantic light/dark theme**

`CardTheme` must use `Color(light:dark:)`-style semantic resolution or an
equivalent `@Environment(\.colorScheme)` mapping with these exact tokens:

```swift
// Light
background = #FAF9F5
primary = #2A2620
secondary = #3D3929
muted = #83827D
accent = #C96442
border = #DAD9D4
accentSurface = #F0EEE7

// Dark
background = #262624
primary = #FAF9F5
secondary = #C3C0B6
muted = #B7B5A9
accent = #D97757
border = #3E3E38
accentSurface = #141413
```

Use system sans-serif for controls and `.system(.title2, design: .serif)` for
the Russian answer. Do not copy AIM branding, logo, proprietary text, or page
layout.

- [ ] **Step 4: Recompose PracticeCardView**

Compact card must fit within 360×240 and show:

1. theme + progress;
2. Chinese intent/Russian prompt;
3. 3-second recall cue;
4. reveal button;
5. after reveal: answer + first collocation only;
6. `Again / Hard / Easy`;
7. small “详情” and “朗读” actions.

Move grammar labels, remaining collocations, example sentence and micro-dialogue
into `PracticeDetailSection`. The details button calls
`practice.toggleDetails()` and changes label to “收起详情” while open.

- [ ] **Step 5: Make the panel observe both collapse and detail state**

`FloatingPanelController.refreshLayout()` selects:

```swift
let presentation: PracticePanelPresentation =
  appModel.isCollapsed ? .collapsed :
  runtime?.practice?.isDetailExpanded == true ? .details :
  .compact
panel.setContentSize(presentation.size)
```

The observation closure must read
`runtime?.practice?.isDetailExpanded` in addition to AppModel preferences, then
re-register observation after every change.

- [ ] **Step 6: Verify accessibility and visual behavior manually**

Run:

```bash
swift run RussianCorner
```

Manual checks:

- Light and dark system appearances both meet readable contrast.
- Russian stress marks are not clipped at font scale 0.85 and 1.35.
- Compact card remains 360×240 before/after reveal.
- Details expand in place and shrink after next/grade.
- Ctrl+Option+R hides/shows; Ctrl+Option+C collapses/expands.
- Card remains movable and snaps to all four corners.

- [ ] **Step 7: Run all tests and commit**

Run:

```bash
swift test
```

Expected: all tests pass.

```bash
git add Sources/RussianCornerUI Tests/RussianCornerAppTests
git commit -m "feat: add compact aim style practice card"
```

### Task 6: Add once-daily reflection

**Files:**
- Create: `Sources/RussianCornerUI/DailyReflectionViewModel.swift`
- Create: `Sources/RussianCornerUI/DailyReflectionView.swift`
- Create: `Tests/RussianCornerAppTests/DailyReflectionViewModelTests.swift`
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Modify: `Sources/RussianCornerUI/FloatingPanelController.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`

- [x] **Step 1: Write failing feedback tests**

```swift
func testCompletedDayOffersReflectionOnlyOnce()
func testSavingAgainUpdatesTodayInsteadOfCreatingDuplicate()
func testMenuCanOpenExistingReflectionForEditing()
func testRepositoryFailureKeepsCoreCompletionUsable()
func testReflectionTextIsTrimmedAndLimitedToTwoHundredCharacters()
```

- [x] **Step 2: Run and verify RED**

Run:

```bash
swift test --filter DailyReflectionViewModelTests
```

Expected: compilation fails because the view model does not exist.

- [x] **Step 3: Implement the feedback view model**

```swift
@MainActor
@Observable
public final class DailyReflectionViewModel {
  public var mostBlocked = ""
  public var spokeNaturally: Bool?
  public var spokeNaturallyNote = ""
  public var completionReason: DailyCompletionReason = .completed
  public var completionReasonNote = ""
  public private(set) var hasSavedToday = false
  public private(set) var statusMessage: String?

  public func loadToday()
  public func saveToday()
  public func shouldOfferAfterCompletion() -> Bool
}
```

Repository failures set `statusMessage`; they do not throw into practice
completion.

- [x] **Step 4: Implement a short user-facing form**

The view contains:

- “今天最卡的地方是什么？” 200 字以内；
- “今天有没有一句真正脱口而出？” 是/否/不确定，并可补一句说明；
- “今天完成或提前退出的原因？” 从完成、时间不足、疲劳、太难、被打断、
  其他中选择，其他原因可补充；
- “保存” and “暂不填写”.

When the queue changes from incomplete to complete, the completion card embeds
`DailyReflectionView` only if `shouldOfferAfterCompletion()` is true. Dismissing
it sets an in-memory “offered today” flag so it does not interrupt again during
that launch. Also provide a dedicated window for the menu action:

```swift
Window("今日反馈", id: "daily-reflection") {
  DailyReflectionView(model: runtime.dailyReflection)
}
```

Add menu item “今日反馈…”, which may always open the existing entry for editing.

- [x] **Step 5: Run tests and manual check**

Run:

```bash
swift test --filter DailyReflectionViewModelTests
swift test
```

Manual check: complete the final card, dismiss feedback, reopen it from the menu,
save twice, and confirm only one record exists for today.

- [x] **Step 6: Commit**

```bash
git add Sources/RussianCornerUI Sources/RussianCornerApp Tests/RussianCornerAppTests/DailyReflectionViewModelTests.swift
git commit -m "feat: add daily trial reflection"
```

### Task 7: Generate and export a user-readable Markdown report

**Files:**
- Create: `Sources/RussianCornerCore/TrialReportBuilder.swift`
- Modify: `Tests/RussianCornerCoreTests/TrialReportBuilderTests.swift`
- Create: `Sources/RussianCornerUI/TrialReportExporter.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`

- [x] **Step 1: Write failing report tests**

Use fixed UTC dates and assert exact sections:

```swift
func testReportContainsUsageCompletionTimeAndDailyCards()
func testReportSeparatesRecognitionProductionAndSentenceOutput()
func testReportUsesMedianOfOnlyRevealedGradedResponses()
func testReportContainsBacklogExitDetailSpeechReflectionAndOralSections()
func testReportDoesNotContainJSONAudioURLOrSourcePath()
func testEmptySevenDayPeriodStillProducesUsefulChineseReport()
```

Expected headings:

```markdown
# 俄语角落卡｜7 天试用报告
## 使用概览
## 主动提取
## 复习与积压
## 使用行为
## 每日反馈
## 口述活动
```

- [x] **Step 2: Run and verify RED**

Run:

```bash
swift test --filter TrialReportBuilderTests
```

Expected: report tests fail because the builder does not exist.

- [x] **Step 3: Implement deterministic aggregation**

```swift
public struct TrialReportBuilder: Sendable {
  public init(calendar: Calendar)
  public func markdown(
    snapshot: TrialReportSnapshot,
    range: ClosedRange<Date>
  ) -> String
}
```

Required calculations:

- usage day = at least one graded item or saved reflection;
- completion rate = completed target / daily target;
- active time = sum of persisted closed session durations;
- direction success rate = `Hard + Easy` divided by all grades in that direction;
- median response time ignores reveal-only and ungraded interactions;
- details/speech rate counts unique graded cards with each flag;
- exits group by `completed/hidden/quit/dayChanged/idle`;
- facts derived from interaction/session data and statements copied from user
  self-reflection are explicitly labelled separately;
- do not generate automatic learning advice or decide the next iteration for the
  user.

- [x] **Step 4: Implement NSSavePanel export**

`TrialReportExporter`:

```swift
@MainActor
public func exportLastSevenDays(
  repository: any TrialDataStoring,
  endingAt now: Date,
  calendar: Calendar
) async
```

Defaults:

- filename: `俄语角落卡-7天试用报告-YYYY-MM-DD.md`;
- allowed content type: Markdown/plain text;
- starts in the user's Documents folder if available;
- writes only after the user confirms `NSSavePanel`;
- displays a non-blocking error through `AppModel.transientStatus`.

Do not auto-write to OneDrive, Obsidian, or a hard-coded path. Do not export
JSON.

- [x] **Step 5: Add the menu action and verify output**

Add “导出 7 天试用报告…” under the progress/diagnostic menu group. Export a fixed
fixture during tests and assert:

```bash
rg -n '\"sessionID\"|file:///|\\.m4a|sourcePath' /tmp/俄语角落卡-7天试用报告-*.md
```

Expected: no matches.

- [x] **Step 6: Run tests and commit**

Run:

```bash
swift test --filter TrialReportBuilderTests
swift test
```

Expected: all tests pass.

```bash
git add Sources/RussianCornerCore/TrialReportBuilder.swift Sources/RussianCornerUI/TrialReportExporter.swift Sources/RussianCornerApp/RussianCornerApp.swift Tests/RussianCornerCoreTests/TrialReportBuilderTests.swift
git commit -m "feat: export user readable trial report"
```

### Task 8: Replace diagnostic recording with speech activity measurement

**Files:**
- Create: `Sources/RussianCornerPlatform/SpeechActivityMonitor.swift`
- Create: `Tests/RussianCornerPlatformTests/SpeechActivityMonitorTests.swift`
- Modify: `Sources/RussianCornerUI/DiagnosticViewModel.swift`
- Modify: `Sources/RussianCornerUI/DiagnosticView.swift`
- Modify: `Tests/RussianCornerAppTests/DiagnosticViewModelTests.swift`
- Delete: `Sources/RussianCornerPlatform/RecordingPlaybackService.swift`
- Delete: `Sources/RussianCornerPlatform/RecordingService.swift`
- Modify: `Tests/RussianCornerPlatformTests/ReviewSessionTests.swift`

- [x] **Step 1: Write failing pure metering tests**

Separate audio hardware from the activity algorithm:

```swift
func testFramesAboveThresholdAccumulateSpeakingDuration()
func testSilenceLongerThanThresholdCountsOnePause()
func testShortSilenceDoesNotCountAsLongPause()
func testStopFlushesFinalSegmentExactlyOnce()
func testDeniedPermissionProducesTimerOnlyFallback()
func testSpeechSummaryContainsNoAudioDataOrFileURL()
```

Use a pure accumulator:

```swift
public struct SpeechActivityAccumulator: Sendable {
  public mutating func ingest(
    decibels: Double,
    duration: TimeInterval
  )
  public mutating func finish() -> SpeechActivitySummary
}
```

Default threshold is calibrated ambient dB + 10 dB, clamped to
`-45 ... -20 dB`; long pause threshold is 1.2 seconds.

- [x] **Step 2: Run and verify RED**

Run:

```bash
swift test --filter SpeechActivityMonitorTests
```

Expected: compilation fails because the accumulator and monitor do not exist.

- [x] **Step 3: Implement no-file AVAudioEngine monitoring**

Expose:

```swift
@MainActor
public protocol SpeechActivityMonitoring: AnyObject {
  var isMonitoring: Bool { get }
  func start() async -> SpeechActivityStartResult
  func stop() -> SpeechActivitySummary?
}
```

Implementation requirements:

- request microphone permission only when the oral test starts;
- use `AVAudioEngine.inputNode.installTap(...)`;
- compute RMS/dB from buffers and feed the accumulator;
- never create an audio URL;
- remove the tap and stop the engine on stop, timeout and view disappearance;
- permission denied/unavailable returns a typed fallback result, not an error that
  blocks diagnostics.

- [x] **Step 4: Convert both diagnostic steps**

Rename user-facing steps to:

- “60 秒自我介绍”
- “60 秒日常生活口述”

Flow:

1. 3-second preparation countdown;
2. 60-second oral timer;
3. if metering is available, show estimated speaking seconds and clear long-pause
   count after completion;
4. always ask 1–5 self-rating;
5. save `OralActivityAttempt`;
6. no playback, save, discard, or “listen to yourself” instruction.

If the microphone is denied, continue with timer + self-rating and
`usedMicrophoneMeter = false`.

- [x] **Step 5: Remove obsolete recording implementation**

Once no production target imports `RecordingManaging` or `RecordingPlaying`,
delete:

- `RecordingService.swift`;
- `RecordingPlaybackService.swift`;
- their platform/app test fakes and recording file tests.

Verify:

```bash
rg -n "AVAudioRecorder|RecordingManaging|RecordingPlaying|temporaryRecordingURL" Sources Tests
```

Expected: no matches.

- [x] **Step 6: Run diagnostics and permission fallbacks**

Run:

```bash
swift test --filter SpeechActivityMonitorTests
swift test --filter DiagnosticViewModelTests
swift test
```

Manual checks:

- microphone allowed: activity numbers appear after 60 seconds;
- microphone denied: timer and self-rating still complete;
- Activity Monitor/open files show no `.m4a`, `.caf`, or `.wav` created;
- diagnostic copy never claims accent or pronunciation accuracy.

- [x] **Step 7: Commit**

```bash
git add Sources/RussianCornerPlatform Sources/RussianCornerUI Tests
git commit -m "feat: replace recordings with oral activity test"
```

### Task 9: Wire runtime lifecycle, failure modes, and documentation

**Files:**
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Modify: `Sources/RussianCornerUI/FloatingPanelController.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`
- Modify: `README.md`
- Modify: `Documentation/USAGE.md`
- Modify: `Tests/RussianCornerAppTests/TransactionalInteractionTests.swift`

- [x] **Step 1: Write failing integration tests**

```swift
func testTrialStoreFailureLeavesPracticeAvailable()
func testHideClosesTrialSessionAsHidden()
func testQuitClosesTrialSessionAsQuit()
func testTemporalRefreshClosesSessionBeforeReplacingPracticeModel()
func testCoreProgressAndTodayQueueSurviveAppRuntimeRecreation()
func testTrialReportFailureShowsStatusWithoutCrashing()
```

- [x] **Step 2: Run and verify RED**

Run:

```bash
swift test --filter TransactionalInteractionTests
```

Expected: lifecycle assertions fail until runtime wiring is complete.

- [x] **Step 3: Assemble the runtime with fail-open trial services**

During `AppRuntime` initialization:

1. initialize core `ProgressRepository` exactly as before;
2. independently attempt `TrialRepository`;
3. if trial init fails, create practice without tracker and set a concise
   `transientStatus`;
4. initialize daily reflection/report export only when trial repository exists;
5. never set `practice = nil` because only the trial store failed.

Add explicit lifecycle calls:

```swift
panelController.hide()              // close(.hidden)
runtime.refreshPracticeForTemporalBoundary() // close(.dayChanged)
applicationWillTerminate            // close(.quit)
practice completion transition      // close(.completed)
```

Use an `NSApplicationDelegateAdaptor` for termination rather than assuming the
menu quit button is the only exit route.

- [x] **Step 4: Update documentation to match the product**

`README.md` and `Documentation/USAGE.md` must state:

- compact card, details expansion and dark mode behavior;
- explicit hide methods: menu “隐藏练习卡”, Ctrl+Option+R, and collapse
  Ctrl+Option+C;
- eight global shortcuts and no recording shortcut;
- oral activity test measures approximate speaking activity only;
- no audio is recorded or saved;
- report is Markdown for the learner to read;
- report export location is chosen by the user;
- `RussianCorner.store` and `RussianCornerTrial.store` are separate;
- original Obsidian sources remain read-only;

- [ ] **Step 5: Run automated acceptance**

Run:

```bash
swift package clean
swift test
bash Tests/Packaging/resource-probe-validation.sh
bash Tests/Packaging/build-app-safety.sh
bash Tests/Packaging/build-app-atomicity.sh
bash Scripts/build-app.sh
codesign --verify --deep --strict dist/Russian\\ Corner.app
```

Expected:

- all Swift and packaging tests pass;
- build script creates `dist/Russian Corner.app`;
- `codesign` exits 0;
- no original source file is touched.

- [ ] **Step 6: Verify source-vault immutability**

Use the existing pre-import manifest/hash file from the MVP acceptance. Re-run
the same hashing command against the original dialogue vault and compare:

```bash
shasum -a 256 -c <existing-original-source-manifest>
```

Expected: every entry reports `OK`. If the manifest path has changed, locate it
with:

```bash
find . -type f \\( -iname '*hash*' -o -iname '*manifest*' \\) -maxdepth 4
```

Do not regenerate the baseline after implementation.

- [ ] **Step 7: Perform the macOS smoke test**

Launch the built app and verify:

- menu bar icon appears;
- compact card is 360×240;
- reveal shows answer plus one collocation;
- details expand to 430×386;
- Again/Hard/Easy persist after restart;
- hidden card returns via menu and Ctrl+Option+R;
- collapse returns via Ctrl+Option+C;
- trial-store failure simulation does not block grading;
- denied microphone does not block diagnostics;
- Markdown report opens in a normal text/Markdown viewer and is understandable
  without reading JSON;
- no audio files are created.

- [ ] **Step 8: Commit final integration**

```bash
git add Sources Tests README.md Documentation/USAGE.md
git commit -m "feat: complete mode a trial optimization"
```

## Final implementation review

- [ ] Compare every item in
  `docs/superpowers/specs/2026-07-26-russian-corner-mode-a-optimization-design.md`
  against a code path or test above.
- [ ] Run `rg -n "TODO|TBD|FIXME|placeholder" Sources Tests README.md Documentation`
  and resolve all new placeholders introduced by this work.
- [ ] Run `rg -n "JSON 报告|录音回放" Sources README.md Documentation`
  and confirm any match is only an explicit exclusion, never an active feature.
- [ ] Confirm the implementation did not modify scheduler intervals, 6/10/12
  adaptive new-word limits, daily 5–10 sentence-card behavior, or the two
  configurable reminders.
- [ ] Confirm every user-facing error is Chinese and trial failures remain
  non-blocking.
- [ ] Confirm all created/modified Swift types use one consistent name and no
  obsolete recording protocol remains.
- [ ] Record final commit, test count, build result, codesign result, app path,
  trial store path, and source-hash verification in the implementation handoff.
