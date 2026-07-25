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
    fixture.model.reveal()
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
    XCTAssertEqual(
      try fixture.repository.dailyCompletedCount(on: now),
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

  func testLegacyCueEqualToAnswerKeepsChinesePromptAtMasteryThree() throws {
    let fixture = try makeFixture(
      initialState: ReviewState(masteryLevel: 3, dueAt: start),
      cueRu: "Я сегодня работаю дома."
    )

    XCTAssertEqual(fixture.model.prompt, "说：我今天在家工作。")
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

  func testDefaultDayQueuesTenNewLexemesAndConfiguredSentenceCards() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 20, sentenceCount: 12)

    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: 7,
      now: { self.start },
      calendar: utcCalendar
    )

    XCTAssertEqual(model.newWordLimit, 10)
    XCTAssertEqual(model.queue.filter { $0.kind == .lexeme }.count, 10)
    XCTAssertEqual(model.queue.filter { $0.kind == .sentence }.count, 7)
  }

  func testLowPreviousDayRecallReducesNewLexemesToSix() throws {
    let repository = try makeRepository()
    addEvents(
      [.again, .again, .again, .easy],
      kind: .lexeme,
      dayOffset: -1,
      to: repository
    )

    let model = try makeModel(
      repository: repository,
      catalog: makeCatalog(lexemeCount: 20, sentenceCount: 10)
    )

    XCTAssertEqual(model.newWordLimit, 6)
    XCTAssertEqual(
      model.queue.filter { $0.kind == .lexeme }.count,
      6
    )
  }

  func testThreeConsecutiveStrongDaysRaisesNewLexemesToTwelve() throws {
    let repository = try makeRepository()
    for dayOffset in -3 ... -1 {
      addEvents(
        Array(repeating: .easy, count: 10),
        kind: .lexeme,
        dayOffset: dayOffset,
        to: repository
      )
    }

    let model = try makeModel(
      repository: repository,
      catalog: makeCatalog(lexemeCount: 24, sentenceCount: 10)
    )

    XCTAssertEqual(model.newWordLimit, 12)
    XCTAssertEqual(
      model.queue.filter { $0.kind == .lexeme }.count,
      12
    )
  }

  func testSignificantLexemeBacklogReducesNewLexemesToSix() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 40, sentenceCount: 10)
    for lexeme in catalog.lexemes.prefix(20) {
      try repository.saveProgress(
        itemType: .lexeme,
        itemId: lexeme.id,
        state: ReviewState(
          masteryLevel: 1,
          dueAt: start.addingTimeInterval(-86_400)
        )
      )
    }

    let model = try makeModel(repository: repository, catalog: catalog)
    let freshIDs = Set(catalog.lexemes.dropFirst(20).map(\.id))

    XCTAssertEqual(model.newWordLimit, 6)
    XCTAssertEqual(
      model.queue.filter {
        $0.kind == .lexeme && freshIDs.contains($0.id)
      }.count,
      6
    )
  }

  func testVocabularyDiagnosticCapsOtherwiseStandardNewWordsAtSix() throws {
    let model = try PracticeViewModel(
      catalog: makeCatalog(lexemeCount: 20, sentenceCount: 10),
      repository: try makeRepository(),
      now: { self.start },
      calendar: utcCalendar,
      diagnosticFindings: [.vocabularyBreadth]
    )

    XCTAssertEqual(model.newWordLimit, 6)
    XCTAssertEqual(model.queue.filter { $0.kind == .lexeme }.count, 6)
  }

  func testSundayAddsNoNewLexemesWhenLearnedContentExists() throws {
    let sunday = Date(timeIntervalSince1970: 1_700_352_000)
    XCTAssertEqual(utcCalendar.component(.weekday, from: sunday), 1)
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 12, sentenceCount: 5)
    try repository.saveProgress(
      itemType: .lexeme,
      itemId: catalog.lexemes[0].id,
      state: ReviewState(
        masteryLevel: 2,
        dueAt: sunday.addingTimeInterval(86_400)
      )
    )

    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      now: { sunday },
      calendar: utcCalendar
    )

    XCTAssertTrue(model.isWeeklyReviewDay)
    XCTAssertEqual(model.newWordLimit, 0)
    XCTAssertEqual(model.remainingNewWordCount, 0)
    XCTAssertEqual(
      Set(model.queue.filter { $0.kind == .lexeme }.map(\.id)),
      [catalog.lexemes[0].id]
    )
    XCTAssertTrue(model.queue.allSatisfy { $0.kind == .lexeme })
  }

  func testFirstLaunchOnSundayStillOffersLexemes() throws {
    let sunday = Date(timeIntervalSince1970: 1_700_352_000)
    let model = try PracticeViewModel(
      catalog: makeCatalog(lexemeCount: 12, sentenceCount: 5),
      repository: try makeRepository(),
      now: { sunday },
      calendar: utcCalendar
    )

    XCTAssertTrue(model.isWeeklyReviewDay)
    XCTAssertEqual(model.newWordLimit, 6)
    XCTAssertEqual(model.queue.filter { $0.kind == .lexeme }.count, 6)
  }

  func testSundayReviewsMultipleLearnedLexemesWithoutAddingFreshItems()
    throws
  {
    let sunday = Date(timeIntervalSince1970: 1_700_352_000)
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 12, sentenceCount: 5)
    for lexeme in catalog.lexemes.prefix(5) {
      try repository.saveProgress(
        itemType: .lexeme,
        itemId: lexeme.id,
        state: ReviewState(
          masteryLevel: 2,
          dueAt: sunday.addingTimeInterval(86_400)
        )
      )
    }

    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      now: { sunday },
      calendar: utcCalendar
    )

    XCTAssertEqual(model.newWordLimit, 0)
    XCTAssertEqual(
      Set(model.queue.filter { $0.kind == .lexeme }.map(\.id)),
      Set(catalog.lexemes.prefix(5).map(\.id))
    )
    XCTAssertTrue(model.queue.allSatisfy { $0.kind == .lexeme })
  }

  func testLexemeCardExposesStressMeaningGrammarCollocationsAndContext() throws {
    let model = try makeModel(
      repository: try makeRepository(),
      catalog: makeCatalog(lexemeCount: 1, sentenceCount: 1)
    )
    guard case .lexeme(let lexeme) = model.currentContent else {
      return XCTFail("expected lexeme card first")
    }

    XCTAssertEqual(lexeme.stressedForm, "сло́во 0")
    XCTAssertEqual(model.prompt, "词义 0")
    model.reveal()
    XCTAssertEqual(model.answer, "сло́во 0")
    XCTAssertEqual(model.currentLexeme?.partOfSpeech, "noun")
    XCTAssertEqual(model.currentLexeme?.grammaticalGender, "neuter")
    XCTAssertEqual(model.lexemeGrammarLabels, ["名词", "中性"])
    XCTAssertEqual(model.currentLexeme?.collocations, ["важное слово 0"])
    XCTAssertEqual(model.currentLexeme?.example, "Это слово 0.")
    XCTAssertEqual(model.currentContextSentence?.theme, "场景 0")
  }

  func testMorningLexemeStartsWithRussianRecognitionAndCanToggleDirection()
    throws
  {
    let morning = try XCTUnwrap(
      utcCalendar.date(
        from: DateComponents(
          year: 2026,
          month: 7,
          day: 27,
          hour: 8
        )
      )
    )
    let model = try PracticeViewModel(
      catalog: makeCatalog(lexemeCount: 1, sentenceCount: 1),
      repository: try makeRepository(),
      now: { morning },
      calendar: utcCalendar
    )

    XCTAssertEqual(model.lexemeDirection, .recognition)
    XCTAssertEqual(model.prompt, "сло́во 0")
    model.reveal()
    XCTAssertEqual(model.answer, "词义 0")

    model.toggleLexemeDirection()

    XCTAssertEqual(model.lexemeDirection, .production)
    XCTAssertEqual(model.prompt, "词义 0")
    XCTAssertNil(model.answer)
  }

  func testTemporalBoundaryRequiresReloadAtNoonAndAfterMidnight() throws {
    let beforeNoon = try XCTUnwrap(
      utcCalendar.date(
        from: DateComponents(
          year: 2026,
          month: 7,
          day: 27,
          hour: 11,
          minute: 59
        )
      )
    )
    let model = try PracticeViewModel(
      catalog: makeCatalog(lexemeCount: 1, sentenceCount: 1),
      repository: try makeRepository(),
      now: { beforeNoon },
      calendar: utcCalendar
    )

    XCTAssertFalse(
      model.needsTemporalReload(
        at: beforeNoon.addingTimeInterval(30)
      )
    )
    XCTAssertTrue(
      model.needsTemporalReload(
        at: beforeNoon.addingTimeInterval(60)
      )
    )
    XCTAssertTrue(
      model.needsTemporalReload(
        at: beforeNoon.addingTimeInterval(13 * 60 * 60)
      )
    )
  }

  func testSentenceCardOffersTwoTurnThemeMicroDialogue() throws {
    let sentences = (0..<2).map { index in
      SentenceCard(
        id: "dialogue-\(index)",
        promptZh: "对话提示 \(index)",
        cueRu: "Что вы скажете в ситуации \(index)?",
        practiceRu: "Ответ \(index).",
        speechText: "Ответ \(index).",
        theme: "共同场景",
        lexemeIDs: [],
        sourcePath: "fixture.md",
        sourceText: "fixture",
        reviewStatus: .reviewed
      )
    }
    let model = try PracticeViewModel(
      catalog: ContentCatalog(lexemes: [], sentences: sentences),
      repository: try makeRepository(),
      targetCount: 5,
      now: { self.start },
      calendar: utcCalendar
    )

    XCTAssertEqual(model.currentItem?.kind, .sentence)
    XCTAssertEqual(model.microDialogueTurns.count, 2)
    XCTAssertEqual(
      model.microDialogueTurns.map(\.cue),
      [
        "Что вы скажете в ситуации 0?",
        "Что вы скажете в ситуации 1?",
      ]
    )
  }

  func testAgainAppendsOneRetryAndSuccessfulRetryCompletes() throws {
    let model = try PracticeViewModel(
      catalog: makeCatalog(lexemeCount: 1, sentenceCount: 0),
      repository: try makeRepository(),
      targetCount: 5,
      now: { self.start },
      calendar: utcCalendar
    )

    model.reveal()
    try model.grade(.again)

    XCTAssertFalse(model.isComplete)
    XCTAssertEqual(model.totalCount, 2)
    XCTAssertEqual(model.currentIndex, 1)
    XCTAssertEqual(model.completedToday, 0)
    XCTAssertEqual(model.currentItem?.kind, .lexeme)

    model.reveal()
    try model.grade(.easy)

    XCTAssertTrue(model.isComplete)
    XCTAssertNil(model.currentItem)
    XCTAssertEqual(model.completedToday, 1)
  }

  func testReloadExcludesSuccessKeepsAgainAndDeductsDailyQuotas() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 20, sentenceCount: 12)
    let first = try makeModel(repository: repository, catalog: catalog)
    let successful = first.currentItem!
    first.reveal()
    try first.grade(.easy)
    let retry = first.currentItem!
    first.reveal()
    try first.grade(.again)

    let restored = try makeModel(repository: repository, catalog: catalog)

    XCTAssertFalse(restored.queue.contains { $0.identity == successful.identity })
    XCTAssertTrue(restored.queue.contains { $0.identity == retry.identity })
    XCTAssertEqual(restored.completedToday, 1)
    XCTAssertEqual(restored.remainingNewWordCount, 8)
    XCTAssertEqual(restored.remainingSentenceCardCount, 7)
  }

  func testReloadDeductsAttemptedSentenceQuotaAndKeepsSentenceRetry() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 10, sentenceCount: 10)
    let first = try makeModel(repository: repository, catalog: catalog)
    while first.currentItem?.kind == .lexeme {
      first.next()
    }
    let retriedSentence = first.currentItem!
    first.reveal()
    try first.grade(.again)

    let restored = try makeModel(repository: repository, catalog: catalog)

    XCTAssertEqual(restored.remainingSentenceCardCount, 6)
    XCTAssertTrue(
      restored.queue.contains {
        $0.identity == retriedSentence.identity && $0.isRetry
      }
    )
    XCTAssertEqual(
      restored.queue.filter { $0.kind == .sentence }.count,
      7
    )
  }

  func testReloadDoesNotMistakeDueReviewForNewLexemeQuota() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 20, sentenceCount: 5)
    let dueLexeme = catalog.lexemes[0]
    try repository.save(
      reviewEvent: ReviewEvent(
        itemType: .lexeme,
        itemId: dueLexeme.id,
        grade: .easy,
        responseTimeMs: 1_000,
        practiceMode: .quiet,
        createdAt: start.addingTimeInterval(-86_400)
      )
    )
    try repository.saveProgress(
      itemType: .lexeme,
      itemId: dueLexeme.id,
      state: ReviewState(
        masteryLevel: 1,
        dueAt: start.addingTimeInterval(-1)
      )
    )
    let first = try makeModel(repository: repository, catalog: catalog)
    XCTAssertEqual(first.currentItem?.id, dueLexeme.id)
    first.reveal()
    try first.grade(.easy)

    let restored = try makeModel(repository: repository, catalog: catalog)

    XCTAssertEqual(restored.remainingNewWordCount, 10)
    XCTAssertEqual(
      restored.queue.filter {
        $0.kind == .lexeme && $0.id != dueLexeme.id
      }.count,
      10
    )
  }

  func testQueueIsStableOnSameDayAndChangesAcrossDays() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 30, sentenceCount: 12)
    let first = try makeModel(repository: repository, catalog: catalog)
    let second = try makeModel(repository: repository, catalog: catalog)
    let nextDay = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: 7,
      now: { self.start.addingTimeInterval(86_400) },
      calendar: utcCalendar
    )

    XCTAssertEqual(first.queue.map(\.identity), second.queue.map(\.identity))
    XCTAssertNotEqual(first.queue.map(\.identity), nextDay.queue.map(\.identity))
  }

  func testGradesLexemeAndSentenceWithCorrectTypeAndIdentifier() throws {
    let repository = try makeRepository()
    let model = try PracticeViewModel(
      catalog: makeCatalog(lexemeCount: 1, sentenceCount: 1),
      repository: repository,
      now: { self.start },
      calendar: utcCalendar
    )

    while let item = model.currentItem {
      model.reveal()
      try model.grade(.easy)
      XCTAssertEqual(
        try repository.progress(itemType: item.kind, itemId: item.id)?
          .masteryLevel,
        1
      )
    }

    XCTAssertEqual(
      Set(try repository.reviewEvents().map(\.itemType)),
      [.lexeme, .sentence]
    )
  }

  private func makeFixture(
    targetCount: Int = 7,
    sentenceCount: Int = 1,
    initialState: ReviewState? = nil,
    cueRu: String = "Что вы скажете о работе сегодня?",
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
        cueRu: cueRu,
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

  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  private func makeRepository() throws -> ProgressRepository {
    ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
  }

  private func makeModel(
    repository: ProgressRepository,
    catalog: ContentCatalog
  ) throws -> PracticeViewModel {
    try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: 7,
      now: { self.start },
      calendar: utcCalendar
    )
  }

  private func makeCatalog(
    lexemeCount: Int,
    sentenceCount: Int
  ) -> ContentCatalog {
    let sentences = (0..<sentenceCount).map { index in
      SentenceCard(
        id: "sentence-\(index)",
        promptZh: "场景提示 \(index)",
        cueRu: "Что вы скажете в ситуации \(index)?",
        practiceRu: "Ответ \(index).",
        speechText: "Ответ \(index).",
        theme: "场景 \(index)",
        lexemeIDs: lexemeCount == 0
          ? [] : ["lexeme-new-\(index % lexemeCount)"],
        sourcePath: "fixture.md",
        sourceText: "fixture",
        reviewStatus: .reviewed
      )
    }
    let lexemes = (0..<lexemeCount).map { index in
      Lexeme(
        id: "lexeme-new-\(index)",
        lemma: "слово \(index)",
        stressedForm: "сло́во \(index)",
        speechText: "слово \(index)",
        partOfSpeech: "noun",
        glossZh: "词义 \(index)",
        collocations: ["важное слово \(index)"],
        example: "Это слово \(index).",
        sentenceIDs: sentenceCount == 0
          ? [] : ["sentence-\(index % sentenceCount)"],
        reviewStatus: .reviewed,
        grammaticalGender: "neuter"
      )
    }
    return ContentCatalog(lexemes: lexemes, sentences: sentences)
  }

  private func addEvents(
    _ grades: [ReviewGrade],
    kind: PracticeItemKind,
    dayOffset: Int,
    to repository: ProgressRepository
  ) {
    for (index, grade) in grades.enumerated() {
      let day = utcCalendar.date(
        byAdding: .day,
        value: dayOffset,
        to: start
      )!
      try! repository.save(
        reviewEvent: ReviewEvent(
          itemType: kind,
          itemId: "history-\(dayOffset)-\(index)",
          grade: grade,
          responseTimeMs: 1_000,
          practiceMode: .quiet,
          createdAt: day.addingTimeInterval(TimeInterval(index))
        )
      )
    }
  }
}

