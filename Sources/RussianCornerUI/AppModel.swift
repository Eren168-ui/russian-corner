import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

public enum FloatingCorner: String, CaseIterable, Codable, Sendable {
  case topLeft
  case topRight
  case bottomLeft
  case bottomRight

  public var title: String {
    switch self {
    case .topLeft: "左上角"
    case .topRight: "右上角"
    case .bottomLeft: "左下角"
    case .bottomRight: "右下角"
    }
  }

  public var symbolName: String {
    switch self {
    case .topLeft: "arrow.up.left"
    case .topRight: "arrow.up.right"
    case .bottomLeft: "arrow.down.left"
    case .bottomRight: "arrow.down.right"
    }
  }
}

@MainActor
@Observable
public final class AppModel {
  private enum Key {
    static let corner = "floating.corner"
    static let opacity = "floating.opacity"
    static let fontScale = "floating.fontScale"
    static let dailyCardCount = "practice.dailyCardCount"
    static let mode = "practice.mode"
    static let collapsed = "floating.collapsed"
    static let preferredScreenIdentifier =
      "floating.preferredScreenIdentifier"
    static let morningHour = "reminder.morning.hour"
    static let morningMinute = "reminder.morning.minute"
    static let eveningHour = "reminder.evening.hour"
    static let eveningMinute = "reminder.evening.minute"
    static let preferredTopicID = "practice.preferredTopicID"
    static let preferredTopicDay = "practice.preferredTopicDay"
  }

  private let defaults: UserDefaults
  private var isLoading = true
  public private(set) var hasExplicitModePreference = false

  public var isCardVisible = true
  public var isCollapsed: Bool {
    didSet { persist(isCollapsed, forKey: Key.collapsed) }
  }
  public var corner: FloatingCorner {
    didSet { persist(corner.rawValue, forKey: Key.corner) }
  }
  public var preferredScreenIdentifier: String? {
    didSet {
      guard !isLoading else { return }
      if let preferredScreenIdentifier {
        defaults.set(
          preferredScreenIdentifier,
          forKey: Key.preferredScreenIdentifier
        )
      } else {
        defaults.removeObject(
          forKey: Key.preferredScreenIdentifier
        )
      }
    }
  }
  public var opacity: Double {
    didSet {
      let clamped = min(max(opacity, 0.55), 1)
      if opacity != clamped {
        opacity = clamped
        return
      }
      persist(opacity, forKey: Key.opacity)
    }
  }
  public var fontScale: Double {
    didSet {
      let clamped = min(max(fontScale, 0.85), 1.35)
      if fontScale != clamped {
        fontScale = clamped
        return
      }
      persist(fontScale, forKey: Key.fontScale)
    }
  }
  public var dailyCardCount: Int {
    didSet {
      let clamped = min(max(dailyCardCount, 5), 10)
      if dailyCardCount != clamped {
        dailyCardCount = clamped
        return
      }
      persist(dailyCardCount, forKey: Key.dailyCardCount)
    }
  }
  public var mode: PracticeMode {
    didSet {
      guard !isLoading else { return }
      hasExplicitModePreference = true
      persist(mode.rawValue, forKey: Key.mode)
    }
  }
  public var morningReminder: ReminderTime {
    didSet {
      persist(morningReminder.hour, forKey: Key.morningHour)
      persist(morningReminder.minute, forKey: Key.morningMinute)
    }
  }
  public var eveningReminder: ReminderTime {
    didSet {
      persist(eveningReminder.hour, forKey: Key.eveningHour)
      persist(eveningReminder.minute, forKey: Key.eveningMinute)
    }
  }
  public var transientStatus: String?
  public private(set) var preferredTopicID: String?
  public private(set) var preferredTopicDay: Date?

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    hasExplicitModePreference =
      defaults.object(forKey: Key.mode) != nil
    corner =
      FloatingCorner(
        rawValue: defaults.string(forKey: Key.corner) ?? ""
      ) ?? .topRight
    preferredScreenIdentifier = defaults.string(
      forKey: Key.preferredScreenIdentifier
    )
    opacity =
      defaults.object(forKey: Key.opacity) == nil
      ? 0.96 : defaults.double(forKey: Key.opacity)
    fontScale =
      defaults.object(forKey: Key.fontScale) == nil
      ? 1 : defaults.double(forKey: Key.fontScale)
    let storedCount = defaults.integer(forKey: Key.dailyCardCount)
    dailyCardCount =
      storedCount == 0
      ? 7 : min(max(storedCount, 5), 10)
    mode =
      PracticeMode(
        rawValue: defaults.string(forKey: Key.mode) ?? ""
      ) ?? .quiet
    morningReminder = ReminderTime(
      hour: defaults.object(forKey: Key.morningHour) == nil
        ? 11 : defaults.integer(forKey: Key.morningHour),
      minute: defaults.object(forKey: Key.morningMinute) == nil
        ? 30 : defaults.integer(forKey: Key.morningMinute)
    )
    eveningReminder = ReminderTime(
      hour: defaults.object(forKey: Key.eveningHour) == nil
        ? 17 : defaults.integer(forKey: Key.eveningHour),
      minute: defaults.object(forKey: Key.eveningMinute) == nil
        ? 30 : defaults.integer(forKey: Key.eveningMinute)
    )
    isCollapsed = defaults.bool(forKey: Key.collapsed)
    preferredTopicID = defaults.string(forKey: Key.preferredTopicID)
    preferredTopicDay = defaults.object(
      forKey: Key.preferredTopicDay
    ) as? Date
    opacity = min(max(opacity, 0.55), 1)
    fontScale = min(max(fontScale, 0.85), 1.35)
    isLoading = false
  }

  public func toggleCard() {
    isCardVisible.toggle()
  }

  public func applyDiagnosticDefaultMode(_ proposed: PracticeMode) {
    guard !hasExplicitModePreference else { return }
    isLoading = true
    mode = proposed
    isLoading = false
  }

  public func preferredTopic(
    on date: Date,
    calendar: Calendar = .current
  ) -> String? {
    guard let preferredTopicID, let preferredTopicDay,
      calendar.isDate(preferredTopicDay, inSameDayAs: date)
    else {
      return nil
    }
    return preferredTopicID
  }

  public func setPreferredTopic(
    _ topicID: String?,
    on date: Date = Date()
  ) {
    preferredTopicID = topicID
    preferredTopicDay = topicID == nil ? nil : date
    if let topicID {
      defaults.set(topicID, forKey: Key.preferredTopicID)
      defaults.set(date, forKey: Key.preferredTopicDay)
    } else {
      defaults.removeObject(forKey: Key.preferredTopicID)
      defaults.removeObject(forKey: Key.preferredTopicDay)
    }
  }

  private func persist(_ value: Any, forKey key: String) {
    guard !isLoading else { return }
    defaults.set(value, forKey: key)
  }
}

