import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
final class PracticeViewModelTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  func testStartsHiddenAndRevealShowsAnswer() throws {
    let fixture = try makeFixture()

    XCTAssertFalse(fixture.model.isRevealed)
    XCTAssertNil(fixture.model.answer)

    fixture.model.reveal()

    XCTAssertTrue(fixture.model.isRevealed)
    XCTAssertEqual(fixture.model.answer, "Я сегодня работаю дома.")
  }

  func testRecallTimerUsesInjectedClockAndStopsAtZero() throws {
    var now = start
    let fixture = try makeFixture(now: { now })

    XCTAssertEqual(fixture.model.remainingRecallSeconds, 3)

    now = start.addingTimeInterval(1.2)
    fixture.model.refreshRecallTimer()
    XCTAssertEqual(fixture.model.remainingRecallSeconds, 2)

    now = start.addingTimeInterval(5)
    fixture.model.refreshRecallTimer()
    XCTAssertEqual(fixture.model.remainingRecallSeconds, 0)
  }

  func testGradePersistsEventAndScheduledState() throws {
    var now = start
    let fixture = try makeFixture(now: { now })
    now = start.addingTimeInterval(2.25)

    try fixture.model.grade(.easy)

    let events = try fixture.repository.reviewEvents()
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].itemId, "sentence-home")
    XCTAssertEqual(events[0].grade, .easy)
    XCTAssertEqual(events[0].responseTimeMs, 2_250)
    XCTAssertEqual(events[0].practiceMode, .quiet)
    XCTAssertEqual(
      try fixture.repository.progress(
        itemType: .sentence,
        itemId: "sentence-home"
      )?.masteryLevel,
      1
    )
  }

  func testPromptSwitchesFromChineseToRussianCueAtMasteryThree() throws {
    let fixture = try makeFixture(
      initialState: ReviewState(masteryLevel: 3, dueAt: start)
    )

    XCTAssertEqual(fixture.model.prompt, "Что вы скажете о работе сегодня?")
    XCTAssertNotEqual(fixture.model.prompt, fixture.model.answer)
  }

  func testModeCanSwitchBetweenQuietAndSpeaking() throws {
    let fixture = try makeFixture()

    fixture.model.mode = .speaking
    XCTAssertEqual(fixture.model.mode, .speaking)

    fixture.model.mode = .quiet
    XCTAssertEqual(fixture.model.mode, .quiet)
  }

  func testTargetCountIsClampedToFiveThroughTen() throws {
    XCTAssertEqual(
      try makeFixture(targetCount: 2, sentenceCount: 12)
        .model.targetCount,
      5
    )
    XCTAssertEqual(
      try makeFixture(targetCount: 20, sentenceCount: 12)
        .model.targetCount,
      10
    )
  }

  func testNextAdvancesThroughRequestedDailyCards() throws {
    let fixture = try makeFixture(targetCount: 7, sentenceCount: 12)

    XCTAssertEqual(fixture.model.totalCount, 7)
    XCTAssertEqual(fixture.model.currentIndex, 0)

    fixture.model.next()

    XCTAssertEqual(fixture.model.currentIndex, 1)
    XCTAssertFalse(fixture.model.isRevealed)
  }

  private func makeFixture(
    targetCount: Int = 7,
    sentenceCount: Int = 1,
    initialState: ReviewState? = nil,
    now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) }
  ) throws -> (
    model: PracticeViewModel,
    repository: ProgressRepository
  ) {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    if let initialState {
      try repository.saveProgress(
        itemType: .sentence,
        itemId: "sentence-home",
        state: initialState
      )
    }
    let sentences = (0..<sentenceCount).map { index in
      SentenceCard(
        id: index == 0 ? "sentence-home" : "sentence-\(index)",
        promptZh: "说：我今天在家工作。",
        cueRu: "Что вы скажете о работе сегодня?",
        practiceRu: "Я сегодня работаю дома.",
        speechText: "Я сегодня работаю дома.",
        theme: "日常",
        lexemeIDs: ["lexeme-work"],
        sourcePath: "fixture.md",
        sourceText: "fixture",
        reviewStatus: .reviewed
      )
    }
    let catalog = ContentCatalog(
      lexemes: [],
      sentences: sentences
    )
    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: targetCount,
      mode: .quiet,
      now: now
    )
    return (model, repository)
  }
}

@MainActor
final class AppModelTests: XCTestCase {
  func testCornerAndDisplayPreferencesPersist() {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var model = AppModel(defaults: defaults)
    model.corner = .bottomLeft
    model.opacity = 0.72
    model.fontScale = 1.2
    model.dailyCardCount = 10
    model.mode = .speaking

    model = AppModel(defaults: defaults)

    XCTAssertEqual(model.corner, .bottomLeft)
    XCTAssertEqual(model.opacity, 0.72, accuracy: 0.001)
    XCTAssertEqual(model.fontScale, 1.2, accuracy: 0.001)
    XCTAssertEqual(model.dailyCardCount, 10)
    XCTAssertEqual(model.mode, .speaking)
  }

  func testDailyCardCountAndVisualValuesAreClamped() {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let model = AppModel(defaults: defaults)

    model.dailyCardCount = 99
    model.opacity = 0.1
    model.fontScale = 9

    XCTAssertEqual(model.dailyCardCount, 10)
    XCTAssertEqual(model.opacity, 0.55, accuracy: 0.001)
    XCTAssertEqual(model.fontScale, 1.35, accuracy: 0.001)
  }
}
