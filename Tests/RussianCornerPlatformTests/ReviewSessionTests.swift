import Foundation
import SwiftData
import XCTest
@testable import RussianCornerCore
@testable import RussianCornerPlatform

final class ReviewSessionTests: XCTestCase {
    func testReviewEventResponseLatencyRoundTripsThroughCodable() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let event = ReviewEvent(
            itemType: .sentence,
            itemId: "sentence-1",
            grade: .hard,
            responseTimeMs: 3_250,
            practiceMode: .speaking,
            createdAt: createdAt
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ReviewEvent.self, from: data)

        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.responseTimeMs, 3_250)
    }

    func testSettingsRoundTripThroughCodable() throws {
        let settings = RussianCornerSettings(
            morningReminder: ReminderTime(hour: 9, minute: 15),
            eveningReminder: ReminderTime(hour: 19, minute: 45)
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            RussianCornerSettings.self,
            from: data
        )

        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.reminderTimes.count, 2)
    }

    func testDefaultReminderTimesAreExactlyElevenThirtyAndSeventeenThirty() {
        let settings = RussianCornerSettings()

        XCTAssertEqual(settings.reminderTimes, [
            ReminderTime(hour: 11, minute: 30),
            ReminderTime(hour: 17, minute: 30),
        ])
        XCTAssertEqual(settings.reminderTimes.count, 2)
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testInMemoryRepositoryRestoresReviewEventWithLatency() throws {
        let container = try ProgressRepository.makeInMemoryContainer()
        let writer = ProgressRepository(container: container)
        let event = ReviewEvent(
            itemType: .lexeme,
            itemId: "lexeme-1",
            grade: .easy,
            responseTimeMs: 2_125,
            practiceMode: .quiet,
            createdAt: now
        )

        try writer.save(reviewEvent: event)
        let restored = try ProgressRepository(container: container).reviewEvents()

        XCTAssertEqual(restored, [event])
    }

    func testInMemoryRepositoryRestoresItemMasteryAndDueDate() throws {
        let container = try ProgressRepository.makeInMemoryContainer()
        let writer = ProgressRepository(container: container)
        let state = ReviewState(
            masteryLevel: 3,
            dueAt: now.addingTimeInterval(86_400)
        )

        try writer.saveProgress(
            itemType: .sentence,
            itemId: "sentence-1",
            state: state
        )
        let restored = try ProgressRepository(container: container).progress(
            itemType: .sentence,
            itemId: "sentence-1"
        )

        XCTAssertEqual(restored, state)
    }

    func testInMemoryRepositoryRestoresDailyCompletion() throws {
        let container = try ProgressRepository.makeInMemoryContainer()
        let writer = ProgressRepository(container: container)

        try writer.saveDailyCompletion(date: now, completedCount: 17)
        let restored = try ProgressRepository(container: container)
            .dailyCompletedCount(on: now)

        XCTAssertEqual(restored, 17)
    }

    func testInMemoryRepositoryRestoresSettings() throws {
        let container = try ProgressRepository.makeInMemoryContainer()
        let writer = ProgressRepository(container: container)
        let settings = RussianCornerSettings(
            morningReminder: ReminderTime(hour: 8, minute: 5),
            eveningReminder: ReminderTime(hour: 20, minute: 10)
        )

        try writer.save(settings: settings)
        let restored = try ProgressRepository(container: container).settings()

        XCTAssertEqual(restored, settings)
        XCTAssertEqual(restored.reminderTimes.count, 2)
    }

    func testCorruptedReviewEventRawValueThrowsExplicitError() throws {
        let container = try ProgressRepository.makeInMemoryContainer()
        let recordID = UUID()
        let event = ReviewEvent(
            itemType: .lexeme,
            itemId: "corrupted-lexeme",
            grade: .hard,
            responseTimeMs: 1_500,
            practiceMode: .quiet,
            createdAt: now
        )
        let corruptedRecord = ReviewEventRecord(id: recordID, event: event)
        corruptedRecord.gradeRawValue = "impossible-grade"
        let context = ModelContext(container)
        context.insert(corruptedRecord)
        try context.save()

        XCTAssertThrowsError(
            try ProgressRepository(container: container).reviewEvents()
        ) { error in
            let description = String(describing: error)
            XCTAssertTrue(description.contains("corruptedRecord"))
            XCTAssertTrue(description.contains(recordID.uuidString))
            XCTAssertTrue(description.contains("gradeRawValue"))
            XCTAssertTrue(description.contains("impossible-grade"))
        }
    }
}

