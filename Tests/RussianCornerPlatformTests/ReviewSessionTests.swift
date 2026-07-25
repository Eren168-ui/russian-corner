import Foundation
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
    func makeEngine(outputURL: URL) throws -> any RecordingEngine {
        try Data("temporary audio".utf8).write(to: outputURL)
        return FakeRecordingEngine()
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

        service.discard()

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
        XCTAssertNil(service.temporaryRecordingURL)
    }

    func testExplicitSaveCopiesRecordingAndCleansTemporaryFile() async throws {
        let service = RecordingService(
            permissionProvider: FixedMicrophonePermissionProvider(
                status: .granted
            ),
            engineFactory: FakeRecordingEngineFactory()
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
    }
}

private actor FakeReminderScheduler: ReminderNotificationScheduling {
    private enum FakeError: Error {
        case addFailed
    }

    private let status: ReminderPermissionStatus
    private let failingAddAttempt: Int?
    private var removedIdentifierBatches: [[String]] = []
    private var requests: [DailyReminderRequest] = []
    private var addAttemptCount = 0

    init(
        status: ReminderPermissionStatus,
        failingAddAttempt: Int? = nil
    ) {
        self.status = status
        self.failingAddAttempt = failingAddAttempt
    }

    func authorizationStatus() async -> ReminderPermissionStatus {
        status
    }

    func requestAuthorization() async -> ReminderPermissionStatus {
        status
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        removedIdentifierBatches.append(identifiers)
        let identifierSet = Set(identifiers)
        requests.removeAll {
            identifierSet.contains($0.identifier)
        }
    }

    func add(_ request: DailyReminderRequest) async throws {
        addAttemptCount += 1
        if addAttemptCount == failingAddAttempt {
            throw FakeError.addFailed
        }
        requests.append(request)
    }

    func snapshot() -> (removed: [[String]], pending: [DailyReminderRequest]) {
        (removedIdentifierBatches, requests)
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
        let scheduler = FakeReminderScheduler(
            status: .authorized,
            failingAddAttempt: 2
        )
        let service = ReminderService(scheduler: scheduler)

        let result = await service.schedule(
            settings: RussianCornerSettings()
        )
        let snapshot = await scheduler.snapshot()

        guard case .failed = result else {
            return XCTFail("expected failed result, got \(result)")
        }
        XCTAssertEqual(snapshot.removed, [
            ReminderService.pendingRequestIDs,
            ReminderService.pendingRequestIDs,
        ])
        XCTAssertTrue(snapshot.pending.isEmpty)
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
