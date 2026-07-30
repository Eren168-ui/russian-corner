import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

public protocol DiagnosticSleeping: Sendable {
    func sleep() async throws
}

public struct SystemDiagnosticSleeper: DiagnosticSleeping {
    public init() {}

    public func sleep() async throws {
        try await Task.sleep(for: .seconds(1))
    }
}

public enum DiagnosticStep:
    Int,
    CaseIterable,
    Equatable,
    Sendable
{
    case intro
    case recognition
    case production
    case listening
    case collocation
    case oralIntroduction
    case oralDailyLife
    case summary

    public var title: String {
        switch self {
        case .intro: "说明"
        case .recognition: "认词"
        case .production: "中文 → 俄语"
        case .listening: "听句"
        case .collocation: "搭配自评"
        case .oralIntroduction: "60 秒自我介绍"
        case .oralDailyLife: "60 秒日常生活口述"
        case .summary: "诊断总结"
        }
    }
}

public enum ListeningEvidenceState: Equatable, Sendable {
    case notPlayed
    case playing
    case played
    case unavailable
    case skipped
}

public enum DiagnosticTrend: Equatable, Sendable {
    case improvement
    case regression
    case unchanged
}

public enum DiagnosticOralPhase: Equatable, Sendable {
    case ready
    case preparing
    case speaking
    case awaitingSelfRating
}

public struct DiagnosticComparisonRow: Equatable, Sendable {
    public let label: String
    public let value: String
    public let trend: DiagnosticTrend

    public init(
        label: String,
        value: String,
        trend: DiagnosticTrend
    ) {
        self.label = label
        self.value = value
        self.trend = trend
    }
}

public struct DiagnosticReviewItem:
    Identifiable,
    Equatable,
    Sendable
{
    public let id: String
    public let itemKind: PracticeItemKind
    public let itemID: String
    public let label: String
    public let grade: ReviewGrade

    public init(
        itemKind: PracticeItemKind,
        itemID: String,
        label: String,
        grade: ReviewGrade
    ) {
        id = "\(itemKind.rawValue)-\(itemID)-\(grade.rawValue)"
        self.itemKind = itemKind
        self.itemID = itemID
        self.label = label
        self.grade = grade
    }
}

@MainActor
@Observable
public final class DiagnosticViewModel {
    public private(set) var step: DiagnosticStep = .intro
    public private(set) var isRevealed = false
    public private(set) var preparationRemainingSeconds = 3
    public private(set) var oralRemainingSeconds = 60
    public private(set) var oralPhase: DiagnosticOralPhase = .ready
    public private(set) var oralSummary: SpeechActivitySummary?
    public private(set) var oralUsesMicrophoneMeter = false
    public private(set) var report: DiagnosticReport?
    public private(set) var statusMessage: String?
    public private(set) var selectedOptionID: String?
    public private(set) var selectedChoiceWasCorrect: Bool?
    public private(set) var reviewItemsAdded: [DiagnosticReviewItem] = []
    public private(set) var reportedProductionOutcomes:
        [DiagnosticProductionOutcome] = []

    public let sample: DiagnosticSample
    public let seed: UInt64
    public let sampleWasRepaired: Bool
    public let historyIssueCount: Int

    private let repository: any DiagnosticReportStoring
    private let reviewStore: (any PracticeProgressStoring)?
    private let comparisonBaselineMetrics: DiagnosticMetrics?
    private let activityMonitor: any SpeechActivityMonitoring
    private let oralAttemptStore: (any TrialDataStoring)?
    private let speechService: SpeechService
    private let sleeper: any DiagnosticSleeping
    private let onReportSaved: (@MainActor () -> Void)?
    private let now: () -> Date
    private let catalog: ContentCatalog
    private let questionBuilder: DiagnosticQuestionBuilder
    private let scheduler = ReviewScheduler()
    private let calendar = Calendar.current
    private var recognitionIndex = 0
    private var productionIndex = 0
    private var listeningIndex = 0
    private var collocationIndex = 0
    private var recognitionCorrect = 0
    private var productionCorrect = 0
    private var listeningCorrect = 0
    private var collocationCorrect = 0
    private var listeningEvidenceCount = 0
    private var listeningStates: [String: ListeningEvidenceState]
    private var listeningPlayCounts: [String: Int] = [:]
    private var collocationRate = 0.0
    private var responseDurations: [Double] = []
    private var selfMonitoringAnswers: [Bool] = []
    private var itemStartedAt: Date
    private var oralStartedAt: Date?
    private var oralTimerTask: Task<Void, Never>?