private actor RuntimeReminderScheduler: ReminderSettingsScheduling {
  private let result: ReminderScheduleResult
  private var reconciledSettings: [RussianCornerSettings] = []

  init(result: ReminderScheduleResult) {
    self.result = result
  }

  func schedule(
    settings: RussianCornerSettings
  ) async -> ReminderScheduleResult {
    result
  }

  func reconcile(
    settings: RussianCornerSettings,
    requestAuthorizationIfNeeded: Bool
  ) async -> ReminderScheduleResult {
    reconciledSettings.append(settings)
    return result
  }

  func callCount() -> Int {
    reconciledSettings.count
  }

  func settings() -> [RussianCornerSettings] {
    reconciledSettings
  }
}

@MainActor
final class AppModelTests: XCTestCase {
  func testRuntimeReloadsPracticeAfterTemporalBoundary() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: []),
      repository: repository,
      enableSystemReminders: false
    )
    let initialPractice = try XCTUnwrap(runtime.practice)

    runtime.refreshPracticeForTemporalBoundary(
      now: Date().addingTimeInterval(48 * 60 * 60)
    )

    let refreshedPractice = try XCTUnwrap(runtime.practice)
    XCTAssertFalse(initialPractice === refreshedPractice)
    XCTAssertNil(runtime.appModel.transientStatus)
  }

  func testSavedDiagnosticImmediatelyReloadsPracticeStrategy() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let lexeme = Lexeme(
      id: "lexeme-work",
      lemma: "работать",
      stressedForm: "рабо́тать",
      speechText: "работать",
      partOfSpeech: "verb",
      glossZh: "工作",
      collocations: ["работать дома"],
      example: "Я работаю дома.",
      sentenceIDs: ["sentence-work"],
      reviewStatus: .reviewed,
      aspect: "imperfective",
      aspectPairNote: "no common perfective pair",
      government: "без дополнения",
      surfaceForms: ["работаю"]
    )
    let sentence = SentenceCard(
      id: "sentence-work",
      promptZh: "我在家工作。",
      cueRu: "Где вы работаете?",
      practiceRu: "Я работаю дома.",
      speechText: "Я работаю дома.",
      theme: "work",
      lexemeIDs: [lexeme.id],
      sourcePath: "fixture",
      sourceText: "fixture",
      reviewStatus: .reviewed
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(
        lexemes: [lexeme],
        sentences: [sentence]
      ),
      repository: repository,
      enableSystemReminders: false
    )
    let diagnostic = try XCTUnwrap(runtime.diagnostics)

    XCTAssertEqual(runtime.practice?.mode, .quiet)
    diagnostic.start()
    diagnostic.submitRecognition(correct: true)
    diagnostic.submitProduction(correct: true)
    diagnostic.skipListening()
    diagnostic.submitCollocation(rate: 100)
    diagnostic.skipRecording(selfMonitoring: true)
    diagnostic.skipRecording(selfMonitoring: true)

    XCTAssertEqual(diagnostic.step, .summary)
    XCTAssertEqual(runtime.practice?.mode, .speaking)
    XCTAssertEqual(
      try repository.latestDiagnosticReport()?.findings.map(\.type),
      [.selfMonitoring]
    )
  }

  func testRuntimeReminderReconciliationIsExplicitlyAsyncAfterInit() async throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let settings = RussianCornerSettings(
      morningReminder: ReminderTime(hour: 8, minute: 20),
      eveningReminder: ReminderTime(hour: 19, minute: 10)
    )
    try repository.save(settings: settings)
    let scheduler = RuntimeReminderScheduler(
      result: .scheduled(ReminderService.pendingRequestIDs)
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: []),
      repository: repository,
      reminderScheduler: scheduler
    )

    let initialCallCount = await scheduler.callCount()
    XCTAssertEqual(initialCallCount, 0)

    await runtime.reconcileRemindersOnLaunch()

    let reconciledSettings = await scheduler.settings()
    XCTAssertEqual(reconciledSettings, [settings])
    XCTAssertNil(runtime.launchError)
  }

  func testUnavailableRemindersDoNotBecomeLaunchFailure() async throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let scheduler = RuntimeReminderScheduler(result: .unavailable)
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: []),
      repository: repository,
      reminderScheduler: scheduler
    )

    let result = await runtime.reconcileRemindersOnLaunch()

    XCTAssertEqual(result, .unavailable)
    XCTAssertNil(runtime.launchError)
    XCTAssertEqual(
      runtime.appModel.transientStatus,
      "当前系统无法提供通知；学习功能仍可正常使用"
    )
  }

  func testLatestListeningFindingDefaultsToSpeakingMode() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    try repository.saveDiagnosticReport(
      diagnosticReport(
        recognition: 90,
        production: 80,
        listening: 50,
        selfMonitoring: 10
      )
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: []),
      repository: repository,
      enableSystemReminders: false
    )

    XCTAssertEqual(runtime.appModel.mode, .speaking)
    XCTAssertEqual(runtime.practice?.mode, .speaking)
    XCTAssertFalse(runtime.appModel.hasExplicitModePreference)
  }

  func testExplicitQuietModeOverridesListeningDiagnosticDefault() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    try repository.saveDiagnosticReport(
      diagnosticReport(
        recognition: 90,
        production: 80,
        listening: 50,
        selfMonitoring: 80
      )
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(PracticeMode.quiet.rawValue, forKey: "practice.mode")
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: []),
      repository: repository,
      enableSystemReminders: false
    )

    XCTAssertTrue(runtime.appModel.hasExplicitModePreference)
    XCTAssertEqual(runtime.appModel.mode, .quiet)
    XCTAssertEqual(runtime.practice?.mode, .quiet)
  }

  func testRuntimeUsesNewestValidDiagnosticWhenLatestMetricsAreInvalid() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    try repository.saveDiagnosticReport(
      diagnosticReport(
        recognition: 90,
        production: 80,
        listening: 50,
        selfMonitoring: 10
      )
    )
    let invalid = DiagnosticMetrics(
      recognitionRate: .nan,
      productionRate: 80,
      medianResponseSeconds: 1,
      listeningRate: 80,
      listeningEvidenceCount: 10,
      collocationRate: 80,
      selfMonitoringRate: 10,
      completedAt: Date(timeIntervalSince1970: 1_700_086_400)
    )
    try repository.saveDiagnosticReport(
      DiagnosticEngine().report(
        baseline: invalid,
        current: invalid
      )
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: []),
      repository: repository,
      enableSystemReminders: false
    )

    XCTAssertEqual(runtime.appModel.mode, .speaking)
  }

  func testRuntimeCompletedTodayCountsUniqueSuccessfulItems() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    for (index, grade) in [ReviewGrade.again, .again, .easy].enumerated() {
      try repository.save(
        reviewEvent: ReviewEvent(
          itemType: .lexeme,
          itemId: "lexeme-one",
          grade: grade,
          responseTimeMs: 1_000,
          practiceMode: .quiet,
          createdAt: now.addingTimeInterval(TimeInterval(index))
        )
      )
    }
    let lexeme = Lexeme(
      id: "lexeme-one",
      lemma: "дом",
      stressedForm: "до́м",
      speechText: "дом",
      partOfSpeech: "noun",
      glossZh: "家",
      collocations: ["мой дом"],
      example: "Это мой дом.",
      sentenceIDs: [],
      reviewStatus: .reviewed,
      grammaticalGender: "masculine"
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [lexeme], sentences: []),
      repository: repository,
      enableSystemReminders: false
    )

    try runtime.refreshProgress(now: now)

    XCTAssertEqual(runtime.progress.completedToday, 1)
    XCTAssertEqual(runtime.progress.accuracy, 1.0 / 3.0, accuracy: 0.001)
  }

  func testRuntimeMasteredCountIncludesLexemesAndSentences() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let due = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.saveProgress(
      itemType: .lexeme,
      itemId: "lexeme-mastered",
      state: ReviewState(masteryLevel: 3, dueAt: due)
    )
    try repository.saveProgress(
      itemType: .sentence,
      itemId: "sentence-mastered",
      state: ReviewState(masteryLevel: 3, dueAt: due)
    )
    let lexeme = Lexeme(
      id: "lexeme-mastered",
      lemma: "дом",
      stressedForm: "до́м",
      speechText: "дом",
      partOfSpeech: "noun",
      glossZh: "家",
      collocations: ["мой дом"],
      example: "Это мой дом.",
      sentenceIDs: ["sentence-mastered"],
      reviewStatus: .reviewed,
      grammaticalGender: "masculine"
    )
    let sentence = SentenceCard(
      id: "sentence-mastered",
      promptZh: "这是我的家。",
      cueRu: "Где вы живёте?",
      practiceRu: "Это мой дом.",
      speechText: "Это мой дом.",
      theme: "家",
      lexemeIDs: [lexeme.id],
      sourcePath: "fixture",
      sourceText: "fixture",
      reviewStatus: .reviewed
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(
        lexemes: [lexeme],
        sentences: [sentence]
      ),
      repository: repository,
      enableSystemReminders: false
    )

    try runtime.refreshProgress(now: due)

    XCTAssertEqual(runtime.progress.masteredCount, 2)
  }

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

  func testPreferredScreenIdentifierPersistsAndRestores() {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var model = AppModel(defaults: defaults)
    model.preferredScreenIdentifier = "69733248"

    model = AppModel(defaults: defaults)

    XCTAssertEqual(model.preferredScreenIdentifier, "69733248")
  }

  private func diagnosticReport(
    recognition: Double,
    production: Double,
    listening: Double,
    selfMonitoring: Double
  ) -> DiagnosticReport {
    let metrics = DiagnosticMetrics(
      recognitionRate: recognition,
      productionRate: production,
      medianResponseSeconds: 1,
      listeningRate: listening,
      listeningEvidenceCount: 10,
      collocationRate: 80,
      selfMonitoringRate: selfMonitoring,
      completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    return DiagnosticEngine().report(
      baseline: metrics,
      current: metrics
    )
  }
}

