import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

public enum PracticeViewModelError:
  LocalizedError,
  Equatable,
  Sendable
{
  case answerNotRevealed
  case transferCheckUnavailable
  case invalidTransferAnswer

  public var errorDescription: String? {
    switch self {
    case .answerNotRevealed:
      return "请先显示答案，再提交评分"
    case .transferCheckUnavailable:
      return "当前没有待完成的迁移检验"
    case .invalidTransferAnswer:
      return "请选择一个有效答案"
    }
  }
}

public struct PracticeItemIdentity: Hashable, Sendable {
  public let kind: PracticeItemKind
  public let id: String

  public init(kind: PracticeItemKind, id: String) {
    self.kind = kind
    self.id = id
  }
}

public enum PracticeContent: Equatable, Sendable {
  case lexeme(Lexeme)
  case sentence(SentenceCard)
}

public enum PracticeQueueOrigin: Equatable, Sendable {
  case todayNew
  case dueReview
  case yesterdayUnfinished
  case sameDayRetry
  case reinforcement

  public var title: String {
    switch self {
    case .todayNew: "今日新内容"
    case .dueReview: "到期复习"
    case .yesterdayUnfinished: "昨日未完成"
    case .sameDayRetry: "本日重练"
    case .reinforcement: "巩固练习"
    }
  }
}

public enum LexemePromptDirection: Equatable, Sendable {
  case recognition
  case production
}

public enum OnlineWordLookupState: Equatable, Sendable {
  case idle
  case loading(String)
  case result(OnlineDictionaryResult)
  case unavailable(String)
}

public struct MicroDialogueTurn: Identifiable, Equatable, Sendable {
  public let cardID: String
  public let cue: String
  public let response: String

  public var id: String { cardID }

  public init(cardID: String, cue: String, response: String) {
    self.cardID = cardID
    self.cue = cue
    self.response = response
  }
}

public struct SentenceSourceSummary: Equatable, Sendable {
  public let theme: String
  public let fileName: String
  public let provenanceLabel: String
  public let dialogueActLabel: String?
  public let usageLabels: [String]
}

public struct RelatedSentenceExpression:
  Identifiable,
  Equatable,
  Sendable
{
  public let cardID: String
  public let promptZh: String
  public let text: String
  public let analyses: [ResolvedWordAnalysis]

  public var id: String { cardID }
}

public struct WordLearningExample: Equatable, Sendable {
  public let label: String
  public let russian: String
  public let translationZh: String?
}

public struct PracticeQueueEntry: Identifiable, Equatable, Sendable {
  public let content: PracticeContent
  public let isRetry: Bool
  public let origin: PracticeQueueOrigin

  public init(
    content: PracticeContent,
    isRetry: Bool = false,
    origin: PracticeQueueOrigin = .todayNew
  ) {
    self.content = content
    self.isRetry = isRetry
    self.origin = origin
  }

  public var kind: PracticeItemKind {
    switch content {
    case .lexeme: .lexeme
    case .sentence: .sentence
    }
  }

  public var id: String {
    switch content {
    case .lexeme(let lexeme): lexeme.id
    case .sentence(let sentence): sentence.id
    }
  }

  public var identity: PracticeItemIdentity {
    PracticeItemIdentity(kind: kind, id: id)
  }
}

@MainActor
@Observable
public final class PracticeViewModel {
  public private(set) var queue: [PracticeQueueEntry]
  public private(set) var currentIndex = 0
  public private(set) var isRevealed = false
  public private(set) var remainingRecallSeconds = 3
  public private(set) var completedToday: Int
  public private(set) var statusMessage: String?
  public private(set) var isDetailExpanded = false
  public private(set) var selectedWordAnalysis: ResolvedWordAnalysis?
  public private(set) var onlineWordLookupState:
    OnlineWordLookupState = .idle
  public private(set) var selectedRecallOutcome: RecallOutcome?
  public private(set) var currentTransferExercise: TransferExercise?
  public private(set) var selectedTransferAnswerID: String?
  public let targetCount: Int
  public let language: StudyLanguage
  public let newWordLimit: Int
  public let remainingNewWordCount: Int
  public let remainingSentenceCardCount: Int
  public let isWeeklyReviewDay: Bool
  public let selectedTopicID: String?
  public var mode: PracticeMode
  public var lexemeDirection: LexemePromptDirection

  private let repository: any PracticeProgressStoring
  private let scheduler: ReviewScheduler
  private let speechService: SpeechService
  private let trialTracker: (any PracticeTrialTracking)?
  private let onlineDictionary: (any OnlineDictionaryLookingUp)?
  private let now: () -> Date
  private let calendar: Calendar
  private let sessionDayStart: Date
  private let automaticDirectionAtCreation: LexemePromptDirection
  private let sentencesByID: [String: SentenceCard]
  private let sentencesByTheme: [String: [SentenceCard]]
  private let lexemesByID: [String: Lexeme]
  private let wordAnalysesByCardID: [String: [ResolvedWordAnalysis]]
  private let studyLexemesByID: [String: StudyLexeme]
  private let studySentencesByID: [String: StudySentence]
  private var states: [PracticeItemIdentity: ReviewState]
  private var successfulToday: Set<PracticeItemIdentity>
  private var recallStartedAt: Date
  private var initialBacklogIDs: Set<PracticeItemIdentity> = []
  private var resolvedBacklogIDs: Set<PracticeItemIdentity> = []
  private var usedSpeechOnCurrentItem = false
  private var openedDetailsOnCurrentItem = false
  private var onlineLookupTask: Task<Void, Never>?
  private var structuredResponseTimeMs: Int?

  public var currentItem: PracticeQueueEntry? {
    queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
  }

  public var currentContent: PracticeContent? {
    currentItem?.content
  }