    public init(
        catalog: ContentCatalog,
        repository: any DiagnosticReportStoring,
        reviewStore: (any PracticeProgressStoring)? = nil,
        activityMonitor: any SpeechActivityMonitoring =
            SpeechActivityMonitor(),
        oralAttemptStore: (any TrialDataStoring)? = nil,
        speechService: SpeechService = SpeechService(),
        seed requestedSeed: UInt64? = nil,
        vocabularyCount: Int = 10,
        listeningCount: Int = 10,
        vocabularyProfile: LearnerVocabularyProfile = .a2ToB1Bridge,
        sleeper: any DiagnosticSleeping = SystemDiagnosticSleeper(),
        onReportSaved: (@MainActor () -> Void)? = nil,
        now: @escaping () -> Date = Date.init
    ) throws {
        let history = try repository.diagnosticHistory()
        let baseline = history.entries.last(where: { $0.kind == .baseline })?
            .report
        let baselineLexemeIDs = baseline?.sampleLexemeIDs ?? []
        let baselineListeningIDs = baseline?.listeningSentenceIDs ?? []
        let resolvedSeed =
            baseline?.diagnosticVersion ?? 0 >= 2
            ? baseline?.seed ?? 0
            : requestedSeed ?? 0x5255_5353_4941_4E
        let resolvedVocabularyCount =
            baselineLexemeIDs.isEmpty
            ? vocabularyCount : baselineLexemeIDs.count
        let resolvedListeningCount =
            baselineListeningIDs.isEmpty
            ? listeningCount : baselineListeningIDs.count
        let levelAdjustedCatalog = ContentCatalog(
            lexemes: catalog.practiceLexemes.filter {
                vocabularyProfile.shouldServeAsStandalone(lexeme: $0)
            },
            sentences: catalog.practiceSentences
        )
        let selectedSample = DiagnosticSampler().sample(
            from: levelAdjustedCatalog,
            seed: resolvedSeed,
            vocabularyCount: resolvedVocabularyCount,
            listeningCount: resolvedListeningCount,
            preferredLexemeIDs: baselineLexemeIDs,
            preferredListeningSentenceIDs: baselineListeningIDs
        )
        sample = selectedSample
        seed = resolvedSeed
        sampleWasRepaired =
            baseline != nil
            && (
                baselineLexemeIDs.isEmpty
                    || baselineListeningIDs.isEmpty
                    || selectedSample.recognition.map(\.id)
                        != baselineLexemeIDs
                    || selectedSample.listening.map(\.id)
                        != baselineListeningIDs
            )
        historyIssueCount = history.issueCount
        comparisonBaselineMetrics = baseline?.current
        listeningStates = Dictionary(
            uniqueKeysWithValues: selectedSample.listening.map {
                ($0.id, ListeningEvidenceState.notPlayed)
            }
        )
        self.repository = repository
        self.activityMonitor = activityMonitor
        self.oralAttemptStore = oralAttemptStore
        self.speechService = speechService
        self.sleeper = sleeper
        self.onReportSaved = onReportSaved
        self.now = now
        itemStartedAt = now()
        report = history.entries.last?.report
        self.catalog = levelAdjustedCatalog
        questionBuilder = DiagnosticQuestionBuilder(seed: resolvedSeed)
        self.reviewStore = reviewStore
    }

    public var canStart: Bool {
        !sample.recognition.isEmpty && !sample.listening.isEmpty
    }