private struct FixedMicrophonePermissionProvider:
    MicrophonePermissionProviding
{
    let status: MicrophonePermissionStatus

    func currentStatus() -> MicrophonePermissionStatus {
        status
    }

    func requestPermission() async -> MicrophonePermissionStatus {
        status
    }
}

@MainActor
private final class FakeRecordingEngine: RecordingEngine {
    private(set) var isRecording = false

    func record() -> Bool {
        isRecording = true
        return true
    }

    func stop() {
        isRecording = false
    }
}

@MainActor
private final class FakeRecordingEngineFactory: RecordingEngineFactory {
    private(set) var makeCallCount = 0

    func makeEngine(outputURL: URL) throws -> any RecordingEngine {
        makeCallCount += 1
        try Data("temporary audio".utf8).write(to: outputURL)
        return FakeRecordingEngine()
    }
}

@MainActor
private final class FakeRecordingFileManager: RecordingFileManaging {
    private enum FakeError: Error {
        case removeFailed
        case moveFailed
    }

    var shouldFailRemoval = false
    var shouldFailMove = false
    private(set) var moveCallCount = 0

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func removeItem(at url: URL) throws {
        if shouldFailRemoval {
            throw FakeError.removeFailed
        }
        try FileManager.default.removeItem(at: url)
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        moveCallCount += 1
        if shouldFailMove {
            throw FakeError.moveFailed
        }
        try FileManager.default.moveItem(
            at: sourceURL,
            to: destinationURL
        )
    }
}

@MainActor
final class RecordingServiceTests: XCTestCase {
    func testDeniedMicrophoneDoesNotStartOrBlockReview() async {
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .denied
            ),
            engineFactory: FakeRecordingEngineFactory()
        )

        let result = await service.start()

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertFalse(service.isRecording)
        XCTAssertNil(service.temporaryRecordingURL)
    }

    func testDiscardDeletesTemporaryRecording() async throws {
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .granted
            ),
            engineFactory: FakeRecordingEngineFactory()
        )
        let result = await service.start()
        let temporaryURL = try XCTUnwrap(result.startedURL)

        service.stop()
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))

        try service.discard()

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
        XCTAssertNil(service.temporaryRecordingURL)
    }

    func testExplicitSaveMovesRecordingAndCleansTemporaryFile() async throws {
        let fileManager = FakeRecordingFileManager()
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .granted
            ),
            engineFactory: FakeRecordingEngineFactory(),
            fileManager: fileManager
        )
        let result = await service.start()
        let temporaryURL = try XCTUnwrap(result.startedURL)
        let savedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        defer {
            try? FileManager.default.removeItem(at: savedURL)
        }

        service.stop()
        let returnedURL = try service.save(to: savedURL)

        XCTAssertEqual(returnedURL, savedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
        XCTAssertNil(service.temporaryRecordingURL)
        XCTAssertEqual(fileManager.moveCallCount, 1)
    }

    func testDiscardFailureKeepsTemporaryURLForRetry() async throws {
        let fileManager = FakeRecordingFileManager()
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .granted
            ),
            engineFactory: FakeRecordingEngineFactory(),
            fileManager: fileManager
        )
        let firstResult = await service.start()
        let temporaryURL = try XCTUnwrap(firstResult.startedURL)
        service.stop()
        fileManager.shouldFailRemoval = true

        XCTAssertThrowsError(try service.discard())
        XCTAssertEqual(service.temporaryRecordingURL, temporaryURL)

        fileManager.shouldFailRemoval = false
        try service.discard()
        XCTAssertNil(service.temporaryRecordingURL)
        XCTAssertFalse(fileManager.fileExists(at: temporaryURL))
    }

    func testStartDoesNotCrossFailedCleanupOfPreviousRecording() async throws {
        let fileManager = FakeRecordingFileManager()
        let engineFactory = FakeRecordingEngineFactory()
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .granted
            ),
            engineFactory: engineFactory,
            fileManager: fileManager
        )
        let firstResult = await service.start()
        let temporaryURL = try XCTUnwrap(firstResult.startedURL)
        service.stop()
        fileManager.shouldFailRemoval = true

        let result = await service.start()

        guard case .failed = result else {
            return XCTFail("expected cleanup failure, got \(result)")
        }
        XCTAssertEqual(service.temporaryRecordingURL, temporaryURL)
        XCTAssertEqual(engineFactory.makeCallCount, 1)
        fileManager.shouldFailRemoval = false
        try service.discard()
    }

    func testMoveFailureKeepsTemporaryURLForRetry() async throws {
        let fileManager = FakeRecordingFileManager()
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .granted
            ),
            engineFactory: FakeRecordingEngineFactory(),
            fileManager: fileManager
        )
        let firstResult = await service.start()
        let temporaryURL = try XCTUnwrap(firstResult.startedURL)
        let savedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        defer {
            try? FileManager.default.removeItem(at: savedURL)
        }
        service.stop()
        fileManager.shouldFailMove = true

        XCTAssertThrowsError(try service.save(to: savedURL))

        XCTAssertEqual(service.temporaryRecordingURL, temporaryURL)
        XCTAssertTrue(fileManager.fileExists(at: temporaryURL))
        XCTAssertFalse(fileManager.fileExists(at: savedURL))
    }

    func testExistingSaveDestinationPreservesTemporaryRecording() async throws {
        let fileManager = FakeRecordingFileManager()
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .granted
            ),
            engineFactory: FakeRecordingEngineFactory(),
            fileManager: fileManager
        )
        let firstResult = await service.start()
        let temporaryURL = try XCTUnwrap(firstResult.startedURL)
        let savedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        try Data("existing".utf8).write(to: savedURL)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
            try? FileManager.default.removeItem(at: savedURL)
        }
        service.stop()

        XCTAssertThrowsError(try service.save(to: savedURL)) { error in
            XCTAssertEqual(
                error as? RecordingServiceError,
                .destinationAlreadyExists
            )
        }
        XCTAssertEqual(service.temporaryRecordingURL, temporaryURL)
        XCTAssertTrue(fileManager.fileExists(at: temporaryURL))
        XCTAssertEqual(fileManager.moveCallCount, 0)
    }
}

