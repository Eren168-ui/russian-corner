import SwiftUI

public struct PracticeAnswerSheetView: View {
  private let items: [PracticeAnswerSheetItem]
  private let onSelect: (Int) -> Void
  @Environment(\.colorScheme) private var colorScheme

  public init(
    items: [PracticeAnswerSheetItem],
    onSelect: @escaping (Int) -> Void
  ) {
    self.items = items
    self.onSelect = onSelect
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(items) { item in
          questionButton(item)
        }
      }
      Divider().overlay(palette.border)
      legend
    }
    .padding(16)
    .frame(width: 300)
    .background(palette.background)
    .foregroundStyle(palette.primary)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 3) {
        Text("今日答题卡")
          .font(.system(size: 14, weight: .semibold))
        Text("可自由跳题；未评估题会一直保留")
          .font(.system(size: 10))
          .foregroundStyle(palette.muted)
      }
      Spacer()
      Text("\(assessedCount)/\(items.count)")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(palette.accent)
    }
  }

  private var legend: some View {
    HStack(spacing: 12) {
      legendItem("未做", status: .unseen)
      legendItem("看过未评", status: .openedUnassessed)
      legendItem("已评", status: .assessed)
      legendItem("需重练", status: .needsRetry)
    }
    .font(.system(size: 8.5, weight: .medium))
    .foregroundStyle(palette.muted)
  }

  private func legendItem(
    _ title: String,
    status: PracticeSessionItemStatus
  ) -> some View {
    HStack(spacing: 4) {
      Circle()
        .fill(statusColor(status))
        .frame(width: 6, height: 6)
      Text(title)
    }
  }

  private func questionButton(
    _ item: PracticeAnswerSheetItem
  ) -> some View {
    Button {
      onSelect(item.index)
    } label: {
      ZStack(alignment: .topTrailing) {
        Text("\(item.number)")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        if item.isRetry {
          Text("R")
            .font(.system(size: 6.5, weight: .bold))
            .foregroundStyle(palette.accent)
            .padding(4)
        }
      }
      .frame(height: 36)
      .foregroundStyle(
        item.status == .assessed ? palette.secondary : palette.primary
      )
      .background(questionBackground(item.status))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(
            item.isCurrent ? palette.accent : statusColor(item.status),
            lineWidth: item.isCurrent ? 2 : 1
          )
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      "第 \(item.number) 题，\(statusAccessibilityLabel(item.status))"
    )
    .accessibilityAddTraits(item.isCurrent ? .isSelected : [])
  }

  private var assessedCount: Int {
    items.count { !$0.status.isPending }
  }

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: 8),
      count: 5
    )
  }

  private var palette: CardThemePalette {
    CardTheme.palette(for: colorScheme)
  }

  private func questionBackground(
    _ status: PracticeSessionItemStatus
  ) -> Color {
    switch status {
    case .unseen:
      palette.accentSurface.opacity(0.62)
    case .openedUnassessed:
      palette.accent.opacity(0.13)
    case .assessed:
      Color.green.opacity(colorScheme == .dark ? 0.13 : 0.09)
    case .needsRetry:
      Color.red.opacity(colorScheme == .dark ? 0.14 : 0.09)
    }
  }

  private func statusColor(
    _ status: PracticeSessionItemStatus
  ) -> Color {
    switch status {
    case .unseen: palette.border
    case .openedUnassessed: palette.accent
    case .assessed: .green.opacity(0.72)
    case .needsRetry: .red.opacity(0.72)
    }
  }

  private func statusAccessibilityLabel(
    _ status: PracticeSessionItemStatus
  ) -> String {
    switch status {
    case .unseen: "未作答"
    case .openedUnassessed: "已看答案但未评估"
    case .assessed: "已评估"
    case .needsRetry: "需要重练"
    }
  }
}
