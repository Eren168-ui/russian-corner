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

  func testStructuredRecallPersistsTransferEvidence() throws {
    var now = start
    let fixture = try makeFixture(
      sentenceCount: 3,
      now: { now }
    )
    fixture.model.reveal()
    now = start.addingTimeInterval(2.25)

    try fixture.model.submitRecallOutcome(
      .fluentWithinThreeSeconds
    )
    let exercise = try XCTUnwrap(
      fixture.model.currentTransferExercise
    )
    try fixture.model.submitTransferAnswer(
      optionID: exercise.correctOptionID
    )

    let event = try XCTUnwrap(
      fixture.repository.reviewEvents().first
    )
    XCTAssertEqual(event.grade, .easy)
    XCTAssertEqual(
      event.recallOutcome,
      .fluentWithinThreeSeconds
    )
    XCTAssertEqual(event.responseTimeMs, 2_250)
    XCTAssertEqual(event.transferExerciseID, exercise.id)
    XCTAssertEqual(
      event.transferAnswerID,
      exercise.correctOptionID
    )
    XCTAssertEqual(event.transferCorrect, true)
  }

  func testTransferAssessmentWaitsForExplicitNext() throws {
    let fixture = try makeFixture(sentenceCount: 3)
    let firstItemID = try XCTUnwrap(fixture.model.currentItem?.id)
    fixture.model.reveal()
    try fixture.model.submitRecallOutcome(
      .fluentWithinThreeSeconds
    )
    let exercise = try XCTUnwrap(
      fixture.model.currentTransferExercise
    )

    try fixture.model.submitTransferAnswer(
      optionID: exercise.correctOptionID
    )

    XCTAssertEqual(fixture.model.currentItem?.id, firstItemID)
    XCTAssertEqual(fixture.model.currentIndex, 0)
    XCTAssertTrue(fixture.model.isRevealed)
    XCTAssertTrue(fixture.model.isAssessmentComplete)
    XCTAssertEqual(
      fixture.model.statusMessage,
      "评估已记录；可继续查看词义，看完后点击“下一题”"
    )

    fixture.model.next()

    XCTAssertEqual(fixture.model.currentIndex, 1)
    XCTAssertFalse(fixture.model.isRevealed)
    XCTAssertFalse(fixture.model.isAssessmentComplete)
  }

  func testFailedTransferDowngradesFluentRecallToHard() throws {
    let fixture = try makeFixture(sentenceCount: 3)
    fixture.model.reveal()
    try fixture.model.submitRecallOutcome(
      .fluentWithinThreeSeconds
    )
    let exercise = try XCTUnwrap(
      fixture.model.currentTransferExercise
    )
    let wrongOption = try XCTUnwrap(
      exercise.options.first {
        $0.id != exercise.correctOptionID
      }
    )

    try fixture.model.submitTransferAnswer(
      optionID: wrongOption.id
    )

    let event = try XCTUnwrap(
      fixture.repository.reviewEvents().first
    )
    XCTAssertEqual(event.grade, .hard)
    XCTAssertEqual(event.transferAnswerID, wrongOption.id)
    XCTAssertEqual(event.transferCorrect, false)
  }

  func testUnknownRecallImmediatelySchedulesAgain() throws {
    let fixture = try makeFixture()
    fixture.model.reveal()

    try fixture.model.submitRecallOutcome(.unknown)

    let event = try XCTUnwrap(
      fixture.repository.reviewEvents().first
    )
    XCTAssertEqual(event.grade, .again)
    XCTAssertEqual(event.recallOutcome, .unknown)
    XCTAssertNil(event.transferAnswerID)
  }

  func testRecallAssessmentKeepsWordDetailUntilExplicitNext() throws {
    let fixture = try makeFixture(sentenceCount: 2)
    let firstItemID = try XCTUnwrap(fixture.model.currentItem?.id)
    fixture.model.reveal()
    fixture.model.toggleWordAnalysis(tokenIndex: 0)
    let selectedWordID = try XCTUnwrap(
      fixture.model.selectedWordAnalysis?.id
    )

    try fixture.model.submitRecallOutcome(.unknown)

    XCTAssertEqual(fixture.model.currentItem?.id, firstItemID)
    XCTAssertEqual(fixture.model.currentIndex, 0)
    XCTAssertTrue(fixture.model.isRevealed)
    XCTAssertTrue(fixture.model.isAssessmentComplete)
    XCTAssertEqual(
      fixture.model.selectedWordAnalysis?.id,
      selectedWordID
    )
    XCTAssertTrue(fixture.model.isDetailExpanded)

    fixture.model.next()

    XCTAssertEqual(fixture.model.currentIndex, 1)
    XCTAssertFalse(fixture.model.isRevealed)
    XCTAssertFalse(fixture.model.isAssessmentComplete)
    XCTAssertNil(fixture.model.selectedWordAnalysis)
  }

  func testJumpToQuestionLeavesSkippedCardsPending() throws {
    let fixture = try makeFixture(sentenceCount: 6)

    fixture.model.jumpToQuestion(at: 4)

    XCTAssertEqual(fixture.model.currentIndex, 4)
    XCTAssertEqual(
      fixture.model.sessionNavigator.status(at: 0),
      .unseen
    )
    XCTAssertTrue(fixture.model.sessionNavigator.isPending(at: 0))
    XCTAssertTrue(try fixture.repository.reviewEvents().isEmpty)
  }

  func testNextFromLastQuestionWrapsToEarlierPendingQuestion() throws {
    let fixture = try makeFixture(sentenceCount: 6)
    fixture.model.jumpToQuestion(at: 5)

    fixture.model.next()

    XCTAssertEqual(fixture.model.currentIndex, 0)
  }

  func testRevealedQuestionRemainsOpenedUnassessedAfterJump() throws {
    let fixture = try makeFixture(sentenceCount: 3)
    fixture.model.reveal()

    fixture.model.jumpToQuestion(at: 2)
    fixture.model.jumpToQuestion(at: 0)

    XCTAssertEqual(
      fixture.model.sessionNavigator.status(at: 0),
      .openedUnassessed
    )
    XCTAssertFalse(fixture.model.isRevealed)
    XCTAssertFalse(fixture.model.isAssessmentComplete)
  }

  func testAssessedQuestionReopensReadOnlyWithoutDuplicateEvent() throws {
    let fixture = try makeFixture(sentenceCount: 3)
    fixture.model.reveal()
    try fixture.model.submitRecallOutcome(.coreMeaningWithUsageIssue)
    let exercise = try XCTUnwrap(
      fixture.model.currentTransferExercise
    )
    try fixture.model.submitTransferAnswer(
      optionID: exercise.correctOptionID
    )
    fixture.model.jumpToQuestion(at: 1)

    fixture.model.jumpToQuestion(at: 0)

    XCTAssertTrue(fixture.model.isRevealed)
    XCTAssertTrue(fixture.model.isAssessmentComplete)
    XCTAssertEqual(
      fixture.model.statusMessage,
      "本题已评估；当前为只读复习"
    )
    XCTAssertEqual(try fixture.repository.reviewEvents().count, 1)
    XCTAssertThrowsError(try fixture.model.grade(.easy)) { error in
      XCTAssertEqual(
        error as? PracticeViewModelError,
        .assessmentAlreadyRecorded
      )
    }
  }

  func testAgainAppendsVisibleRetryQuestion() throws {
    let fixture = try makeFixture(sentenceCount: 3)
    let originalCount = fixture.model.totalCount
    fixture.model.reveal()

    try fixture.model.submitRecallOutcome(.unknown)

    XCTAssertEqual(fixture.model.totalCount, originalCount + 1)
    XCTAssertEqual(
      fixture.model.answerSheetItems.first?.status,
      .needsRetry
    )
    XCTAssertEqual(fixture.model.answerSheetItems.last?.isRetry, true)
    XCTAssertEqual(
      fixture.model.answerSheetItems.last?.status,
      .unseen
    )
  }

  func testSameDayNavigationSnapshotRestoresCurrentQuestion() throws {
    let suiteName = "PracticeViewModelNavigation.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let navigationStore = PracticeNavigationSnapshotStore(
      defaults: defaults
    )
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 0, sentenceCount: 6)
    let first = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      now: { self.start },
      calendar: utcCalendar,
      navigationStore: navigationStore
    )
    first.jumpToQuestion(at: 4)
    first.reveal()

    let restored = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      now: { self.start.addingTimeInterval(3_600) },
      calendar: utcCalendar,
      navigationStore: navigationStore
    )

    XCTAssertEqual(restored.currentIndex, 4)
    XCTAssertEqual(
      restored.sessionNavigator.status(at: 4),
      .openedUnassessed
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

  func testBundledPracticeQueueUsesLongTermCorpus() throws {
    let resourceDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent("RussianCornerCore", isDirectory: true)
      .appendingPathComponent("Resources", isDirectory: true)
    let catalog = try ContentCatalog(
      resourceDirectory: resourceDirectory
    )
    let model = try PracticeViewModel(
      catalog: catalog,
      repository: ProgressRepository(
        container: try ProgressRepository.makeInMemoryContainer()
      ),
      targetCount: 7,
      now: { self.start }
    )
    let allowedSentenceIDs = Set(
      catalog.longTermSentences.map(\.id)
    )

    XCTAssertFalse(model.queue.isEmpty)
    XCTAssertEqual(model.queue.first?.kind, .sentence)
    XCTAssertTrue(
      model.queue.allSatisfy { entry in
        switch entry.content {
        case .lexeme:
          return true
        case .sentence(let sentence):
          return allowedSentenceIDs.contains(sentence.id)
        }
      }
    )
    XCTAssertTrue(
      model.queue.contains { entry in
        guard case .sentence(let sentence) = entry.content else {
          return false
        }
        return !sentence.id.hasPrefix("trial-")
      }
    )
  }

  func testUnknownInflectedWordLooksUpResolvedLemma() async throws {
    let sentence = SentenceCard(
      id: "inflected-noun",
      promptZh: "从这里一览无余。",
      cueRu: "",
      practiceRu: "Всё как на ладони.",
      speechText: "Всё как на ладони.",
      theme: "city",
      lexemeIDs: [],
      sourcePath: "source.md",
      sourceText: "Всё как на ладони.",
      reviewStatus: .reviewed
    )
    let dictionary = RecordingOnlineDictionary()
    let model = try PracticeViewModel(
      catalog: ContentCatalog(
        lexemes: [],
        sentences: [sentence],
        surfaceLemmas: ["ладони": "ладонь"]
      ),
      repository: try makeRepository(),
      targetCount: 5,
      now: { self.start },
      calendar: utcCalendar,
      onlineDictionary: dictionary
    )

    model.reveal()
    model.toggleWordAnalysis(tokenIndex: 3)

    for _ in 0..<20 where await dictionary.recordedQueries().isEmpty {
      await Task.yield()
    }
    let queries = await dictionary.recordedQueries()
    XCTAssertEqual(queries, ["ладонь"])
  }

  func testManualTopicControlsFreshSentences() throws {
    let resourceDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent("RussianCornerCore", isDirectory: true)
      .appendingPathComponent("Resources", isDirectory: true)
    let model = try PracticeViewModel(
      catalog: try ContentCatalog(
        resourceDirectory: resourceDirectory
      ),
      repository: try makeRepository(),
      targetCount: 7,
      preferredTopicID: "topic-19",
      now: { self.start }
    )
    let sentenceTopics = model.queue.compactMap { entry in
      guard case .sentence(let sentence) = entry.content else {
        return nil as String?
      }
      return sentence.topicID
    }

    XCTAssertFalse(sentenceTopics.isEmpty)
    XCTAssertTrue(
      sentenceTopics.allSatisfy { $0 == "topic-19" }
    )
  }

  func testRevealedSentenceExposesAndTogglesEveryInteractiveWord() throws {
    let resourceDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent("RussianCornerCore", isDirectory: true)
      .appendingPathComponent("Resources", isDirectory: true)
    let model = try PracticeViewModel(
      catalog: try ContentCatalog(resourceDirectory: resourceDirectory),
      repository: try makeRepository(),
      targetCount: 7,
      now: { self.start }
    )
    let card = try XCTUnwrap(model.currentCard)

    model.reveal()

    XCTAssertEqual(
      model.currentSentenceWords.count,
      RussianWordTokenizer.words(in: card.practiceRu).count
    )
    XCTAssertNil(model.selectedWordAnalysis)

    model.toggleWordAnalysis(tokenIndex: 0)
    XCTAssertEqual(model.selectedWordAnalysis?.tokenIndex, 0)
    XCTAssertTrue(model.isDetailExpanded)
    XCTAssertEqual(
      model.selectedWordExamples.first?.russian,
      card.stressedForm ?? card.practiceRu
    )
    XCTAssertEqual(
      model.selectedWordExamples.first?.translationZh,
      card.promptZh
    )

    model.toggleWordAnalysis(tokenIndex: 1)
    XCTAssertEqual(model.selectedWordAnalysis?.tokenIndex, 1)

    model.toggleWordAnalysis(tokenIndex: 1)
    XCTAssertNil(model.selectedWordAnalysis)
    XCTAssertFalse(model.isDetailExpanded)
  }

  func testNextAdvancesThroughRequestedDailyCards() throws {
    let fixture = try makeFixture(targetCount: 7, sentenceCount: 12)

    XCTAssertEqual(fixture.model.totalCount, 7)
    XCTAssertEqual(fixture.model.currentIndex, 0)

    fixture.model.next()

    XCTAssertEqual(fixture.model.currentIndex, 1)
    XCTAssertFalse(fixture.model.isRevealed)
  }

  func testSceneSelectionCanMoveExpressionsToQueueFront() throws {
    let fixture = try makeFixture(sentenceCount: 4)

    fixture.model.prioritizeSentenceIDs(["sentence-2"])

    XCTAssertEqual(fixture.model.currentItem?.id, "sentence-2")
    XCTAssertEqual(
      fixture.model.currentItem?.origin,
      .reinforcement
    )
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

  func testFreshSentenceQueueCapsSupplementAtTwentyPercent() throws {
    let catalog = makeLayeredCatalog(
      coreSentenceCount: 20,
      supplementalSentenceCount: 20
    )
    let model = try PracticeViewModel(
      catalog: catalog,
      repository: try makeRepository(),
      targetCount: 10,
      now: { self.start },
      calendar: utcCalendar
    )
    let freshSentences = model.queue.compactMap { entry in
      guard
        entry.origin == .todayNew,
        case .sentence(let sentence) = entry.content
      else {
        return nil as SentenceCard?
      }
      return sentence
    }

    XCTAssertEqual(freshSentences.count, 10)
    XCTAssertLessThanOrEqual(
      freshSentences.filter {
        $0.corpusLayer == .dailySupplement
      }.count,
      2
    )
  }

  func testDueSupplementSentenceIsNeverDroppedByFreshCap() throws {
    let repository = try makeRepository()
    let catalog = makeLayeredCatalog(
      coreSentenceCount: 20,
      supplementalSentenceCount: 20
    )
    try repository.saveProgress(
      itemType: .sentence,
      itemId: "supplement-sentence-0",
      state: ReviewState(
        masteryLevel: 1,
        dueAt: start.addingTimeInterval(-60)
      )
    )

    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: 5,
      now: { self.start },
      calendar: utcCalendar
    )

    XCTAssertTrue(
      model.queue.contains {
        $0.id == "supplement-sentence-0"
          && $0.origin == .dueReview
      }
    )
  }

  func testFreshLexemeQueueAddsAtMostOneSupplement() throws {
    let catalog = makeLayeredCatalog(
      coreLexemeCount: 20,
      supplementalLexemeCount: 20
    )
    let model = try PracticeViewModel(
      catalog: catalog,
      repository: try makeRepository(),
      now: { self.start },
      calendar: utcCalendar
    )
    let freshLexemes = model.queue.compactMap { entry in
      guard
        entry.origin == .todayNew,
        case .lexeme(let lexeme) = entry.content
      else {
        return nil as Lexeme?
      }
      return lexeme
    }

    XCTAssertEqual(freshLexemes.count, 10)
    XCTAssertLessThanOrEqual(
      freshLexemes.filter {
        $0.corpusLayer == .dailySupplement
      }.count,
      1
    )
  }

  func testDueSupplementLexemeIsNeverDroppedByFreshCap() throws {
    let repository = try makeRepository()
    let catalog = makeLayeredCatalog(
      coreLexemeCount: 20,
      supplementalLexemeCount: 20
    )
    try repository.saveProgress(
      itemType: .lexeme,
      itemId: "supplement-lexeme-0",
      state: ReviewState(
        masteryLevel: 1,
        dueAt: start.addingTimeInterval(-60)
      )
    )

    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      now: { self.start },
      calendar: utcCalendar
    )

    XCTAssertTrue(
      model.queue.contains {
        $0.id == "supplement-lexeme-0"
          && $0.origin == .dueReview
      }
    )
  }

  func testA2ToB1ProfileKeepsBasicWordsOutOfStandaloneQueue() throws {
    let repository = try makeRepository()
    let basic = Lexeme(
      id: "basic-hello",
      lemma: "привет",
      stressedForm: "приве́т",
      speechText: "привет",
      partOfSpeech: "interjection",
      glossZh: "你好",
      collocations: ["передать привет"],
      example: "Передай ему привет.",
      sentenceIDs: [],
      reviewStatus: .reviewed
    )
    let bridge = Lexeme(
      id: "bridge-delay",
      lemma: "задерживаться",
      stressedForm: "заде́рживаться",
      speechText: "задерживаться",
      partOfSpeech: "verb",
      glossZh: "耽搁；延误",
      collocations: ["задерживаться на работе"],
      example: "Я иногда задерживаюсь на работе.",
      sentenceIDs: [],
      reviewStatus: .reviewed,
      aspect: "imperfective",
      aspectPairNote: "完成体：задержаться",
      government: "где? / на чём?"
    )

    let model = try PracticeViewModel(
      catalog: ContentCatalog(
        lexemes: [basic, bridge],
        sentences: []
      ),
      repository: repository,
      now: { self.start },
      calendar: utcCalendar
    )

    XCTAssertEqual(
      model.queue.compactMap {
        guard case .lexeme(let lexeme) = $0.content else {
          return nil
        }
        return lexeme.lemma
      },
      ["задерживаться"]
    )
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

  func testSentenceDetailExposesSourceAndRelatedExpressions() throws {
    let sentences = (0..<2).map { index in
      SentenceCard(
        id: "dialogue-\(index)",
        promptZh: "对话提示 \(index)",
        cueRu: "Что вы скажете в ситуации \(index)?",
        practiceRu: "Ответ \(index).",
        speechText: "Ответ \(index).",
        theme: "共同场景",
        lexemeIDs: [],
        sourcePath: "具体场景对话/Тема 23. Мои ребята..md",
        sourceText: "fixture",
        reviewStatus: .reviewed,
        provenanceType: .courseMaterial,
        dialogueAct: index == 0 ? "informationQuestion" : "statement",
        register: .neutral,
        speakerRole: "同学或朋友",
        topicID: "topic-23"
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
    XCTAssertEqual(model.currentSentenceSource?.theme, "共同场景")
    XCTAssertEqual(
      model.currentSentenceSource?.fileName,
      "Тема 23. Мои ребята"
    )
    XCTAssertEqual(
      model.currentSentenceSource?.dialogueActLabel,
      "询问信息"
    )
    XCTAssertEqual(model.relatedSentenceExpressions.count, 1)
    XCTAssertEqual(
      model.relatedSentenceExpressions.map(\.text),
      ["Ответ 1."]
    )
  }

  func testRelatedSentenceWordsCanOpenTheirOwnAnalysis() throws {
    let sentences = (0..<3).map { index in
      SentenceCard(
        id: "related-\(index)",
        promptZh: "意图 \(index)",
        cueRu: "Что сказать?",
        practiceRu: "Ответ \(index).",
        speechText: "Ответ \(index).",
        theme: "共同场景",
        lexemeIDs: [],
        sourcePath: "source.md",
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
    let related = try XCTUnwrap(model.relatedSentenceExpressions.first)
    model.reveal()

    model.toggleWordAnalysis(
      cardID: related.cardID,
      tokenIndex: 0
    )

    XCTAssertEqual(
      model.selectedWordAnalysis?.cardID,
      related.cardID
    )
    XCTAssertTrue(model.isDetailExpanded)
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

  func testDueBacklogStillReservesFreshSentenceCards() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 0, sentenceCount: 12)
    for sentence in catalog.sentences.prefix(8) {
      try repository.saveProgress(
        itemType: .sentence,
        itemId: sentence.id,
        state: ReviewState(
          masteryLevel: 2,
          dueAt: start.addingTimeInterval(-1)
        )
      )
    }

    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: 7,
      now: { self.start },
      calendar: utcCalendar
    )

    XCTAssertGreaterThanOrEqual(
      model.queue.filter { $0.origin == .todayNew }.count,
      2
    )
    XCTAssertTrue(model.queue.contains { $0.origin == .dueReview })
  }

  func testCarryoverEntryIsLabeledYesterdayUnfinished() throws {
    let repository = try makeRepository()
    let catalog = makeCatalog(lexemeCount: 0, sentenceCount: 5)
    let unfinished = PracticeItemIdentity(
      kind: .sentence,
      id: catalog.sentences[0].id
    )

    let model = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: 5,
      now: { self.start },
      calendar: utcCalendar,
      carryoverItemIDs: [unfinished]
    )

    XCTAssertEqual(
      model.queue.first { $0.identity == unfinished }?.origin,
      .yesterdayUnfinished
    )
    XCTAssertEqual(
      model.queue.first { $0.identity == unfinished }?.origin.title,
      "昨日未完成"
    )
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
    now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) },
    navigationStore: PracticeNavigationSnapshotStore? = nil
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
      now: now,
      navigationStore: navigationStore
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

  private func makeLayeredCatalog(
    coreLexemeCount: Int = 0,
    supplementalLexemeCount: Int = 0,
    coreSentenceCount: Int = 0,
    supplementalSentenceCount: Int = 0
  ) -> ContentCatalog {
    func lexeme(
      prefix: String,
      index: Int,
      layer: CorpusLayer
    ) -> Lexeme {
      Lexeme(
        id: "\(prefix)-lexeme-\(index)",
        lemma: "\(prefix)термин\(index)",
        stressedForm: "\(prefix)те́рмин\(index)",
        speechText: "\(prefix)термин\(index)",
        partOfSpeech: "noun",
        glossZh: "\(prefix)词义\(index)",
        collocations: ["изучать \(prefix)термин\(index)"],
        example: "Это \(prefix)термин\(index).",
        sentenceIDs: [],
        reviewStatus: .reviewed,
        grammaticalGender: "masculine",
        corpusLayer: layer
      )
    }
    func sentence(
      prefix: String,
      index: Int,
      layer: CorpusLayer
    ) -> SentenceCard {
      SentenceCard(
        id: "\(prefix)-sentence-\(index)",
        promptZh: "\(prefix)场景\(index)",
        cueRu: "Что вы скажете?",
        practiceRu: "Это \(prefix)ответ \(index).",
        speechText: "Это \(prefix)ответ \(index).",
        theme: "\(prefix)主题",
        lexemeIDs: [],
        sourcePath: "fixture.md",
        sourceText: "fixture",
        reviewStatus: .reviewed,
        corpusLayer: layer
      )
    }

    let coreLexemes = (0..<coreLexemeCount).map {
      lexeme(prefix: "core", index: $0, layer: .core)
    }
    let supplementalLexemes = (0..<supplementalLexemeCount).map {
      lexeme(
        prefix: "supplement",
        index: $0,
        layer: .dailySupplement
      )
    }
    let coreSentences = (0..<coreSentenceCount).map {
      sentence(prefix: "core", index: $0, layer: .core)
    }
    let supplementalSentences = (0..<supplementalSentenceCount).map {
      sentence(
        prefix: "supplement",
        index: $0,
        layer: .dailySupplement
      )
    }
    return ContentCatalog(
      lexemes: coreLexemes,
      sentences: coreSentences,
      supplementalLexemes: supplementalLexemes,
      supplementalSentences: supplementalSentences
    )
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

private actor RecordingOnlineDictionary: OnlineDictionaryLookingUp {
  private var queries: [String] = []

  func recordedQueries() -> [String] {
    queries
  }

  func lookup(
    lemma: String,
    language: StudyLanguage
  ) async throws -> OnlineDictionaryResult {
    _ = language
    queries.append(lemma)
    return OnlineDictionaryResult(
      lemma: lemma,
      partOfSpeech: "noun",
      translations: ["手掌"],
      synonyms: [],
      examples: []
    )
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
  func testCollapseControlHasComfortableHitTarget() {
    XCTAssertGreaterThanOrEqual(
      PracticeCardMetrics.headerActionHitWidth,
      36
    )
    XCTAssertGreaterThanOrEqual(
      PracticeCardMetrics.headerActionHitHeight,
      34
    )
  }

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

  func testRuntimeCarriesUnfinishedQueueIntoNextDayWithLabel() throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let sentences = (0..<6).map { index in
      SentenceCard(
        id: "carry-\(index)",
        promptZh: "提示 \(index)",
        cueRu: "Ситуация \(index)?",
        practiceRu: "Ответ \(index).",
        speechText: "Ответ \(index).",
        theme: "carry",
        lexemeIDs: [],
        sourcePath: "fixture",
        sourceText: "fixture",
        reviewStatus: .reviewed
      )
    }
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: sentences),
      repository: repository,
      enableSystemReminders: false
    )
    let initialDay = Calendar.current.startOfDay(for: Date())

    runtime.refreshPracticeForTemporalBoundary(
      now: initialDay.addingTimeInterval(36 * 60 * 60)
    )

    XCTAssertTrue(
      try XCTUnwrap(runtime.practice).queue.contains {
        $0.origin == .yesterdayUnfinished
      }
    )
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
    diagnostic.skipOralActivity(selfRating: 2)
    diagnostic.skipOralActivity(selfRating: 2)

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

  func testDeniedReminderOffersDirectSystemSettingsAction() async throws {
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let scheduler = RuntimeReminderScheduler(result: .permissionDenied)
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    var didOpenSettings = false
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(lexemes: [], sentences: []),
      repository: repository,
      reminderScheduler: scheduler,
      notificationSettingsOpener: {
        didOpenSettings = true
        return true
      }
    )

    await runtime.reconcileRemindersOnLaunch()

    XCTAssertEqual(
      runtime.appModel.reminderPermissionAction,
      .openSystemSettings
    )
    XCTAssertEqual(
      runtime.appModel.reminderPermissionAction?.title,
      "去开启"
    )

    await runtime.performReminderPermissionAction()

    XCTAssertTrue(didOpenSettings)
    XCTAssertEqual(
      runtime.appModel.transientStatus,
      "已打开系统通知设置；开启 Russian Corner 后返回即可"
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

  func testLanguageSettingsKeepEnglishSeparateAndRussianCompatible() {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(8, forKey: "practice.dailyCardCount")

    let russian = AppModel(
      defaults: defaults,
      language: .russian
    )
    let english = AppModel(
      defaults: defaults,
      language: .english
    )

    XCTAssertEqual(russian.dailyCardCount, 8)
    XCTAssertEqual(english.dailyCardCount, 7)
    XCTAssertTrue(russian.remindersEnabled)
    XCTAssertFalse(english.remindersEnabled)

    english.dailyCardCount = 10
    english.mode = .speaking

    XCTAssertEqual(
      defaults.integer(forKey: "english.practice.dailyCardCount"),
      10
    )
    XCTAssertEqual(defaults.integer(forKey: "practice.dailyCardCount"), 8)
    XCTAssertEqual(
      LanguageStudySettings.dailyQueueKey(for: .english),
      "english.practice.dailyQueueSnapshot.v1"
    )
    XCTAssertEqual(
      LanguageStudySettings.dailyQueueKey(for: .russian),
      "practice.dailyQueueSnapshot.v1"
    )
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

  func testFreePlacementAndDraggedOriginPersistAndRestore() {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var model = AppModel(defaults: defaults)
    model.placementMode = .free
    model.freeOrigin = CGPoint(x: 418, y: 236)

    model = AppModel(defaults: defaults)

    XCTAssertEqual(model.placementMode, .free)
    XCTAssertEqual(model.freeOrigin, CGPoint(x: 418, y: 236))
  }

  func testChoosingCornerExplicitlyEnablesSnapPlacement() {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let model = AppModel(defaults: defaults)
    model.placementMode = .free

    model.snap(to: .bottomLeft)

    XCTAssertEqual(model.placementMode, .snap)
    XCTAssertEqual(model.corner, .bottomLeft)
  }

  func testPreferredTopicPersistsOnlyForSelectedCalendarDay() {
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let today = Date(timeIntervalSince1970: 1_700_000_000)
    let tomorrow = today.addingTimeInterval(86_400)

    var model = AppModel(defaults: defaults)
    model.setPreferredTopic("topic-19", on: today)
    model = AppModel(defaults: defaults)

    XCTAssertEqual(model.preferredTopic(on: today), "topic-19")
    XCTAssertNil(model.preferredTopic(on: tomorrow))
  }

  func testRuntimeSyncsChangedNotesIntoDraftCandidatesOnly() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryRoot,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let noteURL = temporaryRoot.appendingPathComponent("topic.md")
    let originalNote =
      "1. Я хочу уточнить детали. — 我想确认细节。"
    try originalNote.write(
      to: noteURL,
      atomically: true,
      encoding: .utf8
    )
    let topic = TopicDefinition(
      id: "topic-01",
      number: 1,
      titleRu: "Тема",
      titleZh: "话题",
      sourcePath: "topic.md"
    )
    let manifest = LongTermContentManifest(
      schemaVersion: 1,
      sourceRoot: temporaryRoot.path,
      sourceCorpusSHA256: "fixture",
      contentGateClosed: true,
      sentences: []
    )
    let storeURL = temporaryRoot.appendingPathComponent(
      "derived/CandidateCorpus.json"
    )
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    let suiteName = "RussianCornerAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let runtime = AppRuntime(
      defaults: defaults,
      catalog: ContentCatalog(
        lexemes: [],
        sentences: [],
        topics: [topic],
        longTermManifest: manifest
      ),
      repository: repository,
      enableSystemReminders: false,
      candidateCorpusStore: CandidateCorpusStore(fileURL: storeURL),
      enableSourceSync: true
    )

    let state = try CandidateCorpusStore(fileURL: storeURL).load()
    XCTAssertEqual(state.candidates.count, 1)
    XCTAssertEqual(state.candidates.first?.status, .draft)
    XCTAssertEqual(runtime.pendingCandidateCount, 1)
    XCTAssertEqual(
      try String(contentsOf: noteURL, encoding: .utf8),
      originalNote
    )
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
