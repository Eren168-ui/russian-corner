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

  public var errorDescription: String? {
    switch self {
    case .answerNotRevealed:
      return "请先显示答案，再提交评分"
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

public struct PracticeQueueEntry: Identifiable, Equatable, Sendable {
  public let content: PracticeContent
  public let isRetry: Bool

  public init(content: PracticeContent, isRetry: Bool = false) {
    self.content = content
    self.isRetry = isRetry
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
  public let targetCount: Int
  public let newWordLimit: Int
  public let remainingNewWordCount: Int
  public let remainingSentenceCardCount: Int
  public let isWeeklyReviewDay: Bool
  public var mode: PracticeMode

  private let repository: any PracticeProgressStoring
  private let scheduler: ReviewScheduler
  private let speechService: SpeechService
  private let recordingService: any RecordingManaging
  private let playbackService: any RecordingPlaying
  private let recordingsDirectory: URL
  private let now: () -> Date
  private let calendar: Calendar
  private let sentencesByID: [String: SentenceCard]
  private var states: [PracticeItemIdentity: ReviewState]
  private var successfulToday: Set<PracticeItemIdentity>
  private var recallStartedAt: Date

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

  public var currentLexeme: Lexeme? {
    guard case .lexeme(let lexeme) = currentContent else {
      return nil
    }
    return lexeme
  }

  public var currentContextSentence: SentenceCard? {
    guard let lexeme = currentLexeme else { return nil }
    return lexeme.sentenceIDs.lazy.compactMap {
      self.sentencesByID[$0]
    }.first
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
      return lexeme.glossZh
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
      lexeme.stressedForm
    case .sentence(let sentence):
      sentence.practiceRu
    case nil:
      nil
    }
  }

  public init(
    catalog: ContentCatalog,
    repository: any PracticeProgressStoring,
    targetCount: Int = 7,
    mode: PracticeMode = .quiet,
    now: @escaping () -> Date = Date.init,
    calendar: Calendar = .current,
    diagnosticFindings: [DiagnosticFindingType] = [],
    scheduler: ReviewScheduler = ReviewScheduler(),
    speechService: SpeechService = SpeechService(),
    recordingService: any RecordingManaging = RecordingService(),
    playbackService: any RecordingPlaying = RecordingPlaybackService(),
    recordingsDirectory: URL? = nil
  ) throws {
    self.repository = repository
    let sentenceTargetCount = min(max(targetCount, 5), 10)
    self.targetCount = sentenceTargetCount
    self.mode = mode
    self.now = now
    self.calendar = calendar
    self.scheduler = scheduler
    self.speechService = speechService
    self.recordingService = recordingService
    self.playbackService = playbackService
    self.recordingsDirectory =
      recordingsDirectory ?? Self.defaultRecordingsDirectory
    let instant = now()
    recallStartedAt = instant
    sentencesByID = Dictionary(
      uniqueKeysWithValues: catalog.sentences.map { ($0.id, $0) }
    )

    let events = try repository.reviewEvents()
    let todayStart = calendar.startOfDay(for: instant)
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
    for lexeme in catalog.lexemes
    where lexeme.reviewStatus != .draft {
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
    for sentence in catalog.sentences
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
    let adaptiveNewWordLimit =
      diagnosticCapsNewWords
      ? min(scheduledNewWordLimit, 6)
      : scheduledNewWordLimit

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

    let dayIndex = Int(
      floor(todayStart.timeIntervalSince1970 / 86_400)
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

    var lexemeEntries: [PracticeQueueEntry] = orderedRetryIdentities
      .filter { $0.kind == .lexeme }
      .compactMap { identity in
        catalog.lexemes.first { $0.id == identity.id }
      }
      .map { PracticeQueueEntry(content: .lexeme($0), isRetry: true) }
    if weeklyReviewDay && hasLearnedContent {
      lexemeEntries += orderedLearnedLexemes
        .prefix(max(adaptiveNewWordLimit, retryToday.isEmpty ? 1 : 0))
        .map { PracticeQueueEntry(content: .lexeme($0)) }
    } else {
      lexemeEntries += orderedDueLexemes.prefix(20).map {
        PracticeQueueEntry(content: .lexeme($0))
      }
      lexemeEntries += orderedFreshLexemes
        .prefix(newWordsRemaining)
        .map { PracticeQueueEntry(content: .lexeme($0)) }
    }

    let sentenceExcluded = successfulTodaySet.union(retryToday)
    let sentenceCandidates =
      Self.dailyOrder(
        dueSentences.filter {
          !sentenceExcluded.contains(
            PracticeItemIdentity(kind: .sentence, id: $0.id)
          )
        },
        dayIndex: dayIndex,
        salt: 23
      )
      + Self.dailyOrder(
        freshSentences.filter {
          !sentenceExcluded.contains(
            PracticeItemIdentity(kind: .sentence, id: $0.id)
          )
        },
        dayIndex: dayIndex,
        salt: 29
      )
      + Self.dailyOrder(
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
        },
        dayIndex: dayIndex,
        salt: 31
      )
    var sentenceEntries: [PracticeQueueEntry] = orderedRetryIdentities
      .filter { $0.kind == .sentence }
      .compactMap { identity in
        catalog.sentences.first { $0.id == identity.id }
      }
      .map { PracticeQueueEntry(content: .sentence($0), isRetry: true) }
    var seenSentenceIDs = Set(sentenceEntries.map(\.id))
    for sentence in sentenceCandidates
    where sentenceEntries.count
      < orderedRetryIdentities.filter({ $0.kind == .sentence }).count
        + sentenceCardsRemaining
      && seenSentenceIDs.insert(sentence.id).inserted
    {
      sentenceEntries.append(
        PracticeQueueEntry(content: .sentence(sentence))
      )
    }
    isWeeklyReviewDay = weeklyReviewDay
    newWordLimit = adaptiveNewWordLimit
    remainingNewWordCount = newWordsRemaining
    remainingSentenceCardCount = sentenceCardsRemaining
    successfulToday = successfulTodaySet
    completedToday = successfulTodaySet.count
    queue = lexemeEntries + sentenceEntries
  }

  public func reveal() {
    isRevealed = true
    refreshRecallTimer()
  }

  public func refreshRecallTimer() {
    let elapsed = max(0, now().timeIntervalSince(recallStartedAt))
    remainingRecallSeconds = max(0, Int(ceil(3 - elapsed)))
  }

  public func grade(_ grade: ReviewGrade) throws {
    guard isRevealed else {
      throw PracticeViewModelError.answerNotRevealed
    }
    guard let item = currentItem else { return }
    let instant = now()
    let elapsed = max(0, instant.timeIntervalSince(recallStartedAt))
    let event = ReviewEvent(
      itemType: item.kind,
      itemId: item.id,
      grade: grade,
      responseTimeMs: Int((elapsed * 1_000).rounded()),
      practiceMode: mode,
      createdAt: instant
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
    let cleanupMessage = cleanupRecordingForTransition()
    states[item.identity] = newState
    successfulToday = newSuccessfulToday
    completedToday = newCompletedCount
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
    advance(status: cleanupMessage)
  }

  public func next() {
    let cleanupMessage = cleanupRecordingForTransition()
    advance(status: cleanupMessage)
  }

  private func advance(status: String?) {
    guard currentItem != nil else { return }
    speechService.stop()
    currentIndex += 1
    isRevealed = false
    remainingRecallSeconds = 3
    recallStartedAt = now()
    statusMessage = status
  }

  public func showStatus(_ message: String) {
    statusMessage = message
  }

  public func handleDisappear() {
    speechService.stop()
    if let cleanupMessage = cleanupRecordingForTransition() {
      statusMessage = cleanupMessage
    }
  }

  public var isRecording: Bool {
    recordingService.isRecording
  }

  public var hasRecording: Bool {
    recordingService.temporaryRecordingURL != nil
  }

  public var isPlayingRecording: Bool {
    playbackService.isPlaying
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
    switch speechService.speak(text) {
    case .russianVoice:
      statusMessage = "正在朗读俄语"
    case .fallbackVoice(_, let language):
      statusMessage = "未找到俄语语音，使用 \(language) 朗读"
    case .unavailable:
      statusMessage = "系统中没有可用语音，练习可继续"
    case .emptyText:
      statusMessage = "本卡没有可朗读内容"
    }
  }

  public func toggleRecording() async {
    if recordingService.isRecording {
      recordingService.stop()
      statusMessage = "录音已停止，可播放、保存或丢弃"
      return
    }
    var result = await recordingService.start()
    if result == .permissionUndetermined {
      let permission = await recordingService.requestPermission()
      if permission == .granted {
        result = await recordingService.start()
      }
    }
    switch result {
    case .started:
      statusMessage = "正在录音"
    case .permissionDenied:
      statusMessage = "麦克风权限未开启，仍可继续练习"
    case .permissionUndetermined:
      statusMessage = "尚未取得麦克风权限，仍可继续练习"
    case .unavailable:
      statusMessage = "当前设备无法录音，仍可继续练习"
    case .failed(let message):
      statusMessage = "录音未开始：\(message)"
    }
  }

  public func playRecording() {
    guard let url = recordingService.temporaryRecordingURL else {
      statusMessage = "没有可播放的录音"
      return
    }
    if recordingService.isRecording {
      recordingService.stop()
    }
    switch playbackService.play(url: url) {
    case .playing:
      statusMessage = "正在播放录音"
    case .failed(let message):
      statusMessage = "录音播放失败：\(message)"
    }
  }

  @discardableResult
  public func saveRecording() throws -> URL {
    guard recordingService.temporaryRecordingURL != nil else {
      throw RecordingServiceError.noTemporaryRecording
    }
    if recordingService.isRecording {
      recordingService.stop()
    }
    playbackService.stop()
    try FileManager.default.createDirectory(
      at: recordingsDirectory,
      withIntermediateDirectories: true
    )
    let destination =
      recordingsDirectory
      .appendingPathComponent(
        "recording-\(UUID().uuidString)",
        isDirectory: false
      )
      .appendingPathExtension("m4a")
    let outcome = try recordingService.save(to: destination)
    switch outcome {
    case .saved(_, let cleanupPending):
      statusMessage =
        cleanupPending
        ? "录音已保存，临时文件稍后清理"
        : "录音已保存"
    }
    return destination
  }

  public func discardRecording() {
    playbackService.stop()
    if recordingService.isRecording {
      recordingService.stop()
    }
    do {
      try recordingService.discard()
      statusMessage = "录音已丢弃"
    } catch {
      statusMessage = "录音暂未清理：\(error.localizedDescription)"
    }
  }

  private func cleanupRecordingForTransition() -> String? {
    playbackService.stop()
    guard
      recordingService.isRecording
        || recordingService.temporaryRecordingURL != nil
    else {
      return nil
    }
    if recordingService.isRecording {
      recordingService.stop()
    }
    do {
      try recordingService.discard()
      return nil
    } catch {
      return "切换已继续，录音暂未清理：\(error.localizedDescription)"
    }
  }

  private static var defaultRecordingsDirectory: URL {
    let base =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    return
      base
      .appendingPathComponent("RussianCorner", isDirectory: true)
      .appendingPathComponent("Recordings", isDirectory: true)
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
