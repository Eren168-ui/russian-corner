import XCTest
@testable import RussianCornerCore

final class DailyQueueTests: XCTestCase {
    private let builder = DailyQueueBuilder()

    func testQueueUsesSixtyThirtyTenMixAndCategoryOrder() {
        let result = builder.build(
            due: items(prefix: "due", count: 10),
            new: items(prefix: "new", count: 10),
            randomReview: items(prefix: "random", count: 10),
            targetCount: 10,
            retryIDs: []
        )

        XCTAssertEqual(result.map(\.id), [
            "due-0", "due-1", "due-2", "due-3", "due-4", "due-5",
            "new-0", "new-1", "new-2",
            "random-0",
        ])
    }

    func testDueItemsBackfillMissingNewAndRandomSlots() {
        let result = builder.build(
            due: items(prefix: "due", count: 10),
            new: [],
            randomReview: [],
            targetCount: 5,
            retryIDs: []
        )

        XCTAssertEqual(
            result.map(\.id),
            ["due-0", "due-1", "due-2", "due-3", "due-4"]
        )
    }

    func testSuccessfulItemDoesNotDuplicateAcrossBuckets() {
        let duplicate = PracticeItem(id: "shared", kind: .lexeme)

        let result = builder.build(
            due: [duplicate],
            new: [duplicate],
            randomReview: [duplicate],
            targetCount: 3,
            retryIDs: []
        )

        XCTAssertEqual(result.map(\.id), ["shared"])
    }

    func testRetryItemMayRepeatAcrossBuckets() {
        let retry = PracticeItem(id: "retry", kind: .sentence)

        let result = builder.build(
            due: [retry],
            new: [retry],
            randomReview: [retry],
            targetCount: 3,
            retryIDs: ["retry"]
        )

        XCTAssertEqual(result.map(\.id), ["retry", "retry", "retry"])
    }

    func testNonPositiveTargetProducesEmptyQueue() {
        XCTAssertTrue(
            builder.build(
                due: items(prefix: "due", count: 2),
                new: items(prefix: "new", count: 2),
                randomReview: items(prefix: "random", count: 2),
                targetCount: 0,
                retryIDs: []
            ).isEmpty
        )
    }

    private func items(prefix: String, count: Int) -> [PracticeItem] {
        (0..<count).map {
            PracticeItem(id: "\(prefix)-\($0)", kind: .lexeme)
        }
    }
}