  public var currentCard: SentenceCard? {
    guard case .sentence(let sentence) = currentContent else {
      return nil
    }
    return sentence
  }

  public var currentSentenceWords: [ResolvedWordAnalysis] {
    guard let currentCard else {
      return []
    }
    return wordAnalysesByCardID[currentCard.id] ?? []
  }

  public var currentLexeme: Lexeme? {
    guard case .lexeme(let lexeme) = currentContent else {
      return nil
    }
    return lexeme
  }

  public var currentStudyLexeme: StudyLexeme? {
    guard let currentLexeme else { return nil }
    return studyLexemesByID[currentLexeme.id]
  }

  public var selectedWordExamples: [WordLearningExample] {
    guard let word = selectedWordAnalysis else { return [] }
    var examples: [WordLearningExample] = []
    if let sentence = sentencesByID[word.cardID] {
      examples.append(
        WordLearningExample(
          label: "本句场景",
          russian: sentence.stressedForm ?? sentence.practiceRu,
          translationZh: sentence.promptZh
        )
      )
    }
    if let lexemeID = word.lexemeID,
      let lexeme = lexemesByID[lexemeID],
      !lexeme.example.isEmpty,
      !examples.contains(where: {
        $0.russian.caseInsensitiveCompare(lexeme.example)
          == .orderedSame
      })
    {
      examples.append(
        WordLearningExample(
          label: "词条例句",
          russian: lexeme.example,
          translationZh: nil
        )
      )
    }
    return examples
  }

  public var currentContextSentence: SentenceCard? {
    guard let lexeme = currentLexeme else { return nil }
    return lexeme.sentenceIDs.lazy.compactMap {
      self.sentencesByID[$0]
    }.first
  }

  public var microDialogueTurns: [MicroDialogueTurn] {
    guard case .sentence(let current) = currentContent else {
      return []
    }
    let sameTheme = sentencesByTheme[current.theme] ?? [current]
    let ordered = [current] + sameTheme.filter { $0.id != current.id }
    return ordered.prefix(3).map {
      MicroDialogueTurn(
        cardID: $0.id,
        cue: $0.cueRu,
        response: $0.practiceRu
      )
    }
  }

  public var currentSentenceSource: SentenceSourceSummary? {
    guard let card = currentCard else { return nil }
    var usageLabels: [String] = []
    if let role = card.speakerRole, !role.isEmpty {
      usageLabels.append(role)
    }
    if let register = card.register {
      usageLabels.append(Self.localizedRegister(register))
    }
    if let address = card.addressForm,
      address != .notApplicable
    {
      usageLabels.append(address.rawValue)
    }
    return SentenceSourceSummary(
      theme: card.theme,
      fileName: Self.sourceDisplayName(card.sourcePath),
      provenanceLabel: Self.localizedProvenance(
        card.provenanceType
      ),
      dialogueActLabel: card.dialogueAct.map(
        Self.localizedDialogueAct
      ),
      usageLabels: usageLabels
    )
  }

  public var relatedSentenceExpressions: [RelatedSentenceExpression] {
    guard let current = currentCard else { return [] }
    return (sentencesByTheme[current.theme] ?? [])
      .filter { $0.id != current.id }
      .prefix(2)
      .map {
        RelatedSentenceExpression(
          cardID: $0.id,
          promptZh: $0.promptZh,
          text: $0.stressedForm ?? $0.practiceRu,
          analyses: wordAnalysesByCardID[$0.id] ?? []
        )
      }
  }

  public func wordAnalyses(
    forCardID cardID: String
  ) -> [ResolvedWordAnalysis] {
    wordAnalysesByCardID[cardID] ?? []
  }

  public var lexemeGrammarLabels: [String] {
    guard let lexeme = currentLexeme else { return [] }
    var labels = [
      Self.localizedPartOfSpeech(lexeme.partOfSpeech)
    ]
    if let gender = lexeme.grammaticalGender {
      labels.append(Self.localizedGender(gender))
    }
    if let aspect = lexeme.aspect {
      labels.append(Self.localizedAspect(aspect))
    }
    if let pair = lexeme.aspectPair, !pair.isEmpty {
      labels.append("体对：\(pair)")
    }
    if let forms = lexeme.principalForms, !forms.isEmpty {
      labels.append("主要词形：\(forms.joined(separator: " · "))")
    }
    return labels
  }

  public var totalCount: Int {
    queue.count
  }

  public var isComplete: Bool {
    currentItem == nil
  }

  public var isStructuredRecallPresented: Bool {
    isRevealed
      && (
        selectedRecallOutcome == nil
          || currentTransferExercise != nil
      )
  }

  public var currentTheme: String {
    switch currentContent {
    case .lexeme:
      currentContextSentence?.theme ?? "词汇"
    case .sentence(let sentence):
      sentence.theme
    case nil:
      "完成"
    }
  }

  public var prompt: String? {
    switch currentContent {
    case .lexeme(let lexeme):
      return lexemeDirection == .recognition
        ? lexeme.stressedForm : lexeme.glossZh
    case .sentence(let card):
      let identity = PracticeItemIdentity(kind: .sentence, id: card.id)
      let mastery = states[identity]?.masteryLevel ?? 0
      let cueDiffersFromAnswer =
        card.cueRu.trimmingCharacters(in: .whitespacesAndNewlines)
        .caseInsensitiveCompare(
          card.practiceRu.trimmingCharacters(in: .whitespacesAndNewlines)
        ) != .orderedSame
      return mastery >= 3 && cueDiffersFromAnswer
        ? card.cueRu : card.promptZh
    case nil:
      return nil
    }
  }

  public var answer: String? {
    guard isRevealed else { return nil }
    return switch currentContent {
    case .lexeme(let lexeme):
      lexemeDirection == .recognition
        ? lexeme.glossZh : lexeme.stressedForm
    case .sentence(let sentence):
      sentence.stressedForm ?? sentence.practiceRu
    case nil:
      nil
    }
  }

