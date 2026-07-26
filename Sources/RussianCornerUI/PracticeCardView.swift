import RussianCornerCore
import SwiftUI

public struct PracticeCardView: View {
    @Bindable private var appModel: AppModel
    @Bindable private var practice: PracticeViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let onLayoutChanged: () -> Void

    public init(
        appModel: AppModel,
        practice: PracticeViewModel,
        onLayoutChanged: @escaping () -> Void = {}
    ) {
        self.appModel = appModel
        self.practice = practice
        self.onLayoutChanged = onLayoutChanged
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
            value: practice.isDetailExpanded
        )
        .onDisappear {
            practice.handleDisappear()
        }
    }

    private var palette: CardThemePalette {
        CardTheme.palette(for: colorScheme)
    }

    private var practiceCard: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(palette.border)
            mainContent
            if practice.isDetailExpanded, !practice.isComplete {
                Divider().overlay(palette.border)
                PracticeDetailSection(
                    appModel: appModel,
                    practice: practice,
                    palette: palette
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(maxHeight: 136)
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
            width: practice.isDetailExpanded ? 430 : 360,
            height: practice.isDetailExpanded ? 386 : 240
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

    private var collapsedCard: some View {
        Button {
            appModel.isCollapsed = false
            onLayoutChanged()
        } label: {
            ZStack {
                palette.background
                Circle()
                    .fill(palette.accentSurface)
                    .frame(width: 42, height: 42)
                VStack(spacing: 0) {
                    Text("Я")
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
        }
        .buttonStyle(.plain)
        .frame(width: 58, height: 58)
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .accessibilityLabel("展开俄语练习卡")
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text("РУССКИЙ УГОЛОК")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
            Circle()
                .fill(palette.accent)
                .frame(width: 4, height: 4)
            Text(practice.currentTheme.uppercased())
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(palette.muted)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(progressText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(palette.muted)
            Button {
                appModel.isCollapsed = true
                onLayoutChanged()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.muted)
            .accessibilityLabel("收起练习卡")
            .accessibilityHint("全局快捷键 Control Option C")
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
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
                Text(status)
                    .font(.system(size: 9))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
                    .accessibilityLabel(status)
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

    private func revealedAnswer(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(answer)
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
                .accessibilityLabel("答案：\(answer)")

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
                    practice.isDetailExpanded ? "收起详情" : "详情",
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
                gradeButton("Again", grade: .again)
                gradeButton("Hard", grade: .hard)
                gradeButton("Easy", grade: .easy, prominent: true)
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

    private func gradeButton(
        _ title: String,
        grade: ReviewGrade,
        prominent: Bool = false
    ) -> some View {
        Button(title) {
            do {
                try practice.grade(grade)
                onLayoutChanged()
            } catch {
                practice.showStatus(error.localizedDescription)
            }
        }
        .buttonStyle(
            GradeButtonStyle(
                palette: palette,
                prominent: prominent
            )
        )
        .accessibilityHint("提交 \(title) 评分并进入下一项")
    }

    private var progressText: String {
        guard !practice.isComplete else { return "完成" }
        return "\(practice.currentIndex + 1) / \(max(practice.totalCount, 1))"
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
