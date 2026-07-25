import Foundation
import XCTest
@testable import RussianCornerCore

final class SchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let day: TimeInterval = 24 * 60 * 60
    private let scheduler = ReviewScheduler()

    func testAgainResetsMasteryAndSchedulesTomorrow() {
        let state = ReviewState(
            masteryLevel: 4,
            dueAt: now.addingTimeInterval(-day)
        )

        let next = scheduler.next(state: state, grade: .again, now: now)

        XCTAssertEqual(next.masteryLevel, 0)
        XCTAssertEqual(next.dueAt, now.addingTimeInterval(day))
    }

    func testHardKeepsMasteryAndUsesOneDayInterval() {
        let state = ReviewState(masteryLevel: 3, dueAt: now)

        let next = scheduler.next(state: state, grade: .hard, now: now)

        XCTAssertEqual(next.masteryLevel, 3)
        XCTAssertEqual(next.dueAt, now.addingTimeInterval(day))
    }

    func testEasyAdvancesThroughIntervals() {
        let expectedIntervals = [1, 3, 7, 14, 30]

        for (currentLevel, intervalDays) in expectedIntervals.enumerated() {
            let state = ReviewState(masteryLevel: currentLevel, dueAt: now)

            let next = scheduler.next(state: state, grade: .easy, now: now)

            XCTAssertEqual(next.masteryLevel, currentLevel + 1)
            XCTAssertEqual(
                next.dueAt,
                now.addingTimeInterval(TimeInterval(intervalDays) * day)
            )
        }
    }

    func testEasyCapsAtHighestMasteryAndThirtyDayInterval() {
        let state = ReviewState(masteryLevel: 5, dueAt: now)

        let next = scheduler.next(state: state, grade: .easy, now: now)

        XCTAssertEqual(next.masteryLevel, 5)
        XCTAssertEqual(next.dueAt, now.addingTimeInterval(30 * day))
    }

    func testReviewModelsRoundTripThroughCodable() throws {
        let grade = ReviewGrade.easy
        let state = ReviewState(masteryLevel: 2, dueAt: now)

        let decodedGrade = try JSONDecoder().decode(
            ReviewGrade.self,
            from: JSONEncoder().encode(grade)
        )
        let decodedState = try JSONDecoder().decode(
            ReviewState.self,
            from: JSONEncoder().encode(state)
        )

        XCTAssertEqual(decodedGrade, grade)
        XCTAssertEqual(decodedState, state)
    }

    func testReviewStateCanBeUpdated() {
        var state = ReviewState(masteryLevel: 1, dueAt: now)

        state.masteryLevel = 2
        state.dueAt = now.addingTimeInterval(day)

        XCTAssertEqual(
            state,
            ReviewState(
                masteryLevel: 2,
                dueAt: now.addingTimeInterval(day)
            )
        )
    }

    func testLowRecallReducesNewWordLimit() {
        XCTAssertEqual(
            scheduler.adaptiveNewWordLimit(
                previousRecallRate: 0.749,
                strongDayStreak: 10,
                overdueCount: 0
            ),
            6
        )
    }

    func testRecallRateBoundaryAtSeventyFivePercentUsesStandardLimit() {
        XCTAssertEqual(
            scheduler.adaptiveNewWordLimit(
                previousRecallRate: 0.75,
                strongDayStreak: 0,
                overdueCount: 0
            ),
            10
        )
    }

    func testNinetyPercentRecallStillUsesStandardLimit() {
        XCTAssertEqual(
            scheduler.adaptiveNewWordLimit(
                previousRecallRate: 0.90,
                strongDayStreak: 3,
                overdueCount: 0
            ),
            10
        )
    }

    func testTwoStrongDaysStillUseStandardLimit() {
        XCTAssertEqual(
            scheduler.adaptiveNewWordLimit(
                previousRecallRate: 0.91,
                strongDayStreak: 2,
                overdueCount: ReviewScheduler.significantOverdueThreshold - 1
            ),
            10
        )
    }

    func testThreeStrongDaysWithFewOverdueWordsRaisesLimit() {
        XCTAssertEqual(
            scheduler.adaptiveNewWordLimit(
                previousRecallRate: 0.91,
                strongDayStreak: 3,
                overdueCount: ReviewScheduler.significantOverdueThreshold - 1
            ),
            12
        )
    }

    func testSignificantOverdueBoundaryReducesLimit() {
        XCTAssertEqual(
            scheduler.adaptiveNewWordLimit(
                previousRecallRate: 0.91,
                strongDayStreak: 3,
                overdueCount: ReviewScheduler.significantOverdueThreshold
            ),
            6
        )
    }
}
