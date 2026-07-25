import Foundation
import RussianCornerCore
import RussianCornerPlatform

@MainActor
public protocol ReminderSettingsPersisting: AnyObject {
  func save(settings: RussianCornerSettings) throws
}

public protocol ReminderSettingsScheduling: Sendable {
  func schedule(
    settings: RussianCornerSettings
  ) async -> ReminderScheduleResult
}

public enum ReminderSettingsUpdateResult: Equatable, Sendable {
  case applied
  case appliedLocally
  case scheduleFailed(String)
  case databaseFailed(String, rollbackSucceeded: Bool)
  case localDatabaseFailed(String)
}

extension ProgressRepository: ReminderSettingsPersisting {}
extension ReminderService: ReminderSettingsScheduling {}

@MainActor
public final class ReminderSettingsCoordinator {
  private let store: any ReminderSettingsPersisting
  private let scheduler: (any ReminderSettingsScheduling)?

  public init(
    store: any ReminderSettingsPersisting,
    scheduler: (any ReminderSettingsScheduling)?
  ) {
    self.store = store
    self.scheduler = scheduler
  }

  public func apply(
    proposed: RussianCornerSettings,
    to appModel: AppModel
  ) async -> ReminderSettingsUpdateResult {
    let oldSettings = RussianCornerSettings(
      morningReminder: appModel.morningReminder,
      eveningReminder: appModel.eveningReminder
    )
    guard let scheduler else {
      do {
        try store.save(settings: proposed)
        appModel.morningReminder = proposed.morningReminder
        appModel.eveningReminder = proposed.eveningReminder
        return .appliedLocally
      } catch {
        restore(oldSettings, to: appModel)
        return .localDatabaseFailed(error.localizedDescription)
      }
    }
    let scheduleResult = await scheduler.schedule(settings: proposed)
    guard case .scheduled = scheduleResult else {
      restore(oldSettings, to: appModel)
      return .scheduleFailed(message(for: scheduleResult))
    }

    do {
      try store.save(settings: proposed)
      appModel.morningReminder = proposed.morningReminder
      appModel.eveningReminder = proposed.eveningReminder
      return .applied
    } catch {
      let rollbackResult = await scheduler.schedule(settings: oldSettings)
      let rollbackSucceeded: Bool
      if case .scheduled = rollbackResult {
        rollbackSucceeded = true
      } else {
        rollbackSucceeded = false
      }
      restore(oldSettings, to: appModel)
      return .databaseFailed(
        error.localizedDescription,
        rollbackSucceeded: rollbackSucceeded
      )
    }
  }

  private func restore(
    _ settings: RussianCornerSettings,
    to appModel: AppModel
  ) {
    appModel.morningReminder = settings.morningReminder
    appModel.eveningReminder = settings.eveningReminder
  }

  private func message(
    for result: ReminderScheduleResult
  ) -> String {
    switch result {
    case .scheduled:
      return ""
    case .permissionDenied:
      return "通知权限未开启"
    case .permissionUndetermined:
      return "尚未取得通知权限"
    case .unavailable:
      return "当前系统不支持提醒"
    case .failed(let message):
      return message
    }
  }
}
