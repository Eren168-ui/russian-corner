import SwiftUI

public struct RussianCornerProgressView: View {
  @Bindable private var runtime: AppRuntime
  @Environment(\.colorScheme) private var colorScheme

  public init(runtime: AppRuntime) {
    self.runtime = runtime
  }

  public var body: some View {
    ZStack {
      paper.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          header
          summaryGrid
          recentReport
          topicCoverage
          learningNote
        }
        .padding(30)
      }
    }
    .foregroundStyle(ink)
    .frame(
      minWidth: 720,
      idealWidth: 820,
      minHeight: 600,
      idealHeight: 720
    )
    .task {
      refresh()
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 18) {
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 9) {
          Text("РУССКИЙ УГОЛОК")
            .font(.system(size: 10, weight: .bold))
            .tracking(1.7)
          Circle()
            .fill(accent)
            .frame(width: 6, height: 6)
          Text("学习记录")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(mutedInk)
        }
        Text("看见坚持，也看见下一步。")
          .font(.system(size: 30, weight: .semibold, design: .serif))
        Text(
          Date().formatted(
            .dateTime
              .locale(Locale(identifier: "zh_CN"))
              .year().month().day().weekday(.wide)
          )
        )
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(mutedInk)
      }
      Spacer()
      Button {
        refresh()
      } label: {
        Label("刷新", systemImage: "arrow.clockwise")
          .font(.system(size: 11, weight: .semibold))
          .padding(.horizontal, 13)
          .frame(height: 34)
      }
      .buttonStyle(.plain)
      .foregroundStyle(accent)
      .background(accent.opacity(0.1), in: Capsule())
      .accessibilityHint("从本地学习记录重新计算当前页面")
    }
  }

  private var summaryGrid: some View {
    LazyVGrid(
      columns: Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 4
      ),
      spacing: 12
    ) {
      metricCard(title: "今日完成") {
        Text(runtime.learningHistory.todayProgressText)
          .metricValue()
        ProgressView(
          value: Double(runtime.learningHistory.todayCompleted),
          total: Double(max(runtime.learningHistory.todayTarget, 1))
        )
        .tint(accent)
        Text(
          runtime.learningHistory.todayTarget == 0
            ? "今日队列暂不可用"
            : "目标 \(runtime.learningHistory.todayTarget) 卡"
        )
        .metricDetail()
      }

      metricCard(title: "连续学习") {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text("\(runtime.learningHistory.streakDays)")
            .metricValue()
          Text("天")
            .font(.caption)
            .foregroundStyle(mutedInk)
        }
        Text(
          runtime.learningHistory.needsPracticeToday
            ? "今日待续" : "今天已留下记录"
        )
        .metricDetail(color: runtime.learningHistory.needsPracticeToday
          ? accent : mutedInk)
      }

      metricCard(title: "今日正确率") {
        Text(runtime.learningHistory.todayAccuracyText)
          .metricValue()
        Text(
          runtime.learningHistory.todayAttemptCount == 0
            ? "今天尚未作答"
            : "\(runtime.learningHistory.todayCorrectCount) 次正确 · "
              + "\(runtime.learningHistory.todayAttemptCount) 次作答"
        )
        .metricDetail()
      }

      metricCard(title: "已掌握") {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text("\(runtime.learningHistory.masteredTotal)")
            .metricValue()
          Text("项")
            .font(.caption)
            .foregroundStyle(mutedInk)
        }
        Text(
          "单词 \(runtime.learningHistory.masteredLexemeCount)"
            + " · 句子 \(runtime.learningHistory.masteredSentenceCount)"
        )
        .metricDetail()
      }
    }
  }

  private var recentReport: some View {
    section(title: "近 7 天学习报告", index: "01") {
      VStack(spacing: 18) {
        sevenDayChart
        Divider().overlay(border)
        VStack(spacing: 0) {
          ForEach(runtime.learningHistory.recentDays) { record in
            dailyRow(record)
            if record.id != runtime.learningHistory.recentDays.last?.id {
              Divider().overlay(border.opacity(0.7))
            }
          }
        }
      }
      .padding(18)
      .background(surface, in: RoundedRectangle(cornerRadius: 14))
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(border, lineWidth: 1)
      }
    }
  }

  private var sevenDayChart: some View {
    HStack(alignment: .bottom, spacing: 12) {
      ForEach(runtime.learningHistory.recentDays) { record in
        VStack(spacing: 8) {
          Text("\(record.completedCount)")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(
              record.completedCount > 0 ? ink : mutedInk
            )
          GeometryReader { geometry in
            let denominator = max(
              record.targetCount,
              record.completedCount,
              1
            )
            let ratio = min(
              Double(record.completedCount) / Double(denominator),
              1
            )
            ZStack(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 5)
                .fill(border.opacity(0.55))
              RoundedRectangle(cornerRadius: 5)
                .fill(
                  record.completedCount > 0
                    ? accent : mutedInk.opacity(0.16)
                )
                .frame(
                  height: max(
                    record.completedCount > 0 ? 7 : 0,
                    geometry.size.height * ratio
                  )
                )
            }
          }
          .frame(height: 92)
          Text(shortWeekday(record.day))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(mutedInk)
          Text(shortDate(record.day))
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(mutedInk)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "\(longDate(record.day))，完成 \(record.completedCount) 卡，"
            + "目标 \(record.targetCount) 卡"
        )
      }
    }
    .frame(height: 144)
  }

  private func dailyRow(_ record: DailyLearningRecord) -> some View {
    Grid(horizontalSpacing: 14, verticalSpacing: 0) {
      GridRow {
        VStack(alignment: .leading, spacing: 3) {
          Text(longDate(record.day))
            .font(.system(size: 11, weight: .semibold))
          Text(shortWeekday(record.day))
            .font(.system(size: 9))
            .foregroundStyle(mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        reportValue(
          "\(record.completedCount) / \(record.targetCount)",
          label: "完成"
        )
        reportValue(
          record.attemptCount == 0
            ? "—"
            : "\(Int(((record.accuracy ?? 0) * 100).rounded()))%",
          label: "\(record.correctCount) / \(record.attemptCount) 正确"
        )
        reportValue(
          durationText(record.studyDurationSeconds),
          label: "学习时长"
        )
      }
    }
    .padding(.vertical, 11)
  }

  private var topicCoverage: some View {
    section(title: "话题覆盖", index: "02") {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("\(runtime.learningHistory.coveredTopics.count)")
            .font(.system(size: 28, weight: .semibold, design: .serif))
          Text("/ \(runtime.learningHistory.totalTopicCount) 个话题")
            .font(.callout)
            .foregroundStyle(mutedInk)
        }

        if runtime.learningHistory.coveredTopics.isEmpty {
          Label(
            "完成句子练习后，这里会沉淀你覆盖过的真实话题。",
            systemImage: "map"
          )
          .font(.callout)
          .foregroundStyle(mutedInk)
          .padding(.vertical, 8)
        } else {
          LazyVGrid(
            columns: [
              GridItem(.flexible()),
              GridItem(.flexible()),
              GridItem(.flexible()),
            ],
            alignment: .leading,
            spacing: 9
          ) {
            ForEach(runtime.learningHistory.coveredTopics) { topic in
              HStack(spacing: 7) {
                Text(String(format: "%02d", topic.number))
                  .font(.system(size: 9, design: .monospaced))
                  .foregroundStyle(accent)
                Text(topic.titleZh)
                  .font(.system(size: 11, weight: .medium))
                  .lineLimit(1)
                Spacer(minLength: 0)
              }
              .padding(.horizontal, 10)
              .frame(height: 34)
              .background(surface, in: RoundedRectangle(cornerRadius: 8))
              .overlay {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(border, lineWidth: 1)
              }
              .accessibilityLabel(
                "话题 \(topic.number)，\(topic.titleZh)"
              )
            }
          }
        }
      }
    }
  }

  private var learningNote: some View {
    VStack(alignment: .leading, spacing: 9) {
      if let status = runtime.learningHistoryStatus {
        Label(status, systemImage: "exclamationmark.circle")
          .font(.callout)
          .foregroundStyle(accent)
      }
      Text(
        "这些数据来自本机保存的复习记录。掌握度达到 3 后，"
          + "卡片会逐步从中文提示切换为俄语引导。"
      )
      .font(.callout)
      .foregroundStyle(mutedInk)
      .lineSpacing(3)
      Text("Данные остаются на этом Mac · 数据仅保存在本机")
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(mutedInk.opacity(0.85))
    }
    .padding(.bottom, 8)
  }

  private func metricCard<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text(title)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(mutedInk)
      content()
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
    .padding(15)
    .background(surface, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(border, lineWidth: 1)
    }
  }

  private func section<Content: View>(
    title: String,
    index: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack(spacing: 10) {
        Text(index)
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(accent)
        Text(title)
          .font(.system(size: 19, weight: .semibold, design: .serif))
        Rectangle()
          .fill(border)
          .frame(height: 1)
      }
      content()
    }
  }

  private func reportValue(_ value: String, label: String) -> some View {
    VStack(alignment: .trailing, spacing: 3) {
      Text(value)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
      Text(label)
        .font(.system(size: 9))
        .foregroundStyle(mutedInk)
    }
    .frame(minWidth: 100, alignment: .trailing)
  }

  private func refresh() {
    do {
      try runtime.refreshProgress()
    } catch {
      runtime.appModel.transientStatus =
        "学习记录刷新失败：\(error.localizedDescription)"
    }
  }

  private func durationText(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    let minutes = seconds / 60
    let remainder = seconds % 60
    if minutes == 0 { return "\(remainder) 秒" }
    return remainder == 0
      ? "\(minutes) 分钟"
      : "\(minutes)分\(remainder)秒"
  }

  private func shortWeekday(_ date: Date) -> String {
    date.formatted(
      .dateTime
        .locale(Locale(identifier: "zh_CN"))
        .weekday(.short)
    )
  }

  private func shortDate(_ date: Date) -> String {
    date.formatted(
      .dateTime
        .locale(Locale(identifier: "zh_CN"))
        .month(.twoDigits).day(.twoDigits)
    )
  }

  private func longDate(_ date: Date) -> String {
    date.formatted(
      .dateTime
        .locale(Locale(identifier: "zh_CN"))
        .month().day()
    )
  }

  private var paper: Color {
    colorScheme == .dark
      ? Color(red: 0.105, green: 0.105, blue: 0.095)
      : Color(red: 0.965, green: 0.945, blue: 0.89)
  }

  private var surface: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.045)
      : Color.white.opacity(0.42)
  }

  private var ink: Color {
    colorScheme == .dark
      ? Color(red: 0.92, green: 0.91, blue: 0.86)
      : Color(red: 0.12, green: 0.115, blue: 0.1)
  }

  private var mutedInk: Color {
    ink.opacity(0.62)
  }

  private var accent: Color {
    colorScheme == .dark
      ? Color(red: 0.87, green: 0.39, blue: 0.24)
      : Color(red: 0.68, green: 0.25, blue: 0.15)
  }

  private var border: Color {
    ink.opacity(0.13)
  }
}

private extension View {
  func metricValue() -> some View {
    font(.system(size: 27, weight: .semibold, design: .serif))
  }

  func metricDetail(color: Color = .secondary) -> some View {
    font(.system(size: 9))
      .foregroundStyle(color)
      .lineLimit(2)
  }
}
