import AppKit
import Observation
import RussianCornerCore
import SwiftUI

private enum CardPalette {
  static let paper = Color(
    nsColor: NSColor(
      name: nil,
      dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
          ? NSColor(calibratedRed: 0.12, green: 0.11, blue: 0.095, alpha: 1)
          : NSColor(calibratedRed: 0.96, green: 0.925, blue: 0.82, alpha: 1)
      }
    )
  )
  static let ink = Color(
    nsColor: NSColor(
      name: nil,
      dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
          ? NSColor(calibratedWhite: 0.91, alpha: 1)
          : NSColor(calibratedWhite: 0.10, alpha: 1)
      }
    )
  )
  static let mutedInk = ink.opacity(0.58)
  static let rust = Color(
    nsColor: NSColor(
      name: nil,
      dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
          ? NSColor(calibratedRed: 0.78, green: 0.33, blue: 0.23, alpha: 1)
          : NSColor(calibratedRed: 0.56, green: 0.16, blue: 0.10, alpha: 1)
      }
    )
  )
}

public struct PracticeCardView: View {
  @Bindable private var appModel: AppModel
  @Bindable private var practice: PracticeViewModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        expandedCard
      }
    }
    .foregroundStyle(CardPalette.ink)
    .background(CardPalette.paper)
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(CardPalette.ink.opacity(0.18), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    .opacity(appModel.opacity)
    .animation(
      reduceMotion ? nil : .snappy(duration: 0.24),
      value: appModel.isCollapsed
    )
    .onDisappear {
      practice.handleDisappear()
    }
  }

  private var expandedCard: some View {
    VStack(spacing: 0) {
      header
      rule
      promptArea
      rule
      controls
    }
    .background {
      PaperGrain()
        .allowsHitTesting(false)
    }
    .frame(width: 430, height: 386)
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
        CardPalette.rust.opacity(0.14)
        VStack(spacing: 1) {
          Text("Я")
            .font(.custom("PT Serif", size: 25))
          Text(
            practice.isComplete
              ? "✓" : "\(practice.currentIndex + 1)"
          )
            .font(.system(size: 8, design: .monospaced))
        }
      }
    }
    .buttonStyle(.plain)
    .frame(width: 58, height: 58)
    .accessibilityLabel("展开俄语练习卡")
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 9) {
      Text("РУССКИЙ УГОЛОК")
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .tracking(1.3)
      Text("•")
        .foregroundStyle(CardPalette.rust)
      Text(practice.currentTheme.uppercased())
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(CardPalette.mutedInk)
      Spacer()
      Text(
        "\(min(practice.currentIndex + 1, max(practice.totalCount, 1)))"
          + " / \(max(practice.totalCount, 1))"
      )
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(CardPalette.mutedInk)
      Button {
        appModel.isCollapsed = true
        onLayoutChanged()
      } label: {
        Image(systemName: "minus")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("收起练习卡")
      .accessibilityHint("全局快捷键 Control Option C")
    }
    .padding(.horizontal, 20)
    .frame(height: 43)
  }

  private var promptArea: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text(practice.mode == .quiet ? "默读 · 主动回忆" : "开口 · 主动回忆")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(CardPalette.rust)
          Spacer()
          Text("\(practice.remainingRecallSeconds) SEC")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(
              practice.remainingRecallSeconds == 0
                ? CardPalette.rust : CardPalette.mutedInk
            )
        }

        if practice.isComplete {
          completionMessage
        } else {
          Text(practice.prompt ?? "")
            .font(.system(size: 17 * appModel.fontScale, weight: .regular))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("提示：\(practice.prompt ?? "")")

          if let answer = practice.answer {
            VStack(alignment: .leading, spacing: 10) {
              Text("ОТВЕТ")
                .font(
                  .system(
                    size: 9,
                    weight: .semibold,
                    design: .monospaced
                  )
                )
                .tracking(1.2)
                .foregroundStyle(CardPalette.rust)
              Text(answer)
                .font(.custom("PT Serif", size: 24 * appModel.fontScale))
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("答案：\(answer)")
              if practice.currentLexeme != nil {
                lexemeDetails
              } else if practice.microDialogueTurns.count >= 2 {
                microDialogue
              }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
          } else {
            Button("显示答案") {
              practice.reveal()
            }
            .buttonStyle(RustOutlineButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityHint("显示俄语答案")
          }
        }

        if let status = practice.statusMessage ?? appModel.transientStatus {
          Text(status)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(CardPalette.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(status)
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 17)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var completionMessage: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("Сегодня всё.")
        .font(.custom("PT Serif", size: 28 * appModel.fontScale))
      Text("今天的卡片已完成。Again 卡也已经重新练过。")
        .font(.system(size: 14 * appModel.fontScale))
        .foregroundStyle(CardPalette.mutedInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("今天的卡片已完成")
  }

  private var lexemeDetails: some View {
    VStack(alignment: .leading, spacing: 9) {
      if !practice.lexemeGrammarLabels.isEmpty {
        Text(practice.lexemeGrammarLabels.joined(separator: " · "))
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(CardPalette.mutedInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let lexeme = practice.currentLexeme {
        Text("中文：\(lexeme.glossZh)")
          .font(.system(size: 12 * appModel.fontScale))
        if !lexeme.collocations.isEmpty {
          detailBlock(
            title: "搭配",
            value: lexeme.collocations.prefix(2).joined(separator: "  ·  ")
          )
        }
        if let government = lexeme.government, !government.isEmpty {
          detailBlock(title: "支配 / 用法", value: government)
        }
        if let aspectPairNote = lexeme.aspectPairNote,
          !aspectPairNote.isEmpty
        {
          detailBlock(title: "体对说明", value: aspectPairNote)
        }
        detailBlock(title: "例句", value: lexeme.example)
      }
      if let context = practice.currentContextSentence {
        detailBlock(
          title: "场景 · \(context.theme)",
          value: context.practiceRu
        )
      }
    }
    .textSelection(.enabled)
  }

  private var microDialogue: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("МИКРО-ДИАЛОГ · 场景串练")
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(CardPalette.rust)
      ForEach(Array(practice.microDialogueTurns.enumerated()), id: \.element.id) {
        index, turn in
        VStack(alignment: .leading, spacing: 2) {
          Text("A\(index + 1) · \(turn.cue)")
            .font(.system(size: 11 * appModel.fontScale))
            .foregroundStyle(CardPalette.mutedInk)
          Text("Вы · \(turn.response)")
            .font(.system(size: 12 * appModel.fontScale))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .textSelection(.enabled)
  }

  private func detailBlock(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title.uppercased())
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(CardPalette.rust)
      Text(value)
        .font(.system(size: 12 * appModel.fontScale))
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var controls: some View {
    VStack(spacing: 10) {
      HStack(spacing: 8) {
        utilityButton("朗读", systemImage: "speaker.wave.2") {
          practice.speak()
        }
        if practice.currentLexeme != nil {
          utilityButton(
            practice.lexemeDirection == .recognition ? "俄→中" : "中→俄",
            systemImage: "arrow.left.arrow.right"
          ) {
            practice.toggleLexemeDirection()
          }
          .accessibilityHint("切换认词和主动提取方向")
        }
        utilityButton(
          practice.isRecording ? "停止" : "录音",
          systemImage: practice.isRecording ? "stop.circle" : "mic"
        ) {
          Task { await practice.toggleRecording() }
        }
        .accessibilityHint("全局快捷键 Control Option M")
        utilityButton("下一项", systemImage: "arrow.right") {
          practice.next()
        }
        Spacer()
      }

      if practice.hasRecording {
        HStack(spacing: 12) {
          utilityButton("播放", systemImage: "play.circle") {
            practice.playRecording()
          }
          utilityButton("保存", systemImage: "square.and.arrow.down") {
            do {
              try practice.saveRecording()
            } catch {
              practice.showStatus(
                "录音保存失败：\(error.localizedDescription)"
              )
            }
          }
          utilityButton("丢弃", systemImage: "trash") {
            practice.discardRecording()
          }
          Spacer()
        }
      }

      HStack(spacing: 8) {
        gradeButton("Again", grade: .again)
        gradeButton("Hard", grade: .hard)
        gradeButton("Easy", grade: .easy, prominent: true)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 13)
  }

  private var rule: some View {
    Rectangle()
      .fill(CardPalette.ink.opacity(0.16))
      .frame(height: 1)
  }

  private func utilityButton(
    _ title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.system(size: 11, weight: .medium))
    }
    .buttonStyle(.plain)
    .foregroundStyle(CardPalette.mutedInk)
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
      } catch {
        practice.showStatus("进度暂未保存：\(error.localizedDescription)")
      }
    }
    .buttonStyle(
      GradeButtonStyle(
        prominent: prominent,
        enabled: practice.isRevealed
      )
    )
    .disabled(!practice.isRevealed)
    .accessibilityLabel("评分 \(title)")
    .accessibilityHint(
      "显示答案后可评分；全局快捷键 Control Option \(gradeShortcut(grade))"
    )
  }

  private func gradeShortcut(_ grade: ReviewGrade) -> String {
    switch grade {
    case .again: "1"
    case .hard: "2"
    case .easy: "3"
    }
  }
}

private struct PaperGrain: View {
  var body: some View {
    Canvas { context, size in
      for index in 0..<90 {
        let x = CGFloat((index * 47) % 431) / 431 * size.width
        let y = CGFloat((index * 83) % 389) / 389 * size.height
        let rect = CGRect(x: x, y: y, width: 0.8, height: 0.8)
        context.fill(
          Path(ellipseIn: rect),
          with: .color(CardPalette.ink.opacity(0.045))
        )
      }
    }
  }
}

private struct RustOutlineButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(CardPalette.rust)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .overlay {
        RoundedRectangle(cornerRadius: 4)
          .stroke(CardPalette.rust.opacity(0.75), lineWidth: 1)
      }
      .opacity(configuration.isPressed ? 0.65 : 1)
  }
}

private struct GradeButtonStyle: ButtonStyle {
  let prominent: Bool
  let enabled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 11, weight: .semibold, design: .monospaced))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .foregroundStyle(
        prominent && enabled ? CardPalette.paper : CardPalette.ink
      )
      .background(
        prominent && enabled
          ? CardPalette.rust
          : CardPalette.ink.opacity(configuration.isPressed ? 0.12 : 0.045)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 4)
          .stroke(CardPalette.ink.opacity(0.19), lineWidth: 1)
      }
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .opacity(enabled ? 1 : 0.38)
  }
}