private actor FakeReminderScheduler: ReminderNotificationScheduling {
    private enum FakeError: Error {
        case addFailed
    }

    private let status: ReminderPermissionStatus
    private let failingAddAttempt: Int?
    private let suspendingAddAttempt: Int?
    private var removedIdentifierBatches: [[String]] = []
    private var queriedIdentifierBatches: [[String]] = []
    private var requestsByID: [String: DailyReminderRequest]
    private var addAttemptCount = 0
    private var suspendedAddContinuation: CheckedContinuation<Void, Never>?

    init(
        status: ReminderPermissionStatus,
        failingAddAttempt: Int? = nil,
        suspendingAddAttempt: Int? = nil,
        initialRequests: [DailyReminderRequest] = []
    ) {
        self.status = status
        self.failingAddAttempt = failingAddAttempt
        self.suspendingAddAttempt = suspendingAddAttempt
        requestsByID = Dictionary(
            uniqueKeysWithValues: initialRequests.map {
                ($0.identifier, $0)
            }
        )
    }

    func authorizationStatus() async -> ReminderPermissionStatus {
        status
    }

    func requestAuthorization() async -> ReminderPermissionStatus {
        status
    }

    func pendingRequests(
        withIdentifiers identifiers: [String]
    ) async throws -> [DailyReminderRequest] {
        queriedIdentifierBatches.append(identifiers)
        return identifiers.compactMap { requestsByID[$0] }
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        removedIdentifierBatches.append(identifiers)
        for identifier in identifiers {
            requestsByID[identifier] = nil
        }
    }

    func add(_ request: DailyReminderRequest) async throws {
        addAttemptCount += 1
        if addAttemptCount == failingAddAttempt {
            throw FakeError.addFailed
        }
        if addAttemptCount == suspendingAddAttempt {
            await withCheckedContinuation {
                suspendedAddContinuation = $0
            }
        }
        requestsByID[request.identifier] = request
    }

    func resumeSuspendedAdd() {
        suspendedAddContinuation?.resume()
        suspendedAddContinuation = nil
    }

    func removalCount() -> Int {
        removedIdentifierBatches.count
    }

    func isAddSuspended() -> Bool {
        suspendedAddContinuation != nil
    }

    func snapshot() -> (
        removed: [[String]],
        queried: [[String]],
        pending: [DailyReminderRequest]
    ) {
        let ownedIDs = ReminderService.pendingRequestIDs
        let otherIDs = requestsByID.keys
            .filter { !ownedIDs.contains($0) }
            .sorted()
        return (
            removedIdentifierBatches,
            queriedIdentifierBatches,
            (ownedIDs + otherIDs).compactMap { requestsByID[$0] }
        )
    }
}

