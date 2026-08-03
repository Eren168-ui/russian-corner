import AppKit
import RussianCornerCore
import SwiftUI

public enum CollapsedCardDragGeometry {
    nonisolated public static func windowOrigin(
        initialMouseLocation: CGPoint,
        currentMouseLocation: CGPoint,
        initialWindowOrigin: CGPoint
    ) -> CGPoint {
        CGPoint(
            x: initialWindowOrigin.x
                + currentMouseLocation.x
                - initialMouseLocation.x,
            y: initialWindowOrigin.y
                + currentMouseLocation.y
                - initialMouseLocation.y
        )
    }
}

public enum PracticeCardMetrics {
    public static let headerActionHitWidth: CGFloat = 38
    public static let headerActionHitHeight: CGFloat = 34
    public static let moreActionHitWidth: CGFloat = 32
    public static let historyActionTitle = "记录"
    public static let historyActionHitHeight: CGFloat = 30
    public static let wordCloseActionTitle = "关闭词义"
    public static let recallOutcomeTitles = [
        "3 秒内完整说出",
        "大意对，用法有卡顿",
        "看答案才想起",
        "不会",
    ]
}

public enum PracticeCardUtilityAction: CaseIterable, Sendable {
    case sceneTraining
    case expressionCapture
    case settings
    case history
    case reflection
    case diagnostics
    case exportReport

    public var title: String {
        switch self {
        case .sceneTraining: "今日英语场景…"
        case .expressionCapture: "收集英语表达…"
        case .settings: "设置…"
        case .history: "学习记录…"
        case .reflection: "今日反馈…"
        case .diagnostics: "学习诊断…"
        case .exportReport: "导出近 7 天学习报告…"
        }
    }

    public var symbolName: String {
        switch self {
        case .sceneTraining: "person.2.wave.2"
        case .expressionCapture: "text.badge.plus"
        case .settings: "gearshape"
        case .history: "chart.bar"
        case .reflection: "square.and.pencil"
        case .diagnostics: "waveform.badge.magnifyingglass"
        case .exportReport: "square.and.arrow.up"
        }
    }
}

public struct PracticeCardUtilityActions {
    public var openSceneTraining: () -> Void
    public var openExpressionCapture: () -> Void
    public var openSettings: () -> Void
    public var openHistory: () -> Void
    public var openReflection: () -> Void
    public var openDiagnostics: () -> Void
    public var exportReport: () -> Void

    public init(
        openSceneTraining: @escaping () -> Void = {},
        openExpressionCapture: @escaping () -> Void = {},
        openSettings: @escaping () -> Void = {},
        openHistory: @escaping () -> Void = {},
        openReflection: @escaping () -> Void = {},
        openDiagnostics: @escaping () -> Void = {},
        exportReport: @escaping () -> Void = {}
    ) {
        self.openSceneTraining = openSceneTraining
        self.openExpressionCapture = openExpressionCapture
        self.openSettings = openSettings
        self.openHistory = openHistory
        self.openReflection = openReflection
        self.openDiagnostics = openDiagnostics
        self.exportReport = exportReport
    }

    public func perform(_ action: PracticeCardUtilityAction) {
        switch action {
        case .sceneTraining: openSceneTraining()
        case .expressionCapture: openExpressionCapture()
        case .settings: openSettings()
        case .history: openHistory()
        case .reflection: openReflection()
        case .diagnostics: openDiagnostics()
        case .exportReport: exportReport()
        }
    }
}

public struct PracticeCardLanguageActions {
    public let availableLanguages: [StudyLanguage]
    public let switchLanguage: (StudyLanguage) -> Void

    public init(
        availableLanguages: [StudyLanguage],
        switchLanguage: @escaping (StudyLanguage) -> Void
    ) {
        self.availableLanguages = availableLanguages
        self.switchLanguage = switchLanguage
    }
}

public struct PracticeCardView: View {
    @Bindable private var appModel: AppModel
    @Bindable private var practice: PracticeViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let reflectionModel: DailyReflectionViewModel?
    private let onLayoutChanged: () -> Void
    private let onCollapsedCardActivated: (() -> Void)?
    private let onReminderPermissionAction: () -> Void
    private let onOpenLearningHistory: () -> Void
    private let utilityActions: PracticeCardUtilityActions
    private let languageActions: PracticeCardLanguageActions?