    public var startBlockReason: String? {
        canStart
            ? nil
            : "没有可用的 reviewed 词条或听句，无法开始诊断。"
    }

    public var listeningEvidenceSummary: String? {
        guard let metrics = report?.current else { return nil }
        if metrics.listeningEvidenceCount
            < DiagnosticThresholds.minimumListeningEvidenceCount
        {
            return "证据不足 \(metrics.listeningEvidenceCount)/\(DiagnosticThresholds.targetListeningEvidenceCount)"
        }
        return nil
    }

    public var comparisonNotice: String? {
        switch report?.comparisonStatus {
        case .sampleChanged:
            "题目变化，本次重建基线"
        case .invalidMetrics:
            "指标无效，本次不生成诊断结论或趋势"
        default:
            nil
        }
    }

    public var currentLexeme: Lexeme? {
        switch step {
        case .recognition:
            sample.recognition[safe: recognitionIndex]
        case .production:
            sample.production[safe: productionIndex]
        default:
            nil
        }
    }

    public var currentListeningSentence: SentenceCard? {
        guard step == .listening else { return nil }
        return sample.listening[safe: listeningIndex]
    }

    public var currentRecognitionQuestion: DiagnosticChoiceQuestion? {
        guard let lexeme = currentLexeme, step == .recognition else {
            return nil
        }
        return questionBuilder.recognitionQuestion(
            for: lexeme,
            pool: catalog.practiceLexemes
        )
    }

    public var currentListeningQuestion: DiagnosticChoiceQuestion? {
        guard let sentence = currentListeningSentence else { return nil }
        return questionBuilder.listeningQuestion(
            for: sentence,
            pool: catalog.practiceSentences
        )
    }

    public var collocationLexemes: [Lexeme] {
        sample.recognition.filter {
            !$0.collocations.isEmpty || !$0.example.isEmpty
        }
    }

    public var currentCollocationQuestion: DiagnosticChoiceQuestion? {
        guard step == .collocation,
            let lexeme = collocationLexemes[safe: collocationIndex]
        else {
            return nil
        }
        return questionBuilder.collocationQuestion(
            for: lexeme,
            pool: catalog.practiceLexemes
        )
    }

    public var currentListeningState: ListeningEvidenceState {
        guard let id = currentListeningSentence?.id else {
            return .notPlayed
        }
        return listeningStates[id] ?? .notPlayed
    }

    public var currentPosition: Int {
        switch step {
        case .recognition: recognitionIndex + 1
        case .production: productionIndex + 1
        case .listening: listeningIndex + 1
        case .collocation: collocationIndex + 1
        default: 1
        }
    }

    public var currentTotal: Int {
        switch step {
        case .recognition: sample.recognition.count
        case .production: sample.production.count
        case .listening: sample.listening.count
        case .collocation: max(1, collocationLexemes.count)
        default: 1
        }
    }

    public var overallProgress: Double {
        Double(step.rawValue) / Double(DiagnosticStep.allCases.count - 1)
    }

    public var isOralActivityRunning: Bool {
        oralPhase == .preparing || oralPhase == .speaking
    }

    public var trainingSuggestions: [String] {
        guard let report else { return [] }
        guard report.comparisonStatus != .invalidMetrics else { return [] }
        var suggestions: [String] = []
        for finding in report.findings {
            switch finding.type {
            case .vocabularyBreadth:
                suggestions.append("先巩固高频词，再逐步增加新词。")
            case .activeRetrieval:
                suggestions.append("优先安排中文到俄语的主动提取练习。")
            case .slowRetrieval:
                suggestions.append("使用 3 秒短时限回忆，练习快速提取。")
            case .listeningGap:
                suggestions.append("增加听句，并在练习中选择开口模式。")
            case .collocationGap:
                suggestions.append("把单词放进常用搭配与短语块复习。")
            case .selfMonitoring:
                suggestions.append("先完整表达，再集中复盘卡顿位置。")
            }
        }
        if suggestions.isEmpty {
            suggestions.append("保持当前练习节奏，每周用同一指标复测。")
        }
        return suggestions
    }

