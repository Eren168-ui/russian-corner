import RussianCornerCore
import SwiftUI

public struct RussianCornerDiagnosticView: View {
    public static let introPurpose =
        "用 5–8 分钟找出：哪些词只是眼熟、哪些词说不出来、哪些搭配和听句还没有自动化。结果会直接调整接下来一周的练习。"
    public static let productionOutcomeTitles = [
        "3 秒内完整说出",
        "核心说出，词形或搭配不准",
        "揭晓后才想起来",
        "完全不会",
    ]
    public static let pronunciationDisclaimer =
        "本诊断不录音、不保存音频，只估算开口活动。发音准确度需由老师或母语者评估；二期 AI 反馈接入前，本应用不判断发音或母语地道度。"
    public static let minimumSize = CGSize(width: 540, height: 500)
    public static let collocationAccessibilityLabel = "常用搭配把握度"
    public static let diagnosticSchedulingNotice =
        "下次日队列会应用该诊断；手动练习模式优先。"

    public static func trendLabel(_ trend: DiagnosticTrend) -> String {
        switch trend {
        case .improvement: "改善"
        case .regression: "需关注"
        case .unchanged: "持平"
        }
    }

    @Bindable private var model: DiagnosticViewModel
    @State private var collocationDraft = 50.0
    @State private var oralSelfRating = 3

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
                    case .oralIntroduction, .oralDailyLife:
                        oralActivity
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
                if model.historyIssueCount > 0 {
                    Text("已跳过\(model.historyIssueCount)条损坏历史，不影响练习")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                Text(model.diagnosticTitle)
                    .font(
                        .system(
                            .largeTitle,
                            design: .serif,
                            weight: .semibold
                        )
                    )
                Text(model.currentStepTitle)
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
        VStack(alignment: .leading, spacing: 20) {
            Text("不是考试，是一次训练校准")
                .font(.system(size: 25, weight: .semibold, design: .serif))
            Text(Self.introPurpose)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                introStep("01", "认词")
                introStep("02", "主动提取")
                introStep("03", "听句")
                introStep("04", "搭配")
                introStep("05", "连续表达")
            }

            Label(
                "选择题由系统判分；只有口述体验需要你补充一次自评。",
                systemImage: "checkmark.seal"
            )
            .font(.subheadline.weight(.medium))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            notice
            if let reason = model.startBlockReason {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button(model.report == nil ? "开始基线诊断" : "开始本周复测") {
                model.start()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canStart)
        }
    }

    private var recognition: some View {
        Group {
            if let question = model.currentRecognitionQuestion {
                choiceTask(
                    eyebrow:
                        "\(model.recognitionDirectionTitle) · 系统判分",
                    question: question,
                    supportingText: "选择最接近的核心含义",
                    select: model.selectRecognitionOption
                )
            } else {
                unavailableTask
            }
        }
    }

    private var production: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(model.productionDirectionTitle) · 主动提取")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.orange)
            Text(model.currentLexeme?.glossZh ?? "没有可用词条")
                .font(.system(size: 38, weight: .medium, design: .serif))
            Text("先完整说出来，再查看参考答案。系统正在记录反应时间。")
                .foregroundStyle(.secondary)
            if model.isRevealed {
                Divider()
                Text(model.currentLexeme?.stressedForm ?? "")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                if let exercise =
                    model.currentProductionTransferExercise
                {
                    productionTransfer(exercise)
                } else {
                    Text("按刚才真实表现选择；“3 秒内说出”还要通过一道迁移题。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 8) {
                        productionButton(
                            .completeFast,
                            title: Self.productionOutcomeTitles[0],
                            detail: "继续完成迁移题，由系统最终判分"
                        )
                        productionButton(
                            .partial,
                            title: Self.productionOutcomeTitles[1],
                            detail: "方向正确，但还不能算稳定掌握"
                        )
                        productionButton(
                            .recalledAfterReveal,
                            title: Self.productionOutcomeTitles[2],
                            detail: "属于认识，但主动提取失败"
                        )
                        productionButton(
                            .unknown,
                            title: Self.productionOutcomeTitles[3],
                            detail: "词汇或表达尚未建立"
                        )
                    }
                }
            } else {
                Button("查看参考表达", systemImage: "eye") {
                    model.reveal()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            Spacer(minLength: 0)
        }
    }

