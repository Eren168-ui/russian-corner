import Foundation
import RussianCornerCore
import RussianCornerPlatform
import SwiftData
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
            speechService: makeSpeechService(),
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

        model.speakListeningSentence()
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
            try repository.diagnosticHistory().entries.map(\.kind),
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
            speechService: makeSpeechService(),
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
        let sleeper = ControlledDiagnosticSleeper()
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
            speechService: makeSpeechService(),
            seed: 9,
            vocabularyCount: 1,
            listeningCount: 1,
            sleeper: sleeper,
            now: { now }
        )
        advanceToFirstRecording(model)

        await model.toggleRecording()
        XCTAssertEqual(model.recordingRemainingSeconds, 60)

        now = start.addingTimeInterval(61)
        await Task.yield()
        await sleeper.resume()
        for _ in 0..<100 where model.recordingRemainingSeconds != 0 {
            await Task.yield()
        }

        XCTAssertEqual(model.recordingRemainingSeconds, 0)
        XCTAssertFalse(recording.isRecording)
        XCTAssertEqual(recording.stopCallCount, 1)
    }

    func testWindowDisappearCancelsTimerStopsAndDiscardsRecording() async throws {
        let sleeper = ControlledDiagnosticSleeper()
        let recording = DiagnosticFakeRecordingService(
            startResult: .started(
                URL(fileURLWithPath: "/tmp/diagnostic-close.m4a")
            )
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: recording,
            speechService: makeSpeechService(),
            seed: 11,
            vocabularyCount: 1,
            listeningCount: 1,
            sleeper: sleeper,
            now: { self.start }
        )
        advanceToFirstRecording(model)
        await model.toggleRecording()

        model.handleDisappear()

        XCTAssertFalse(recording.isRecording)
        XCTAssertEqual(recording.discardCallCount, 1)
        XCTAssertEqual(model.step, .recordingIntroduction)
    }

    func testDiscardFailureKeepsRecordingStepForRetry() throws {
        let recording = DiagnosticFakeRecordingService()
        recording.discardShouldFail = true
        recording.temporaryRecordingURL = URL(
            fileURLWithPath: "/tmp/diagnostic-retry.m4a"
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: recording,
            speechService: makeSpeechService(),
            seed: 12,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstRecording(model)

        model.skipRecording(selfMonitoring: false)

        XCTAssertEqual(model.step, .recordingIntroduction)
        XCTAssertTrue(model.statusMessage?.contains("清理失败") == true)
        XCTAssertEqual(recording.discardCallCount, 1)
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
            speechService: makeSpeechService(),
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
        XCTAssertEqual(
            model.comparisonRows.first {
                $0.label == "认词"
            }?.trend,
            .improvement
        )
        XCTAssertEqual(
            model.comparisonRows.first {
                $0.label == "回答中位数"
            }?.trend,
            .improvement
        )
        XCTAssertEqual(
            model.comparisonRows.first {
                $0.label == "卡顿/过度检查自评"
            }?.trend,
            .regression
        )
        XCTAssertTrue(
            model.trainingSuggestions.contains {
                $0.contains("中文到俄语")
            }
        )
        XCTAssertLessThanOrEqual(model.recommendedNewWordUpperLimit, 7)
        XCTAssertEqual(
            try repository.diagnosticHistory().entries.map(\.kind),
            [.baseline, .weekly]
        )
    }

    func testCorruptDiagnosticHistoryDoesNotBlockRuntimePracticeOrSettings() throws {
        let container = try ProgressRepository.makeInMemoryContainer()
        let repository = ProgressRepository(container: container)
        try repository.save(
            settings: RussianCornerSettings(
                morningReminder: ReminderTime(hour: 8, minute: 20),
                eveningReminder: ReminderTime(hour: 19, minute: 10)
            )
        )
        let metrics = DiagnosticMetrics(
            recognitionRate: 70,
            productionRate: 60,
            medianResponseSeconds: 2,
            listeningRate: 60,
            collocationRate: 60,
            selfMonitoringRate: 20,
            completedAt: start
        )
        let corrupt = try DiagnosticReportRecord(
            kind: .baseline,
            report: DiagnosticEngine().report(
                baseline: metrics,
                current: metrics
            )
        )
        corrupt.reportJSON = Data("broken".utf8)
        let context = ModelContext(container)
        context.insert(corrupt)
        try context.save()
        let suiteName = "DiagnosticRuntimeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let runtime = AppRuntime(
            defaults: defaults,
            catalog: makeCatalog(),
            repository: repository,
            enableSystemReminders: false
        )

        XCTAssertNotNil(runtime.practice)
        XCTAssertNotNil(runtime.diagnostics)
        XCTAssertNil(runtime.launchError)
        XCTAssertEqual(runtime.appModel.morningReminder.hour, 8)
    }

    func testDiagnosticViewStatesPronunciationBoundaryExplicitly() {
        let disclaimer = RussianCornerDiagnosticView.pronunciationDisclaimer

        XCTAssertTrue(disclaimer.contains("老师"))
        XCTAssertTrue(disclaimer.contains("母语者"))
        XCTAssertTrue(disclaimer.contains("二期 AI"))
        XCTAssertFalse(disclaimer.contains("自动判断发音"))
    }

    func testDiagnosticViewAccessibilityAndTrendLabelsAreExplicit() {
        XCTAssertGreaterThanOrEqual(
            RussianCornerDiagnosticView.minimumSize.width,
            520
        )
        XCTAssertGreaterThanOrEqual(
            RussianCornerDiagnosticView.minimumSize.height,
            480
        )
        XCTAssertEqual(
            RussianCornerDiagnosticView.collocationAccessibilityLabel,
            "常用搭配把握度"
        )
        XCTAssertEqual(
            RussianCornerDiagnosticView.trendLabel(.improvement),
            "改善"
        )
        XCTAssertEqual(
            RussianCornerDiagnosticView.trendLabel(.regression),
            "需关注"
        )
        XCTAssertEqual(
            RussianCornerDiagnosticView.trendLabel(.unchanged),
            "持平"
        )
    }

    func testListeningCannotBeScoredBeforeSuccessfulPlayback() throws {
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 13,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToListening(model)

        XCTAssertEqual(model.currentListeningState, .notPlayed)
        model.submitListening(understood: true)
        XCTAssertEqual(model.step, .listening)

        model.speakListeningSentence()
        XCTAssertEqual(model.currentListeningState, .played)
        model.submitListening(understood: true)
        XCTAssertEqual(model.step, .collocation)
    }

    func testUnavailableListeningCanBeSkippedWithoutEnteringEvidenceRate() throws {
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeUnavailableSpeechService(),
            seed: 14,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToListening(model)

        model.speakListeningSentence()
        XCTAssertEqual(model.currentListeningState, .unavailable)
        model.skipListening()
        XCTAssertEqual(model.step, .collocation)
        model.submitCollocation(rate: 50)
        model.skipRecording(selfMonitoring: false)
        model.skipRecording(selfMonitoring: false)

        XCTAssertEqual(model.report?.current.listeningEvidenceCount, 0)
        XCTAssertFalse(
            model.report?.findings.contains {
                $0.type == .listeningGap
            } ?? true
        )
    }

    func testEmptyCatalogRefusesToStartWithExplicitError() throws {
        let model = try DiagnosticViewModel(
            catalog: ContentCatalog(lexemes: [], sentences: []),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 15,
            now: { self.start }
        )

        model.start()

        XCTAssertEqual(model.step, .intro)
        XCTAssertFalse(model.canStart)
        XCTAssertTrue(model.statusMessage?.contains("没有可用") == true)
        XCTAssertNil(model.report)
    }

    func testNaNCollocationRateIsRejectedWithoutAdvancing() throws {
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 16,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToListening(model)
        model.speakListeningSentence()
        model.submitListening(understood: true)

        model.submitCollocation(rate: .nan)

        XCTAssertEqual(model.step, .collocation)
        XCTAssertTrue(model.statusMessage?.contains("有效") == true)
    }

    func testRestartedWeeklyRunReusesBaselineSeedAndSampleOrder() throws {
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let catalog = makeMultiCatalog(count: 4)
        let baseline = try DiagnosticViewModel(
            catalog: catalog,
            repository: repository,
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 123,
            vocabularyCount: 3,
            listeningCount: 3,
            now: { self.start }
        )
        completeDiagnostic(baseline)
        let baselineReport = try XCTUnwrap(baseline.report)

        let weekly = try DiagnosticViewModel(
            catalog: catalog,
            repository: ProgressRepository(container: repository.container),
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 999,
            vocabularyCount: 3,
            listeningCount: 3,
            now: { self.start.addingTimeInterval(7 * 86_400) }
        )

        XCTAssertEqual(weekly.seed, 123)
        XCTAssertEqual(
            weekly.sample.recognition.map(\.id),
            baselineReport.sampleLexemeIDs
        )
        XCTAssertEqual(
            weekly.sample.production.map(\.id),
            baselineReport.sampleLexemeIDs
        )
        XCTAssertEqual(
            weekly.sample.listening.map(\.id),
            baselineReport.listeningSentenceIDs
        )
        XCTAssertFalse(weekly.sampleWasRepaired)
    }

    func testMissingBaselineItemsAreDeterministicallyRepairedAndMarked() throws {
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let catalog = makeMultiCatalog(count: 5)
        let baseline = try DiagnosticViewModel(
            catalog: catalog,
            repository: repository,
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 222,
            vocabularyCount: 3,
            listeningCount: 3,
            now: { self.start }
        )
        completeDiagnostic(baseline)
        let report = try XCTUnwrap(baseline.report)
        let missingLexemeID = try XCTUnwrap(report.sampleLexemeIDs.first)
        let missingSentenceID = try XCTUnwrap(
            report.listeningSentenceIDs.first
        )
        let reducedCatalog = ContentCatalog(
            lexemes: catalog.lexemes.filter { $0.id != missingLexemeID },
            sentences: catalog.sentences.filter {
                $0.id != missingSentenceID
            }
        )

        let first = try DiagnosticViewModel(
            catalog: reducedCatalog,
            repository: repository,
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 999,
            vocabularyCount: 3,
            listeningCount: 3,
            now: { self.start }
        )
        let second = try DiagnosticViewModel(
            catalog: reducedCatalog,
            repository: ProgressRepository(container: repository.container),
            recordingService: DiagnosticFakeRecordingService(),
            speechService: makeSpeechService(),
            seed: 1,
            vocabularyCount: 3,
            listeningCount: 3,
            now: { self.start }
        )

        XCTAssertTrue(first.sampleWasRepaired)
        XCTAssertEqual(first.sample.recognition.count, 3)
        XCTAssertEqual(first.sample.listening.count, 3)
        XCTAssertFalse(
            first.sample.recognition.map(\.id).contains(missingLexemeID)
        )
        XCTAssertFalse(
            first.sample.listening.map(\.id).contains(missingSentenceID)
        )
        XCTAssertEqual(first.sample, second.sample)
    }

    private func advanceToFirstRecording(_ model: DiagnosticViewModel) {
        advanceToListening(model)
        model.speakListeningSentence()
        model.submitListening(understood: false)
        model.submitCollocation(rate: 50)
    }

    private func advanceToListening(_ model: DiagnosticViewModel) {
        model.start()
        model.reveal()
        model.submitRecognition(correct: true)
        model.reveal()
        model.submitProduction(correct: false)
    }

    private func completeDiagnostic(_ model: DiagnosticViewModel) {
        model.start()
        while model.step == .recognition {
            model.reveal()
            model.submitRecognition(correct: true)
        }
        while model.step == .production {
            model.reveal()
            model.submitProduction(correct: true)
        }
        while model.step == .listening {
            model.speakListeningSentence()
            model.submitListening(understood: true)
        }
        model.submitCollocation(rate: 70)
        model.skipRecording(selfMonitoring: false)
        model.skipRecording(selfMonitoring: false)
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

    private func makeMultiCatalog(count: Int) -> ContentCatalog {
        let sentences = (0..<count).map { index in
            SentenceCard(
                id: "sentence-\(index)",
                promptZh: "中文 \(index)",
                cueRu: "Подсказка \(index)",
                practiceRu: "Фраза \(index)",
                speechText: "Фраза \(index)",
                theme: "主题 \(index)",
                lexemeIDs: ["lexeme-\(index)"],
                sourcePath: "fixture.md",
                sourceText: "fixture",
                reviewStatus: .reviewed
            )
        }
        let lexemes = (0..<count).map { index in
            Lexeme(
                id: "lexeme-\(index)",
                lemma: "слово\(index)",
                stressedForm: "сло́во\(index)",
                speechText: "слово\(index)",
                partOfSpeech: "noun",
                glossZh: "词 \(index)",
                collocations: ["слово\(index) рядом"],
                example: "Это слово\(index).",
                sentenceIDs: ["sentence-\(index)"],
                reviewStatus: .reviewed
            )
        }
        return ContentCatalog(lexemes: lexemes, sentences: sentences)
    }

    private func makeSpeechService() -> SpeechService {
        SpeechService(
            voiceProvider: DiagnosticVoiceProvider(hasVoice: true),
            synthesizer: DiagnosticSpeechSynthesizer()
        )
    }

    private func makeUnavailableSpeechService() -> SpeechService {
        SpeechService(
            voiceProvider: DiagnosticVoiceProvider(hasVoice: false),
            synthesizer: DiagnosticSpeechSynthesizer()
        )
    }
}