    public var comparisonRows: [DiagnosticComparisonRow] {
        guard let report,
            report.baseline.completedAt != report.current.completedAt,
            report.comparisonStatus == .comparable,
            let deltas = report.deltas
        else {
            return []
        }
        var rows = [
            DiagnosticComparisonRow(
                label: "认词",
                value: Self.signed(deltas.recognitionPoints)
                    + " 个百分点",
                trend: Self.trend(deltas.recognitionPoints)
            ),
            DiagnosticComparisonRow(
                label: "中文 → 俄语",
                value: Self.signed(deltas.productionPoints)
                    + " 个百分点",
                trend: Self.trend(deltas.productionPoints)
            ),
            DiagnosticComparisonRow(
                label: "回答中位数",
                value: Self.signed(deltas.responseSeconds) + " 秒",
                trend: Self.trend(
                    deltas.responseSeconds,
                    lowerIsBetter: true
                )
            ),
            DiagnosticComparisonRow(
                label: "搭配自评",
                value: Self.signed(deltas.collocationPoints)
                    + " 个百分点",
                trend: Self.trend(deltas.collocationPoints)
            ),
            DiagnosticComparisonRow(
                label: "卡顿/过度检查自评",
                value: Self.signed(deltas.selfMonitoringPoints)
                    + " 个百分点",
                trend: Self.trend(
                    deltas.selfMonitoringPoints,
                    lowerIsBetter: true
                )
            ),
        ]
        if let listeningPoints = deltas.listeningPoints {
            rows.insert(
                DiagnosticComparisonRow(
                    label: "听句理解",
                    value: Self.signed(listeningPoints)
                        + " 个百分点",
                    trend: Self.trend(listeningPoints)
                ),
                at: 3
            )
        }
        return rows
    }

    public var recommendedNewWordUpperLimit: Int {
        guard let findings = report?.findings else { return 10 }
        if findings.contains(where: { $0.type == .vocabularyBreadth }) {
            return 6
        }
        if findings.contains(where: { $0.type == .activeRetrieval }) {
            return 6
        }
        return 10
    }

    public func start() {
        guard canStart else {
            step = .intro
            statusMessage = startBlockReason
            return
        }
        resetMeasurements()
        move(to: .recognition)
    }

    public func retest() {
        start()
    }

    public func reveal() {
        isRevealed = true
    }

    public func selectRecognitionOption(_ optionID: String) {
        guard step == .recognition,
            !isRevealed,
            let question = currentRecognitionQuestion,
            question.options.contains(where: { $0.id == optionID })
        else {
            return
        }
        selectedOptionID = optionID
        let correct = question.isCorrect(optionID)
        selectedChoiceWasCorrect = correct
        isRevealed = true
        if correct {
            recognitionCorrect += 1
        } else {
            recordReview(
                itemKind: .lexeme,
                itemID: question.itemID,
                label: question.prompt,
                grade: .again,
                responseTimeMs: currentResponseTimeMs
            )
        }
    }

    public func selectListeningOption(_ optionID: String) {
        guard step == .listening,
            currentListeningState == .played,
            !isRevealed,
            let question = currentListeningQuestion,
            question.options.contains(where: { $0.id == optionID })
        else {
            return
        }
        selectedOptionID = optionID
        let correct = question.isCorrect(optionID)
        selectedChoiceWasCorrect = correct
        isRevealed = true
        listeningEvidenceCount += 1
        if correct {
            listeningCorrect += 1
        }
        let playCount = listeningPlayCounts[question.itemID, default: 0]
        if !correct || playCount > 1 {
            recordReview(
                itemKind: .sentence,
                itemID: question.itemID,
                label: currentListeningSentence?.practiceRu
                    ?? question.correctOption.text,
                grade: correct ? .hard : .again,
                responseTimeMs: currentResponseTimeMs
            )
        }
    }