  public init(
    catalog: ContentCatalog,
    repository: any PracticeProgressStoring,
    language: StudyLanguage = .russian,
    studyCatalog: LanguageContentCatalog? = nil,
    targetCount: Int = 7,
    mode: PracticeMode = .quiet,
    preferredTopicID: String? = nil,
    now: @escaping () -> Date = Date.init,
    calendar: Calendar = .current,
    diagnosticFindings: [DiagnosticFindingType] = [],
    vocabularyProfile: LearnerVocabularyProfile = .a2ToB1Bridge,
    scheduler: ReviewScheduler = ReviewScheduler(),
    speechService: SpeechService = SpeechService(),
    trialTracker: (any PracticeTrialTracking)? = nil,
    onlineDictionary: (any OnlineDictionaryLookingUp)? = nil,
    carryoverItemIDs: Set<PracticeItemIdentity> = []
  ) throws {
    self.repository = repository
    self.language = language
    let sentenceTargetCount = min(max(targetCount, 5), 10)
    self.targetCount = sentenceTargetCount
    self.mode = mode
    self.now = now
    self.calendar = calendar
    self.scheduler = scheduler
    self.speechService = speechService
    self.trialTracker = trialTracker
    self.onlineDictionary = onlineDictionary
    let instant = now()
    sessionDayStart = calendar.startOfDay(for: instant)
    let dayIndex = Int(
      floor(sessionDayStart.timeIntervalSince1970 / 86_400)
    )
    let primaryTopicID = TopicSelector().select(
      dayIndex: dayIndex,
      topics: catalog.topics,
      recentTopicIDs: [],
      weaknessByTopic: [:],
      manualTopicID: preferredTopicID
    )?.id
    selectedTopicID = primaryTopicID
    automaticDirectionAtCreation =
      calendar.component(.hour, from: instant) < 12
      ? .recognition : .production
    lexemeDirection = automaticDirectionAtCreation
    recallStartedAt = instant
    let servedLexemes = catalog.practiceLexemes
    let servedSentences = catalog.practiceSentences
    lexemesByID = Dictionary(
      uniqueKeysWithValues: servedLexemes.map { ($0.id, $0) }
    )
    sentencesByID = Dictionary(
      uniqueKeysWithValues: servedSentences.map { ($0.id, $0) }
    )
    sentencesByTheme = Dictionary(
      grouping: servedSentences,
      by: \.theme
    )
    wordAnalysesByCardID = Dictionary(
      uniqueKeysWithValues: servedSentences.map {
        (
          $0.id,
          catalog.wordAnalyses(for: $0, language: language)
        )
      }
    )
    studyLexemesByID = Dictionary(
      uniqueKeysWithValues: (
        studyCatalog?.lexemes
          ?? servedLexemes.map(\.studyContent)
      ).map { ($0.id, $0) }
    )
    studySentencesByID = Dictionary(
      uniqueKeysWithValues: (
        studyCatalog?.sentences
          ?? servedSentences.map(\.studyContent)
      ).map { ($0.id, $0) }
    )

    let events = try repository.reviewEvents()
    let todayStart = sessionDayStart
    let todayEvents = events.filter {
      calendar.startOfDay(for: $0.createdAt) == todayStart
    }
    let attemptedToday = Set(
      todayEvents.map {
        PracticeItemIdentity(kind: $0.itemType, id: $0.itemId)
      }
    )
    let successfulTodaySet = Set(
      todayEvents.compactMap {
        $0.grade == .again
          ? nil
          : PracticeItemIdentity(kind: $0.itemType, id: $0.itemId)
      }
    )
    let retryToday = Set(
      todayEvents.compactMap {
        let identity = PracticeItemIdentity(
          kind: $0.itemType,
          id: $0.itemId
        )
        return $0.grade == .again && !successfulTodaySet.contains(identity)
          ? identity : nil
      }
    )

    var restored: [PracticeItemIdentity: ReviewState] = [:]
    var dueLexemes: [Lexeme] = []
    var learnedLexemes: [Lexeme] = []
    var freshLexemes: [Lexeme] = []
    for lexeme in servedLexemes
    where lexeme.reviewStatus != .draft
      && vocabularyProfile.shouldServeAsStandalone(lexeme: lexeme)
    {
      let identity = PracticeItemIdentity(kind: .lexeme, id: lexeme.id)
      if let state = try repository.progress(
        itemType: .lexeme,
        itemId: lexeme.id
      ) {
        restored[identity] = state
        learnedLexemes.append(lexeme)
        if state.dueAt <= instant {
          dueLexemes.append(lexeme)
        }
      } else {
        freshLexemes.append(lexeme)
      }
    }

    var dueSentences: [SentenceCard] = []
    var learnedSentences: [SentenceCard] = []
    var freshSentences: [SentenceCard] = []
    for sentence in servedSentences
    where sentence.reviewStatus != .draft {
      let identity = PracticeItemIdentity(
        kind: .sentence,
        id: sentence.id
      )
      if let state = try repository.progress(
        itemType: .sentence,
        itemId: sentence.id
      ) {
        restored[identity] = state
        learnedSentences.append(sentence)
        if state.dueAt <= instant {
          dueSentences.append(sentence)
        }
      } else {
        freshSentences.append(sentence)
      }
    }
    states = restored

    let previousRate = Self.recallRate(
      on: calendar.date(byAdding: .day, value: -1, to: instant)!,
      events: events,
      calendar: calendar
    ) ?? 0.8
    let strongStreak = Self.strongDayStreak(
      endingBefore: instant,
      events: events,
      calendar: calendar
    )
    let overdueCount = dueLexemes.filter {
      !successfulTodaySet.contains(
        PracticeItemIdentity(kind: .lexeme, id: $0.id)
      )
    }.count
    initialBacklogIDs = Set(
      dueLexemes.map {
        PracticeItemIdentity(kind: .lexeme, id: $0.id)
      }
      + dueSentences.map {
        PracticeItemIdentity(kind: .sentence, id: $0.id)
      }
    ).subtracting(successfulTodaySet)
    let weeklyReviewDay =
      calendar.component(.weekday, from: instant) == 1
    let hasLearnedContent =
      !learnedLexemes.isEmpty
      || !learnedSentences.isEmpty
      || !events.isEmpty
    let scheduledNewWordLimit =
      weeklyReviewDay && !hasLearnedContent
      ? 6
      : scheduler.adaptiveNewWordLimit(
        previousRecallRate: previousRate,
        strongDayStreak: strongStreak,
        overdueCount: overdueCount
      )
    let diagnosticCapsNewWords = diagnosticFindings.contains {
      $0 == .vocabularyBreadth || $0 == .activeRetrieval
    }
    let diagnosedNewWordLimit =
      diagnosticCapsNewWords
      ? min(scheduledNewWordLimit, 6)
      : scheduledNewWordLimit
    let adaptiveNewWordLimit =
      weeklyReviewDay && hasLearnedContent
      ? 0 : diagnosedNewWordLimit

    let attemptedBeforeToday = Set(
      events.compactMap { event in
        event.createdAt < todayStart
          ? PracticeItemIdentity(
            kind: event.itemType,
            id: event.itemId
          )
          : nil
      }
    )
    let attemptedNewLexemeCount = attemptedToday.filter {
      $0.kind == .lexeme && !attemptedBeforeToday.contains($0)
    }.count
    let attemptedSentenceCount = attemptedToday.filter {
      $0.kind == .sentence
    }.count
    let newWordsRemaining = max(
      0,
      adaptiveNewWordLimit - attemptedNewLexemeCount
    )
    let sentenceCardsRemaining = max(
      0,
      sentenceTargetCount - attemptedSentenceCount
    )

    let orderedRetryIdentities = retryToday.sorted {
      if $0.kind.rawValue == $1.kind.rawValue {
        return $0.id < $1.id
      }
      return $0.kind.rawValue < $1.kind.rawValue
    }
    let excluded = successfulTodaySet.union(retryToday)
    let orderedDueLexemes = Self.dailyOrder(
      dueLexemes.filter {
        !excluded.contains(
          PracticeItemIdentity(kind: .lexeme, id: $0.id)
        )
      },
      dayIndex: dayIndex,
      salt: 11
    )
    let orderedLearnedLexemes = Self.dailyOrder(
      learnedLexemes.filter {
        !excluded.contains(
          PracticeItemIdentity(kind: .lexeme, id: $0.id)
        )
      },
      dayIndex: dayIndex,
      salt: 13
    )
    let orderedFreshLexemes = Self.dailyOrder(
      freshLexemes.filter {
        !excluded.contains(
          PracticeItemIdentity(kind: .lexeme, id: $0.id)
        )
      },
      dayIndex: dayIndex,
      salt: 17
    )

    let carryover = carryoverItemIDs
      .subtracting(successfulTodaySet)
      .subtracting(retryToday)
    let carryoverLexemes = Self.dailyOrder(
      servedLexemes.filter {
        carryover.contains(
          PracticeItemIdentity(kind: .lexeme, id: $0.id)
        )
      },
      dayIndex: dayIndex,
      salt: 7
    )
    var lexemeEntries: [PracticeQueueEntry] = orderedRetryIdentities
      .filter { $0.kind == .lexeme }
      .compactMap { identity in
        servedLexemes.first { $0.id == identity.id }
      }
      .map {
        PracticeQueueEntry(
          content: .lexeme($0),
          isRetry: true,
          origin: .sameDayRetry
        )
      }
    lexemeEntries += carryoverLexemes.prefix(2).map {
      PracticeQueueEntry(
        content: .lexeme($0),
        origin: .yesterdayUnfinished
      )
    }
    let queuedLexemeIDs = Set(lexemeEntries.map(\.id))
    if weeklyReviewDay && hasLearnedContent {
      lexemeEntries += orderedLearnedLexemes.filter {
        !queuedLexemeIDs.contains($0.id)
      }
        .prefix(max(diagnosedNewWordLimit, 1))
        .map {
          PracticeQueueEntry(
            content: .lexeme($0),
            origin: .reinforcement
          )
        }
    } else {
      lexemeEntries += orderedDueLexemes.filter {
        !queuedLexemeIDs.contains($0.id)
      }.prefix(20).map {
        PracticeQueueEntry(
          content: .lexeme($0),
          origin: .dueReview
        )
      }
      let queuedAfterDue = Set(lexemeEntries.map(\.id))
      lexemeEntries += orderedFreshLexemes.filter {
        !queuedAfterDue.contains($0.id)
      }
        .prefix(newWordsRemaining)
        .map {
          PracticeQueueEntry(
            content: .lexeme($0),
            origin: .todayNew
          )
        }
    }

    let sentenceExcluded = successfulTodaySet.union(retryToday)
    let topicFreshSentenceCandidates =
      weeklyReviewDay && hasLearnedContent
      ? []
      : Self.dailyOrder(
        freshSentences.filter {
          !sentenceExcluded.contains(
            PracticeItemIdentity(kind: .sentence, id: $0.id)
          )
            && (
              primaryTopicID == nil
                || $0.topicID == primaryTopicID
            )
        },
        dayIndex: dayIndex,
        salt: 29
      )
    let otherFreshSentenceCandidates =
      weeklyReviewDay && hasLearnedContent
      ? []
      : Self.dailyOrder(
        freshSentences.filter {
          !sentenceExcluded.contains(
            PracticeItemIdentity(kind: .sentence, id: $0.id)
          )
            && !topicFreshSentenceCandidates.contains($0)
        },
        dayIndex: dayIndex,
        salt: 37
      )
    let freshSentenceCandidates =
      topicFreshSentenceCandidates + otherFreshSentenceCandidates
    let orderedDueSentences = Self.dailyOrder(
      dueSentences.filter {
        !sentenceExcluded.contains(
          PracticeItemIdentity(kind: .sentence, id: $0.id)
        )
      },
      dayIndex: dayIndex,
      salt: 23
    )
    let reinforcementSentences = Self.dailyOrder(
      learnedSentences.filter {
        let identity = PracticeItemIdentity(
          kind: .sentence,
          id: $0.id
        )
        guard let dueAt = restored[identity]?.dueAt else {
          return false
        }
        return dueAt > instant
          && !sentenceExcluded.contains(identity)
          && (
            primaryTopicID == nil
              || $0.topicID == primaryTopicID
          )
      },
      dayIndex: dayIndex,
      salt: 31
    )
    var sentenceEntries: [PracticeQueueEntry] = orderedRetryIdentities
      .filter { $0.kind == .sentence }
      .compactMap { identity in
        servedSentences.first { $0.id == identity.id }
      }
      .map {
        PracticeQueueEntry(
          content: .sentence($0),
          isRetry: true,
          origin: .sameDayRetry
        )
      }
    var seenSentenceIDs = Set(sentenceEntries.map(\.id))
    let sentenceLimit =
      orderedRetryIdentities.filter({ $0.kind == .sentence }).count
      + sentenceCardsRemaining
    let carryoverSentences = Self.dailyOrder(
      servedSentences.filter {
        carryover.contains(
          PracticeItemIdentity(kind: .sentence, id: $0.id)
        )
      },
      dayIndex: dayIndex,
      salt: 5
    )
    for sentence in carryoverSentences.prefix(2)
    where sentenceEntries.count < sentenceLimit
      && seenSentenceIDs.insert(sentence.id).inserted {
      sentenceEntries.append(
        PracticeQueueEntry(
          content: .sentence(sentence),
          origin: .yesterdayUnfinished
        )
      )
    }
    let availableSlots = max(0, sentenceLimit - sentenceEntries.count)
    let freshReserve = weeklyReviewDay && hasLearnedContent
      ? 0
      : min(
        freshSentenceCandidates.filter {
          !seenSentenceIDs.contains($0.id)
        }.count,
        min(availableSlots, max(2, sentenceCardsRemaining * 3 / 10))
      )
    for sentence in orderedDueSentences
    where sentenceEntries.count < sentenceLimit - freshReserve
      && seenSentenceIDs.insert(sentence.id).inserted {
      sentenceEntries.append(
        PracticeQueueEntry(
          content: .sentence(sentence),
          origin: .dueReview
        )
      )
    }
    for sentence in freshSentenceCandidates
    where sentenceEntries.count < sentenceLimit
      && seenSentenceIDs.insert(sentence.id).inserted {
      sentenceEntries.append(
        PracticeQueueEntry(
          content: .sentence(sentence),
          origin: .todayNew
        )
      )
    }
    if sentenceEntries.count < sentenceLimit {
      for sentence in orderedDueSentences + reinforcementSentences
      where sentenceEntries.count < sentenceLimit
        && seenSentenceIDs.insert(sentence.id).inserted {
        sentenceEntries.append(
          PracticeQueueEntry(
            content: .sentence(sentence),
            origin: orderedDueSentences.contains(sentence)
              ? .dueReview : .reinforcement
          )
        )
      }
    }
    isWeeklyReviewDay = weeklyReviewDay
    newWordLimit = adaptiveNewWordLimit
    remainingNewWordCount = newWordsRemaining
    remainingSentenceCardCount = sentenceCardsRemaining
    successfulToday = successfulTodaySet
    completedToday = successfulTodaySet.count
    queue = catalog.topics.isEmpty
      ? lexemeEntries + sentenceEntries
      : sentenceEntries + lexemeEntries
  }