@MainActor
private final class DiagnosticFakeRecordingService: RecordingManaging {
    var isRecording = false
    var temporaryRecordingURL: URL?
    let startResult: RecordingStartResult
    var discardShouldFail = false
    private(set) var stopCallCount = 0
    private(set) var discardCallCount = 0

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
        stopCallCount += 1
        isRecording = false
    }

    func discard() throws {
        discardCallCount += 1
        if discardShouldFail {
            throw DiagnosticRecordingFixtureError.discardFailed
        }
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

private enum DiagnosticRecordingFixtureError: Error {
    case discardFailed
}

private actor ControlledDiagnosticSleeper: DiagnosticSleeping {
    private var continuation: CheckedContinuation<Void, Error>?
    private var hasPendingTick = false

    func sleep() async throws {
        if hasPendingTick {
            hasPendingTick = false
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        if let continuation {
            continuation.resume()
            self.continuation = nil
        } else {
            hasPendingTick = true
        }
    }
}

private struct DiagnosticVoiceProvider: SpeechVoiceProviding {
    let hasVoice: Bool

    func availableVoices() -> [SpeechVoice] {
        hasVoice
            ? [SpeechVoice(identifier: "ru-fixture", language: "ru-RU")]
            : []
    }
}

@MainActor
private final class DiagnosticSpeechSynthesizer: SpeechSynthesizing {
    func speak(_ text: String, voiceIdentifier: String) {}
    func stop() {}
}