    public init(
        appModel: AppModel,
        practice: PracticeViewModel,
        reflectionModel: DailyReflectionViewModel? = nil,
        onLayoutChanged: @escaping () -> Void = {},
        onCollapsedCardActivated: (() -> Void)? = nil,
        onReminderPermissionAction: @escaping () -> Void = {},
        onOpenLearningHistory: @escaping () -> Void = {},
        utilityActions: PracticeCardUtilityActions = .init(),
        languageActions: PracticeCardLanguageActions? = nil
    ) {
        self.appModel = appModel
        self.practice = practice
        self.reflectionModel = reflectionModel
        self.onLayoutChanged = onLayoutChanged
        self.onCollapsedCardActivated = onCollapsedCardActivated
        self.onReminderPermissionAction = onReminderPermissionAction
        self.onOpenLearningHistory = onOpenLearningHistory
        self.utilityActions = utilityActions
        self.languageActions = languageActions
    }

    public var body: some View {
        Group {
            if appModel.isCollapsed {
                collapsedCard
            } else {
                practiceCard
            }
        }
        .opacity(appModel.opacity)
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.22),
            value: appModel.isCollapsed
        )
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.22),
            value: reflectionModel?.isCompletionOfferPresented ?? false
        )
        .onChange(of: practice.isComplete) { wasComplete, isComplete in
            guard !wasComplete, isComplete else { return }
            if reflectionModel?.presentAfterCompletionIfNeeded() == true {
                onLayoutChanged()
            }
        }
        .onDisappear {
            practice.handleDisappear()
        }
    }

    private var palette: CardThemePalette {
        CardTheme.palette(for: colorScheme)
    }

    @ViewBuilder
    private var practiceCard: some View {
        if practice.isComplete,
            let reflectionModel,
            reflectionModel.isCompletionOfferPresented
        {
            DailyReflectionView(
                model: reflectionModel,
                embedded: true,
                onLayoutChanged: onLayoutChanged
            )
            .shadow(color: .black.opacity(0.16), radius: 16, y: 7)
        } else {
            standardPracticeCard
        }
    }

    private var standardPracticeCard: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(palette.border)
            mainContent
            if practice.isDetailExpanded, !practice.isComplete {
                Divider().overlay(palette.border)
                PracticeDetailSection(
                    appModel: appModel,
                    practice: practice,
                    palette: palette,
                    onLayoutChanged: onLayoutChanged
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(
                    maxHeight: practice.selectedWordAnalysis == nil
                        ? 136 : 215
                )
            }
            if practice.isStructuredRecallPresented,
                !practice.isComplete
            {
                Divider().overlay(palette.border)
                structuredRecallSection
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .frame(maxHeight: 118)
            }
            Divider().overlay(palette.border)
            bottomControls
        }
        .foregroundStyle(palette.primary)
        .background(palette.background)
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 16, y: 7)
        .frame(
            width: standardCardPresentation.size.width,
            height: standardCardPresentation.size.height
        )
        .task(id: practice.currentIndex) {
            while !Task.isCancelled
                && !practice.isRevealed
                && practice.remainingRecallSeconds > 0
            {
                try? await Task.sleep(for: .milliseconds(200))
                practice.refreshRecallTimer()
            }
        }
    }

    private var standardCardPresentation: PracticePanelPresentation {
        PracticePanelPresentation.resolve(
            isCollapsed: false,
            isDetailExpanded: practice.isDetailExpanded,
            hasSelectedWord: practice.selectedWordAnalysis != nil,
            isTransferPresented:
                practice.isStructuredRecallPresented
        )
    }

    private var collapsedCard: some View {
        ZStack {
            palette.background
            Circle()
                .fill(palette.accentSurface)
                .frame(width: 42, height: 42)
            VStack(spacing: 0) {
                Text(
                    appModel.language == .english ? "EN" : "Я"
                )
                    .font(.system(size: 23, design: .serif))
                    .foregroundStyle(palette.primary)
                Text(
                    practice.isComplete
                        ? "✓" : "\(practice.currentIndex + 1)"
                )
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(palette.accent)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
        .overlay {
            CollapsedCardInteractionSurface(
                onActivate: activateCollapsedCard
            )
        }
        .frame(width: 58, height: 58)
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    private func activateCollapsedCard() {
        if let onCollapsedCardActivated {
            onCollapsedCardActivated()
        } else {
            appModel.isCollapsed = false
            onLayoutChanged()
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text("LANGUAGE CORNER")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
            if let languageActions {
                Menu {
                    ForEach(
                        languageActions.availableLanguages,
                        id: \.self
                    ) { language in
                        Button {
                            languageActions.switchLanguage(language)
                        } label: {
                            if language == appModel.language {
                                Label(
                                    language.displayName,
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(language.displayName)
                            }
                        }
                    }
                } label: {
                    Text(appModel.language.shortLabel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("切换学习语言")
            }
            Circle()
                .fill(palette.accent)
                .frame(width: 4, height: 4)
            Text(practice.currentTheme.uppercased())
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(palette.muted)
                .lineLimit(1)
            utilityMenu
            Spacer(minLength: 8)
            Menu {
                ForEach(FloatingCorner.allCases, id: \.self) { corner in
                    Button {
                        appModel.snap(to: corner)
                        onLayoutChanged()
                    } label: {
                        if appModel.placementMode == .snap
                            && appModel.corner == corner
                        {
                            Label(
                                corner.title,
                                systemImage: "checkmark"
                            )
                        } else {
                            Text(corner.title)
                        }
                    }
                }
            } label: {
                Image(
                    systemName: appModel.placementMode == .free
                        ? "move.3d"
                        : appModel.corner.symbolName
                )
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(palette.muted)
            .accessibilityLabel(
                appModel.placementMode == .free
                    ? "卡片当前为自由拖放"
                    : "移动卡片位置，当前\(appModel.corner.title)"
            )
            Text(progressText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(palette.muted)
            Button {
                practice.clearWordAnalysis()
                appModel.isCollapsed = true
                onLayoutChanged()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(
                        width: PracticeCardMetrics.headerActionHitWidth,
                        height: PracticeCardMetrics.headerActionHitHeight
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.muted)
            .help("收起练习卡（Control Option C）")
            .accessibilityLabel("收起练习卡")
            .accessibilityHint("全局快捷键 Control Option C")
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
    }

    private var utilityMenu: some View {
        Menu {
            ForEach(
                PracticeCardUtilityAction.allCases,
                id: \.self
            ) { action in
                Button(
                    action.title,
                    systemImage: action.symbolName
                ) {
                    if action == .history {
                        onOpenLearningHistory()
                    } else {
                        utilityActions.perform(action)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 11, weight: .semibold))
                .frame(
                    width: PracticeCardMetrics.moreActionHitWidth,
                    height: PracticeCardMetrics.headerActionHitHeight
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(palette.accent)
        .help("更多功能")
        .accessibilityLabel("更多功能")
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if practice.isComplete {
                completionMessage
            } else {
                HStack {
                    Text(
                        practice.mode == .quiet
                            ? "默读 · 主动回忆"
                            : "开口 · 主动回忆"
                    )
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    if let origin = practice.currentItem?.origin {
                        Text(origin.title)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(palette.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                palette.secondary.opacity(0.16),
                                in: Capsule()
                            )
                            .accessibilityLabel("内容来源：\(origin.title)")
                    }
                    Spacer()
                    Text("\(practice.remainingRecallSeconds) 秒")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(
                            practice.remainingRecallSeconds == 0
                                ? palette.accent : palette.muted
                        )
                }

                Text(practice.prompt ?? "")
                    .font(
                        .system(
                            size: 16 * appModel.fontScale,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(palette.primary)
                    .lineLimit(practice.isDetailExpanded ? 3 : 2)
                    .minimumScaleFactor(0.82)
                    .accessibilityLabel("提示：\(practice.prompt ?? "")")

                if let answer = practice.answer {
                    revealedAnswer(answer)
                } else {
                    recallHint
                }
            }

            if let status = practice.statusMessage
                ?? appModel.transientStatus
            {
                HStack(spacing: 8) {
                    Text(status)
                        .font(.system(size: 9))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                        .accessibilityLabel(status)
                    if practice.statusMessage == nil,
                        let action = appModel.reminderPermissionAction
                    {
                        Button(action.title) {
                            onReminderPermissionAction()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .accessibilityHint(
                            action == .openSystemSettings
                                ? "直接打开 macOS 通知设置"
                                : "请求 macOS 通知权限"
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private var recallHint: some View {
        HStack(spacing: 7) {
            Image(systemName: "timer")
                .font(.system(size: 10, weight: .semibold))
            Text(
                practice.remainingRecallSeconds > 0
                    ? "先说出来，再核对答案"
                    : "现在核对你的表达"
            )
            .font(.system(size: 10))
        }
        .foregroundStyle(palette.muted)
        .padding(.horizontal, 10)
        .frame(height: 27)
        .background(palette.accentSurface)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var structuredRecallSection: some View {
        if let exercise = practice.currentTransferExercise {
            transferExerciseSection(exercise)
        } else {
            recallOutcomeSection
        }
    }

    private var recallOutcomeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本次记忆评估")
                        .font(.system(size: 11, weight: .semibold))
                    Text("刚才实际说到了哪一步？")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.muted)
                }
                Spacer()
                Text("用于安排下次复习")
                    .font(.system(size: 8))
                    .foregroundStyle(palette.muted)
            }
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 7),
                    GridItem(.flexible(), spacing: 7),
                ],
                spacing: 7
            ) {
                recallOutcomeButton(
                    PracticeCardMetrics.recallOutcomeTitles[0],
                    outcome: .fluentWithinThreeSeconds
                )
                recallOutcomeButton(
                    PracticeCardMetrics.recallOutcomeTitles[1],
                    outcome: .coreMeaningWithUsageIssue
                )
                recallOutcomeButton(
                    PracticeCardMetrics.recallOutcomeTitles[2],
                    outcome: .rememberedAfterReveal
                )
                recallOutcomeButton(
                    PracticeCardMetrics.recallOutcomeTitles[3],
                    outcome: .unknown
                )
            }
        }
    }

    private func recallOutcomeButton(
        _ title: String,
        outcome: RecallOutcome
    ) -> some View {
        Button(title) {
            do {
                try practice.submitRecallOutcome(outcome)
                onLayoutChanged()
            } catch {
                practice.showStatus(error.localizedDescription)
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(palette.primary)
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(palette.accentSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .accessibilityHint("记录回忆表现；必要时继续完成迁移检验")
    }

    private func transferExerciseSection(
        _ exercise: TransferExercise
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("记忆迁移检验 · 用于安排下次复习")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(palette.muted)
            Text("再验一次：\(exercise.prompt)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.accent)
                .lineLimit(2)
            ForEach(exercise.options) { option in
                Button {
                    do {
                        try practice.submitTransferAnswer(
                            optionID: option.id
                        )
                        onLayoutChanged()
                    } catch {
                        practice.showStatus(
                            error.localizedDescription
                        )
                    }
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .stroke(palette.border, lineWidth: 1)
                            .frame(width: 11, height: 11)
                        Text(option.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(palette.primary)
                .accessibilityLabel("迁移答案：\(option.text)")
            }
        }
    }

    private func revealedAnswer(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if practice.currentCard != nil,
                    !practice.currentSentenceWords.isEmpty
                {
                    InteractiveTargetText(
                        text: answer,
                        language: appModel.language,
                        selectedTokenIndex:
                            practice.selectedWordAnalysis?.tokenIndex
                    ) { tokenIndex in
                        practice.toggleWordAnalysis(
                            tokenIndex: tokenIndex
                        )
                        onLayoutChanged()
                    }
                } else {
                    Text(answer)
                        .accessibilityLabel("答案：\(answer)")
                }
            }
            .font(
                .system(
                    size: 20 * appModel.fontScale,
                    weight: .medium,
                    design: .serif
                )
            )
            .foregroundStyle(palette.secondary)
            .lineLimit(practice.isDetailExpanded ? 3 : 2)
            .minimumScaleFactor(0.78)
            .textSelection(.enabled)

            if let collocation = practice.currentLexeme?
                .collocations.first
            {
                Text("搭配 · \(collocation)")
                    .font(.system(size: 10 * appModel.fontScale))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
        }
        .transition(.opacity)
    }

    private var completionMessage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Сегодня всё.")
                .font(
                    .system(
                        size: 25 * appModel.fontScale,
                        weight: .medium,
                        design: .serif
                    )
                )
            Text("今天的卡片已经完成。")
                .font(.system(size: 12 * appModel.fontScale))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今天的卡片已完成")
    }

    private var bottomControls: some View {
        HStack(spacing: 7) {
            if !practice.isComplete {
                compactButton(
                    practice.selectedWordAnalysis != nil
                        ? PracticeCardMetrics.wordCloseActionTitle
                        : (practice.isDetailExpanded ? "收起详情" : "详情"),
                    systemImage: practice.isDetailExpanded
                        ? "chevron.up" : "text.alignleft"
                ) {
                    practice.toggleDetails()
                    onLayoutChanged()
                }
                compactButton("朗读", systemImage: "speaker.wave.2") {
                    practice.speak()
                }
                if practice.currentLexeme != nil {
                    compactButton(
                        practice.lexemeDirection == .recognition
                            ? "俄→中" : "中→俄",
                        systemImage: "arrow.left.arrow.right"
                    ) {
                        practice.toggleLexemeDirection()
                    }
                }
            }
            Spacer(minLength: 4)
            if practice.isRevealed, !practice.isComplete {
                Text(
                    practice.currentTransferExercise == nil
                        ? "选择实际回忆表现"
                        : "完成上方迁移检验"
                )
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(palette.muted)
            } else if !practice.isComplete {
                compactButton("下一项", systemImage: "arrow.right") {
                    practice.next()
                    onLayoutChanged()
                }
                Button("显示答案") {
                    practice.reveal()
                }
                .buttonStyle(AccentButtonStyle(palette: palette))
                .keyboardShortcut(.space, modifiers: [])
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }

    private func compactButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 9, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.muted)
        .accessibilityLabel(title)
    }

    private var progressText: String {
        guard !practice.isComplete else { return "完成" }
        return "\(practice.currentIndex + 1) / \(max(practice.totalCount, 1))"
    }
}

private struct CollapsedCardInteractionSurface: NSViewRepresentable {
    let onActivate: () -> Void

    func makeNSView(context: Context) -> CollapsedCardInteractionNSView {
        CollapsedCardInteractionNSView(onActivate: onActivate)
    }

    func updateNSView(
        _ nsView: CollapsedCardInteractionNSView,
        context: Context
    ) {
        nsView.onActivate = onActivate
    }
}

private final class CollapsedCardInteractionNSView: NSView {
    var onActivate: () -> Void
    private var initialMouseLocation: CGPoint?
    private var initialWindowOrigin: CGPoint?

    init(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
        super.init(frame: .zero)
        let panGesture = NSPanGestureRecognizer(
            target: self,
            action: #selector(handlePanGesture(_:))
        )
        let clickGesture = CollapsedCardClickGestureRecognizer(
            target: self,
            action: #selector(handleClickGesture(_:))
        )
        clickGesture.requiredDragGesture = panGesture
        addGestureRecognizer(panGesture)
        addGestureRecognizer(clickGesture)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("展开俄语练习卡")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    @objc
    private func handleClickGesture(
        _ gesture: NSClickGestureRecognizer
    ) {
        guard gesture.state == .ended else { return }
        onActivate()
    }

    @objc
    private func handlePanGesture(
        _ gesture: NSPanGestureRecognizer
    ) {
        switch gesture.state {
        case .began:
            guard let window else { return }
            initialMouseLocation = NSEvent.mouseLocation
            initialWindowOrigin = window.frame.origin
        case .changed:
            guard
                let window,
                let initialMouseLocation,
                let initialWindowOrigin
            else {
                return
            }
            window.setFrameOrigin(
                CollapsedCardDragGeometry.windowOrigin(
                    initialMouseLocation: initialMouseLocation,
                    currentMouseLocation: NSEvent.mouseLocation,
                    initialWindowOrigin: initialWindowOrigin
                )
            )
        case .ended, .cancelled, .failed:
            initialMouseLocation = nil
            initialWindowOrigin = nil
        default:
            break
        }
    }

    override func accessibilityPerformPress() -> Bool {
        if initialMouseLocation == nil {
            onActivate()
        }
        return true
    }
}

private final class CollapsedCardClickGestureRecognizer:
    NSClickGestureRecognizer
{
    weak var requiredDragGesture: NSGestureRecognizer?

    override func shouldRequireFailure(
        of otherGestureRecognizer: NSGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer === requiredDragGesture
            || super.shouldRequireFailure(
                of: otherGestureRecognizer
            )
    }
}

private struct AccentButtonStyle: ButtonStyle {
    let palette: CardThemePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background(
                palette.accent.opacity(configuration.isPressed ? 0.78 : 1)
            )
            .clipShape(Capsule())
    }
}

private struct GradeButtonStyle: ButtonStyle {
    let palette: CardThemePalette
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(
                prominent ? Color.white : palette.secondary
            )
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(
                prominent
                    ? palette.accent.opacity(
                        configuration.isPressed ? 0.78 : 1
                    )
                    : palette.accentSurface
            )
            .clipShape(Capsule())
            .overlay {
                if !prominent {
                    Capsule()
                        .stroke(palette.border, lineWidth: 1)
                }
            }
    }
}
