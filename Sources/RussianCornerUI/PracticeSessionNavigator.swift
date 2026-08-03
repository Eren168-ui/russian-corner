import RussianCornerCore

public enum PracticeSessionItemStatus:
  String,
  Codable,
  Equatable,
  Sendable
{
  case unseen
  case openedUnassessed
  case assessed
  case needsRetry

  public var isPending: Bool {
    self == .unseen || self == .openedUnassessed
  }
}

public struct PracticeSessionEntryKey:
  Hashable,
  Codable,
  Sendable
{
  public let kind: PracticeItemKind
  public let itemID: String
  public let occurrence: Int

  public init(
    kind: PracticeItemKind,
    itemID: String,
    occurrence: Int
  ) {
    self.kind = kind
    self.itemID = itemID
    self.occurrence = occurrence
  }
}

public struct PracticeSessionNavigator:
  Codable,
  Equatable,
  Sendable
{
  public private(set) var keys: [PracticeSessionEntryKey]
  public private(set) var statuses: [PracticeSessionItemStatus]

  public init(queue: [PracticeQueueEntry]) {
    keys = Self.makeKeys(for: queue)
    statuses = Array(repeating: .unseen, count: keys.count)
  }

  public var assessedCount: Int {
    statuses.count { !$0.isPending }
  }

  public var pendingCount: Int {
    statuses.count(where: \.isPending)
  }

  public func status(at index: Int) -> PracticeSessionItemStatus {
    guard statuses.indices.contains(index) else { return .unseen }
    return statuses[index]
  }

  public func isPending(at index: Int) -> Bool {
    status(at: index).isPending
  }

  public mutating func markOpened(at index: Int) {
    guard statuses.indices.contains(index), statuses[index] == .unseen
    else { return }
    statuses[index] = .openedUnassessed
  }

  public mutating func markAssessed(
    at index: Int,
    needsRetry: Bool
  ) {
    guard statuses.indices.contains(index) else { return }
    statuses[index] = needsRetry ? .needsRetry : .assessed
  }

  public mutating func synchronize(with queue: [PracticeQueueEntry]) {
    let oldStatuses = Dictionary(
      uniqueKeysWithValues: zip(keys, statuses)
    )
    let nextKeys = Self.makeKeys(for: queue)
    keys = nextKeys
    statuses = nextKeys.map { oldStatuses[$0] ?? .unseen }
  }

  public func nextPendingIndex(after index: Int) -> Int? {
    guard !statuses.isEmpty else { return nil }
    let start = min(max(index + 1, 0), statuses.count)
    for candidate in start..<statuses.count
    where statuses[candidate].isPending {
      return candidate
    }
    let wrapEnd = min(max(index, -1), statuses.count - 1)
    guard wrapEnd >= 0 else { return nil }
    for candidate in 0...wrapEnd
    where statuses[candidate].isPending {
      return candidate
    }
    return nil
  }

  private static func makeKeys(
    for queue: [PracticeQueueEntry]
  ) -> [PracticeSessionEntryKey] {
    var occurrences: [PracticeItemIdentity: Int] = [:]
    return queue.map { entry in
      let occurrence = occurrences[entry.identity, default: 0]
      occurrences[entry.identity] = occurrence + 1
      return PracticeSessionEntryKey(
        kind: entry.kind,
        itemID: entry.id,
        occurrence: occurrence
      )
    }
  }
}
