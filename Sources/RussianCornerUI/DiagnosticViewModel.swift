import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

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
    case recordingIntroduction
    case recordingDailyLife
    case summary

    public var title: String {
        switch self {
        case .intro: "说明"
        case .recognition: "认词"
        case .production: "中文 → 俄语"
        case .listening: "听句"
        case .collocation: "搭配自评"
        case .recordingIntroduction: "60 秒自我介绍"
        case .recordingDailyLife: "60 秒日常生活"
        case .summary: "诊断总结"
        }
    }
}

public struct DiagnosticComparisonRow: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

@MainActor
@Observable
public final class DiagnosticViewModel {
    public private(set) var step: DiagnosticStep = .intro
    public private(set) var isRevealed = false
    public private(set) var recordingRemainingSeconds = 60
    public private(set) var report: DiagnosticReport?
    public private(set) var statusMessage: String?

    public let sample: DiagnosticSample

    private let repository: any DiagnosticReportStoring
    private let recordingService: any RecordingManaging
    private let speechService: SpeechService
    private let now: () -> Date
    private var recognitionIndex = 0
    private var productionIndex = 0
    private var listeningIndex = 0
    private var recognitionCorrect = 0
    private var productionCorrect = 0
    private var listeningCorrect = 0
    private var collocationRate = 0.0
    private var responseDurations: [Double] = []
    private var selfMonitoringAnswers: [Bool] = []
    private var itemStartedAt: Date
    private var recordingStartedAt: Date?