  public func needsTemporalReload(at instant: Date) -> Bool {
    if calendar.startOfDay(for: instant) != sessionDayStart {
      return true
    }
    let expectedDirection: LexemePromptDirection =
      calendar.component(.hour, from: instant) < 12
      ? .recognition : .production
    return expectedDirection != automaticDirectionAtCreation
  }

  public func reveal() {
    guard currentItem != nil else { return }
    isRevealed = true
    refreshRecallTimer()
    trialTracker?.record(
      kind: .reveal,
      context: trialContext(
        kind: .reveal,
        occurredAt: now()
      )
    )
  }

  public func submitRecallOutcome(
    _ outcome: RecallOutcome
  ) throws {
    guard isRevealed else {
      throw PracticeViewModelError.answerNotRevealed
    }
    let elapsed = max(0, now().timeIntervalSince(recallStartedAt))
    let responseTimeMs = Int((elapsed * 1_000).rounded())
    selectedRecallOutcome = outcome
    structuredResponseTimeMs = responseTimeMs
    selectedTransferAnswerID = nil
    clearWordAnalysis()

    guard outcome.requiresTransferCheck else {
      let grade = outcome.reviewGrade(
        responseTimeMs: responseTimeMs,
        transferCorrect: false
      )
      try persistGrade(
        grade,
        recallOutcome: outcome,
        responseTimeMs: responseTimeMs
      )
      return
    }

    currentTransferExercise = makeTransferExercise()
  }

