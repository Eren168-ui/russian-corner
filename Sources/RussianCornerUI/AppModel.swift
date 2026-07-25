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
  }

  private let defaults: UserDefaults
  private var isLoading = true

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
    didSet { persist(mode.rawValue, forKey: Key.mode) }
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

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
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
    opacity = min(max(opacity, 0.55), 1)
    fontScale = min(max(fontScale, 0.85), 1.35)
    isLoading = false
  }

  public func toggleCard() {
    isCardVisible.toggle()
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

  public init(
    completedToday: Int = 0,
    streakDays: Int = 0,
    accuracy: Double = 0,
    masteredCount: Int = 0
  ) {
    self.completedToday = completedToday
    self.streakDays = streakDays
    self.accuracy = accuracy
    self.masteredCount = masteredCount
  }
}

@MainActor
@Observable
public final class AppRuntime {
  public let appModel: AppModel
  public private(set) var practice: PracticeViewModel?
  public private(set) var progress = LearningProgressSnapshot()
  public private(set) var launchError: String?

  private var catalog: ContentCatalog?
  private var repository: ProgressRepository?
  private let reminderService: ReminderService?

  public init(defaults: UserDefaults = .standard) {
    appModel = AppModel(defaults: defaults)
    reminderService =
      Bundle.main.bundleIdentifier == nil
      ? nil : ReminderService()
    do {
      let catalog = try ContentCatalog()
      let repository = ProgressRepository(
        container: try ProgressRepository.makeContainer()
      )
      self.catalog = catalog
      self.repository = repository
      let persistedSettings = try repository.settings()
      appModel.morningReminder = persistedSettings.morningReminder
      appModel.eveningReminder = persistedSettings.eveningReminder
      try reloadPractice()
      try refreshProgress()
    } catch {
      launchError = "学习数据暂时无法载入：\(error.localizedDescription)"
    }
  }

  public func reloadPractice() throws {
    guard let catalog, let repository else { return }
    practice = try PracticeViewModel(
      catalog: catalog,
      repository: repository,
      targetCount: appModel.dailyCardCount,
      mode: appModel.mode
    )
  }

  public func saveReminderSettings() async {
    guard let repository else { return }
    let settings = RussianCornerSettings(
      morningReminder: appModel.morningReminder,
      eveningReminder: appModel.eveningReminder
    )
    do {
      try repository.save(settings: settings)
      guard let reminderService else {
        appModel.transientStatus =
          "提醒时间已保存；应用打包后可启用系统通知"
        return
      }
      if await reminderService.permissionStatus() == .undetermined {
        _ = await reminderService.requestPermission()
      }
      let result = await reminderService.schedule(settings: settings)
      switch result {
      case .scheduled:
        appModel.transientStatus = "提醒时间已保存"
      case .permissionDenied:
        appModel.transientStatus = "通知权限未开启，时间已保存"
      case .permissionUndetermined:
        appModel.transientStatus = "提醒时间已保存，可在系统设置中开启通知"
      case .unavailable:
        appModel.transientStatus = "当前系统不支持提醒，时间已保存"
      case .failed(let message):
        appModel.transientStatus = "提醒暂未更新：\(message)"
      }
    } catch {
      appModel.transientStatus = "设置保存失败：\(error.localizedDescription)"
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
    for sentence in catalog.sentences {
      if try repository.progress(
        itemType: .sentence,
        itemId: sentence.id
      )?.masteryLevel ?? 0 >= 3 {
        mastered += 1
      }
    }
    progress = LearningProgressSnapshot(
      completedToday: todayEvents.count,
      streakDays: streak,
      accuracy: accuracy,
      masteredCount: mastered
    )
  }
}
