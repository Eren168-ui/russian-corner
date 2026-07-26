import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

private enum FixtureFailure: Error {
  case commit
  case database
}

@MainActor
private final class TransactionalPracticeStore: PracticeProgressStoring {
  var shouldFailCommit = false
  private(set) var commitCallCount = 0
  private(set) var events: [ReviewEvent] = []
  private var states: [String: ReviewState] = [:]
  private var completed = 0

  func reviewEvents() throws -> [ReviewEvent] {
    events
  }

  func progress(
    itemType: PracticeItemKind,
    itemId: String
  ) throws -> ReviewState? {
    states["\(itemType.rawValue):\(itemId)"]
  }

  func dailyCompletedCount(
    on date: Date,
    calendar: Calendar
  ) throws -> Int? {
    completed
  }

  func commitReview(
    event: ReviewEvent,
    state: ReviewState,
    dailyCompletedCount: Int,
    calendar: Calendar
  ) throws {
    commitCallCount += 1
    if shouldFailCommit {
      shouldFailCommit = false
      throw FixtureFailure.commit
    }
    events.append(event)
    states["\(event.itemType.rawValue):\(event.itemId)"] = state
    completed = dailyCompletedCount
  }
}

@MainActor
final class TransactionalPracticeTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  func testGradeFailureDoesNotAdvanceAndRetryCommitsOnlyOnce() throws {
    let store = TransactionalPracticeStore()
    store.shouldFailCommit = true
    let fixture = try makeModel(store: store)
    fixture.model.reveal()

    XCTAssertThrowsError(try fixture.model.grade(.easy))

    XCTAssertEqual(fixture.model.currentIndex, 0)
    XCTAssertTrue(fixture.model.isRevealed)
    XCTAssertEqual(fixture.model.completedToday, 0)
    XCTAssertEqual(store.commitCallCount, 1)
    XCTAssertTrue(store.events.isEmpty)

    try fixture.model.grade(.easy)

    XCTAssertEqual(fixture.model.currentIndex, 1)
    XCTAssertFalse(fixture.model.isRevealed)
    XCTAssertEqual(store.commitCallCount, 2)
    XCTAssertEqual(store.events.count, 1)
  }

  func testGradeBeforeRevealIsRejectedWithoutCommit() throws {
    let store = TransactionalPracticeStore()
    let fixture = try makeModel(store: store)

    XCTAssertThrowsError(try fixture.model.grade(.easy)) {
      XCTAssertEqual(
        $0 as? PracticeViewModelError,
        .answerNotRevealed
      )
    }
    XCTAssertEqual(store.commitCallCount, 0)
    XCTAssertEqual(fixture.model.currentIndex, 0)
  }

  private func makeModel(
    store: TransactionalPracticeStore
  ) throws -> (
    model: PracticeViewModel,
    store: TransactionalPracticeStore
  ) {
    let sentences = (0..<2).map { index in
      SentenceCard(
        id: "sentence-\(index)",
        promptZh: "提示 \(index)",
        cueRu: "Как ответить на вопрос \(index)?",
        practiceRu: "Ответ номер \(index).",
        speechText: "Ответ номер \(index).",
        theme: "fixture",
        lexemeIDs: ["fixture"],
        sourcePath: "fixture",
        sourceText: "fixture",
        reviewStatus: .reviewed
      )
    }
    return (
      try PracticeViewModel(
        catalog: ContentCatalog(lexemes: [], sentences: sentences),
        repository: store,
        targetCount: 5,
        now: { self.now }
      ),
      store
    )
  }
}

@MainActor
private final class FakeReminderSettingsStore:
  ReminderSettingsPersisting
{
  var shouldFailSave = false
  private(set) var saveCallCount = 0
  private(set) var savedSettings: RussianCornerSettings?

  func save(settings: RussianCornerSettings) throws {
    saveCallCount += 1
    if shouldFailSave {
      throw FixtureFailure.database
    }
    savedSettings = settings
  }
}

private actor FakeReminderScheduler: ReminderSettingsScheduling {
  var results: [ReminderScheduleResult]
  var reconciliationResults: [ReminderScheduleResult]
  private(set) var scheduledSettings: [RussianCornerSettings] = []
  private(set) var reconciledSettings: [RussianCornerSettings] = []

  init(
    results: [ReminderScheduleResult],
    reconciliationResults: [ReminderScheduleResult] = []
  ) {
    self.results = results
    self.reconciliationResults = reconciliationResults
  }

  func schedule(
    settings: RussianCornerSettings
  ) async -> ReminderScheduleResult {
    scheduledSettings.append(settings)
    return results.removeFirst()
  }

  func reconcile(
    settings: RussianCornerSettings,
    requestAuthorizationIfNeeded: Bool
  ) async -> ReminderScheduleResult {
    reconciledSettings.append(settings)
    scheduledSettings.append(settings)
    if !reconciliationResults.isEmpty {
      return reconciliationResults.removeFirst()
    }
    return results.removeFirst()
  }

  func calls() -> [RussianCornerSettings] {
    scheduledSettings
  }

  func reconciliationCalls() -> [RussianCornerSettings] {
    reconciledSettings
  }
}

@MainActor
final class ReminderSettingsCoordinatorTests: XCTestCase {
  private let old = RussianCornerSettings(
    morningReminder: ReminderTime(hour: 11, minute: 30),
    eveningReminder: ReminderTime(hour: 17, minute: 30)
  )
  private let proposed = RussianCornerSettings(
    morningReminder: ReminderTime(hour: 9, minute: 0),
    eveningReminder: ReminderTime(hour: 20, minute: 15)
  )

