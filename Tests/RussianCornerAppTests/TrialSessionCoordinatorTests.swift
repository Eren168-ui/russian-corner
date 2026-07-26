import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
private final class TrialStoreSpy: TrialDataStoring {
    var shouldFail = false
    private(set) var sessions: [TrialSession] = []
    private(set) var interactions: [TrialInteraction] = []
    private(set) var reflections: [DailyReflection] = []
    private(set) var oralAttempts: [OralActivityAttempt] = []

    func save(session: TrialSession) throws {
        if shouldFail { throw TrialCoordinatorFixtureError.writeFailed }
        sessions.append(session)
    }

    func save(interaction: TrialInteraction) throws {
        if shouldFail { throw TrialCoordinatorFixtureError.writeFailed }
        interactions.append(interaction)
    }

    func upsert(
        reflection: DailyReflection,
        calendar: Calendar
    ) throws {
        if shouldFail { throw TrialCoordinatorFixtureError.writeFailed }
        reflections.removeAll {
            calendar.isDate($0.day, inSameDayAs: reflection.day)
        }
        reflections.append(reflection)
    }

    func save(oralAttempt: OralActivityAttempt) throws {
        if shouldFail { throw TrialCoordinatorFixtureError.writeFailed }
        oralAttempts.append(oralAttempt)
    }

    func fetchSnapshot(
        from start: Date,
        through end: Date
    ) throws -> TrialReportSnapshot {
        TrialReportSnapshot(
            sessions: sessions.filter {
                $0.startedAt >= start && $0.startedAt <= end
            },
            interactions: interactions.filter {
                $0.createdAt >= start && $0.createdAt <= end
            },
            reflections: reflections.filter {
                $0.day >= start && $0.day <= end
            },
            oralAttempts: oralAttempts.filter {
                $0.attemptedAt >= start && $0.attemptedAt <= end
            }
        )
    }

    func reflection(
        on day: Date,
        calendar: Calendar
    ) throws -> DailyReflection? {
        reflections.first {
            calendar.isDate($0.day, inSameDayAs: day)
        }
    }
}

private enum TrialCoordinatorFixtureError: Error {
    case writeFailed
}

