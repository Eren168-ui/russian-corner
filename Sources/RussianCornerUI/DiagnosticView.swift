import RussianCornerCore
import SwiftUI

public struct RussianCornerDiagnosticView: View {
    public static let pronunciationDisclaimer =
        "本诊断不分析录音内容。发音准确度需由老师或母语者评估；二期 AI 反馈接入前，本应用不判断发音或母语地道度。"
    public static let minimumSize = CGSize(width: 540, height: 500)
    public static let collocationAccessibilityLabel = "常用搭配把握度"

    public static func trendLabel(_ trend: DiagnosticTrend) -> String {
        switch trend {
        case .improvement: "改善"
        case .regression: "需关注"
        case .unchanged: "持平"
        }
    }

    @Bindable private var model: DiagnosticViewModel
    @State private var collocationDraft = 50.0
    @State private var selfMonitoringDraft = false

    public init(model: DiagnosticViewModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ProgressView(value: model.overallProgress)
                    .tint(.blue)

                Group {
                    switch model.step {
                    case .intro:
                        intro
                    case .recognition:
                        recognition
                    case .production:
                        production
                    case .listening:
                        listening
                    case .collocation:
                        collocation
                    case .recordingIntroduction, .recordingDailyLife:
                        recording
                    case .summary:
                        summary
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let status = model.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(status)
                }
            }
            .padding(26)
        }
        .frame(
            minWidth: Self.minimumSize.width,
            idealWidth: 620,
            minHeight: Self.minimumSize.height,
            idealHeight: 650
        )
        .onDisappear {
            model.handleDisappear()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("俄语学习诊断")
                    .font(
                        .system(
                            .largeTitle,
                            design: .serif,
                            weight: .semibold
                        )
                    )
                Text(model.step.title)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.step != .intro && model.step != .summary {
                Text("\(model.currentPosition) / \(model.currentTotal)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("用同一组指标建立基线，并在每周复测时比较变化。")
                .font(.title3)
            Text(
                "流程包含认词、中文到俄语、10 条听句、搭配自评，以及两段最多 60 秒的表达提示。麦克风可随时跳过，不会阻塞诊断。"
            )
            .foregroundStyle(.secondary)
            notice
            Spacer()
            Button(model.report == nil ? "开始基线诊断" : "开始本周复测") {
                model.start()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canStart)
        }
    }

    private var recognition: some View {
        taskCard(
            eyebrow: "看到俄语词，先判断是否认识",
            prompt: model.currentLexeme?.stressedForm ?? "没有可用词条",
            answer: model.currentLexeme?.glossZh
        ) {
            scoreButtons(
                negative: "不认识",
                positive: "认识"
            ) { correct in
                model.submitRecognition(correct: correct)
            }
        }
    }

    private var production: some View {
        taskCard(
            eyebrow: "看到中文，尝试说出俄语",
            prompt: model.currentLexeme?.glossZh ?? "没有可用词条",
            answer: model.currentLexeme?.stressedForm
        ) {
            scoreButtons(
                negative: "没想起",
                positive: "想起来了"
            ) { correct in
                model.submitProduction(correct: correct)
            }
        }
    }

    private var listening: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("先听句子，再判断自己是否理解。")
                .foregroundStyle(.secondary)
            HStack {
                Button("播放俄语听句", systemImage: "speaker.wave.2") {
                    model.speakListeningSentence()
                }
                .buttonStyle(.borderedProminent)
                Button(model.isRevealed ? "已揭晓" : "揭晓文本") {
                    model.reveal()
                }
                .disabled(model.isRevealed)
                Button("跳过本条") {
                    model.skipListening()
                }
            }
            if model.isRevealed {
                Text(model.currentListeningSentence?.practiceRu ?? "")
                    .font(.title2)
                    .textSelection(.enabled)
                Text(model.currentListeningSentence?.promptZh ?? "")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            scoreButtons(
                negative: "未理解",
                positive: "理解"
            ) { understood in
                model.submitListening(understood: understood)
            }
            .disabled(model.currentListeningState != .played)
        }
    }