  public func submitTransferAnswer(optionID: String) throws {
    guard
      let outcome = selectedRecallOutcome,
      let exercise = currentTransferExercise,
      let responseTimeMs = structuredResponseTimeMs
    else {
      throw PracticeViewModelError.transferCheckUnavailable
    }
    guard exercise.options.contains(where: { $0.id == optionID }) else {
      throw PracticeViewModelError.invalidTransferAnswer
    }
    selectedTransferAnswerID = optionID
    let isCorrect = exercise.isCorrect(optionID: optionID)
    let grade = outcome.reviewGrade(
      responseTimeMs: responseTimeMs,
      transferCorrect: isCorrect
    )
    try persistGrade(
      grade,
      recallOutcome: outcome,
      responseTimeMs: responseTimeMs,
      transferExerciseID: exercise.id,
      transferAnswerID: optionID,
      transferCorrect: isCorrect
    )
  }

  public func toggleDetails() {
    guard currentItem != nil else { return }
    isDetailExpanded.toggle()
    guard isDetailExpanded else {
      clearWordAnalysis()
      return
    }
    openedDetailsOnCurrentItem = true
    trialTracker?.record(
      kind: .detailsOpened,
      context: trialContext(
        kind: .detailsOpened,
        occurredAt: now()
      )
    )
  }