    private var listening: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("听力连接 · 系统判分")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.orange)
            Text(
                "不看文本，先听\(model.targetLanguageNameZh)，再选择最接近的中文意图。"
            )
                .font(.title3)
            HStack {
                Button(
                    model.currentListeningState == .played
                        ? "再听一次" : "播放\(model.targetLanguageNameZh)",
                    systemImage: "speaker.wave.2"
                ) {
                    model.speakListeningSentence()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                Button("跳过本条") {
                    model.skipListening()
                }
            }
            if let question = model.currentListeningQuestion,
                model.currentListeningState == .played
                    || model.isRevealed
            {
                choiceOptions(
                    question: question,
                    select: model.selectListeningOption
                )
                if model.isRevealed {
                    answerFeedback(question)
                    Text(model.currentListeningSentence?.practiceRu ?? "")
                        .font(.title2)
                        .textSelection(.enabled)
                    nextChoiceButton
                }
            } else if model.currentListeningState == .playing {
                Label("正在播放…", systemImage: "waveform")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var collocation: some View {
        Group {
            if let question = model.currentCollocationQuestion {
                choiceTask(
                    eyebrow: "固定搭配 · 系统判分",
                    question: question,
                    supportingText: "选择真正自然、可直接说出口的搭配",
                    select: model.selectCollocationOption
                )
            } else {
                unavailableTask
            }
        }
    }

    private var oralActivity: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                model.step == .oralIntroduction
                    ? "请用\(model.targetLanguageNameZh)做自我介绍"
                    : "请用\(model.targetLanguageNameZh)描述你的日常生活"
            )
            .font(.title2)
            Text("尽量连续表达。应用只读取实时音量活动，不录音、不保存，也不判断发音是否准确。")
                .foregroundStyle(.secondary)

            switch model.oralPhase {
            case .ready:
                Text("开始后先准备 3 秒，再口述 60 秒。")
                    .foregroundStyle(.secondary)
                Button(
                    "开始口述活动",
                    systemImage: "waveform"
                ) {
                    Task { await model.startOralActivity() }
                }
                .buttonStyle(.borderedProminent)

            case .preparing:
                Text("准备 \(model.preparationRemainingSeconds)")
                    .font(
                        .system(
                            .largeTitle,
                            design: .rounded,
                            weight: .light
                        )
                    )
                    .monospacedDigit()
                Button("取消本次") {
                    model.handleDisappear()
                }

            case .speaking:
                Text("\(model.oralRemainingSeconds)")
                    .font(
                        .system(
                            .largeTitle,
                            design: .rounded,
                            weight: .light
                        )
                    )
                    .monospacedDigit()
                Button(
                    "提前结束并自评",
                    systemImage: "stop.circle"
                ) {
                    model.stopOralActivity()
                }

            case .awaitingSelfRating:
                if let summary = model.oralSummary {
                    Text(
                        "活动估算：开口约 \(summary.estimatedSpeakingMs / 1_000) 秒，长停顿约 \(summary.longPauseCount) 次"
                    )
                    .font(.headline)
                } else {
                    Text("本段使用计时 + 自评完成。")
                        .font(.headline)
                }
                Text("给刚才的表达流畅度打分：1 = 卡顿很多，5 = 比较顺畅")
                    .foregroundStyle(.secondary)
                Picker("自评", selection: $oralSelfRating) {
                    ForEach(1...5, id: \.self) { score in
                        Text("\(score) 分").tag(score)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                Button("保存本段摘要并继续") {
                    model.submitOralActivity(
                        selfRating: oralSelfRating
                    )
                    oralSelfRating = 3
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
            notice
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let report = model.report {
                Text(
                    model.isLegacySelfRatedReport
                        ? "旧版自评诊断" : "本次结论"
                )
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.orange)
                Text(model.diagnosticHeadline)
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold,
                            design: .serif
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    abilityCard(
                        "认词",
                        report.current.recognitionRate,
                        symbol: "eye"
                    )
                    abilityCard(
                        "主动提取",
                        report.current.productionRate,
                        symbol: "bubble.left.and.bubble.right"
                    )
                    abilityCard(
                        "听句",
                        report.current.listeningRate,
                        symbol: "ear"
                    )
                    abilityCard(
                        "搭配",
                        report.current.collocationRate,
                        symbol: "link"
                    )
                }

                if !model.reviewItemsAdded.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "已加入正常复习",
                            systemImage: "arrow.uturn.backward.circle"
                        )
                        .font(.headline)
                        ForEach(model.reviewItemsAdded) { item in
                            HStack {
                                Text(item.label)
                                    .font(.system(.body, design: .serif))
                                Spacer()
                                Text(item.grade == .hard ? "短间隔" : "尽快再练")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(14)
                    .background(.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("接下来 7 天")
                        .font(.headline)
                    ForEach(model.sevenDayAdjustments, id: \.self) { item in
                        Label(item, systemImage: "arrow.right")
                            .font(.subheadline)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                DisclosureGroup("查看指标与基线对比") {
                    VStack(alignment: .leading, spacing: 12) {
                        metrics(report.current)
                        if let notice = model.comparisonNotice {
                            Text(notice)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.comparisonRows, id: \.label) { row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text(row.value).monospacedDigit()
                                Text(Self.trendLabel(row.trend))
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                .font(.subheadline)
            }
            notice
            Button("重新测试") {
                model.retest()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
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

    private func introStep(_ number: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(number)
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(.orange)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func abilityCard(
        _ title: String,
        _ value: Double,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol)
                .foregroundStyle(.orange)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(
                value.formatted(
                    .number.precision(.fractionLength(0))
                ) + "%"
            )
            .font(.title3.monospacedDigit().weight(.semibold))
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func choiceTask(
        eyebrow: String,
        question: DiagnosticChoiceQuestion,
        supportingText: String,
        select: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.orange)
            Text(question.prompt)
                .font(.system(size: 36, weight: .medium, design: .serif))
                .textSelection(.enabled)
            Text(supportingText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            choiceOptions(question: question, select: select)
            if model.isRevealed {
                answerFeedback(question)
                nextChoiceButton
            }
            Spacer(minLength: 0)
        }
    }

    private func choiceOptions(
        question: DiagnosticChoiceQuestion,
        select: @escaping (String) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            ForEach(question.options) { option in
                Button {
                    select(option.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(
                            systemName: optionSymbol(
                                optionID: option.id,
                                question: question
                            )
                        )
                        .frame(width: 18)
                        Text(option.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        optionBackground(
                            optionID: option.id,
                            question: question
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(
                                optionBorder(
                                    optionID: option.id,
                                    question: question
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(model.isRevealed)
            }
        }
    }

    private func answerFeedback(
        _ question: DiagnosticChoiceQuestion
    ) -> some View {
        Label(
            model.selectedChoiceWasCorrect == true
                ? "正确，已记录本次反应"
                : "正确答案：\(question.correctOption.text)；本条已加入复习",
            systemImage: model.selectedChoiceWasCorrect == true
                ? "checkmark.circle.fill"
                : "arrow.uturn.backward.circle.fill"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(
            model.selectedChoiceWasCorrect == true ? .green : .orange
        )
    }

    private var nextChoiceButton: some View {
        Button("继续下一题", systemImage: "arrow.right") {
            model.advanceFromChoice()
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }

    private func optionSymbol(
        optionID: String,
        question: DiagnosticChoiceQuestion
    ) -> String {
        guard model.isRevealed else { return "circle" }
        if question.isCorrect(optionID) {
            return "checkmark.circle.fill"
        }
        if model.selectedOptionID == optionID {
            return "xmark.circle.fill"
        }
        return "circle"
    }

    private func optionBackground(
        optionID: String,
        question: DiagnosticChoiceQuestion
    ) -> Color {
        guard model.isRevealed else {
            return Color.primary.opacity(0.045)
        }
        if question.isCorrect(optionID) {
            return .green.opacity(0.12)
        }
        if model.selectedOptionID == optionID {
            return .orange.opacity(0.12)
        }
        return Color.primary.opacity(0.03)
    }

    private func optionBorder(
        optionID: String,
        question: DiagnosticChoiceQuestion
    ) -> Color {
        guard model.isRevealed else {
            return Color.primary.opacity(0.08)
        }
        if question.isCorrect(optionID) {
            return .green.opacity(0.5)
        }
        if model.selectedOptionID == optionID {
            return .orange.opacity(0.5)
        }
        return Color.clear
    }

    private func productionButton(
        _ outcome: DiagnosticProductionOutcome,
        title: String,
        detail: String
    ) -> some View {
        Button {
            model.submitProduction(outcome: outcome)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(.primary.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private func productionTransfer(
        _ exercise: TransferExercise
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("迁移检验 · 系统判分", systemImage: "checkmark.seal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(exercise.prompt)
                .font(.headline)
            ForEach(exercise.options) { option in
                Button {
                    model.submitProductionTransfer(optionID: option.id)
                } label: {
                    HStack {
                        Text(option.text)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(.primary.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var unavailableTask: some View {
        ContentUnavailableView(
            "本环节暂无可用题目",
            systemImage: "tray",
            description: Text("未审核内容不会被拿来凑题。")
        )
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
            metricRow(
                model.productionDirectionTitle,
                metrics.productionRate,
                suffix: "%"
            )
            metricRow(
                "回答中位数",
                metrics.medianResponseSeconds,
                suffix: " 秒"
            )
            if let summary = model.listeningEvidenceSummary {
                GridRow {
                    Text("听句理解").foregroundStyle(.secondary)
                    Text(summary).monospacedDigit()
                }
            } else {
                metricRow("听句理解", metrics.listeningRate, suffix: "%")
            }
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
