import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
final class LearningHistoryTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  func testBuildsSevenOrderedDaysAndTodayMetrics() {
    let now = date(2026, 7, 29, hour: 12)
    let today = calendar.startOfDay(for: now)
    let yesterday = dayOffset(-1, from: today)
    let sixDaysAgo = dayOffset(-6, from: today)
    let sessionID = UUID()
    let events = [
      event(.easy, item: "word-1", at: sixDaysAgo),
      event(.easy, item: "word-1", at: yesterday),
      event(.again, item: "word-1", at: today.addingTimeInterval(100)),
      event(.hard, item: "word-1", at: today.addingTimeInterval(200)),
      event(
        .easy,
        kind: .sentence,
        item: "sentence-1",
        at: today.addingTimeInterval(300)
      ),
    ]
    let trial = TrialReportSnapshot(
      sessions: [
        TrialSession(
          id: sessionID,
          startedAt: today.addingTimeInterval(60),
          endedAt: today.addingTimeInterval(660),
          endReason: .completed,
          startQueueCount: 10,
          endQueueCount: 0,
          completedLexemeCount: 1,
          completedSentenceCount: 1,
          newItemCount: 2,
          reviewItemCount: 0,
          remainingBacklogCount: 0,
          exitItemType: nil,
          exitQueuePosition: nil
        )
      ],
      interactions: [],
      reflections: [],
      oralAttempts: []
    )

    let snapshot = LearningHistoryBuilder.build(
      events: events,
      masteryByItem: [:],
      catalog: catalog(),
      trialSnapshot: trial,
      currentTarget: 10,
      now: now,
      calendar: calendar
    )