    public func selectCollocationOption(_ optionID: String) {
        guard step == .collocation,
            !isRevealed,
            let question = currentCollocationQuestion,
            question.options.contains(where: { $0.id == optionID })
        else {
            return
        }
        selectedOptionID = optionID
        let correct = question.isCorrect(optionID)
        selectedChoiceWasCorrect = correct
        isRevealed = true
        if correct {
            collocationCorrect += 1
        } else {
            recordReview(
                itemKind: .lexeme,
                itemID: question.itemID,
                label: question.correctOption.text,
                grade: .again,
                responseTimeMs: currentResponseTimeMs
            )
        }
    }

    public func advanceFromChoice() {
        guard isRevealed, selectedOptionID != nil else { return }
        switch step {
        case .recognition:
            recognitionIndex += 1
            if recognitionIndex >= sample.recognition.count {
                move(to: .production)
            } else {
                beginItem()
            }
        case .listening:
            advanceListening()
        case .collocation:
            collocationIndex += 1
            if collocationIndex >= collocationLexemes.count {
                collocationRate = Self.rate(
                    correct: collocationCorrect,
                    total: collocationLexemes.count
                )
                move(to: .oralIntroduction)
            } else {
                beginItem()
            }
        default:
            break
        }
    }

    public func submitRecognition(correct: Bool) {
        guard step == .recognition else { return }
        if correct {
            recognitionCorrect += 1
        }
        recognitionIndex += 1
        if recognitionIndex >= sample.recognition.count {
            move(to: .production)
        } else {
            beginItem()
        }
    }

    public func submitProduction(correct: Bool) {
        guard step == .production else { return }
        if correct {
            productionCorrect += 1
        }
        responseDurations.append(
            max(0, now().timeIntervalSince(itemStartedAt))
        )
        productionIndex += 1
        if productionIndex >= sample.production.count {
            move(to: .listening)
        } else {
            beginItem()
        }
    }

    public func submitProduction(
        outcome: DiagnosticProductionOutcome
    ) {
        guard step == .production, isRevealed,
            let lexeme = currentLexeme
        else {
            return
        }
        reportedProductionOutcomes.append(outcome)
        if outcome.isSuccessful {
            productionCorrect += 1
        }
        responseDurations.append(
            max(0, now().timeIntervalSince(itemStartedAt))
        )
        if outcome.reviewGrade != .easy {
            recordReview(
                itemKind: .lexeme,
                itemID: lexeme.id,
                label: lexeme.stressedForm,
                grade: outcome.reviewGrade,
                responseTimeMs: currentResponseTimeMs
            )
        }
        productionIndex += 1
        if productionIndex >= sample.production.count {
            move(to: .listening)
        } else {
            beginItem()
        }
    }

    public func speakListeningSentence() {
        guard let sentence = currentListeningSentence else { return }
        let sentenceID = sentence.id
        listeningPlayCounts[sentence.id, default: 0] += 1
        listeningStates[sentence.id] = .playing
        statusMessage = "正在播放第 \(currentPosition) 条听句"
        let playbackStatus = speechService.speak(
            sentence.speechText,
            voicePolicy: .russianOnly
        ) { [weak self] outcome in
            guard let self,
                self.step == .listening,
                self.currentListeningSentence?.id == sentenceID,
                self.listeningStates[sentenceID] == .playing
            else {
                return
            }
            switch outcome {
            case .finished:
                self.listeningStates[sentenceID] = .played
                self.statusMessage = "第 \(self.currentPosition) 条听句播放完成"
            case .cancelled:
                self.listeningStates[sentenceID] = .notPlayed
                self.statusMessage = "听句播放已取消，请重新播放"
            }
        }
        switch playbackStatus {
        case .russianVoice:
            break
        case .fallbackVoice(_, let language):
            listeningStates[sentence.id] = .unavailable
            statusMessage = "未找到俄语语音（仅有 \(language)），请跳过本条听句"
        case .unavailable:
            listeningStates[sentence.id] = .unavailable
            statusMessage = "系统语音不可用，请跳过本条听句"
        case .emptyText:
            listeningStates[sentence.id] = .unavailable
            statusMessage = "当前听句没有可播放文本，请跳过"
        }
    }