  public func toggleWordAnalysis(tokenIndex: Int) {
    guard let cardID = currentCard?.id else { return }
    toggleWordAnalysis(cardID: cardID, tokenIndex: tokenIndex)
  }

  public func toggleWordAnalysis(
    cardID: String,
    tokenIndex: Int
  ) {
    guard isRevealed else { return }
    guard let analysis = wordAnalyses(forCardID: cardID).first(where: {
      $0.tokenIndex == tokenIndex
    }) else {
      return
    }
    if selectedWordAnalysis?.id == analysis.id {
      clearWordAnalysis()
      return
    }
    selectedWordAnalysis = analysis
    let lookupText = analysis.lemma
    startOnlineLookup(
      for: lookupText,
      selectionID: analysis.id
    )
    guard !isDetailExpanded else { return }
    isDetailExpanded = true
    openedDetailsOnCurrentItem = true
    trialTracker?.record(
      kind: .detailsOpened,
      context: trialContext(
        kind: .detailsOpened,
        occurredAt: now()
      )
    )
  }

  private static func sourceDisplayName(_ sourcePath: String) -> String {
    if sourcePath.hasPrefix("curated://") {
      let name = sourcePath.split(separator: "/").last.map(String.init)
        ?? sourcePath
      return "应用内策展语料 · \(name)"
    }
    let fileName = URL(fileURLWithPath: sourcePath).lastPathComponent
    let title = fileName.lowercased().hasSuffix(".md")
      ? (fileName as NSString).deletingPathExtension
      : fileName
    return title.trimmingCharacters(
      in: .whitespacesAndNewlines.union(
        CharacterSet(charactersIn: ".")
      )
    )
  }

  private static func localizedProvenance(
    _ provenance: ProvenanceType?
  ) -> String {
    switch provenance {
    case .courseMaterial: "课程材料"
    case .userNote: "用户笔记"
    case .derived: "派生审核语料"
    case .aiGenerated: "AI 生成候选"
    case nil: "本地审核语料"
    }
  }

  private static func localizedRegister(
    _ register: DialogueRegister
  ) -> String {
    switch register {
    case .informal: "非正式"
    case .neutral: "中性表达"
    case .polite: "礼貌表达"
    case .formal: "正式表达"
    case .textbook: "教材表达"
    case .possiblyDated: "可能较旧"
    }
  }

  private static func localizedDialogueAct(_ value: String) -> String {
    switch value {
    case "informationQuestion": "询问信息"
    case "statement": "陈述信息"
    case "greetingAndPermission": "问候并征求许可"
    case "smallTalkQuestion": "寒暄提问"
    case "farewell": "告别"
    case "apology": "道歉"
    case "clarification": "澄清"
    case "requestCallback": "请求回电"
    case "askLocation": "询问位置"
    case "askRoute": "问路"
    case "giveDirections": "指路"
    case "advice": "建议"
    case "reportSymptom": "描述症状"
    default: value
    }
  }

  public func clearWordAnalysis() {
    onlineLookupTask?.cancel()
    onlineLookupTask = nil
    selectedWordAnalysis = nil
    onlineWordLookupState = .idle
    isDetailExpanded = false
  }

  private func startOnlineLookup(
    for lookupText: String,
    selectionID: String
  ) {
    onlineLookupTask?.cancel()
    guard let onlineDictionary else {
      onlineWordLookupState = .idle
      return
    }
    onlineWordLookupState = .loading(lookupText)
    let lookupLanguage = language
    onlineLookupTask = Task { [weak self] in
      do {
        let result = try await onlineDictionary.lookup(
          lemma: lookupText,
          language: lookupLanguage
        )
        guard !Task.isCancelled else { return }
        guard self?.selectedWordAnalysis?.id == selectionID else {
          return
        }
        self?.onlineWordLookupState = .result(result)
      } catch {
        guard !Task.isCancelled else { return }
        guard self?.selectedWordAnalysis?.id == selectionID else {
          return
        }
        self?.onlineWordLookupState = .unavailable(
          (error as? LocalizedError)?.errorDescription
            ?? "在线补充暂时不可用"
        )
      }
    }
  }

  public func toggleLexemeDirection() {
    guard currentLexeme != nil else { return }
    lexemeDirection =
      lexemeDirection == .recognition
      ? .production : .recognition
    isRevealed = false
    remainingRecallSeconds = 3
    recallStartedAt = now()
    clearWordAnalysis()
    speechService.stop()
  }

  public func refreshRecallTimer() {
    let elapsed = max(0, now().timeIntervalSince(recallStartedAt))
    remainingRecallSeconds = max(0, Int(ceil(3 - elapsed)))
  }

  public func grade(_ grade: ReviewGrade) throws {
    try persistGrade(grade)
  }