public struct LearningProgressSnapshot: Equatable, Sendable {
  public var completedToday: Int
  public var streakDays: Int
  public var accuracy: Double
  public var masteredCount: Int
  public var coveredTopicCount: Int
  public var totalTopicCount: Int

  public init(
    completedToday: Int = 0,
    streakDays: Int = 0,
    accuracy: Double = 0,
    masteredCount: Int = 0,
    coveredTopicCount: Int = 0,
    totalTopicCount: Int = 0
  ) {
    self.completedToday = completedToday
    self.streakDays = streakDays
    self.accuracy = accuracy
    self.masteredCount = masteredCount
    self.coveredTopicCount = coveredTopicCount
    self.totalTopicCount = totalTopicCount
  }
}

@MainActor
@Observable
public final class AppRuntime {
  public let appModel: AppModel
  public private(set) var practice: PracticeViewModel?
  public private(set) var diagnostics: DiagnosticViewModel?
  public private(set) var dailyReflection: DailyReflectionViewModel?
  public private(set) var trialRepository:
    (any TrialDataStoring)?
  public private(set) var progress = LearningProgressSnapshot()
  public private(set) var launchError: String?
  public private(set) var diagnosticError: String?
  public private(set) var trialError: String?
  public private(set) var diagnosticHistoryIssueCount = 0
  public private(set) var sourceSyncResult: SourceSyncResult?
  public private(set) var pendingCandidateCount = 0
  public private(set) var lastSourceSyncAt: Date?