    public func submitListening(understood: Bool) {
        guard step == .listening else { return }
        guard currentListeningState == .played else {
            statusMessage = "请先成功播放听句，再提交理解结果"
            return
        }
        listeningEvidenceCount += 1
        if understood {
            listeningCorrect += 1
        }
        advanceListening()
    }

    public func skipListening() {
        guard step == .listening,
            let sentence = currentListeningSentence
        else {
            return
        }
        listeningStates[sentence.id] = .skipped
        advanceListening()
    }

    private func advanceListening() {
        speechService.stop()
        listeningIndex += 1
        if listeningIndex >= sample.listening.count {
            if collocationLexemes.isEmpty {
                collocationRate = 0
                move(to: .oralIntroduction)
            } else {
                move(to: .collocation)
            }
        } else {
            beginItem()
        }
    }

    public func submitCollocation(rate: Double) {
        guard step == .collocation else { return }
        guard rate.isFinite else {
            statusMessage = "请输入有效的搭配自评分数"
            return
        }
        collocationRate = min(max(rate, 0), 100)
        move(to: .oralIntroduction)
    }

    public func startOralActivity() async {
        guard isOralStep, oralPhase == .ready else { return }
        preparationRemainingSeconds = 3
        oralRemainingSeconds = 60
        oralSummary = nil
        oralUsesMicrophoneMeter = false
        oralPhase = .preparing
        statusMessage = "准备 3 秒后开始；只估算说话活动，不保存音频"
        let expectedStep = step
        let result = await activityMonitor.start()
        guard step == expectedStep, oralPhase == .preparing else {
            _ = activityMonitor.stop()
            return
        }
        switch result {
        case .started:
            oralUsesMicrophoneMeter = true
        case .timerOnly(let reason):
            oralUsesMicrophoneMeter = false
            statusMessage = timerOnlyMessage(reason)
        }
        startOralTimer()
    }

    public func advanceOralClock() {
        switch oralPhase {
        case .preparing:
            preparationRemainingSeconds = max(
                0,
                preparationRemainingSeconds - 1
            )
            if preparationRemainingSeconds == 0 {
                oralPhase = .speaking
                oralStartedAt = now()
                statusMessage = oralUsesMicrophoneMeter
                    ? "请开始口述；只显示活动估算，不保存音频"
                    : "请开始口述；当前使用计时 + 自评模式"
            }
        case .speaking:
            oralRemainingSeconds = max(0, oralRemainingSeconds - 1)
            if oralRemainingSeconds == 0 {
                finishOralMeasurement(
                    message: "60 秒已到，请完成 1–5 分自评"
                )
            }
        case .ready, .awaitingSelfRating:
            break
        }
    }

    public func stopOralActivity() {
        guard isOralActivityRunning else { return }
        finishOralMeasurement(
            message: "本段计时已停止，请完成 1–5 分自评"
        )
    }

    public func submitOralActivity(selfRating: Int) {
        guard isOralStep, oralPhase == .awaitingSelfRating else {
            return
        }
        let rating = min(max(selfRating, 1), 5)
        selfMonitoringAnswers.append(rating <= 2)
        let elapsedMs = max(0, 60 - oralRemainingSeconds) * 1_000
        let attempt = OralActivityAttempt(
            topic: oralTopic,
            attemptedAt: now(),
            elapsedMs: elapsedMs,
            estimatedSpeakingMs: oralSummary?.estimatedSpeakingMs,
            longPauseCount: oralSummary?.longPauseCount,
            selfRating: rating,
            usedMicrophoneMeter: oralUsesMicrophoneMeter
                && oralSummary != nil
        )
        var persistenceIssue: String?
        do {
            try oralAttemptStore?.save(oralAttempt: attempt)
        } catch {
            persistenceIssue =
                "口述摘要暂时无法保存：\(error.localizedDescription)"
        }
        advanceOralStep()
        if let persistenceIssue {
            statusMessage = persistenceIssue
        }
    }

