import Foundation
import RussianCornerCore

public struct DailyLearningRecord: Identifiable, Equatable, Sendable {
  public var id: Date { day }
  public let day: Date
  public let completedCount: Int
  public let targetCount: Int
  public let correctCount: Int
  public let attemptCount: Int
  public let studyDurationSeconds: Int
  public let topicIDs: [String]

  public init(
    day: Date,
    completedCount: Int,
    targetCount: Int,
    correctCount: Int,
    attemptCount: Int,
    studyDurationSeconds: Int,
    topicIDs: [String]
  ) {
    self.day = day
    self.completedCount = max(0, completedCount)
    self.targetCount = max(0, targetCount)
    self.correctCount = max(0, correctCount)
    self.attemptCount = max(0, attemptCount)
    self.studyDurationSeconds = max(0, studyDurationSeconds)
    self.topicIDs = topicIDs
  }

  public var accuracy: Double? {
    guard attemptCount > 0 else { return nil }
    return Double(correctCount) / Double(attemptCount)
  }
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

  public init(
    todayCompleted: Int = 0,
    todayTarget: Int = 0,
    streakDays: Int = 0,
    needsPracticeToday: Bool = true,
    todayCorrectCount: Int = 0,
    todayAttemptCount: Int = 0,
    masteredLexemeCount: Int = 0,
    masteredSentenceCount: Int = 0,
    coveredTopics: [TopicDefinition] = [],
    totalTopicCount: Int = 0,
    recentDays: [DailyLearningRecord] = []
  ) {
    self.todayCompleted = max(0, todayCompleted)
    self.todayTarget = max(0, todayTarget)
    self.streakDays = max(0, streakDays)
    self.needsPracticeToday = needsPracticeToday
    self.todayCorrectCount = max(0, todayCorrectCount)
    self.todayAttemptCount = max(0, todayAttemptCount)
    self.masteredLexemeCount = max(0, masteredLexemeCount)
    self.masteredSentenceCount = max(0, masteredSentenceCount)
    self.coveredTopics = coveredTopics
    self.totalTopicCount = max(0, totalTopicCount)
    self.recentDays = recentDays
  }

  public var todayAccuracy: Double? {
    guard todayAttemptCount > 0 else { return nil }
    return Double(todayCorrectCount) / Double(todayAttemptCount)
  }

  public var masteredTotal: Int {
    masteredLexemeCount + masteredSentenceCount
  }

  public var todayProgressText: String {
    "\(todayCompleted) / \(todayTarget)"
  }

  public var todayAccuracyText: String {
    guard let todayAccuracy else { return "—" }
    return "\(Int((todayAccuracy * 100).rounded()))%"
  }
}

public enum LearningHistoryBuilder {
  public static func build(
    events: [ReviewEvent],
    masteryByItem: [PracticeItemIdentity: ReviewState],
    catalog: ContentCatalog,
    trialSnapshot: TrialReportSnapshot,
    currentTarget: Int,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> LearningHistorySnapshot {
    let today = calendar.startOfDay(for: now)
    let recentDays = (0..<7).compactMap {
      calendar.date(byAdding: .day, value: $0 - 6, to: today)
    }
    let eventsByDay = Dictionary(grouping: events) {
      calendar.startOfDay(for: $0.createdAt)
    }
    let sessionsByDay = Dictionary(grouping: trialSnapshot.sessions) {
      calendar.startOfDay(for: $0.startedAt)
    }
    let sentenceByID = Dictionary(
      uniqueKeysWithValues: catalog.practiceSentences.map {
        ($0.id, $0)
      }
    )

    let dailyRecords = recentDays.map { day in
      let dayEvents = eventsByDay[day] ?? []
      let successfulItems = Set(
        dayEvents.compactMap { event in
          event.grade == .again
            ? nil
            : PracticeItemIdentity(
              kind: event.itemType,
              id: event.itemId
            )
        }
      )
      let daySessions = sessionsByDay[day] ?? []
      let sessionTarget = daySessions
        .min(by: { $0.startedAt < $1.startedAt })?
        .startQueueCount ?? 0
      let target =
        day == today
        ? max(max(0, currentTarget), sessionTarget)
        : sessionTarget
      let topicIDs = Set<String>(
        dayEvents.compactMap { event in
          guard event.itemType == .sentence else { return nil }
          return sentenceByID[event.itemId]?.topicID
        }
      ).sorted()
      return DailyLearningRecord(
        day: day,
        completedCount: successfulItems.count,
        targetCount: target,
        correctCount: dayEvents.filter { $0.grade != .again }.count,
        attemptCount: dayEvents.count,
        studyDurationSeconds: daySessions.reduce(0) {
          $0 + ($1.durationMs / 1_000)
        },
        topicIDs: topicIDs
      )
    }

    let activeDays = Set(eventsByDay.keys)
    let needsPracticeToday = !activeDays.contains(today)
    var streakDays = 0
    var cursor =
      needsPracticeToday
      ? calendar.date(byAdding: .day, value: -1, to: today) ?? today
      : today
    while activeDays.contains(cursor) {
      streakDays += 1
      guard
        let previous = calendar.date(
          byAdding: .day,
          value: -1,
          to: cursor
        )
      else { break }
      cursor = previous
    }

    let practicedTopicIDs = Set<String>(
      events.compactMap { event in
        guard event.itemType == .sentence else { return nil }
        return sentenceByID[event.itemId]?.topicID
      }
    )
    let coveredTopics = catalog.topics
      .filter { practicedTopicIDs.contains($0.id) }
      .sorted { $0.number < $1.number }
    let lexemeIDs = Set(catalog.practiceLexemes.map(\.id))
    let sentenceIDs = Set(catalog.practiceSentences.map(\.id))
    let masteredLexemeCount = masteryByItem.filter {
      $0.key.kind == .lexeme
        && lexemeIDs.contains($0.key.id)
        && $0.value.masteryLevel >= 3
    }.count
    let masteredSentenceCount = masteryByItem.filter {
      $0.key.kind == .sentence
        && sentenceIDs.contains($0.key.id)
        && $0.value.masteryLevel >= 3
    }.count
    let todayRecord = dailyRecords.last

    return LearningHistorySnapshot(
      todayCompleted: todayRecord?.completedCount ?? 0,
      todayTarget: todayRecord?.targetCount ?? max(0, currentTarget),
      streakDays: streakDays,
      needsPracticeToday: needsPracticeToday,
      todayCorrectCount: todayRecord?.correctCount ?? 0,
      todayAttemptCount: todayRecord?.attemptCount ?? 0,
      masteredLexemeCount: masteredLexemeCount,
      masteredSentenceCount: masteredSentenceCount,
      coveredTopics: coveredTopics,
      totalTopicCount: catalog.topics.count,
      recentDays: dailyRecords
    )
  }
}