final class ReminderServiceTests: XCTestCase {
    func testAuthorizedSchedulingUsesExactlyTwoStableDailyReminderIDs() async {
        let scheduler = FakeReminderScheduler(status: .authorized)
        let service = ReminderService(scheduler: scheduler)
        let settings = RussianCornerSettings(
            morningReminder: ReminderTime(hour: 10, minute: 5),
            eveningReminder: ReminderTime(hour: 21, minute: 40)
        )

        let result = await service.schedule(settings: settings)
        let snapshot = await scheduler.snapshot()

        XCTAssertEqual(result, .scheduled(ReminderService.pendingRequestIDs))
        XCTAssertEqual(snapshot.removed, [ReminderService.pendingRequestIDs])
        XCTAssertEqual(snapshot.pending.map(\.identifier), [
            "russian-corner.reminder.morning",
            "russian-corner.reminder.evening",
        ])
        XCTAssertEqual(snapshot.pending.map(\.time), settings.reminderTimes)
        XCTAssertTrue(snapshot.pending.allSatisfy(\.repeatsDaily))
        XCTAssertEqual(snapshot.pending.count, 2)
    }

    func testDeniedReminderPermissionReturnsStatusWithoutScheduling() async {
        let scheduler = FakeReminderScheduler(status: .denied)
        let service = ReminderService(scheduler: scheduler)

        let result = await service.schedule(settings: RussianCornerSettings())
        let snapshot = await scheduler.snapshot()

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertTrue(snapshot.removed.isEmpty)
        XCTAssertTrue(snapshot.pending.isEmpty)
    }

    func testSecondAddFailureRollsBackOwnPendingReminders() async {
        let oldRequests = reminderRequests(
            settings: RussianCornerSettings(
                morningReminder: ReminderTime(hour: 7, minute: 10),
                eveningReminder: ReminderTime(hour: 16, minute: 20)
            ),
            generation: "old"
        )
        let unrelated = DailyReminderRequest(
            identifier: "another-feature.reminder",
            time: ReminderTime(hour: 6, minute: 0),
            title: "Other",
            body: "Do not delete"
        )
        let scheduler = FakeReminderScheduler(
            status: .authorized,
            failingAddAttempt: 2,
            initialRequests: oldRequests + [unrelated]
        )
        let service = ReminderService(scheduler: scheduler)

        let result = await service.schedule(
            settings: RussianCornerSettings(
                morningReminder: ReminderTime(hour: 11, minute: 35),
                eveningReminder: ReminderTime(hour: 19, minute: 5)
            )
        )
        let snapshot = await scheduler.snapshot()

        guard case .failed = result else {
            return XCTFail("expected failed result, got \(result)")
        }
        XCTAssertEqual(snapshot.removed, [
            ReminderService.pendingRequestIDs,
            ReminderService.pendingRequestIDs,
        ])
        XCTAssertEqual(
            snapshot.queried,
            [ReminderService.pendingRequestIDs]
        )
        XCTAssertEqual(
            snapshot.pending.filter {
                ReminderService.pendingRequestIDs.contains($0.identifier)
            },
            oldRequests
        )
        XCTAssertTrue(snapshot.pending.contains(unrelated))
    }