  private var catalog: ContentCatalog?
  private var repository: ProgressRepository?
  private var candidateCorpusStore: CandidateCorpusStore?
  private let sourceCorpusScanner = SourceCorpusScanner()
  private let enableSourceSync: Bool
  private var trialSessionCoordinator: TrialSessionCoordinator?
  private let reminderScheduler: (any ReminderSettingsScheduling)?
  private var reminderSettingsCoordinator: ReminderSettingsCoordinator?
  private let onlineDictionary: any OnlineDictionaryLookingUp =
    YandexDictionaryService()

  public init(
    defaults: UserDefaults = .standard,
    catalog injectedCatalog: ContentCatalog? = nil,
    repository injectedRepository: ProgressRepository? = nil,
    trialRepository injectedTrialRepository:
      (any TrialDataStoring)? = nil,
    trialRepositoryFactory injectedTrialRepositoryFactory:
      (() throws -> any TrialDataStoring)? = nil,
    reminderScheduler injectedReminderScheduler:
      (any ReminderSettingsScheduling)? = nil,
    enableSystemReminders: Bool = true,
    candidateCorpusStore injectedCandidateCorpusStore:
      CandidateCorpusStore? = nil,
    enableSourceSync: Bool = false
  ) {
    appModel = AppModel(defaults: defaults)
    self.enableSourceSync = enableSourceSync
    if let injectedCandidateCorpusStore {
      candidateCorpusStore = injectedCandidateCorpusStore
    } else if enableSourceSync,
      let fileURL = try? CandidateCorpusStore.defaultFileURL()
    {
      candidateCorpusStore = CandidateCorpusStore(fileURL: fileURL)
    }
    if let injectedReminderScheduler {
      reminderScheduler = injectedReminderScheduler
    } else {
      reminderScheduler =
        !enableSystemReminders || Bundle.main.bundleIdentifier == nil
        ? nil : ReminderService()
    }
    do {
      let catalog: ContentCatalog
      if let injectedCatalog {
        catalog = injectedCatalog
      } else {
        catalog = try ContentCatalog()
      }
      let repository: ProgressRepository
      if let injectedRepository {
        repository = injectedRepository
      } else {
        repository = ProgressRepository(
          container: try ProgressRepository.makeContainer()
        )
      }
      self.catalog = catalog
      self.repository = repository
      reminderSettingsCoordinator = ReminderSettingsCoordinator(
        store: repository,
        scheduler: reminderScheduler
      )
      let persistedSettings = try repository.settings()
      appModel.morningReminder = persistedSettings.morningReminder
      appModel.eveningReminder = persistedSettings.eveningReminder

      do {
        let trialRepository: any TrialDataStoring
        if let injectedTrialRepository {
          trialRepository = injectedTrialRepository
        } else if let injectedTrialRepositoryFactory {
          trialRepository = try injectedTrialRepositoryFactory()
        } else {
          trialRepository = TrialRepository(
            container: try TrialRepository.makeContainer(
              inMemory: injectedRepository != nil
            )
          )
        }
        self.trialRepository = trialRepository
        let statusModel = appModel
        trialSessionCoordinator = TrialSessionCoordinator(
          repository: trialRepository,
          onIssue: { [weak statusModel] message in
            statusModel?.transientStatus = message
          }
        )
        let reflection = DailyReflectionViewModel(
          repository: trialRepository
        )
        _ = reflection.loadToday()
        dailyReflection = reflection
      } catch {
        trialError =
          "学习统计暂时不可用，学习功能不受影响：\(error.localizedDescription)"
        appModel.transientStatus = trialError
      }

      try reloadPractice()
      try refreshProgress()
      if enableSourceSync {
        syncSourceCorpus()
      }
    } catch {
      launchError = "学习数据暂时无法载入：\(error.localizedDescription)"
      return
    }

    do {
      guard let catalog, let repository else { return }
      diagnostics = try DiagnosticViewModel(
        catalog: catalog,
        repository: repository,
        oralAttemptStore: trialRepository,
        onReportSaved: { [weak self] in
          self?.applyLatestDiagnosticStrategy()
        }
      )
      diagnosticHistoryIssueCount = diagnostics?.historyIssueCount ?? 0
    } catch {
      diagnosticError = "诊断数据暂时无法载入：\(error.localizedDescription)"
    }
  }

