import SwiftUI

public struct RussianCornerProgressView: View {
  @Bindable private var runtime: AppRuntime

  public init(runtime: AppRuntime) {
    self.runtime = runtime
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      VStack(alignment: .leading, spacing: 5) {
        Text("学习进度")
          .font(.custom("PT Serif", size: 30))
        Text("Сегодня · 今日")
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(.secondary)
      }

      LazyVGrid(
        columns: [
          GridItem(.flexible()),
          GridItem(.flexible()),
        ],
        spacing: 12
      ) {
        metric("今日完成", "\(runtime.progress.completedToday)", "卡")
        metric("连续学习", "\(runtime.progress.streakDays)", "天")
        metric(
          "今日正确率",
          runtime.progress.accuracy.formatted(.percent.precision(.fractionLength(0))),
          ""
        )
        metric("已掌握", "\(runtime.progress.masteredCount)", "句")
      }

      Divider()

      Text("掌握度达到 3 后，卡片会从中文提示切换为俄语引导，让回忆逐步脱离翻译。")
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineSpacing(3)

      Spacer()
    }
    .padding(28)
    .frame(width: 460, height: 390)
    .task {
      try? runtime.refreshProgress()
    }
  }

  private func metric(
    _ title: String,
    _ value: String,
    _ suffix: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text(title)
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(value)
          .font(.custom("PT Serif", size: 30))
        Text(suffix)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(15)
    .background(.primary.opacity(0.035))
    .overlay {
      RoundedRectangle(cornerRadius: 6)
        .stroke(.primary.opacity(0.12), lineWidth: 1)
    }
  }
}
