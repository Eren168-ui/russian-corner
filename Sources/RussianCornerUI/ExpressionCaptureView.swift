import AppKit
import RussianCornerCore
import SwiftUI
import UniformTypeIdentifiers

public struct ExpressionCaptureView: View {
  @Bindable private var model: ExpressionCaptureViewModel
  @Environment(\.colorScheme) private var colorScheme

  public init(model: ExpressionCaptureViewModel) {
    self.model = model
  }

  public var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HSplitView {
        importColumn
          .frame(minWidth: 390)
        reviewColumn
          .frame(minWidth: 360)
      }
      Divider()
      footer
    }
    .background(background)
    .foregroundStyle(primary)
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "text.badge.plus")
        .font(.system(size: 27))
        .foregroundStyle(accent)
      VStack(alignment: .leading, spacing: 4) {
        Text("收集\(languageName)表达")
          .font(.system(size: 25, weight: .semibold, design: .serif))
        Text("从字幕、阅读笔记或粘贴文本中，只挑你真正想说出口的内容。")
          .font(.system(size: 12))
          .foregroundStyle(secondary)
      }
      Spacer()
      Text("LOCAL · DRAFT FIRST")
        .font(.system(size: 10, weight: .bold))
        .tracking(1.5)
        .foregroundStyle(accent)
    }
    .padding(22)
  }

  private var languageName: String {
    model.language == .russian ? "俄语" : "英语"
  }

  private var importColumn: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle("1 · 导入或粘贴")
      HStack {
        Button("选择字幕或笔记…", systemImage: "doc.badge.plus") {
          chooseFile()
        }
        .buttonStyle(CapturePrimaryButtonStyle(accent: accent))
        Text("支持 SRT / VTT / TXT / MD")
          .font(.system(size: 11))
          .foregroundStyle(secondary)
      }
      TextEditor(text: $model.pastedText)
        .font(.system(size: 13, design: .monospaced))
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .stroke(border, lineWidth: 1)
        }
        .frame(minHeight: 100, maxHeight: 130)
      HStack {
        Button("拆分粘贴内容", systemImage: "scissors") {
          model.loadPastedText()
        }
        .disabled(
          model.pastedText.trimmingCharacters(
            in: .whitespacesAndNewlines
          ).isEmpty
        )
        Spacer()
        Text("原文件不会被修改、移动或上传")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(secondary)
      }

      sectionTitle("2 · 勾选具体句子")
      if let preview = model.preview {
        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(preview.segments) { segment in
              Button {
                model.toggleSegmentSelection(segment.id)
              } label: {
                HStack(alignment: .top, spacing: 10) {
                  Image(
                    systemName: model.selectedSegmentIDs.contains(segment.id)
                      ? "checkmark.square.fill" : "square"
                  )
                  .foregroundStyle(accent)
                  Text(segment.text)
                    .font(.system(size: 13, weight: .medium))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(surface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
          }
        }
      } else {
        ContentUnavailableView(
          "还没有候选句",
          systemImage: "captions.bubble",
          description: Text("选择本地文件，或在上方粘贴一小段文本。")
        )
      }
    }
    .padding(22)
  }

  private var reviewColumn: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        sectionTitle("3 · 把它变成可练的表达")
        field(
          "只取其中一个短语（可选）",
          placeholder: "例如：be about to",
          text: $model.selectedPhrase
        )
        field(
          "中文意图",
          placeholder: "这句话在真实交流中想表达什么？",
          text: $model.promptZh
        )
        field(
          "使用场景",
          placeholder: "例如：临时改计划、回复朋友",
          text: $model.scene
        )
        field(
          "说话人角色（可选）",
          placeholder: "例如：朋友、同事、顾客",
          text: $model.speakerRole
        )
        VStack(alignment: .leading, spacing: 6) {
          Text("语体")
            .fieldLabel()
          Picker("语体", selection: $model.register) {
            Text("随意").tag(DialogueRegister.informal)
            Text("中性").tag(DialogueRegister.neutral)
            Text("礼貌").tag(DialogueRegister.polite)
            Text("正式").tag(DialogueRegister.formal)
          }
          .labelsHidden()
        }
        field(
          "常见下一轮回应（可选）",
          placeholder: "对方通常会怎么接？",
          text: $model.expectedReply
        )
        Button("保存为待审核候选", systemImage: "tray.and.arrow.down") {
          do {
            _ = try model.saveSelectedAsDraft()
          } catch {
            model.showStatus(error.localizedDescription)
          }
        }
        .buttonStyle(CapturePrimaryButtonStyle(accent: accent))

        Divider().padding(.vertical, 3)
        sectionTitle("本地候选")
        if model.candidates.isEmpty {
          Text("保存后的候选会出现在这里。draft 不会进入每日练习。")
            .font(.system(size: 12))
            .foregroundStyle(secondary)
        } else {
          ForEach(model.candidates.reversed()) { candidate in
            candidateRow(candidate)
          }
        }
      }
      .padding(22)
    }
  }

  private func candidateRow(
    _ candidate: ImportedExpression
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text(candidate.reviewStatus == .draft ? "DRAFT" : "REVIEWED")
          .font(.system(size: 9, weight: .bold))
          .tracking(1)
          .foregroundStyle(
            candidate.reviewStatus == .draft ? accent : .green
          )
        Spacer()
        Text(candidate.scene)
          .font(.system(size: 10))
          .foregroundStyle(secondary)
      }
      Text(candidate.targetText)
        .font(.system(size: 16, weight: .semibold, design: .serif))
      Text(candidate.promptZh)
        .font(.system(size: 12))
        .foregroundStyle(secondary)
      if candidate.reviewStatus == .draft {
        Button("我已核对，标记为可练", systemImage: "checkmark.seal") {
          do {
            try model.markReviewed(candidate.id)
          } catch {
            model.showStatus(error.localizedDescription)
          }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(accent)
      }
    }
    .padding(12)
    .background(surface)
    .clipShape(RoundedRectangle(cornerRadius: 11))
    .overlay {
      RoundedRectangle(cornerRadius: 11)
        .stroke(border, lineWidth: 1)
    }
  }

  private var footer: some View {
    HStack {
      Image(systemName: "lock.shield")
      Text("所有导入内容仅保存在本机；只有 reviewed 内容才具备投放资格。")
        .font(.system(size: 11, weight: .medium))
      Spacer()
      if let status = model.statusMessage {
        Text(status)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(accent)
          .lineLimit(1)
      }
    }
    .foregroundStyle(secondary)
    .padding(.horizontal, 22)
    .frame(height: 48)
  }

  private func field(
    _ title: String,
    placeholder: String,
    text: Binding<String>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).fieldLabel()
      TextField(placeholder, text: text)
        .textFieldStyle(.plain)
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay {
          RoundedRectangle(cornerRadius: 9)
            .stroke(border, lineWidth: 1)
        }
    }
  }

  private func sectionTitle(_ value: String) -> some View {
    Text(value)
      .font(.system(size: 11, weight: .bold))
      .tracking(1.2)
      .foregroundStyle(accent)
  }

  private func chooseFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [
      "srt", "vtt", "txt", "md",
    ].compactMap { UTType(filenameExtension: $0) }
    guard panel.runModal() == .OK, let url = panel.url else {
      return
    }
    do {
      try model.loadFile(url)
    } catch {
      model.showStatus("读取失败：\(error.localizedDescription)")
    }
  }

  private var background: Color {
    colorScheme == .dark
      ? Color(red: 0.085, green: 0.09, blue: 0.095)
      : Color(red: 0.965, green: 0.947, blue: 0.91)
  }

  private var surface: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.055)
      : Color.white.opacity(0.62)
  }

  private var primary: Color {
    colorScheme == .dark ? .white.opacity(0.9) : Color(red: 0.08, green: 0.11, blue: 0.15)
  }

  private var secondary: Color { primary.opacity(0.62) }
  private var accent: Color {
    Color(red: 0.78, green: 0.31, blue: 0.18)
  }
  private var border: Color { primary.opacity(0.13) }
}

private extension View {
  func fieldLabel() -> some View {
    font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
  }
}

private struct CapturePrimaryButtonStyle: ButtonStyle {
  let accent: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .bold))
      .padding(.horizontal, 14)
      .frame(height: 34)
      .foregroundStyle(.white)
      .background(
        accent.opacity(configuration.isPressed ? 0.74 : 1),
        in: Capsule()
      )
  }
}