    func testConcurrentSchedulesLeaveOneCompleteGeneration() async {
        let scheduler = FakeReminderScheduler(
            status: .authorized,
            suspendingAddAttempt: 2
        )
        let service = ReminderService(scheduler: scheduler)
        let firstSettings = RussianCornerSettings(
            morningReminder: ReminderTime(hour: 8, minute: 10),
            eveningReminder: ReminderTime(hour: 18, minute: 20)
        )
        let secondSettings = RussianCornerSettings(
            morningReminder: ReminderTime(hour: 9, minute: 30),
            eveningReminder: ReminderTime(hour: 20, minute: 40)
        )

        let first = Task {
            await service.schedule(settings: firstSettings)
        }
        while !(await scheduler.isAddSuspended()) {
            await Task.yield()
        }
        let second = Task {
            await service.schedule(settings: secondSettings)
        }
        for _ in 0..<100 {
            if await scheduler.removalCount() >= 2 {
                break
            }
            await Task.yield()
        }
        await scheduler.resumeSuspendedAdd()

        _ = await first.value
        _ = await second.value
        let snapshot = await scheduler.snapshot()
        let owned = snapshot.pending.filter {
            ReminderService.pendingRequestIDs.contains($0.identifier)
        }

        XCTAssertEqual(
            owned,
            reminderRequests(
                settings: secondSettings,
                generation: "new"
            )
        )
    }

    private func reminderRequests(
        settings: RussianCornerSettings,
        generation: String
    ) -> [DailyReminderRequest] {
        zip(
            ReminderService.pendingRequestIDs,
            settings.reminderTimes
        ).map { identifier, time in
            DailyReminderRequest(
                identifier: identifier,
                time: time,
                title: "Russian Corner",
                body: generation == "old"
                    ? "old generation"
                    : "该练一轮俄语主动回忆了。"
            )
        }
    }
}

private struct FixedSpeechVoiceProvider: SpeechVoiceProviding {
    let voices: [SpeechVoice]

    func availableVoices() -> [SpeechVoice] {
        voices
    }
}

@MainActor
private final class FakeSpeechSynthesizer: SpeechSynthesizing {
    private(set) var spoken: [(text: String, voiceIdentifier: String)] = []
    private(set) var stopCallCount = 0

    func speak(_ text: String, voiceIdentifier: String) {
        spoken.append((text, voiceIdentifier))
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
final class SpeechServiceTests: XCTestCase {
    func testSpeechPrefersExactRussianLocaleVoice() {
        let synthesizer = FakeSpeechSynthesizer()
        let service = SpeechService(
            voiceProvider: FixedSpeechVoiceProvider(voices: [
                SpeechVoice(identifier: "english", language: "en-US"),
                SpeechVoice(identifier: "russian", language: "ru-RU"),
                SpeechVoice(identifier: "other-russian", language: "ru-UA"),
            ]),
            synthesizer: synthesizer
        )

        let status = service.speak("Здравствуйте")

        XCTAssertEqual(status, .russianVoice(identifier: "russian"))
        XCTAssertEqual(synthesizer.spoken.first?.text, "Здравствуйте")
        XCTAssertEqual(synthesizer.spoken.first?.voiceIdentifier, "russian")
    }

    func testSpeechFallsBackSafelyWhenRussianVoiceIsMissing() {
        let synthesizer = FakeSpeechSynthesizer()
        let service = SpeechService(
            voiceProvider: FixedSpeechVoiceProvider(voices: [
                SpeechVoice(identifier: "fallback", language: "en-US"),
            ]),
            synthesizer: synthesizer
        )

        let status = service.speak("Спасибо")
        service.stop()

        XCTAssertEqual(
            status,
            .fallbackVoice(identifier: "fallback", language: "en-US")
        )
        XCTAssertEqual(synthesizer.spoken.count, 1)
        XCTAssertEqual(synthesizer.stopCallCount, 1)
    }

    func testSpeechReturnsUnavailableWithoutCrashingWhenNoVoiceExists() {
        let synthesizer = FakeSpeechSynthesizer()
        let service = SpeechService(
            voiceProvider: FixedSpeechVoiceProvider(voices: []),
            synthesizer: synthesizer
        )

        let status = service.speak("Пожалуйста")

        XCTAssertEqual(status, .unavailable)
        XCTAssertTrue(synthesizer.spoken.isEmpty)
    }
}