    public init(
        catalog: ContentCatalog,
        repository: any DiagnosticReportStoring,
        recordingService: any RecordingManaging = RecordingService(),
        speechService: SpeechService = SpeechService(),
        seed: UInt64 = UInt64(Date().timeIntervalSince1970),
        vocabularyCount: Int = 10,
        listeningCount: Int = 10,
        now: @escaping () -> Date = Date.init
    ) throws {
        sample = DiagnosticSampler().sample(
            from: catalog,
            seed: seed,
            vocabularyCount: vocabularyCount,
            listeningCount: listeningCount
        )
        self.repository = repository
        self.recordingService = recordingService
        self.speechService = speechService
        self.now = now
        itemStartedAt = now()
        report = try repository.latestDiagnosticReport()
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

    public var currentPosition: Int {
        switch step {
        case .recognition: recognitionIndex + 1
        case .production: productionIndex + 1
        case .listening: listeningIndex + 1
        default: 1
        }
    }

    public var currentTotal: Int {
        switch step {
        case .recognition: sample.recognition.count
        case .production: sample.production.count
        case .listening: sample.listening.count
        default: 1
        }
    }

    public var overallProgress: Double {
        Double(step.rawValue) / Double(DiagnosticStep.allCases.count - 1)
    }

    public var isRecording: Bool {
        recordingService.isRecording
    }

    public var trainingSuggestions: [String] {
        guard let report else { return [] }
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
            report.baseline.completedAt != report.current.completedAt
        else {
            return []
        }
        let deltas = report.deltas
        return [
            DiagnosticComparisonRow(
                label: "认词",
                value: Self.signed(deltas.recognitionPoints)
                    + " 个百分点"
            ),
            DiagnosticComparisonRow(
                label: "中文 → 俄语",
                value: Self.signed(deltas.productionPoints)
                    + " 个百分点"
            ),
            DiagnosticComparisonRow(
                label: "回答中位数",
                value: Self.signed(deltas.responseSeconds) + " 秒"
            ),
            DiagnosticComparisonRow(
                label: "听句理解",
                value: Self.signed(deltas.listeningPoints)
                    + " 个百分点"
            ),
            DiagnosticComparisonRow(
                label: "搭配自评",
                value: Self.signed(deltas.collocationPoints)
                    + " 个百分点"
            ),
            DiagnosticComparisonRow(
                label: "卡顿/过度检查自评",
                value: Self.signed(deltas.selfMonitoringPoints)
                    + " 个百分点"
            ),
        ]
    }

    public var recommendedNewWordUpperLimit: Int {
        guard let findings = report?.findings else { return 7 }
        if findings.contains(where: { $0.type == .vocabularyBreadth }) {
            return 5
        }
        if findings.contains(where: { $0.type == .activeRetrieval }) {
            return 6
        }
        return 7
    }

    public func start() {
        resetMeasurements()
        move(to: .recognition)
    }

    public func retest() {
        start()
    }

    public func reveal() {
        isRevealed = true
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

    public func speakListeningSentence() {
        guard let sentence = currentListeningSentence else { return }
        switch speechService.speak(sentence.speechText) {
        case .russianVoice:
            statusMessage = "正在播放第 \(currentPosition) 条听句"
        case .fallbackVoice(_, let language):
            statusMessage = "未找到俄语语音，使用 \(language) 播放"
        case .unavailable:
            statusMessage = "系统语音不可用，可查看答案后继续"
        case .emptyText:
            statusMessage = "当前听句没有可播放文本"
        }
    }

    public func submitListening(understood: Bool) {
        guard step == .listening else { return }
        if understood {
            listeningCorrect += 1
        }
        listeningIndex += 1
        if listeningIndex >= sample.listening.count {
            move(to: .collocation)
        } else {
            beginItem()
        }
    }

    public func submitCollocation(rate: Double) {
        guard step == .collocation else { return }
        collocationRate = min(max(rate, 0), 100)
        move(to: .recordingIntroduction)
    }

    public func toggleRecording() async {
        guard isRecordingStep else { return }
        if recordingService.isRecording {
            recordingService.stop()
            statusMessage = "录音已停止，请完成自评或跳过"
            return
        }
        var result = await recordingService.start()
        if result == .permissionUndetermined {
            if await recordingService.requestPermission() == .granted {
                result = await recordingService.start()
            }
        }
        switch result {
        case .started:
            recordingStartedAt = now()
            recordingRemainingSeconds = 60
            statusMessage = "正在录音，最多 60 秒"
        case .permissionDenied:
            statusMessage = "麦克风权限未开启，仍可跳过并继续"
        case .permissionUndetermined:
            statusMessage = "尚未取得麦克风权限，仍可跳过并继续"
        case .unavailable:
            statusMessage = "当前设备无法录音，仍可跳过并继续"
        case .failed(let message):
            statusMessage = "录音未开始：\(message)；仍可跳过"
        }
    }

    public func refreshRecordingTimer() {
        guard let recordingStartedAt else { return }
        let elapsed = max(0, now().timeIntervalSince(recordingStartedAt))
        recordingRemainingSeconds = max(0, 60 - Int(elapsed.rounded(.down)))
        if recordingRemainingSeconds == 0 {
            recordingService.stop()
            statusMessage = "60 秒已到，请完成自评"
            self.recordingStartedAt = nil
        }
    }

    public func completeRecording(selfMonitoring: Bool) {
        guard isRecordingStep else { return }
        recordingService.stop()
        try? recordingService.discard()
        selfMonitoringAnswers.append(selfMonitoring)
        advanceRecordingStep()
    }

    public func skipRecording(selfMonitoring: Bool) {
        guard isRecordingStep else { return }
        recordingService.stop()
        try? recordingService.discard()
        selfMonitoringAnswers.append(selfMonitoring)
        advanceRecordingStep()
    }

    private var isRecordingStep: Bool {
        step == .recordingIntroduction || step == .recordingDailyLife
    }

    private func advanceRecordingStep() {
        recordingStartedAt = nil
        recordingRemainingSeconds = 60
        if step == .recordingIntroduction {
            move(to: .recordingDailyLife)
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
                total: sample.listening.count
            ),
            collocationRate: collocationRate,
            selfMonitoringRate: Self.rate(
                correct: selfMonitoringAnswers.filter { $0 }.count,
                total: selfMonitoringAnswers.count
            ),
            completedAt: instant
        )
        do {
            let baseline =
                try repository.baselineDiagnosticReport()?.baseline
                ?? current
            let generated = DiagnosticEngine().report(
                baseline: baseline,
                current: current
            )
            try repository.saveDiagnosticReport(generated)
            report = generated
            statusMessage =
                baseline == current
                ? "基线诊断已保存"
                : "本周诊断已保存，并与基线比较"
        } catch {
            report = DiagnosticEngine().report(
                baseline: current,
                current: current
            )
            statusMessage = "诊断已完成，但保存失败：\(error.localizedDescription)"
        }
        step = .summary
        isRevealed = false
    }

    private func resetMeasurements() {
        recognitionIndex = 0
        productionIndex = 0
        listeningIndex = 0
        recognitionCorrect = 0
        productionCorrect = 0
        listeningCorrect = 0
        collocationRate = 0
        responseDurations = []
        selfMonitoringAnswers = []
        recordingStartedAt = nil
        recordingRemainingSeconds = 60
        statusMessage = nil
    }

    private func move(to newStep: DiagnosticStep) {
        step = newStep
        beginItem()
    }

    private func beginItem() {
        itemStartedAt = now()
        isRevealed = false
        statusMessage = nil
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
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