    XCTAssertEqual(snapshot.recentDays.count, 7)
    XCTAssertEqual(snapshot.recentDays.map(\.day), (0..<7).map {
      dayOffset($0 - 6, from: today)
    })
    XCTAssertEqual(snapshot.recentDays[1].completedCount, 0)
    XCTAssertEqual(snapshot.todayCompleted, 2)
    XCTAssertEqual(snapshot.todayTarget, 10)
    XCTAssertEqual(snapshot.todayCorrectCount, 2)
    XCTAssertEqual(snapshot.todayAttemptCount, 3)
    XCTAssertEqual(snapshot.recentDays.last?.studyDurationSeconds, 600)
  }

  func testStreakCarriesThroughYesterdayWhenTodayHasNoPractice() {
    let now = date(2026, 7, 29, hour: 12)
    let today = calendar.startOfDay(for: now)
    let snapshot = LearningHistoryBuilder.build(
      events: [
        event(.easy, item: "word-1", at: dayOffset(-1, from: today)),
        event(.hard, item: "word-1", at: dayOffset(-2, from: today)),
      ],
      masteryByItem: [:],
      catalog: catalog(),
      trialSnapshot: .empty,
      currentTarget: 10,
      now: now,
      calendar: calendar
    )

    XCTAssertEqual(snapshot.streakDays, 2)
    XCTAssertTrue(snapshot.needsPracticeToday)
  }

  func testSeparatesMasteryAndMapsCoveredTopics() {
    let now = date(2026, 7, 29, hour: 12)
    let content = catalog()
    let snapshot = LearningHistoryBuilder.build(
      events: [
        event(
          .easy,
          kind: .sentence,
          item: "sentence-1",
          at: now
        )
      ],
      masteryByItem: [
        PracticeItemIdentity(kind: .lexeme, id: "word-1"):
          ReviewState(masteryLevel: 3, dueAt: now),
        PracticeItemIdentity(kind: .sentence, id: "sentence-1"):
          ReviewState(masteryLevel: 4, dueAt: now),
        PracticeItemIdentity(kind: .lexeme, id: "word-2"):
          ReviewState(masteryLevel: 2, dueAt: now),
      ],
      catalog: content,
      trialSnapshot: .empty,
      currentTarget: 10,
      now: now,
      calendar: calendar
    )

    XCTAssertEqual(snapshot.masteredLexemeCount, 1)
    XCTAssertEqual(snapshot.masteredSentenceCount, 1)
    XCTAssertEqual(snapshot.coveredTopics.map(\.id), ["topic-1"])
    XCTAssertEqual(snapshot.totalTopicCount, 2)
  }

  func testRuntimeLearningHistoryUsesPersistedEventsAndCurrentQueueTarget()
    throws
  {
    let now = date(2026, 7, 29, hour: 12)
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    try repository.save(reviewEvent: event(.easy, item: "word-1", at: now))
    let suiteName = "LearningHistoryTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: catalog(),
      repository: repository,
      enableSystemReminders: false
    )

    try runtime.refreshLearningHistory(now: now, calendar: calendar)

    XCTAssertEqual(runtime.learningHistory.todayCompleted, 1)
    XCTAssertEqual(
      runtime.learningHistory.todayTarget,
      runtime.practice?.totalCount
    )
    XCTAssertEqual(runtime.learningHistory.recentDays.count, 7)
  }

  func testRuntimeLearningHistoryKeepsCoreDataWhenTrialHistoryFails()
    throws
  {
    let now = date(2026, 7, 29, hour: 12)
    let repository = ProgressRepository(
      container: try ProgressRepository.makeInMemoryContainer()
    )
    try repository.save(reviewEvent: event(.hard, item: "word-1", at: now))
    let suiteName = "LearningHistoryTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let runtime = AppRuntime(
      defaults: defaults,
      catalog: catalog(),
      repository: repository,
      trialRepository: ThrowingHistoryTrialStore(),
      enableSystemReminders: false
    )

    try runtime.refreshLearningHistory(now: now, calendar: calendar)

    XCTAssertEqual(runtime.learningHistory.todayCompleted, 1)
    XCTAssertEqual(runtime.learningHistory.recentDays.count, 7)
    XCTAssertNotNil(runtime.learningHistoryStatus)
  }

  private func event(
    _ grade: ReviewGrade,
    kind: PracticeItemKind = .lexeme,
    item: String,
    at date: Date
  ) -> ReviewEvent {
    ReviewEvent(
      itemType: kind,
      itemId: item,
      grade: grade,
      responseTimeMs: 1_000,
      practiceMode: .quiet,
      createdAt: date
    )
  }

  private func catalog() -> ContentCatalog {
    let sentence = SentenceCard(
      id: "sentence-1",
      promptZh: "这是家。",
      cueRu: "Где это?",
      practiceRu: "Это дом.",
      speechText: "Это дом.",
      theme: "家",
      lexemeIDs: ["word-1"],
      sourcePath: "fixture",
      sourceText: "fixture",
      reviewStatus: .reviewed,
      topicID: "topic-1"
    )
    return ContentCatalog(
      lexemes: [
        Lexeme(
          id: "word-1",
          lemma: "дом",
          stressedForm: "до́м",
          speechText: "дом",
          partOfSpeech: "noun",
          glossZh: "家",
          collocations: ["мой дом"],
          example: "Это дом.",
          sentenceIDs: ["sentence-1"],
          reviewStatus: .reviewed,
          grammaticalGender: "masculine"
        ),
        Lexeme(
          id: "word-2",
          lemma: "город",
          stressedForm: "го́род",
          speechText: "город",
          partOfSpeech: "noun",
          glossZh: "城市",
          collocations: ["мой город"],
          example: "Это город.",
          sentenceIDs: [],
          reviewStatus: .reviewed,
          grammaticalGender: "masculine"
        ),
      ],
      sentences: [sentence],
      topics: [
        TopicDefinition(
          id: "topic-1",
          number: 1,
          titleRu: "Дом",
          titleZh: "家与生活",
          sourcePath: "fixture"
        ),
        TopicDefinition(
          id: "topic-2",
          number: 2,
          titleRu: "Учёба",
          titleZh: "学习",
          sourcePath: "fixture"
        ),
      ],
      longTermManifest: LongTermContentManifest(
        schemaVersion: 1,
        sourceRoot: "fixture",
        sourceCorpusSHA256: "fixture",
        contentGateClosed: true,
        sentences: [sentence]
      )
    )
  }

  private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 0
  ) -> Date {
    calendar.date(
      from: DateComponents(
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour
      )
    )!
  }

  private func dayOffset(_ value: Int, from date: Date) -> Date {
    calendar.date(byAdding: .day, value: value, to: date)!
  }
}

@MainActor
private final class ThrowingHistoryTrialStore: TrialDataStoring {
  enum Failure: Error {
    case unavailable
  }

  func save(session: TrialSession) throws {}
  func save(interaction: TrialInteraction) throws {}
  func upsert(
    reflection: DailyReflection,
    calendar: Calendar
  ) throws {}
  func save(oralAttempt: OralActivityAttempt) throws {}

  func fetchSnapshot(
    from start: Date,
    through end: Date
  ) throws -> TrialReportSnapshot {
    throw Failure.unavailable
  }

  func reflection(
    on day: Date,
    calendar: Calendar
  ) throws -> DailyReflection? {
    nil
  }
}