@MainActor
final class TrialSessionCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testSessionStartsOnFirstMeaningfulInteractionNotViewAppearance() {
        let store = TrialStoreSpy()
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { self.start },
            calendar: utcCalendar
        )

        XCTAssertFalse(coordinator.hasOpenSession)
        XCTAssertTrue(store.interactions.isEmpty)

        coordinator.record(kind: .reveal, context: context(at: start))

        XCTAssertTrue(coordinator.hasOpenSession)
        XCTAssertEqual(store.interactions.count, 1)
    }

    func testThreeMinutesOfInactivityClosesSessionAtLastInteraction() {
        var now = start
        let store = TrialStoreSpy()
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { now },
            calendar: utcCalendar
        )
        coordinator.record(kind: .reveal, context: context(at: now))

        now = start.addingTimeInterval(181)
        coordinator.expireIdleSession(at: now)

        XCTAssertFalse(coordinator.hasOpenSession)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].endReason, .idle)
        XCTAssertEqual(store.sessions[0].endedAt, start)
    }

    func testInteractionBeforeThreeMinutesKeepsSameSession() {
        var now = start
        let store = TrialStoreSpy()
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { now },
            calendar: utcCalendar
        )
        coordinator.record(kind: .reveal, context: context(at: now))
        now = start.addingTimeInterval(120)
        coordinator.record(kind: .speak, context: context(at: now))
        now = start.addingTimeInterval(130)
        coordinator.close(reason: .hidden)

        XCTAssertEqual(Set(store.interactions.map(\.sessionID)).count, 1)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].durationMs, 130_000)
    }

    func testExplicitCloseReasonsArePersisted() {
        for reason in [
            TrialSessionEndReason.completed,
            .hidden,
            .quit,
            .dayChanged,
        ] {
            let store = TrialStoreSpy()
            let coordinator = TrialSessionCoordinator(
                repository: store,
                now: { self.start },
                calendar: utcCalendar
            )
            coordinator.record(
                kind: .reveal,
                context: context(at: start)
            )
            coordinator.close(reason: reason)

            XCTAssertEqual(store.sessions.map(\.endReason), [reason])
        }
    }

    func testCrossDayInteractionClosesOldSessionAndStartsNewOne() {
        var now = start
        let store = TrialStoreSpy()
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { now },
            calendar: utcCalendar
        )
        coordinator.record(kind: .reveal, context: context(at: now))
        now = start.addingTimeInterval(86_400)
        coordinator.record(kind: .next, context: context(at: now))

        XCTAssertEqual(store.sessions.map(\.endReason), [.dayChanged])
        XCTAssertEqual(Set(store.interactions.map(\.sessionID)).count, 2)
        XCTAssertTrue(coordinator.hasOpenSession)
    }

    func testRecognitionAndProductionDirectionsRemainSeparate() {
        let store = TrialStoreSpy()
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { self.start },
            calendar: utcCalendar
        )
        coordinator.record(
            kind: .grade,
            context: context(at: start, direction: .recognition)
        )
        coordinator.record(
            kind: .grade,
            context: context(at: start, direction: .production)
        )

        XCTAssertEqual(
            store.interactions.map(\.direction),
            [.recognition, .production]
        )
    }

    func testTrialWriteFailureDoesNotThrowIntoCaller() {
        let store = TrialStoreSpy()
        store.shouldFail = true
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { self.start },
            calendar: utcCalendar
        )

        coordinator.record(kind: .grade, context: context(at: start))
        coordinator.close(reason: .completed)

        XCTAssertNotNil(coordinator.lastIssue)
    }

    func testCardFlagsResetAfterAdvance() throws {
        var now = start
        let store = TrialStoreSpy()
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { now },
            calendar: utcCalendar
        )
        let model = try makePracticeModel(
            tracker: coordinator,
            now: { now },
            sentenceCount: 2
        )

        model.toggleDetails()
        model.reveal()
        now = start.addingTimeInterval(2)
        try model.grade(.easy)

        XCTAssertFalse(model.isDetailExpanded)

        model.reveal()
        now = start.addingTimeInterval(4)
        try model.grade(.easy)

        let grades = store.interactions.filter { $0.kind == .grade }
        XCTAssertEqual(grades.map(\.openedDetails), [true, false])
        XCTAssertEqual(grades.map(\.usedSpeech), [false, false])
    }

    func testTrialWriteFailureDoesNotUndoCommittedReview() throws {
        let store = TrialStoreSpy()
        store.shouldFail = true
        let coordinator = TrialSessionCoordinator(
            repository: store,
            now: { self.start },
            calendar: utcCalendar
        )
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let model = try makePracticeModel(
            tracker: coordinator,
            repository: repository,
            now: { self.start },
            sentenceCount: 1
        )

        model.reveal()
        try model.grade(.easy)

        XCTAssertEqual(try repository.reviewEvents().count, 1)
        XCTAssertEqual(model.currentIndex, 1)
        XCTAssertNotNil(coordinator.lastIssue)
    }

    private func context(
        at date: Date,
        direction: TrialPromptDirection = .production
    ) -> TrialInteractionContext {
        TrialInteractionContext(
            itemType: .lexeme,
            itemID: "lex-001",
            direction: direction,
            promptLevel: direction == .recognition ? .russian : .chinese,
            grade: .hard,
            responseTimeMs: 2_000,
            usedSpeech: false,
            openedDetails: false,
            practiceMode: .speaking,
            occurredAt: date,
            queueCountBeforeAction: 7,
            queueCountAfterAction: 6,
            queuePosition: 1,
            remainingBacklogCount: 2,
            isNewItem: true
        )
    }

    private func makePracticeModel(
        tracker: any PracticeTrialTracking,
        repository: ProgressRepository? = nil,
        now: @escaping () -> Date,
        sentenceCount: Int
    ) throws -> PracticeViewModel {
        let progress = try repository ?? ProgressRepository(
            container: ProgressRepository.makeInMemoryContainer()
        )
        let sentences = (0..<sentenceCount).map { index in
            SentenceCard(
                id: "sentence-\(index)",
                promptZh: "提示 \(index)",
                cueRu: "Что вы скажете \(index)?",
                practiceRu: "Ответ \(index).",
                speechText: "Ответ \(index).",
                theme: "测试",
                lexemeIDs: [],
                sourcePath: "fixture",
                sourceText: "fixture",
                reviewStatus: .reviewed
            )
        }
        return try PracticeViewModel(
            catalog: ContentCatalog(lexemes: [], sentences: sentences),
            repository: progress,
            targetCount: 5,
            now: now,
            calendar: utcCalendar,
            trialTracker: tracker
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
