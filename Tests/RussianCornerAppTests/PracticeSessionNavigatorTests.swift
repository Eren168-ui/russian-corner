import RussianCornerCore
import XCTest

@testable import RussianCornerUI

final class PracticeSessionNavigatorTests: XCTestCase {
  func testOpenedItemRemainsPending() {
    var navigator = PracticeSessionNavigator(queue: makeQueue(count: 5))

    navigator.markOpened(at: 0)

    XCTAssertEqual(navigator.status(at: 0), .openedUnassessed)
    XCTAssertEqual(navigator.nextPendingIndex(after: 4), 0)
  }

  func testNextPendingMovesForwardThenWrapsToEarlierMissedItem() {
    var navigator = PracticeSessionNavigator(queue: makeQueue(count: 6))
    navigator.markAssessed(at: 0, needsRetry: false)
    navigator.markAssessed(at: 4, needsRetry: false)
    navigator.markAssessed(at: 5, needsRetry: false)

    XCTAssertEqual(navigator.nextPendingIndex(after: 4), 1)
    XCTAssertEqual(navigator.nextPendingIndex(after: 1), 2)
  }

  func testAssessedItemStatusSupportsReadOnlySelection() {
    var navigator = PracticeSessionNavigator(queue: makeQueue(count: 2))

    navigator.markAssessed(at: 0, needsRetry: false)

    XCTAssertEqual(navigator.status(at: 0), .assessed)
    XCTAssertFalse(navigator.isPending(at: 0))
  }

  func testAgainKeepsOriginalDistinctFromAppendedRetry() {
    let original = makeQueue(count: 1)
    var navigator = PracticeSessionNavigator(queue: original)
    navigator.markAssessed(at: 0, needsRetry: true)

    navigator.synchronize(
      with: original + [
        PracticeQueueEntry(
          content: original[0].content,
          isRetry: true,
          origin: .sameDayRetry
        )
      ]
    )

    XCTAssertEqual(navigator.keys.count, 2)
    XCTAssertEqual(navigator.keys.map(\.occurrence), [0, 1])
    XCTAssertEqual(navigator.statuses, [.needsRetry, .unseen])
  }

  func testAllAssessedReturnsNoNextPendingIndex() {
    var navigator = PracticeSessionNavigator(queue: makeQueue(count: 3))
    for index in 0..<3 {
      navigator.markAssessed(at: index, needsRetry: false)
    }

    XCTAssertNil(navigator.nextPendingIndex(after: 2))
    XCTAssertEqual(navigator.assessedCount, 3)
    XCTAssertEqual(navigator.pendingCount, 0)
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
