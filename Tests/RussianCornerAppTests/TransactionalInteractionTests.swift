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
private final class FakeRecordingManager: RecordingManaging {
  var isRecording = false
  var temporaryRecordingURL: URL?
  private(set) var stopCallCount = 0
  private(set) var discardCallCount = 0
  private(set) var savedURLs: [URL] = []

  func permissionStatus() -> MicrophonePermissionStatus { .granted }
  func requestPermission() async -> MicrophonePermissionStatus { .granted }

  func start() async -> RecordingStartResult {
    isRecording = true
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("fixture-recording.m4a")
    temporaryRecordingURL = url
    return .started(url)
  }

  func stop() {
    stopCallCount += 1
    isRecording = false
  }

  func discard() throws {
    discardCallCount += 1
    temporaryRecordingURL = nil
    isRecording = false
  }

  func save(to destinationURL: URL) throws -> RecordingSaveOutcome {
    savedURLs.append(destinationURL)
    temporaryRecordingURL = nil
    return .saved(
      destinationURL: destinationURL,
      temporaryCleanupPending: false
    )
  }
}

@MainActor
private final class FakeRecordingPlayer: RecordingPlaying {
  private(set) var playedURLs: [URL] = []
  private(set) var stopCallCount = 0
  var isPlaying = false

  func play(url: URL) -> RecordingPlaybackResult {
    playedURLs.append(url)
    isPlaying = true
    return .playing(url)
  }

  func stop() {
    stopCallCount += 1
    isPlaying = false
  }
}

@MainActor
final class TransactionalPracticeTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  func testGradeFailureDoesNotAdvanceAndRetryCommitsOnlyOnce() throws {
    let store = TransactionalPracticeStore()
    store.shouldFailCommit = true
    let recording = FakeRecordingManager()
    recording.isRecording = true
    recording.temporaryRecordingURL = URL(
      fileURLWithPath: "/tmp/russian-corner-grade-retry.m4a"
    )
    let fixture = try makeModel(
      store: store,
      recording: recording
    )
    fixture.model.reveal()

    XCTAssertThrowsError(try fixture.model.grade(.easy))

    XCTAssertEqual(fixture.model.currentIndex, 0)
    XCTAssertTrue(fixture.model.isRevealed)
    XCTAssertEqual(fixture.model.completedToday, 0)
    XCTAssertEqual(store.commitCallCount, 1)
    XCTAssertTrue(store.events.isEmpty)
    XCTAssertTrue(recording.isRecording)
    XCTAssertEqual(
      recording.temporaryRecordingURL,
      URL(fileURLWithPath: "/tmp/russian-corner-grade-retry.m4a")
    )
    XCTAssertEqual(recording.stopCallCount, 0)
    XCTAssertEqual(recording.discardCallCount, 0)

    try fixture.model.grade(.easy)

    XCTAssertEqual(fixture.model.currentIndex, 1)
    XCTAssertFalse(fixture.model.isRevealed)
    XCTAssertEqual(store.commitCallCount, 2)
    XCTAssertEqual(store.events.count, 1)
    XCTAssertFalse(recording.isRecording)
    XCTAssertNil(recording.temporaryRecordingURL)
    XCTAssertEqual(recording.stopCallCount, 1)
    XCTAssertEqual(recording.discardCallCount, 1)
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

  func testNextStopsAndDiscardsRecordingBeforeAdvancing() throws {
    let store = TransactionalPracticeStore()
    let recording = FakeRecordingManager()
    recording.isRecording = true
    recording.temporaryRecordingURL = URL(
      fileURLWithPath: "/tmp/russian-corner-fixture.m4a"
    )
    let fixture = try makeModel(
      store: store,
      recording: recording
    )

    fixture.model.next()

    XCTAssertEqual(recording.stopCallCount, 1)
    XCTAssertEqual(recording.discardCallCount, 1)
    XCTAssertNil(recording.temporaryRecordingURL)
    XCTAssertEqual(fixture.model.currentIndex, 1)
  }

  func testStoppedRecordingCanPlayAndSaveToRecordingsDirectory() throws {
    let store = TransactionalPracticeStore()
    let recording = FakeRecordingManager()
    let player = FakeRecordingPlayer()
    recording.temporaryRecordingURL = URL(
      fileURLWithPath: "/tmp/russian-corner-fixture.m4a"
    )
    let destinationDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: destinationDirectory) }
    let fixture = try makeModel(
      store: store,
      recording: recording,
      player: player,
      recordingsDirectory: destinationDirectory
    )

    fixture.model.playRecording()
    let savedURL = try fixture.model.saveRecording()

    XCTAssertEqual(
      player.playedURLs,
      [URL(fileURLWithPath: "/tmp/russian-corner-fixture.m4a")]
    )
    XCTAssertEqual(recording.savedURLs, [savedURL])
    XCTAssertEqual(savedURL.deletingLastPathComponent(), destinationDirectory)
    XCTAssertFalse(fixture.model.hasRecording)
  }

  private func makeModel(
    store: TransactionalPracticeStore,
    recording: FakeRecordingManager = FakeRecordingManager(),
    player: FakeRecordingPlayer = FakeRecordingPlayer(),
    recordingsDirectory: URL? = nil
  ) throws -> (
    model: PracticeViewModel,
    recording: FakeRecordingManager,
    player: FakeRecordingPlayer
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
        now: { self.now },
        recordingService: recording,
        playbackService: player,
        recordingsDirectory: recordingsDirectory
      ),
      recording,
      player
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
  private(set) var scheduledSettings: [RussianCornerSettings] = []

  init(results: [ReminderScheduleResult]) {
    self.results = results
  }

  func schedule(
    settings: RussianCornerSettings
  ) async -> ReminderScheduleResult {
    scheduledSettings.append(settings)
    return results.removeFirst()
  }

  func calls() -> [RussianCornerSettings] {
    scheduledSettings
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
      .toggleRecording,
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
  }
}
