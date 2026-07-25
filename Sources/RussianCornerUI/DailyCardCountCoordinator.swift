import Foundation

@MainActor
public final class DailyCardCountCoordinator {
  private let reloadPractice: () throws -> Void

  public init(reloadPractice: @escaping () throws -> Void) {
    self.reloadPractice = reloadPractice
  }

  @discardableResult
  public func apply(
    proposed: Int,
    to appModel: AppModel
  ) -> Bool {
    let oldValue = appModel.dailyCardCount
    appModel.dailyCardCount = proposed
    do {
      try reloadPractice()
      return true
    } catch {
      appModel.dailyCardCount = oldValue
      appModel.transientStatus =
        "每日卡数未更新：\(error.localizedDescription)"
      return false
    }
  }
}