    private var collocation: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("搭配运用自评")
                .font(.title2)
            Text("看到熟悉单词时，你有多大把握能说出一个常用搭配？")
                .foregroundStyle(.secondary)
            Slider(value: $collocationDraft, in: 0...100, step: 10)
                .accessibilityLabel(Self.collocationAccessibilityLabel)
                .accessibilityValue("\(Int(collocationDraft))%")
            Text("\(Int(collocationDraft))%")
                .font(.title)
                .monospacedDigit()
            Spacer()
            Button("提交搭配自评") {
                model.submitCollocation(rate: collocationDraft)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var recording: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                model.step == .recordingIntroduction
                    ? "请用俄语做自我介绍"
                    : "请用俄语描述你的日常生活"
            )
            .font(.title2)
            Text("尽量连续表达；录音仅供你完成后自评，不会自动分析。")
                .foregroundStyle(.secondary)
            Text("\(model.recordingRemainingSeconds)")
                .font(
                    .system(
                        .largeTitle,
                        design: .rounded,
                        weight: .light
                    )
                )
                .monospacedDigit()
            HStack {
                Button(
                    model.isRecording ? "停止录音" : "开始 60 秒录音",
                    systemImage: model.isRecording ? "stop.circle" : "mic.circle"
                ) {
                    Task { await model.toggleRecording() }
                }
                .buttonStyle(.borderedProminent)
                Button("跳过麦克风") {
                    model.skipRecording(
                        selfMonitoring: selfMonitoringDraft
                    )
                    selfMonitoringDraft = false
                }
            }
            Toggle(
                "刚才表达时，我经常卡顿或过度检查自己",
                isOn: $selfMonitoringDraft
            )
            .padding(.top, 8)
            Spacer()
            Button("完成这段并继续") {
                model.completeRecording(
                    selfMonitoring: selfMonitoringDraft
                )
                selfMonitoringDraft = false
            }
            .disabled(model.isRecording)
            notice
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let report = model.report {
                metrics(report.current)
                if !model.comparisonRows.isEmpty {
                    Text("相对基线")
                        .font(.headline)
                        .padding(.top, 4)
                    Grid(
                        alignment: .leading,
                        horizontalSpacing: 24,
                        verticalSpacing: 6
                    ) {
                        ForEach(model.comparisonRows, id: \.label) { row in
                            GridRow {
                                Text(row.label)
                                    .foregroundStyle(.secondary)
                                Text(row.value)
                                    .monospacedDigit()
                                Text(Self.trendLabel(row.trend))
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
                Divider()
                Text("提示与建议")
                    .font(.headline)
                if report.findings.isEmpty {
                    Text("本次没有指标触发关注阈值，继续每周复测。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.findings, id: \.type) { finding in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(findingTitle(finding.type))
                                .font(.headline)
                            Text(finding.evidence)
                            Text(finding.explanation)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Text("训练建议")
                    .font(.headline)
                ForEach(model.trainingSuggestions, id: \.self) {
                    Text("• \($0)")
                }
                Text("建议的新词上限：每天 \(model.recommendedNewWordUpperLimit) 个")
                    .font(.subheadline.weight(.semibold))
                Text("该上限仅用于展示建议，不会改动复习调度规则。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            notice
            Button("重新测试") {
                model.retest()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var notice: some View {
        Label(
            Self.pronunciationDisclaimer,
            systemImage: "person.2.badge.gearshape"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(12)
        .background(.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func taskCard<Actions: View>(
        eyebrow: String,
        prompt: String,
        answer: String?,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(eyebrow)
                .foregroundStyle(.secondary)
            Text(prompt)
                .font(
                    .system(
                        .largeTitle,
                        design: .serif,
                        weight: .medium
                    )
                )
                .textSelection(.enabled)
            if model.isRevealed {
                Divider()
                Text(answer ?? "没有可揭晓内容")
                    .font(.title2)
            } else {
                Button("揭晓答案") {
                    model.reveal()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if model.isRevealed {
                actions()
            }
        }
    }

    private func scoreButtons(
        negative: String,
        positive: String,
        submit: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            Button(negative) { submit(false) }
            Button(positive) { submit(true) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func metrics(_ metrics: DiagnosticMetrics) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            metricRow("认词", metrics.recognitionRate, suffix: "%")
            metricRow("中文 → 俄语", metrics.productionRate, suffix: "%")
            metricRow(
                "回答中位数",
                metrics.medianResponseSeconds,
                suffix: " 秒"
            )
            metricRow("听句理解", metrics.listeningRate, suffix: "%")
            metricRow("搭配自评", metrics.collocationRate, suffix: "%")
            metricRow("卡顿/过度检查自评", metrics.selfMonitoringRate, suffix: "%")
        }
    }

    private func metricRow(
        _ label: String,
        _ value: Double,
        suffix: String
    ) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value.formatted(.number.precision(.fractionLength(0...1))) + suffix)
                .monospacedDigit()
        }
    }

    private func findingTitle(_ type: DiagnosticFindingType) -> String {
        switch type {
        case .vocabularyBreadth: "词汇覆盖"
        case .activeRetrieval: "主动提取"
        case .slowRetrieval: "提取速度"
        case .listeningGap: "听力连接"
        case .collocationGap: "搭配运用"
        case .selfMonitoring: "表达自我监控"
        }
    }
}