    public func skipOralActivity(selfRating: Int = 3) {
        guard isOralStep else { return }
        cancelOralTimer()
        _ = activityMonitor.stop()
        oralUsesMicrophoneMeter = false
        oralSummary = nil
        oralPhase = .awaitingSelfRating
        submitOralActivity(selfRating: selfRating)
    }

    public func handleDisappear() {
        speechService.stop()
        if let sentenceID = currentListeningSentence?.id,
            listeningStates[sentenceID] == .playing
        {
            listeningStates[sentenceID] = .notPlayed
        }
        cancelOralTimer()
        if isOralStep {
            _ = activityMonitor.stop()
            oralPhase = .ready
            preparationRemainingSeconds = 3
            oralRemainingSeconds = 60
            oralStartedAt = nil
            oralSummary = nil
            oralUsesMicrophoneMeter = false
        }
    }

    private var isOralStep: Bool {
        step == .oralIntroduction || step == .oralDailyLife
    }

    private var oralTopic: String {
        step == .oralIntroduction ? "自我介绍" : "日常生活"
    }

    private func advanceOralStep() {
        cancelOralTimer()
        oralStartedAt = nil
        preparationRemainingSeconds = 3
        oralRemainingSeconds = 60
        oralPhase = .ready
        oralSummary = nil
        oralUsesMicrophoneMeter = false
        if step == .oralIntroduction {
            move(to: .oralDailyLife)
        } else {
            finish()
        }
    }

    private func finish() {
        let instant = now()
        let current = DiagnosticMetrics(
            recognitionRate: Self.rate(
                correct: recognitionCorrect,
                total: sample.recognition.count
            ),
            productionRate: Self.rate(
                correct: productionCorrect,
                total: sample.production.count
            ),
            medianResponseSeconds: Self.median(responseDurations),
            listeningRate: Self.rate(
                correct: listeningCorrect,
                total: listeningEvidenceCount
            ),
            listeningEvidenceCount: listeningEvidenceCount,
            collocationRate: collocationRate,
            selfMonitoringRate: Self.rate(
                correct: selfMonitoringAnswers.filter { $0 }.count,
                total: selfMonitoringAnswers.count
            ),
            completedAt: instant
        )
        let baseline = comparisonBaselineMetrics ?? current
        let generated = DiagnosticEngine().report(
            baseline: baseline,
            current: current,
            seed: seed,
            sampleLexemeIDs: sample.recognition.map(\.id),
            listeningSentenceIDs: sample.listening.map(\.id),
            sampleWasRepaired: sampleWasRepaired
        )
        report = generated
        do {
            try repository.saveDiagnosticReport(generated)
            onReportSaved?()
            statusMessage =
                sampleWasRepaired
                ? "题目变化，本次重建基线"
                : baseline == current
                ? "基线诊断已保存"
                : "本周诊断已保存，并与基线比较"
        } catch {
            statusMessage = "诊断已完成，但保存失败：\(error.localizedDescription)"
        }
        step = .summary
        isRevealed = false
    }

    private func resetMeasurements() {
        speechService.stop()
        cancelOralTimer()
        _ = activityMonitor.stop()
        recognitionIndex = 0
        productionIndex = 0
        listeningIndex = 0
        collocationIndex = 0
        recognitionCorrect = 0
        productionCorrect = 0
        listeningCorrect = 0
        collocationCorrect = 0
        listeningEvidenceCount = 0
        listeningStates = Dictionary(
            uniqueKeysWithValues: sample.listening.map {
                ($0.id, ListeningEvidenceState.notPlayed)
            }
        )
        listeningPlayCounts = [:]
        collocationRate = 0
        responseDurations = []
        selfMonitoringAnswers = []
        reportedProductionOutcomes = []
        reviewItemsAdded = []
        selectedOptionID = nil
        selectedChoiceWasCorrect = nil
        oralStartedAt = nil
        preparationRemainingSeconds = 3
        oralRemainingSeconds = 60
        oralPhase = .ready
        oralSummary = nil
        oralUsesMicrophoneMeter = false
        statusMessage = nil
    }

