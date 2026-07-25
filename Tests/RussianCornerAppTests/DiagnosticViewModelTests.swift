import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
final class DiagnosticViewModelTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testWizardProgressesThroughEveryMetricAndPersistsSummary() throws {
        var now = start
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: repository,
            recordingService: DiagnosticFakeRecordingService(),
            seed: 7,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { now }
        )

        XCTAssertEqual(model.step, .intro)
        model.start()
        XCTAssertEqual(model.step, .recognition)

        model.reveal()
        model.submitRecognition(correct: true)
        XCTAssertEqual(model.step, .production)

        now = start.addingTimeInterval(2.4)
        model.reveal()
        model.submitProduction(correct: false)
        XCTAssertEqual(model.step, .listening)

        model.submitListening(understood: true)
        XCTAssertEqual(model.step, .collocation)

        model.submitCollocation(rate: 50)
        XCTAssertEqual(model.step, .recordingIntroduction)
        model.skipRecording(selfMonitoring: true)
        XCTAssertEqual(model.step, .recordingDailyLife)
        model.skipRecording(selfMonitoring: false)

        XCTAssertEqual(model.step, .summary)
        XCTAssertEqual(model.report?.current.recognitionRate, 100)
        XCTAssertEqual(model.report?.current.productionRate, 0)
        XCTAssertEqual(
            try XCTUnwrap(model.report?.current.medianResponseSeconds),
            2.4,
            accuracy: 0.001
        )
        XCTAssertEqual(model.report?.current.listeningRate, 100)
        XCTAssertEqual(model.report?.current.collocationRate, 50)
        XCTAssertEqual(model.report?.current.selfMonitoringRate, 50)
        XCTAssertEqual(
            try repository.diagnosticHistory().map(\.kind),
            [.baseline]
        )
    }

    func testSkippingMicrophoneNeverBlocksAndDeniedStartCanBeSkipped() async throws {
        let recording = DiagnosticFakeRecordingService(
            startResult: .permissionDenied
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: recording,
            seed: 8,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstRecording(model)

        await model.toggleRecording()

        XCTAssertEqual(model.step, .recordingIntroduction)
        XCTAssertTrue(model.statusMessage?.contains("仍可跳过") == true)

        model.skipRecording(selfMonitoring: false)
        model.skipRecording(selfMonitoring: false)

        XCTAssertEqual(model.step, .summary)
        XCTAssertNotNil(model.report)
    }

    func testRecordingCountdownStartsAtSixtyAndStopsAtZero() async throws {
        var now = start
        let recording = DiagnosticFakeRecordingService(
            startResult: .started(
                URL(fileURLWithPath: "/tmp/diagnostic-fixture.m4a")
            )
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: recording,
            seed: 9,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { now }
        )
        advanceToFirstRecording(model)

        await model.toggleRecording()
        XCTAssertEqual(model.recordingRemainingSeconds, 60)

        now = start.addingTimeInterval(61)
        model.refreshRecordingTimer()

        XCTAssertEqual(model.recordingRemainingSeconds, 0)
        XCTAssertFalse(recording.isRecording)
    }

    func testWeeklyRunUsesStoredBaselineAndExposesTrainingSuggestionsWithoutChangingScheduler() throws {
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let baselineMetrics = DiagnosticMetrics(
            recognitionRate: 80,
            productionRate: 40,
            medianResponseSeconds: 4,
            listeningRate: 50,
            collocationRate: 55,
            selfMonitoringRate: 70,
            completedAt: start.addingTimeInterval(-7 * 86_400)
        )
        try repository.saveDiagnosticReport(
            DiagnosticEngine().report(
                baseline: baselineMetrics,
                current: baselineMetrics
            )
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: repository,
            recordingService: DiagnosticFakeRecordingService(),
            seed: 10,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstRecording(model)
        model.skipRecording(selfMonitoring: true)
        model.skipRecording(selfMonitoring: true)

        XCTAssertEqual(model.report?.baseline, baselineMetrics)
        XCTAssertFalse(model.comparisonRows.isEmpty)
        XCTAssertTrue(
            model.comparisonRows.contains {
                $0.label == "认词" && $0.value.contains("百分点")
            }
        )
        XCTAssertTrue(
            model.comparisonRows.contains {
                $0.label == "回答中位数" && $0.value.contains("秒")
            }
        )
        XCTAssertTrue(
            model.trainingSuggestions.contains {
                $0.contains("中文到俄语")
            }
        )
        XCTAssertLessThanOrEqual(model.recommendedNewWordUpperLimit, 7)
        XCTAssertEqual(
            try repository.diagnosticHistory().map(\.kind),
            [.baseline, .weekly]
        )
    }

    func testDiagnosticViewStatesPronunciationBoundaryExplicitly() {
        let disclaimer = RussianCornerDiagnosticView.pronunciationDisclaimer

        XCTAssertTrue(disclaimer.contains("老师"))
        XCTAssertTrue(disclaimer.contains("母语者"))
        XCTAssertTrue(disclaimer.contains("二期 AI"))
        XCTAssertFalse(disclaimer.contains("自动判断发音"))
    }

    private func advanceToFirstRecording(_ model: DiagnosticViewModel) {
        model.start()
        model.reveal()
        model.submitRecognition(correct: true)
        model.reveal()
        model.submitProduction(correct: false)
        model.submitListening(understood: false)
        model.submitCollocation(rate: 50)
    }

    private func makeCatalog() -> ContentCatalog {
        let sentence = SentenceCard(
            id: "sentence-1",
            promptZh: "说：我在学习。",
            cueRu: "Что вы делаете?",
            practiceRu: "Я учусь.",
            speechText: "Я учусь.",
            theme: "学习",
            lexemeIDs: ["lexeme-1"],
            sourcePath: "fixture.md",
            sourceText: "fixture",
            reviewStatus: .reviewed
        )
        let lexeme = Lexeme(
            id: "lexeme-1",
            lemma: "учиться",
            stressedForm: "учи́ться",
            speechText: "учиться",
            partOfSpeech: "verb",
            glossZh: "学习",
            collocations: ["учиться в школе"],
            example: "Я учусь.",
            sentenceIDs: ["sentence-1"],
            reviewStatus: .reviewed
        )
        return ContentCatalog(lexemes: [lexeme], sentences: [sentence])
    }
}

@MainActor
private final class DiagnosticFakeRecordingService: RecordingManaging {
    var isRecording = false
    var temporaryRecordingURL: URL?
    let startResult: RecordingStartResult

    init(startResult: RecordingStartResult = .unavailable) {
        self.startResult = startResult
    }

    func permissionStatus() -> MicrophonePermissionStatus {
        .denied
    }

    func requestPermission() async -> MicrophonePermissionStatus {
        .denied
    }

    func start() async -> RecordingStartResult {
        if case let .started(url) = startResult {
            isRecording = true
            temporaryRecordingURL = url
        }
        return startResult
    }

    func stop() {
        isRecording = false
    }

    func discard() throws {
        isRecording = false
        temporaryRecordingURL = nil
    }

    func save(to destinationURL: URL) throws -> RecordingSaveOutcome {
        .saved(
            destinationURL: destinationURL,
            temporaryCleanupPending: false
        )
    }
}
