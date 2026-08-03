import CryptoKit
import Foundation
import RussianCornerCore

public struct PracticeNavigationSnapshot:
  Codable,
  Equatable,
  Sendable
{
  public let dayStart: Date
  public let language: StudyLanguage
  public let queueSignature: String
  public let currentIndex: Int
  public let navigator: PracticeSessionNavigator
}

public final class PracticeNavigationSnapshotStore: @unchecked Sendable {
  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public static func storageKey(for language: StudyLanguage) -> String {
    "practice.navigation.snapshot.\(language.rawValue)"
  }

  public func load(
    language: StudyLanguage,
    dayStart: Date,
    queue: [PracticeQueueEntry],
    calendar: Calendar = .current
  ) -> PracticeNavigationSnapshot? {
    guard let snapshot = loadSnapshot(
      language: language,
      dayStart: dayStart,
      calendar: calendar
    ),
      snapshot.queueSignature == Self.queueSignature(for: queue),
      snapshot.navigator.keys == PracticeSessionNavigator(queue: queue).keys,
      snapshot.navigator.statuses.count == queue.count
    else {
      return nil
    }
    return snapshot
  }

  public func loadSnapshot(
    language: StudyLanguage,
    dayStart: Date,
    calendar: Calendar = .current
  ) -> PracticeNavigationSnapshot? {
    guard
      let data = defaults.data(
        forKey: Self.storageKey(for: language)
      ),
      let snapshot = try? decoder.decode(
        PracticeNavigationSnapshot.self,
        from: data
      ),
      snapshot.language == language,
      calendar.isDate(snapshot.dayStart, inSameDayAs: dayStart),
      snapshot.navigator.keys.count == snapshot.navigator.statuses.count,
      snapshot.queueSignature == Self.queueSignature(
        for: snapshot.navigator.keys
      ),
      (0...snapshot.navigator.keys.count).contains(
        snapshot.currentIndex
      )
    else {
      return nil
    }
    return snapshot
  }

  public func save(
    navigator: PracticeSessionNavigator,
    currentIndex: Int,
    language: StudyLanguage,
    dayStart: Date,
    queue: [PracticeQueueEntry]
  ) {
    guard
      navigator.keys == PracticeSessionNavigator(queue: queue).keys,
      navigator.statuses.count == queue.count,
      (0...queue.count).contains(currentIndex)
    else {
      return
    }
    let snapshot = PracticeNavigationSnapshot(
      dayStart: dayStart,
      language: language,
      queueSignature: Self.queueSignature(for: queue),
      currentIndex: currentIndex,
      navigator: navigator
    )
    guard let data = try? encoder.encode(snapshot) else { return }
    defaults.set(data, forKey: Self.storageKey(for: language))
  }

  private static func queueSignature(
    for queue: [PracticeQueueEntry]
  ) -> String {
    queueSignature(for: PracticeSessionNavigator(queue: queue).keys)
  }

  private static func queueSignature(
    for keys: [PracticeSessionEntryKey]
  ) -> String {
    let payload = keys.map {
      "\($0.kind.rawValue):\($0.itemID):\($0.occurrence)"
    }.joined(separator: "\u{1F}")
    let digest = SHA256.hash(data: Data(payload.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