    private func startOralTimer() {
        oralTimerTask?.cancel()
        oralTimerTask = Task { [weak self, sleeper] in
            do {
                while !Task.isCancelled {
                    try await sleeper.sleep()
                    guard !Task.isCancelled, let self else { return }
                    self.advanceOralClock()
                    if self.oralPhase == .awaitingSelfRating {
                        return
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.oralSummary = self.activityMonitor.stop()
                self.oralStartedAt = nil
                self.oralTimerTask = nil
                self.oralPhase = .awaitingSelfRating
                self.statusMessage =
                    "口述计时已中断：\(error.localizedDescription)；仍可完成自评"
            }
        }
    }

    private func cancelOralTimer() {
        oralTimerTask?.cancel()
        oralTimerTask = nil
    }

    private func finishOralMeasurement(message: String) {
        cancelOralTimer()
        oralSummary = activityMonitor.stop()
        oralStartedAt = nil
        oralPhase = .awaitingSelfRating
        statusMessage = message
    }

    private func timerOnlyMessage(
        _ reason: SpeechActivityFallbackReason
    ) -> String {
        switch reason {
        case .permissionDenied:
            "麦克风权限未开启；本段改为计时 + 自评，不影响诊断"
        case .unavailable:
            "当前设备无法读取麦克风；本段改为计时 + 自评"
        case .engineFailed:
            "麦克风活动估算未启动；本段改为计时 + 自评"
        }
    }

    private func move(to newStep: DiagnosticStep) {
        step = newStep
        beginItem()
    }

    private func beginItem() {
        itemStartedAt = now()
        isRevealed = false
        selectedOptionID = nil
        selectedChoiceWasCorrect = nil
        statusMessage = nil
    }

    private var currentResponseTimeMs: Int {
        Int(
            (
                max(0, now().timeIntervalSince(itemStartedAt))
                    * 1_000
            ).rounded()
        )
    }

    private func recordReview(
        itemKind: PracticeItemKind,
        itemID: String,
        label: String,
        grade: ReviewGrade,
        responseTimeMs: Int
    ) {
        guard let reviewStore else { return }
        let instant = now()
        do {
            let oldState =
                try reviewStore.progress(
                    itemType: itemKind,
                    itemId: itemID
                )
                ?? ReviewState(masteryLevel: 0, dueAt: instant)
            let newState = scheduler.next(
                state: oldState,
                grade: grade,
                now: instant
            )
            let completed =
                try reviewStore.dailyCompletedCount(
                    on: instant,
                    calendar: calendar
                )
                ?? 0
            try reviewStore.commitReview(
                event: ReviewEvent(
                    itemType: itemKind,
                    itemId: itemID,
                    grade: grade,
                    responseTimeMs: responseTimeMs,
                    practiceMode: .speaking,
                    createdAt: instant
                ),
                state: newState,
                dailyCompletedCount: completed,
                calendar: calendar
            )
            let item = DiagnosticReviewItem(
                itemKind: itemKind,
                itemID: itemID,
                label: label,
                grade: grade
            )
            if !reviewItemsAdded.contains(where: {
                $0.itemKind == itemKind && $0.itemID == itemID
            }) {
                reviewItemsAdded.append(item)
            }
        } catch {
            statusMessage =
                "诊断结果已记录，但错题暂时无法加入复习：\(error.localizedDescription)"
        }
    }

    private static func rate(correct: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total) * 100
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func signed(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix
            + value.formatted(
                .number.precision(.fractionLength(0...1))
            )
    }

    private static func trend(
        _ delta: Double,
        lowerIsBetter: Bool = false
    ) -> DiagnosticTrend {
        guard delta != 0 else { return .unchanged }
        let improved = lowerIsBetter ? delta < 0 : delta > 0
        return improved ? .improvement : .regression
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