final class ScreenPlacementTests: XCTestCase {
  private let screens = [
    ScreenDescriptor(
      identifier: "100",
      name: "Studio Display",
      visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1050),
      isMain: true
    ),
    ScreenDescriptor(
      identifier: "200",
      name: "Built-in Retina Display",
      visibleFrame: CGRect(x: -1512, y: 0, width: 1512, height: 945),
      isMain: false
    ),
    ScreenDescriptor(
      identifier: "300",
      name: "Projector",
      visibleFrame: CGRect(x: 1920, y: 0, width: 1280, height: 720),
      isMain: false
    ),
  ]

  func testPreferredIdentifierSelectsMatchingScreen() {
    XCTAssertEqual(
      ScreenPlacement.selectedScreen(
        preferredIdentifier: "200",
        screens: screens
      )?.identifier,
      "200"
    )
  }

  func testScreenNumberProducesStableIdentifier() {
    XCTAssertEqual(
      ScreenPlacement.identifier(
        screenNumber: NSNumber(value: UInt32(69_733_248))
      ),
      "69733248"
    )
  }

  func testUnknownIdentifierFallsBackToMainScreen() {
    XCTAssertEqual(
      ScreenPlacement.selectedScreen(
        preferredIdentifier: "missing",
        screens: screens
      )?.identifier,
      "100"
    )
  }

  func testMissingMainScreenFallsBackToFirstDescriptor() {
    let noMain = screens.map {
      ScreenDescriptor(
        identifier: $0.identifier,
        name: $0.name,
        visibleFrame: $0.visibleFrame,
        isMain: false
      )
    }

    XCTAssertEqual(
      ScreenPlacement.selectedScreen(
        preferredIdentifier: nil,
        screens: noMain
      )?.identifier,
      "100"
    )
  }

  func testNextScreenCyclesFromPreferredAndWraps() {
    XCTAssertEqual(
      ScreenPlacement.nextScreen(
        after: "200",
        screens: screens
      )?.identifier,
      "300"
    )
    XCTAssertEqual(
      ScreenPlacement.nextScreen(
        after: "300",
        screens: screens
      )?.identifier,
      "100"
    )
  }

  func testUnknownPreferredCyclesFromFallbackMain() {
    XCTAssertEqual(
      ScreenPlacement.nextScreen(
        after: "missing",
        screens: screens
      )?.identifier,
      "200"
    )
  }

  func testSingleScreenCycleIsSafeNoOp() {
    XCTAssertEqual(
      ScreenPlacement.nextScreen(
        after: "100",
        screens: [screens[0]]
      ),
      screens[0]
    )
  }
}