  public func reloadPractice(
    now: @escaping () -> Date = Date.init
  ) throws {
    guard let catalog, let repository else { return }
    let latestValidReport = try repository
      .diagnosticHistory()
      .entries
      .reversed()
      .first { $0.report.current.isValid }?
      .report
    let findings = latestValidReport?.findings.map(\.type) ?? []
    let prefersSpeaking = findings.contains {
      $0 == .listeningGap || $0 == .selfMonitoring
    }
    appModel.applyDiagnosticDefaultMode(
      prefersSpeaking ? .speaking : .quiet
    )
    let nextPractice = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: appModel.dailyCardCount,
      mode: appModel.mode,
      preferredTopicID: appModel.preferredTopic(on: now()),
      now: now,
      diagnosticFindings: findings,
      trialTracker: trialSessionCoordinator,
      onlineDictionary: onlineDictionary
    )
    practice?.handleDisappear()
    practice = nextPractice
  }

  public func refreshPracticeForTemporalBoundary(
    now instant: Date = Date()
  ) {
    guard practice?.needsTemporalReload(at: instant) == true else {
      return
    }
    do {
      trialSessionCoordinator?.close(reason: .dayChanged)
      if enableSourceSync {
        syncSourceCorpus(now: instant)
      }
      try reloadPractice(now: { instant })
      try refreshProgress(now: instant)
      _ = dailyReflection?.loadToday()
    } catch {
      appModel.transientStatus =
        "跨时段队列刷新失败：\(error.localizedDescription)"
    }
  }

  public var topics: [TopicDefinition] {
    catalog?.topics.sorted { $0.number < $1.number } ?? []
  }

  public var selectedTopic: TopicDefinition? {
    guard let topicID = practice?.selectedTopicID else { return nil }
    return topics.first { $0.id == topicID }
  }

  public func selectTopicForToday(
    _ topicID: String?,
    now: Date = Date()
  ) {
    guard topicID == nil || topics.contains(where: { $0.id == topicID })
    else { return }
    appModel.setPreferredTopic(topicID, on: now)
    do {
      try reloadPractice(now: { now })
      appModel.transientStatus =
        topicID == nil ? "今天已恢复自动选题" : "今天的话题已切换"
    } catch {
      appModel.transientStatus =
        "话题切换失败：\(error.localizedDescription)"
    }
  }

  public func syncSourceCorpus(now: Date = Date()) {
    guard enableSourceSync, let catalog, let candidateCorpusStore,
      !catalog.longTermManifest.sourceRoot.isEmpty
    else { return }
    do {
      let previous = try candidateCorpusStore.load()
      let output = sourceCorpusScanner.scan(
        sourceRoot: URL(
          fileURLWithPath: catalog.longTermManifest.sourceRoot,
          isDirectory: true
        ),
        topics: catalog.topics,
        previousSnapshots: previous.snapshots
      )
      sourceSyncResult = output.result
      switch output.result {
      case .unavailableUsingBundledCorpus:
        pendingCandidateCount = previous.candidates.count
        lastSourceSyncAt = previous.lastSyncedAt
      case .unchanged:
        pendingCandidateCount = previous.candidates.count
        lastSourceSyncAt = previous.lastSyncedAt
      case .updated:
        let previousHashes = Dictionary(
          uniqueKeysWithValues: previous.snapshots.map {
            ($0.relativePath, $0.sha256)
          }
        )
        let changedPaths = Set(
          output.snapshots.compactMap {
            previousHashes[$0.relativePath] == $0.sha256
              ? nil : $0.relativePath
          }
        )
        let merged = previous.candidates.filter {
          !changedPaths.contains($0.sourcePath)
        } + output.candidates
        let state = CandidateCorpusState(
          snapshots: output.snapshots,
          candidates: merged,
          lastSyncedAt: now
        )
        try candidateCorpusStore.save(state)
        pendingCandidateCount = merged.count
        lastSourceSyncAt = now
      }
    } catch {
      sourceSyncResult = .unavailableUsingBundledCorpus(
        error.localizedDescription
      )
    }
  }

  public func closeTrialSession(
    reason: TrialSessionEndReason
  ) {
    trialSessionCoordinator?.close(reason: reason)
  }

  private func applyLatestDiagnosticStrategy() {
    do {
      try reloadPractice()
      try refreshProgress()
      diagnosticHistoryIssueCount =
        try repository?.diagnosticHistory().issueCount ?? 0
      diagnosticError = nil
    } catch {
      diagnosticError =
        "诊断已保存，但训练策略暂时无法刷新：\(error.localizedDescription)"
    }
  }

  @discardableResult
  public func reconcileRemindersOnLaunch() async
    -> ReminderScheduleResult?
  {
    guard launchError == nil, let reminderScheduler else {
      return nil
    }
    let settings = RussianCornerSettings(
      morningReminder: appModel.morningReminder,
      eveningReminder: appModel.eveningReminder
    )
    let result = await reminderScheduler.reconcile(
      settings: settings,
      requestAuthorizationIfNeeded: true
    )
    switch result {
    case .scheduled:
      break
    case .permissionDenied:
      appModel.transientStatus =
        "通知权限未开启；学习功能仍可正常使用"
    case .permissionUndetermined:
      appModel.transientStatus =
        "尚未取得通知权限；学习功能仍可正常使用"
    case .unavailable:
      appModel.transientStatus =
        "当前系统无法提供通知；学习功能仍可正常使用"
    case .failed(let message):
      appModel.transientStatus =
        "提醒暂时无法同步：\(message)"
    }
    return result
  }

  @discardableResult
  public func saveReminderSettings(
    _ proposed: RussianCornerSettings
  ) async -> Bool {
    guard let reminderSettingsCoordinator else {
      appModel.transientStatus = "提醒设置暂时无法保存"
      return false
    }
    let result = await reminderSettingsCoordinator.apply(
      proposed: proposed,
      to: appModel
    )
    switch result {
    case .applied:
      appModel.transientStatus = "提醒时间已更新"
      return true
    case .appliedLocally:
      appModel.transientStatus =
        "提醒时间已保存；当前运行方式不支持系统通知"
      return true
    case .scheduleFailed(let message):
      appModel.transientStatus =
        "提醒未更新，原设置保持不变：\(message)"
      return false
    case .databaseFailed(let message, let rollbackSucceeded):
      appModel.transientStatus =
        rollbackSucceeded
        ? "提醒保存失败，系统时间已恢复：\(message)"
        : "提醒保存失败，系统回滚也未完成：\(message)"
      return false
    case .localDatabaseFailed(let message):
      appModel.transientStatus = "提醒保存失败：\(message)"
      return false
    }
  }

  public func refreshProgress(
    now: Date = Date(),
    calendar: Calendar = .current
  ) throws {
    guard let repository, let catalog else { return }
    let events = try repository.reviewEvents()
    let today = calendar.startOfDay(for: now)
    let todayEvents = events.filter {
      calendar.startOfDay(for: $0.createdAt) == today
    }
    let correct = todayEvents.filter { $0.grade != .again }.count
    let completedItems = Set(
      todayEvents.compactMap { event in
        event.grade == .again
          ? nil
          : PracticeItemIdentity(
            kind: event.itemType,
            id: event.itemId
          )
      }
    )
    let accuracy =
      todayEvents.isEmpty
      ? 0 : Double(correct) / Double(todayEvents.count)
    let activeDays = Set(
      events.map {
        calendar.startOfDay(for: $0.createdAt)
      })
    var streak = 0
    var cursor = today
    while activeDays.contains(cursor) {
      streak += 1
      guard
        let previous = calendar.date(
          byAdding: .day,
          value: -1,
          to: cursor
        )
      else { break }
      cursor = previous
    }
    var mastered = 0
    for lexeme in catalog.practiceLexemes {
      if try repository.progress(
        itemType: .lexeme,
        itemId: lexeme.id
      )?.masteryLevel ?? 0 >= 3 {
        mastered += 1
      }
    }
    for sentence in catalog.practiceSentences {
      if try repository.progress(
        itemType: .sentence,
        itemId: sentence.id
      )?.masteryLevel ?? 0 >= 3 {
        mastered += 1
      }
    }
    progress = LearningProgressSnapshot(
      completedToday: completedItems.count,
      streakDays: streak,
      accuracy: accuracy,
      masteredCount: mastered,
      coveredTopicCount: Set<String>(
        events.compactMap { event in
          guard event.itemType == .sentence else { return nil }
          return catalog.practiceSentences.first {
            $0.id == event.itemId
          }?.topicID
        }
      ).count,
      totalTopicCount: catalog.topics.count
    )
  }
}