  private func persistGrade(
    _ grade: ReviewGrade,
    recallOutcome: RecallOutcome? = nil,
    responseTimeMs explicitResponseTimeMs: Int? = nil,
    transferExerciseID: String? = nil,
    transferAnswerID: String? = nil,
    transferCorrect: Bool? = nil
  ) throws {
    guard isRevealed else {
      throw PracticeViewModelError.answerNotRevealed
    }
    guard let item = currentItem else { return }
    let instant = now()
    let elapsed = max(0, instant.timeIntervalSince(recallStartedAt))
    let wasNewItem = states[item.identity] == nil && !item.isRetry
    let event = ReviewEvent(
      itemType: item.kind,
      itemId: item.id,
      grade: grade,
      responseTimeMs: explicitResponseTimeMs
        ?? Int((elapsed * 1_000).rounded()),
      practiceMode: mode,
      createdAt: instant,
      recallOutcome: recallOutcome,
      transferExerciseID: transferExerciseID,
      transferAnswerID: transferAnswerID,
      transferCorrect: transferCorrect
    )
    let oldState =
      states[item.identity]
      ?? ReviewState(masteryLevel: 0, dueAt: instant)
    let newState = scheduler.next(
      state: oldState,
      grade: grade,
      now: instant
    )
    var newSuccessfulToday = successfulToday
    if grade != .again {
      newSuccessfulToday.insert(item.identity)
    }
    let newCompletedCount = newSuccessfulToday.count
    try repository.commitReview(
      event: event,
      state: newState,
      dailyCompletedCount: newCompletedCount,
      calendar: calendar
    )
    states[item.identity] = newState
    successfulToday = newSuccessfulToday
    completedToday = newCompletedCount
    if grade != .again,
      initialBacklogIDs.contains(item.identity)
    {
      resolvedBacklogIDs.insert(item.identity)
    }
    if grade == .again {
      let hasFutureRetry = queue
        .dropFirst(currentIndex + 1)
        .contains {
          $0.identity == item.identity && $0.isRetry
        }
      if !hasFutureRetry {
        queue.append(
          PracticeQueueEntry(content: item.content, isRetry: true)
        )
      }
    }
    trialTracker?.record(
      kind: .grade,
      context: trialContext(
        kind: .grade,
        grade: grade,
        responseTimeMs: event.responseTimeMs,
        isNewItem: wasNewItem,
        occurredAt: instant,
        recallOutcome: recallOutcome,
        transferExerciseID: transferExerciseID,
        transferAnswerID: transferAnswerID,
        transferCorrect: transferCorrect
      )
    )
    advance(status: nil)
  }

  public func next() {
    guard currentItem != nil else { return }
    trialTracker?.record(
      kind: .next,
      context: trialContext(
        kind: .next,
        occurredAt: now()
      )
    )
    advance(status: nil)
  }

  private func advance(status: String?) {
    guard currentItem != nil else { return }
    speechService.stop()
    currentIndex += 1
    isRevealed = false
    selectedRecallOutcome = nil
    currentTransferExercise = nil
    selectedTransferAnswerID = nil
    structuredResponseTimeMs = nil
    clearWordAnalysis()
    usedSpeechOnCurrentItem = false
    openedDetailsOnCurrentItem = false
    remainingRecallSeconds = 3
    recallStartedAt = now()
    statusMessage = status
    if isComplete {
      trialTracker?.close(reason: .completed)
    }
  }

  public func showStatus(_ message: String) {
    statusMessage = message
  }

  public func handleDisappear() {
    speechService.stop()
  }

  public func speak() {
    let text: String?
    switch currentContent {
    case .lexeme(let lexeme):
      text = lexeme.speechText
    case .sentence(let sentence):
      text = sentence.speechText
    case nil:
      text = nil
    }
    guard let text else { return }
    usedSpeechOnCurrentItem = true
    trialTracker?.record(
      kind: .speak,
      context: trialContext(
        kind: .speak,
        occurredAt: now()
      )
    )
    switch speechService.speak(
      text,
      language: language,
      allowUnrelatedFallback: false
    ) {
    case .preferredVoice, .fallbackVoice:
      statusMessage =
        language == .english ? "正在朗读英语" : "正在朗读俄语"
    case .unavailable:
      statusMessage =
        language == .english
        ? "系统中没有英语语音，练习可继续"
        : "系统中没有俄语语音，练习可继续"
    case .emptyText:
      statusMessage = "本卡没有可朗读内容"
    }
  }

  private func trialContext(
    kind: TrialInteractionKind,
    grade: ReviewGrade? = nil,
    responseTimeMs: Int? = nil,
    isNewItem explicitIsNewItem: Bool? = nil,
    occurredAt: Date,
    recallOutcome: RecallOutcome? = nil,
    transferExerciseID: String? = nil,
    transferAnswerID: String? = nil,
    transferCorrect: Bool? = nil
  ) -> TrialInteractionContext {
    guard let item = currentItem else {
      preconditionFailure("Trial context requires a current practice item")
    }
    let beforeCount = max(0, queue.count - currentIndex)
    let consumesCurrentItem = kind == .grade || kind == .next
    let afterCount = max(
      0,
      beforeCount - (consumesCurrentItem ? 1 : 0)
    )
    let direction: TrialPromptDirection
    let promptLevel: TrialPromptLevel
    switch item.content {
    case .lexeme:
      direction =
        lexemeDirection == .recognition
        ? .recognition : .production
      promptLevel =
        lexemeDirection == .recognition
        ? .russian : .chinese
    case .sentence:
      direction = .sentenceProduction
      promptLevel = prompt == currentCard?.promptZh
        ? .chinese : .scene
    }
    return TrialInteractionContext(
      itemType: item.kind,
      itemID: item.id,
      direction: direction,
      promptLevel: promptLevel,
      grade: grade,
      responseTimeMs: responseTimeMs,
      usedSpeech: usedSpeechOnCurrentItem,
      openedDetails: openedDetailsOnCurrentItem,
      practiceMode: mode,
      occurredAt: occurredAt,
      queueCountBeforeAction: beforeCount,
      queueCountAfterAction: afterCount,
      queuePosition: currentIndex,
      remainingBacklogCount: initialBacklogIDs
        .subtracting(resolvedBacklogIDs).count,
      isNewItem: explicitIsNewItem
        ?? (states[item.identity] == nil && !item.isRetry),
      recallOutcome: recallOutcome,
      transferExerciseID: transferExerciseID,
      transferAnswerID: transferAnswerID,
      transferCorrect: transferCorrect
    )
  }

