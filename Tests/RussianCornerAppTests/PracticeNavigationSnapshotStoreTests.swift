import RussianCornerCore
import XCTest

@testable import RussianCornerUI

final class PracticeNavigationSnapshotStoreTests: XCTestCase {
  private let day = Date(timeIntervalSince1970: 1_775_347_200)

  func testSameDayMatchingQueueRestoresSnapshot() {
    let fixture = makeStore()
    let queue = makeQueue(count: 4)
    var navigator = PracticeSessionNavigator(queue: queue)
    navigator.markOpened(at: 0)
    navigator.markAssessed(at: 1, needsRetry: false)
    fixture.store.save(
      navigator: navigator,
      currentIndex: 2,
      language: .russian,
      dayStart: day,
      queue: queue
    )

    let restored = fixture.store.load(
      language: .russian,
      dayStart: day.addingTimeInterval(3_600),
      queue: queue,
      calendar: utcCalendar
    )

    XCTAssertEqual(restored?.currentIndex, 2)
    XCTAssertEqual(restored?.navigator, navigator)
  }

  func testLanguageKeysAreIsolated() {
    let fixture = makeStore()
    let queue = makeQueue(count: 2)
    fixture.store.save(
      navigator: PracticeSessionNavigator(queue: queue),
      currentIndex: 1,
      language: .russian,
      dayStart: day,
      queue: queue
    )

    XCTAssertNil(
      fixture.store.load(
        language: .english,
        dayStart: day,
        queue: queue,
        calendar: utcCalendar
      )
    )
  }

  func testCrossDaySnapshotIsRejected() {
    let fixture = makeStore()
    let queue = makeQueue(count: 2)
    fixture.store.save(
      navigator: PracticeSessionNavigator(queue: queue),
      currentIndex: 1,
      language: .russian,
      dayStart: day,
      queue: queue
    )

    XCTAssertNil(
      fixture.store.load(
        language: .russian,
        dayStart: day.addingTimeInterval(86_400),
        queue: queue,
        calendar: utcCalendar
      )
    )
  }

  func testQueueSignatureMismatchIsRejected() {
    let fixture = makeStore()
    let queue = makeQueue(count: 2)
    fixture.store.save(
      navigator: PracticeSessionNavigator(queue: queue),
      currentIndex: 1,
      language: .russian,
      dayStart: day,
      queue: queue
    )

    XCTAssertNil(
      fixture.store.load(
        language: .russian,
        dayStart: day,
        queue: makeQueue(count: 3),
        calendar: utcCalendar
      )
    )
  }

  func testCorruptSnapshotIsRejected() {
    let fixture = makeStore()
    fixture.defaults.set(
      Data("not-json".utf8),
      forKey: PracticeNavigationSnapshotStore.storageKey(
        for: .russian
      )
    )

    XCTAssertNil(
      fixture.store.load(
        language: .russian,
        dayStart: day,
        queue: makeQueue(count: 2),
        calendar: utcCalendar
      )
    )
  }

  private func makeStore() -> (
    store: PracticeNavigationSnapshotStore,
    defaults: UserDefaults
  ) {
    let suiteName = "PracticeNavigationSnapshotStoreTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (
      PracticeNavigationSnapshotStore(defaults: defaults),
      defaults
    )
  }

  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  private func makeQueue(count: Int) -> [PracticeQueueEntry] {
    (0..<count).map { index in
      PracticeQueueEntry(
        content: .sentence(
          SentenceCard(
            id: "sentence-\(index)",
            promptZh: "提示 \(index)",
            cueRu: "Что сказать?",
            practiceRu: "Ответ \(index).",
            speechText: "Ответ \(index).",
            theme: "测试",
            lexemeIDs: [],
            sourcePath: "fixture.md",
            sourceText: "fixture",
            reviewStatus: .reviewed
          )
        )
      )
    }
  }
}
