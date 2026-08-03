import Foundation
import RussianCornerCore
import RussianCornerPlatform
import SwiftData
import XCTest

@testable import RussianCornerUI

@MainActor
final class DiagnosticViewModelTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testObjectiveRecognitionScoresSelectedOptionAndQueuesWrongItem()
        throws
    {
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let model = try DiagnosticViewModel(
            catalog: makeMultiCatalog(count: 4),
            repository: repository,
            reviewStore: repository,
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 5,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        model.start()
        let question = try XCTUnwrap(model.currentRecognitionQuestion)
        let wrong = try XCTUnwrap(
            question.options.first { !$0.id.hasSuffix("-correct") }
        )

        model.selectRecognitionOption(wrong.id)

        XCTAssertEqual(model.step, .recognition)
        XCTAssertEqual(model.selectedOptionID, wrong.id)
        XCTAssertEqual(model.selectedChoiceWasCorrect, false)
        XCTAssertEqual(
            try repository.reviewEvents().map(\.grade),
            [.again]
        )
        XCTAssertEqual(model.reviewItemsAdded.count, 1)

        model.advanceFromChoice()
        XCTAssertEqual(model.step, .production)
    }

    func testProductionOutcomeUsesFourLevelEvidenceAndNormalScheduler()
        throws
    {
        var now = start
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let model = try DiagnosticViewModel(
            catalog: makeMultiCatalog(count: 4),
            repository: repository,
            reviewStore: repository,
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 6,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { now }
        )
        model.start()
        let recognition = try XCTUnwrap(model.currentRecognitionQuestion)
        model.selectRecognitionOption(recognition.correctOptionID)
        model.advanceFromChoice()
        now = start.addingTimeInterval(4.2)
        model.reveal()

        model.submitProduction(outcome: .partial)

        XCTAssertEqual(model.step, .listening)
        XCTAssertEqual(model.reportedProductionOutcomes, [.partial])
        XCTAssertEqual(
            try repository.reviewEvents().map(\.grade),
            [.hard]
        )
    }

    func testFastProductionNeedsObjectiveTransferAndFailedCheckIsHard()
        throws
    {
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let model = try DiagnosticViewModel(
            catalog: makeMultiCatalog(count: 4),
            repository: repository,
            reviewStore: repository,
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 61,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        model.start()
        let recognition = try XCTUnwrap(model.currentRecognitionQuestion)
        model.selectRecognitionOption(recognition.correctOptionID)
        model.advanceFromChoice()
        model.reveal()

        model.submitProduction(outcome: .completeFast)

        XCTAssertEqual(model.step, .production)
        let exercise = try XCTUnwrap(
            model.currentProductionTransferExercise
        )
        let wrong = try XCTUnwrap(
            exercise.options.first {
                $0.id != exercise.correctOptionID
            }
        )
        model.submitProductionTransfer(optionID: wrong.id)

        XCTAssertEqual(model.step, .listening)
        XCTAssertEqual(
            try repository.reviewEvents().map(\.grade),
            [.hard]
        )
    }

    func testEnglishDiagnosticUsesEnglishLabelsAndVoice() throws {
        let synthesizer = DiagnosticSpeechSynthesizer()
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: SpeechService(
                voiceProvider: DiagnosticVoiceProvider(
                    hasVoice: true,
                    language: "en-US"
                ),
                synthesizer: synthesizer
            ),
            language: .english,
            seed: 62,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )

        XCTAssertEqual(model.language, .english)
        XCTAssertEqual(model.targetLanguageNameZh, "英语")
        XCTAssertEqual(model.productionDirectionTitle, "中文 → 英语")
        advanceToListening(model)
        model.speakListeningSentence()

        XCTAssertEqual(model.currentListeningState, .played)
        XCTAssertEqual(synthesizer.requests.count, 1)
    }

    func testWizardProgressesThroughEveryMetricAndPersistsSummary() throws {
        var now = start
        let repository = ProgressRepository(
            container: try ProgressRepository.makeInMemoryContainer()
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: repository,
            activityMonitor: DiagnosticFakeActivityMonitor(),
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
        XCTAssertEqual(model.step, .oralIntroduction)
        model.skipOralActivity(selfRating: 2)
        XCTAssertEqual(model.step, .oralDailyLife)
        model.skipOralActivity(selfRating: 4)

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

    func testDeniedMicrophoneFallsBackToTimerAndSelfRating() async throws {
        let monitor = DiagnosticFakeActivityMonitor(
            startResult: .timerOnly(.permissionDenied)
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: monitor,
            speechService: makeSpeechService(),
            seed: 8,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstOral(model)

        await model.startOralActivity()

        XCTAssertEqual(model.step, .oralIntroduction)
        XCTAssertEqual(model.oralPhase, .preparing)
        XCTAssertFalse(model.oralUsesMicrophoneMeter)
        XCTAssertTrue(model.statusMessage?.contains("计时 + 自评") == true)

        for _ in 0..<3 {
            model.advanceOralClock()
        }
        XCTAssertEqual(model.oralPhase, .speaking)
        model.stopOralActivity()
        model.submitOralActivity(selfRating: 3)
        model.skipOralActivity(selfRating: 3)

        XCTAssertEqual(model.step, .summary)
        XCTAssertNotNil(model.report)
    }

    func testOralCountdownPreparesThenStopsAtSixtySeconds() async throws {
        let monitor = DiagnosticFakeActivityMonitor(
            startResult: .started,
            stopSummary: SpeechActivitySummary(
                elapsedMs: 60_000,
                estimatedSpeakingMs: 42_000,
                longPauseCount: 3,
                usedMicrophoneMeter: true
            )
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: monitor,
            speechService: makeSpeechService(),
            seed: 9,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstOral(model)

        await model.startOralActivity()
        XCTAssertEqual(model.preparationRemainingSeconds, 3)
        XCTAssertEqual(model.oralRemainingSeconds, 60)

        for _ in 0..<3 {
            model.advanceOralClock()
        }
        XCTAssertEqual(model.oralPhase, .speaking)
        for _ in 0..<60 {
            model.advanceOralClock()
        }

        XCTAssertEqual(model.oralRemainingSeconds, 0)
        XCTAssertEqual(model.oralPhase, .awaitingSelfRating)
        XCTAssertEqual(model.oralSummary?.estimatedSpeakingMs, 42_000)
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertEqual(monitor.stopCallCount, 1)
    }

    func testWindowDisappearStopsActivityWithoutCreatingSummary() async throws {
        let monitor = DiagnosticFakeActivityMonitor(
            startResult: .started
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: monitor,
            speechService: makeSpeechService(),
            seed: 11,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstOral(model)
        await model.startOralActivity()

        model.handleDisappear()

        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertEqual(monitor.stopCallCount, 1)
        XCTAssertEqual(model.step, .oralIntroduction)
        XCTAssertEqual(model.oralPhase, .ready)
        XCTAssertNil(model.oralSummary)
    }

    func testOralSelfRatingAndMeterSummaryAreSavedWithoutAudio() async throws {
        let trialRepository = TrialRepository(
            container: try TrialRepository.makeContainer(inMemory: true)
        )
        let monitor = DiagnosticFakeActivityMonitor(
            startResult: .started,
            stopSummary: SpeechActivitySummary(
                elapsedMs: 18_000,
                estimatedSpeakingMs: 12_000,
                longPauseCount: 2,
                usedMicrophoneMeter: true
            )
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: monitor,
            oralAttemptStore: trialRepository,
            speechService: makeSpeechService(),
            seed: 13,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstOral(model)
        await model.startOralActivity()
        for _ in 0..<3 {
            model.advanceOralClock()
        }
        model.stopOralActivity()
        model.submitOralActivity(selfRating: 4)

        let snapshot = try trialRepository.fetchSnapshot(
            from: start.addingTimeInterval(-1),
            through: start.addingTimeInterval(1)
        )
        let attempt = try XCTUnwrap(snapshot.oralAttempts.first)
        XCTAssertEqual(attempt.topic, "自我介绍")
        XCTAssertEqual(attempt.estimatedSpeakingMs, 12_000)
        XCTAssertEqual(attempt.longPauseCount, 2)
        XCTAssertEqual(attempt.selfRating, 4)
        XCTAssertTrue(attempt.usedMicrophoneMeter)
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
                current: baselineMetrics,
                seed: 10,
                sampleLexemeIDs: ["lexeme-1"],
                listeningSentenceIDs: ["sentence-1"]
            )
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: repository,
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 10,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToFirstOral(model)
        model.skipOralActivity(selfRating: 2)
        model.skipOralActivity(selfRating: 2)

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
        XCTAssertEqual(model.recommendedNewWordUpperLimit, 6)
        XCTAssertTrue(model.diagnosticHeadline.contains("主动提取"))
        XCTAssertTrue(
            model.sevenDayAdjustments.contains {
                $0.contains("每天最多 6 个新词")
            }
        )
        XCTAssertEqual(
            try repository.diagnosticHistory().entries.map(\.kind),
            [.baseline, .weekly]
        )
    }

    func testSaveFailureKeepsGeneratedComparisonReportVisible() throws {
        let baselineMetrics = DiagnosticMetrics(
            recognitionRate: 20,
            productionRate: 10,
            medianResponseSeconds: 5,
            listeningRate: 10,
            listeningEvidenceCount: 5,
            collocationRate: 20,
            selfMonitoringRate: 80,
            completedAt: start.addingTimeInterval(-86_400)
        )
        let baselineReport = DiagnosticEngine().report(
            baseline: baselineMetrics,
            current: baselineMetrics,
            seed: 31,
            sampleLexemeIDs: ["lexeme-1"],
            listeningSentenceIDs: ["sentence-1"]
        )
        let repository = FailingDiagnosticStore(report: baselineReport)
        var reportSaved = false
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: repository,
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 31,
            vocabularyCount: 1,
            listeningCount: 1,
            onReportSaved: {
                reportSaved = true
            },
            now: { self.start }
        )

        completeDiagnostic(model)

        XCTAssertEqual(model.report?.baseline, baselineMetrics)
        XCTAssertNotEqual(model.report?.baseline, model.report?.current)
        XCTAssertFalse(model.comparisonRows.isEmpty)
        XCTAssertTrue(model.statusMessage?.contains("保存失败") == true)
        XCTAssertFalse(reportSaved)
    }

    func testSuccessfulReportSaveInvokesRefreshCallback() throws {
        var reportSaved = false
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 310,
            vocabularyCount: 1,
            listeningCount: 1,
            onReportSaved: {
                reportSaved = true
            },
            now: { self.start }
        )

        completeDiagnostic(model)

        XCTAssertTrue(reportSaved)
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
        XCTAssertEqual(runtime.diagnosticHistoryIssueCount, 1)
        XCTAssertEqual(runtime.diagnostics?.historyIssueCount, 1)
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
        XCTAssertEqual(
            RussianCornerDiagnosticView.diagnosticSchedulingNotice,
            "下次日队列会应用该诊断；手动练习模式优先。"
        )
        XCTAssertGreaterThanOrEqual(
            RussianCornerDiagnosticView.startButtonMinimumHeight,
            50
        )
        XCTAssertEqual(
            RussianCornerDiagnosticView.autoAdvanceDelayMilliseconds,
            1_200
        )
        XCTAssertTrue(
            RussianCornerDiagnosticView.introPurpose.contains("5–8 分钟")
        )
        XCTAssertEqual(
            RussianCornerDiagnosticView.productionOutcomeTitles,
            [
                "3 秒内完整说出",
                "核心说出，词形或搭配不准",
                "揭晓后才想起来",
                "完全不会",
            ]
        )
    }

    func testDefaultDiagnosticRecommendationUsesTenNewWords() throws {
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 312,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )

        XCTAssertEqual(model.recommendedNewWordUpperLimit, 10)
    }

    func testListeningCannotBeScoredUntilPlaybackActuallyFinishes() throws {
        let synthesizer = DiagnosticSpeechSynthesizer(
            automaticallyFinishes: false
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(synthesizer: synthesizer),
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
        XCTAssertEqual(model.currentListeningState, .playing)
        model.submitListening(understood: true)
        XCTAssertEqual(model.step, .listening)

        synthesizer.finish(0)
        XCTAssertEqual(model.currentListeningState, .played)
        model.submitListening(understood: true)
        XCTAssertEqual(model.step, .collocation)
    }

    func testCancelledListeningPlaybackNeverBecomesEvidence() throws {
        let synthesizer = DiagnosticSpeechSynthesizer(
            automaticallyFinishes: false
        )
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(synthesizer: synthesizer),
            seed: 131,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToListening(model)

        model.speakListeningSentence()
        synthesizer.cancel(0)

        XCTAssertNotEqual(model.currentListeningState, .played)
        model.submitListening(understood: true)
        XCTAssertEqual(model.step, .listening)
    }

    func testLateCompletionFromSkippedSentenceCannotUnlockNextSentence() throws {
        let synthesizer = DiagnosticSpeechSynthesizer(
            automaticallyFinishes: false
        )
        let model = try DiagnosticViewModel(
            catalog: makeMultiCatalog(count: 2),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(synthesizer: synthesizer),
            seed: 132,
            vocabularyCount: 1,
            listeningCount: 2,
            now: { self.start }
        )
        advanceToListening(model)

        let firstID = model.currentListeningSentence?.id
        model.speakListeningSentence()
        model.skipListening()
        let secondID = model.currentListeningSentence?.id
        model.speakListeningSentence()

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(model.currentListeningState, .playing)

        synthesizer.finish(0)
        XCTAssertEqual(model.currentListeningState, .playing)

        synthesizer.finish(1)
        XCTAssertEqual(model.currentListeningState, .played)
    }

    func testSkippingAndLeavingDiagnosticStopCurrentSpeech() throws {
        let synthesizer = DiagnosticSpeechSynthesizer(
            automaticallyFinishes: false
        )
        let model = try DiagnosticViewModel(
            catalog: makeMultiCatalog(count: 2),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(synthesizer: synthesizer),
            seed: 133,
            vocabularyCount: 1,
            listeningCount: 2,
            now: { self.start }
        )
        advanceToListening(model)

        model.speakListeningSentence()
        let stopsAfterSpeak = synthesizer.stopCallCount
        model.skipListening()
        XCTAssertEqual(synthesizer.stopCallCount, stopsAfterSpeak + 1)

        model.speakListeningSentence()
        let stopsBeforeDisappear = synthesizer.stopCallCount
        model.handleDisappear()
        XCTAssertEqual(
            synthesizer.stopCallCount,
            stopsBeforeDisappear + 1
        )
        synthesizer.finish(1)
        XCTAssertEqual(model.currentListeningState, .notPlayed)
    }

    func testUnavailableListeningCanBeSkippedWithoutEnteringEvidenceRate() throws {
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
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
        model.skipOralActivity(selfRating: 4)
        model.skipOralActivity(selfRating: 4)

        XCTAssertEqual(model.report?.current.listeningEvidenceCount, 0)
        XCTAssertFalse(
            model.report?.findings.contains {
                $0.type == .listeningGap
            } ?? true
        )
        XCTAssertEqual(model.listeningEvidenceSummary, "证据不足 0/10")
        XCTAssertFalse(
            model.comparisonRows.contains { $0.label == "听句理解" }
        )
    }

    func testNonRussianFallbackVoiceIsNotAcceptedAsListeningEvidence() throws {
        let synthesizer = DiagnosticSpeechSynthesizer()
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: SpeechService(
                voiceProvider: DiagnosticVoiceProvider(
                    hasVoice: true,
                    language: "en-US"
                ),
                synthesizer: synthesizer
            ),
            seed: 141,
            vocabularyCount: 1,
            listeningCount: 1,
            now: { self.start }
        )
        advanceToListening(model)

        model.speakListeningSentence()

        XCTAssertEqual(model.currentListeningState, .unavailable)
        XCTAssertTrue(model.statusMessage?.contains("en-US") == true)
        XCTAssertTrue(synthesizer.requests.isEmpty)
        model.submitListening(understood: true)
        XCTAssertEqual(model.step, .listening)
        model.skipListening()
        XCTAssertEqual(model.step, .collocation)
    }

    func testEmptyCatalogRefusesToStartWithExplicitError() throws {
        let model = try DiagnosticViewModel(
            catalog: ContentCatalog(lexemes: [], sentences: []),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 15,
            now: { self.start }
        )

        model.start()

        XCTAssertEqual(model.step, .intro)
        XCTAssertFalse(model.canStart)
        XCTAssertTrue(model.startBlockReason?.contains("没有可用") == true)
        XCTAssertTrue(model.statusMessage?.contains("没有可用") == true)
        XCTAssertNil(model.report)
    }

    func testNaNCollocationRateIsRejectedWithoutAdvancing() throws {
        let model = try DiagnosticViewModel(
            catalog: makeCatalog(),
            repository: ProgressRepository(
                container: try ProgressRepository.makeInMemoryContainer()
            ),
            activityMonitor: DiagnosticFakeActivityMonitor(),
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
            activityMonitor: DiagnosticFakeActivityMonitor(),
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
            activityMonitor: DiagnosticFakeActivityMonitor(),
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
            activityMonitor: DiagnosticFakeActivityMonitor(),
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
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 999,
            vocabularyCount: 3,
            listeningCount: 3,
            now: { self.start }
        )
        let second = try DiagnosticViewModel(
            catalog: reducedCatalog,
            repository: ProgressRepository(container: repository.container),
            activityMonitor: DiagnosticFakeActivityMonitor(),
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

        completeDiagnostic(first)
        XCTAssertEqual(first.report?.comparisonStatus, .sampleChanged)
        XCTAssertNil(first.report?.deltas)
        XCTAssertEqual(first.comparisonNotice, "题目变化，本次重建基线")
        XCTAssertEqual(
            try repository.diagnosticHistory().entries.map(\.kind),
            [.baseline, .baseline]
        )

        let next = try DiagnosticViewModel(
            catalog: reducedCatalog,
            repository: repository,
            activityMonitor: DiagnosticFakeActivityMonitor(),
            speechService: makeSpeechService(),
            seed: 5,
            vocabularyCount: 3,
            listeningCount: 3,
            now: { self.start.addingTimeInterval(14 * 86_400) }
        )
        XCTAssertFalse(next.sampleWasRepaired)
        XCTAssertEqual(next.sample, first.sample)
    }

    private func advanceToFirstOral(_ model: DiagnosticViewModel) {
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
        model.skipOralActivity(selfRating: 4)
        model.skipOralActivity(selfRating: 4)
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

    private func makeSpeechService(
        synthesizer: DiagnosticSpeechSynthesizer =
            DiagnosticSpeechSynthesizer()
    ) -> SpeechService {
        SpeechService(
            voiceProvider: DiagnosticVoiceProvider(hasVoice: true),
            synthesizer: synthesizer
        )
    }

    private func makeUnavailableSpeechService() -> SpeechService {
        SpeechService(
            voiceProvider: DiagnosticVoiceProvider(hasVoice: false),
            synthesizer: DiagnosticSpeechSynthesizer()
        )
    }

    private func makeFallbackSpeechService() -> SpeechService {
        SpeechService(
            voiceProvider: DiagnosticVoiceProvider(
                hasVoice: true,
                language: "en-US"
            ),
            synthesizer: DiagnosticSpeechSynthesizer()
        )
    }
}

@MainActor
private final class DiagnosticFakeActivityMonitor:
    SpeechActivityMonitoring
{
    private(set) var isMonitoring = false
    let startResult: SpeechActivityStartResult
    let stopSummary: SpeechActivitySummary?
    private(set) var stopCallCount = 0

    init(
        startResult: SpeechActivityStartResult =
            .timerOnly(.unavailable),
        stopSummary: SpeechActivitySummary? = nil
    ) {
        self.startResult = startResult
        self.stopSummary = stopSummary
    }

    func start() async -> SpeechActivityStartResult {
        if startResult == .started {
            isMonitoring = true
        }
        return startResult
    }

    func stop() -> SpeechActivitySummary? {
        guard isMonitoring else {
            return nil
        }
        stopCallCount += 1
        isMonitoring = false
        return stopSummary
    }
}

private enum DiagnosticFixtureError: Error {
    case persistenceFailed
}

@MainActor
private final class FailingDiagnosticStore: DiagnosticReportStoring {
    private let report: DiagnosticReport

    init(report: DiagnosticReport) {
        self.report = report
    }

    func saveDiagnosticReport(_ report: DiagnosticReport) throws {
        throw DiagnosticFixtureError.persistenceFailed
    }

    func diagnosticHistory() throws -> DiagnosticHistorySnapshot {
        DiagnosticHistorySnapshot(
            entries: [
                DiagnosticHistoryEntry(
                    id: UUID(),
                    kind: .baseline,
                    report: report
                )
            ],
            issueCount: 0
        )
    }

    func baselineDiagnosticReport() throws -> DiagnosticReport? {
        report
    }

    func latestDiagnosticReport() throws -> DiagnosticReport? {
        report
    }
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
    var language = "ru-RU"

    func availableVoices() -> [SpeechVoice] {
        hasVoice
            ? [SpeechVoice(identifier: "voice-fixture", language: language)]
            : []
    }
}

@MainActor
private final class DiagnosticSpeechSynthesizer: SpeechSynthesizing {
    struct Request {
        let text: String
        let voiceIdentifier: String
        let completion: @MainActor @Sendable (SpeechSynthesisOutcome) -> Void
    }

    let automaticallyFinishes: Bool
    private(set) var requests: [Request] = []
    private(set) var stopCallCount = 0

    init(automaticallyFinishes: Bool = true) {
        self.automaticallyFinishes = automaticallyFinishes
    }

    func speak(
        _ text: String,
        voiceIdentifier: String,
        completion: @escaping @MainActor @Sendable (
            SpeechSynthesisOutcome
        ) -> Void
    ) {
        requests.append(
            Request(
                text: text,
                voiceIdentifier: voiceIdentifier,
                completion: completion
            )
        )
        if automaticallyFinishes {
            completion(.finished)
        }
    }

    func stop() {
        stopCallCount += 1
    }

    func finish(_ index: Int) {
        requests[index].completion(.finished)
    }

    func cancel(_ index: Int) {
        requests[index].completion(.cancelled)
    }
}