  func testScheduleFailureDoesNotWriteDatabaseOrMutateModel() async {
    let fixture = makeReminderFixture(
      results: [.failed("notification failed")]
    )

    let result = await fixture.coordinator.apply(
      proposed: proposed,
      to: fixture.model
    )

    XCTAssertEqual(
      result,
      .scheduleFailed("notification failed")
    )
    XCTAssertEqual(fixture.store.saveCallCount, 0)
    XCTAssertEqual(settings(from: fixture.model), old)
    let scheduleCalls = await fixture.scheduler.calls()
    XCTAssertEqual(scheduleCalls, [proposed])
  }

  func testDatabaseFailureRollsSystemBackAndRestoresModel() async {
    let fixture = makeReminderFixture(
      results: [
        .scheduled(ReminderService.pendingRequestIDs),
        .scheduled(ReminderService.pendingRequestIDs),
      ],
      failDatabase: true
    )

    let result = await fixture.coordinator.apply(
      proposed: proposed,
      to: fixture.model
    )

    guard case .databaseFailed = result else {
      return XCTFail("expected database failure")
    }
    XCTAssertEqual(fixture.store.saveCallCount, 1)
    XCTAssertEqual(settings(from: fixture.model), old)
    let scheduleCalls = await fixture.scheduler.calls()
    XCTAssertEqual(scheduleCalls, [proposed, old])
  }

  func testSuccessfulScheduleThenDatabaseCommitUpdatesModel() async {
    let fixture = makeReminderFixture(
      results: [.scheduled(ReminderService.pendingRequestIDs)]
    )

    let result = await fixture.coordinator.apply(
      proposed: proposed,
      to: fixture.model
    )

    XCTAssertEqual(result, .applied)
    XCTAssertEqual(fixture.store.savedSettings, proposed)
    XCTAssertEqual(settings(from: fixture.model), proposed)
    let scheduleCalls = await fixture.scheduler.calls()
    XCTAssertEqual(scheduleCalls, [proposed])
  }

  func testMissingSystemSchedulerStillPersistsAndUpdatesModel() async {
    let fixture = makeReminderFixture(results: [])
    let coordinator = ReminderSettingsCoordinator(
      store: fixture.store,
      scheduler: nil
    )

    let result = await coordinator.apply(
      proposed: proposed,
      to: fixture.model
    )

    XCTAssertEqual(result, .appliedLocally)
    XCTAssertEqual(fixture.store.savedSettings, proposed)
    XCTAssertEqual(settings(from: fixture.model), proposed)
    let scheduleCalls = await fixture.scheduler.calls()
    XCTAssertTrue(scheduleCalls.isEmpty)
  }

  private func makeReminderFixture(
    results: [ReminderScheduleResult],
    failDatabase: Bool = false
  ) -> (
    coordinator: ReminderSettingsCoordinator,
    model: AppModel,
    store: FakeReminderSettingsStore,
    scheduler: FakeReminderScheduler
  ) {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let model = AppModel(defaults: defaults)
    model.morningReminder = old.morningReminder
    model.eveningReminder = old.eveningReminder
    let store = FakeReminderSettingsStore()
    store.shouldFailSave = failDatabase
    let scheduler = FakeReminderScheduler(results: results)
    return (
      ReminderSettingsCoordinator(
        store: store,
        scheduler: scheduler
      ),
      model,
      store,
      scheduler
    )
  }

  private func settings(from model: AppModel) -> RussianCornerSettings {
    RussianCornerSettings(
      morningReminder: model.morningReminder,
      eveningReminder: model.eveningReminder
    )
  }
}

@MainActor
final class DailyCardCountCoordinatorTests: XCTestCase {
  func testPersistentReloadFailureRestoresModelWithOneAttempt() {
    let suiteName = "DailyCardCountCoordinatorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let model = AppModel(defaults: defaults)
    model.dailyCardCount = 7
    var reloadCallCount = 0
    let coordinator = DailyCardCountCoordinator {
      reloadCallCount += 1
      throw FixtureFailure.database
    }

    let result = coordinator.apply(proposed: 9, to: model)

    XCTAssertFalse(result)
    XCTAssertEqual(model.dailyCardCount, 7)
    XCTAssertEqual(reloadCallCount, 1)
  }
}

final class GlobalHotKeyMappingTests: XCTestCase {
  func testDefaultMappingCoversAllAccessiblePracticeActionsUniquely() {
    let required: Set<GlobalHotKeyAction> = [
      .toggleCard,
      .nextCard,
      .speak,
      .reveal,
      .gradeAgain,
      .gradeHard,
      .gradeEasy,
      .toggleCollapsed,
    ]

    XCTAssertEqual(
      Set(GlobalHotKeyAction.defaultShortcuts.keys),
      required
    )
    XCTAssertEqual(
      Set(GlobalHotKeyAction.defaultShortcuts.values).count,
      required.count
    )
    XCTAssertEqual(required.count, 8)
  }
}

final class PracticePanelPresentationTests: XCTestCase {
  func testCollapsedPanelIs58By58() {
    XCTAssertEqual(
      PracticePanelPresentation.collapsed.size,
      CGSize(width: 58, height: 58)
    )
  }

  func testCompactPanelIs360By240() {
    XCTAssertEqual(
      PracticePanelPresentation.compact.size,
      CGSize(width: 360, height: 240)
    )
  }

  func testDetailsPanelIs430By386() {
    XCTAssertEqual(
      PracticePanelPresentation.details.size,
      CGSize(width: 430, height: 386)
    )
  }

  func testCollapseTakesPriorityOverDetailsExpansion() {
    XCTAssertEqual(
      PracticePanelPresentation.resolve(
        isCollapsed: true,
        isDetailExpanded: true
      ),
      .collapsed
    )
    XCTAssertEqual(
      PracticePanelPresentation.resolve(
        isCollapsed: false,
        isDetailExpanded: true
      ),
      .details
    )
  }
}