  private func makeTransferExercise() -> TransferExercise {
    let exerciseID = "transfer.\(currentItem?.id ?? "unknown")"
    let kind: TransferExerciseKind
    let promptText: String
    let correctText: String
    var distractors: [String] = []

    if let card = currentCard,
      let studySentence = studySentencesByID[card.id],
      let variant = studySentence.variants.first
    {
      kind = .slotReplacement
      promptText = "换一个信息来说：\(variant.promptZh)"
      correctText = variant.targetText
      distractors = studySentencesByID.values
        .flatMap(\.variants)
        .map(\.targetText)
    } else if let card = currentCard,
      let expectedReply = card.expectedReply,
      !expectedReply.isEmpty
    {
      kind = .nextReplySelection
      promptText = "对方说完这句，下一轮最自然怎么接？"
      correctText = expectedReply
      distractors = sentencesByID.values.compactMap(\.expectedReply)
    } else if let card = currentCard {
      kind = .slotReplacement
      promptText = "同类场景里，哪一句表达最自然？"
      correctText = card.practiceRu
      distractors = sentencesByID.values.map(\.practiceRu)
    } else if let lexeme = currentLexeme {
      kind = .collocationCompletion
      promptText = "哪个搭配最适合直接用于口语？"
      correctText = lexeme.collocations.first ?? lexeme.example
      distractors = lexemesByID.values.flatMap(\.collocations)
    } else {
      kind = .slotReplacement
      promptText = "请选择刚刚练习的自然表达"
      correctText = answer ?? ""
    }

    let fallbackDistractors =
      language == .english
      ? ["Could you give me a moment?", "I’m not sure yet."]
      : ["Мину́точку, пожа́луйста.", "Я пока́ не уве́рен."]
    let uniqueDistractors = (distractors + fallbackDistractors)
      .filter {
        $0.caseInsensitiveCompare(correctText) != .orderedSame
      }
      .reduce(into: [String]()) { result, candidate in
        guard !result.contains(where: {
          $0.caseInsensitiveCompare(candidate) == .orderedSame
        }) else { return }
        result.append(candidate)
      }

    var options = [
      TransferOption(id: "\(exerciseID).correct", text: correctText)
    ]
    options += uniqueDistractors.prefix(2).enumerated().map {
      TransferOption(
        id: "\(exerciseID).distractor.\($0.offset)",
        text: $0.element
      )
    }
    let rotation = exerciseID.unicodeScalars.reduce(0) {
      $0 + Int($1.value)
    } % options.count
    options = Array(options[rotation...] + options[..<rotation])

    return try! TransferExercise(
      id: exerciseID,
      kind: kind,
      prompt: promptText,
      options: options,
      correctOptionID: "\(exerciseID).correct"
    )
  }

  private static func recallRate(
    on date: Date,
    events: [ReviewEvent],
    calendar: Calendar
  ) -> Double? {
    let day = calendar.startOfDay(for: date)
    let daily = events.filter {
      calendar.startOfDay(for: $0.createdAt) == day
    }
    guard !daily.isEmpty else { return nil }
    return Double(daily.filter { $0.grade != .again }.count)
      / Double(daily.count)
  }

  private static func strongDayStreak(
    endingBefore date: Date,
    events: [ReviewEvent],
    calendar: Calendar
  ) -> Int {
    var count = 0
    var cursor = calendar.date(
      byAdding: .day,
      value: -1,
      to: date
    )!
    while let rate = recallRate(
      on: cursor,
      events: events,
      calendar: calendar
    ), rate > 0.90 {
      count += 1
      guard let previous = calendar.date(
        byAdding: .day,
        value: -1,
        to: cursor
      ) else { break }
      cursor = previous
    }
    return count
  }

  private static func dailyOrder<Item: Identifiable>(
    _ items: [Item],
    dayIndex: Int,
    salt: Int
  ) -> [Item] where Item.ID == String {
    let sorted = items.sorted { $0.id < $1.id }
    guard sorted.count > 1 else { return sorted }
    let offset = positiveModulo(dayIndex + salt, sorted.count)
    return Array(sorted[offset...] + sorted[..<offset])
  }

  private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
    let remainder = value % divisor
    return remainder >= 0 ? remainder : remainder + divisor
  }

  private static func localizedPartOfSpeech(_ value: String) -> String {
    switch value {
    case "noun": "名词"
    case "verb": "动词"
    case "adjective": "形容词"
    case "adverb": "副词"
    case "preposition": "介词"
    case "pronoun": "代词"
    case "conjunction": "连词"
    case "particle": "语气词"
    case "numeral": "数词"
    default: value
    }
  }

  private static func localizedGender(_ value: String) -> String {
    switch value {
    case "masculine": "阳性"
    case "feminine": "阴性"
    case "neuter": "中性"
    case "plural": "复数"
    default: value
    }
  }

  private static func localizedAspect(_ value: String) -> String {
    switch value {
    case "perfective": "完成体"
    case "imperfective": "未完成体"
    case "biaspectual": "双体"
    default: value
    }
  }
}
