import Foundation
import XCTest
@testable import RussianCornerCore
@testable import RussianCornerPlatform

@MainActor
final class TrialPersistenceTests: XCTestCase {
    nonisolated(unsafe) private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        super.tearDown()
    }

    func testTrialContainerUsesDifferentStoreFromCoreProgress() throws {
        let support = try makeTemporaryDirectory()
        let coreContainer = try ProgressRepository.makeContainer(
            applicationSupportDirectory: support
        )
        let trialContainer = try TrialRepository.makeContainer(
            applicationSupportDirectory: support
        )
        let core = ProgressRepository(container: coreContainer)
        let trial = TrialRepository(container: trialContainer)

        try core.saveProgress(
            itemType: .lexeme,
            itemId: "core-item",
            state: ReviewState(
                masteryLevel: 1,
                dueAt: Date(timeIntervalSince1970: 100)
            )
        )
        try trial.save(session: makeSession())

        let appDirectory = support.appendingPathComponent(
            "com.openclaw.russiancorner",
            isDirectory: true
        )
        let files = try FileManager.default.contentsOfDirectory(
            atPath: appDirectory.path
        )

        XCTAssertTrue(files.contains("RussianCorner.store"))
        XCTAssertTrue(files.contains("RussianCornerTrial.store"))
    }

    func testSessionAndInteractionsSurviveRepositoryReopen() throws {
        let support = try makeTemporaryDirectory()
        let session = makeSession()
        let interaction = makeInteraction(sessionID: session.id)

        do {
            let container = try TrialRepository.makeContainer(
                applicationSupportDirectory: support
            )
            let repository = TrialRepository(container: container)
            try repository.save(session: session)
            try repository.save(interaction: interaction)
        }

        let reopened = TrialRepository(
            container: try TrialRepository.makeContainer(
                applicationSupportDirectory: support
            )
        )
        let snapshot = try reopened.fetchSnapshot(
            from: Date(timeIntervalSince1970: 0),
            through: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(snapshot.sessions, [session])
        XCTAssertEqual(snapshot.interactions, [interaction])
    }

    func testDailyReflectionUpsertsOneRecordPerCalendarDay() throws {
        let repository = try makeInMemoryRepository()
        let calendar = utcCalendar()
        let morning = Date(timeIntervalSince1970: 86_400 + 100)
        let evening = Date(timeIntervalSince1970: 86_400 + 800)

        try repository.upsert(
            reflection: DailyReflection(
                day: morning,
                mostBlocked: "第一个答案",
                spokeNaturally: false,
                spokeNaturallyNote: "",
                completionReason: .interrupted,
                completionReasonNote: "",
                updatedAt: morning
            ),
            calendar: calendar
        )
        let expected = DailyReflection(
            day: calendar.startOfDay(for: evening),
            mostBlocked: "第二个答案",
            spokeNaturally: true,
            spokeNaturallyNote: "Да, получилось.",
            completionReason: .completed,
            completionReasonNote: "",
            updatedAt: evening
        )
        try repository.upsert(reflection: expected, calendar: calendar)

        let snapshot = try repository.fetchSnapshot(
            from: calendar.startOfDay(for: morning),
            through: evening.addingTimeInterval(1)
        )

        XCTAssertEqual(snapshot.reflections, [expected])
        XCTAssertEqual(
            try repository.reflection(on: morning, calendar: calendar),
            expected
        )
    }

    func testFetchRangeExcludesRowsOutsideSevenDayWindow() throws {
        let repository = try makeInMemoryRepository()
        let inside = makeSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 500)
        )
        let outside = makeSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 50)
        )
        try repository.save(session: inside)
        try repository.save(session: outside)

        let snapshot = try repository.fetchSnapshot(
            from: Date(timeIntervalSince1970: 100),
            through: Date(timeIntervalSince1970: 900)
        )

        XCTAssertEqual(snapshot.sessions, [inside])
    }

    func testOralAttemptStoresNumbersButNeverAudioURL() throws {
        let repository = try makeInMemoryRepository()
        let attempt = OralActivityAttempt(
            topic: "自我介绍",
            attemptedAt: Date(timeIntervalSince1970: 400),
            elapsedMs: 60_000,
            estimatedSpeakingMs: 42_000,
            longPauseCount: 3,
            selfRating: 4,
            usedMicrophoneMeter: true
        )
        try repository.save(oralAttempt: attempt)

        let snapshot = try repository.fetchSnapshot(
            from: Date(timeIntervalSince1970: 0),
            through: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(snapshot.oralAttempts, [attempt])
        XCTAssertFalse(String(reflecting: snapshot.oralAttempts).contains("URL"))
        XCTAssertFalse(
            String(reflecting: snapshot.oralAttempts).contains("file://")
        )
    }

    private func makeInMemoryRepository() throws -> TrialRepository {
        TrialRepository(
            container: try TrialRepository.makeContainer(inMemory: true)
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryDirectories.append(directory)
        return directory
    }

    private func makeSession(
        id: UUID = UUID(),
        startedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> TrialSession {
        TrialSession(
            id: id,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(20),
            endReason: .hidden,
            startQueueCount: 7,
            endQueueCount: 5,
            completedLexemeCount: 1,
            completedSentenceCount: 1,
            newItemCount: 1,
            reviewItemCount: 1,
            remainingBacklogCount: 2,
            exitItemType: .sentence,
            exitQueuePosition: 2
        )
    }

    private func makeInteraction(sessionID: UUID) -> TrialInteraction {
        TrialInteraction(
            sessionID: sessionID,
            itemType: .lexeme,
            itemID: "lex-001",
            kind: .grade,
            direction: .production,
            promptLevel: .chinese,
            grade: .easy,
            responseTimeMs: 2_400,
            usedSpeech: false,
            openedDetails: true,
            practiceMode: .speaking,
            createdAt: Date(timeIntervalSince1970: 110)
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
