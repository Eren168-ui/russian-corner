import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
private final class ReflectionStoreSpy: TrialDataStoring {
    var shouldFail = false
    private(set) var upsertCount = 0
    private(set) var reflections: [DailyReflection] = []

    func save(session: TrialSession) throws {}
    func save(interaction: TrialInteraction) throws {}
    func save(oralAttempt: OralActivityAttempt) throws {}

    func upsert(
        reflection: DailyReflection,
        calendar: Calendar
    ) throws {
        if shouldFail { throw ReflectionFixtureError.writeFailed }
        upsertCount += 1
        reflections.removeAll {
            calendar.isDate($0.day, inSameDayAs: reflection.day)
        }
        reflections.append(reflection)
    }

    func fetchSnapshot(
        from start: Date,
        through end: Date
    ) throws -> TrialReportSnapshot {
        TrialReportSnapshot(
            sessions: [],
            interactions: [],
            reflections: reflections.filter {
                $0.day >= start && $0.day <= end
            },
            oralAttempts: []
        )
    }

    func reflection(
        on day: Date,
        calendar: Calendar
    ) throws -> DailyReflection? {
        if shouldFail { throw ReflectionFixtureError.readFailed }
        return reflections.first {
            calendar.isDate($0.day, inSameDayAs: day)
        }
    }
}

private enum ReflectionFixtureError: Error {
    case readFailed
    case writeFailed
}

@MainActor
final class DailyReflectionViewModelTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testCompletedDayOffersReflectionOnlyOnce() {
        let store = ReflectionStoreSpy()
        let model = makeModel(store: store)

        XCTAssertTrue(model.presentAfterCompletionIfNeeded())
        XCTAssertTrue(model.isCompletionOfferPresented)

        model.dismissCompletionOffer()

        XCTAssertFalse(model.presentAfterCompletionIfNeeded())
        XCTAssertFalse(model.isCompletionOfferPresented)
    }

    func testSavingAgainUpdatesTodayInsteadOfCreatingDuplicate() {
        let store = ReflectionStoreSpy()
        let model = makeModel(store: store)
        model.mostBlocked = "第一次"

        XCTAssertTrue(model.saveToday())

        model.mostBlocked = "第二次"
        XCTAssertTrue(model.saveToday())

        XCTAssertEqual(store.upsertCount, 2)
        XCTAssertEqual(store.reflections.count, 1)
        XCTAssertEqual(store.reflections.first?.mostBlocked, "第二次")
    }

    func testMenuCanOpenExistingReflectionForEditing() {
        let store = ReflectionStoreSpy()
        let first = makeModel(store: store)
        first.mostBlocked = "动词搭配"
        first.spokeNaturally = true
        first.spokeNaturallyNote = "一句完整表达"
        XCTAssertTrue(first.saveToday())

        let reopened = makeModel(store: store)
        XCTAssertTrue(reopened.loadToday())

        XCTAssertTrue(reopened.hasSavedToday)
        XCTAssertEqual(reopened.mostBlocked, "动词搭配")
        XCTAssertEqual(reopened.spokeNaturally, true)
        XCTAssertEqual(reopened.spokeNaturallyNote, "一句完整表达")
    }

    func testRepositoryFailureKeepsCoreCompletionUsable() {
        let store = ReflectionStoreSpy()
        store.shouldFail = true
        let model = makeModel(store: store)

        XCTAssertTrue(model.presentAfterCompletionIfNeeded())
        XCTAssertFalse(model.saveToday())
        XCTAssertNotNil(model.statusMessage)

        model.dismissCompletionOffer()
        XCTAssertFalse(model.isCompletionOfferPresented)
    }

    func testReflectionTextIsTrimmedAndLimitedToTwoHundredCharacters() {
        let store = ReflectionStoreSpy()
        let model = makeModel(store: store)
        model.mostBlocked = "  " + String(repeating: "я", count: 240) + "  "
        model.spokeNaturallyNote =
            "  " + String(repeating: "д", count: 240) + "  "
        model.completionReasonNote =
            "  " + String(repeating: "о", count: 240) + "  "

        XCTAssertTrue(model.saveToday())

        let saved = store.reflections[0]
        XCTAssertEqual(saved.mostBlocked.count, 200)
        XCTAssertEqual(saved.spokeNaturallyNote.count, 200)
        XCTAssertEqual(saved.completionReasonNote.count, 200)
        XCTAssertFalse(saved.mostBlocked.hasPrefix(" "))
        XCTAssertFalse(saved.mostBlocked.hasSuffix(" "))
    }

    private func makeModel(
        store: ReflectionStoreSpy
    ) -> DailyReflectionViewModel {
        DailyReflectionViewModel(
            repository: store,
            now: { self.start },
            calendar: utcCalendar
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
