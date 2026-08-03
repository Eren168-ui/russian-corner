import RussianCornerCore
import SwiftUI

public struct SceneTrainingView: View {
  @Bindable private var model: SceneTrainingViewModel
  @Environment(\.colorScheme) private var colorScheme

  public init(model: SceneTrainingViewModel) {
    self.model = model
  }

  public var body: some View {
    ZStack {
      background.ignoresSafeArea()
      VStack(spacing: 0) {
        header
        Divider().overlay(border)
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            stageIntroduction
            stageContent
            if model.selectedWord != nil {
              dictionaryCard
            }
          }
          .padding(28)
        }
        Divider().overlay(border)
        footer
      }
    }
    .foregroundStyle(primary)
    .onDisappear {
      model.stopSpeech()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack(alignment: .firstTextBaseline) {
        Text("ENGLISH SCENE")
          .font(.system(size: 12, weight: .bold))
          .tracking(2.2)
          .foregroundStyle(accent)
        Text("/ \(model.lesson.titleZh)")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(secondary)
        Spacer()
        Toggle("中文辅助", isOn: $model.chineseSupportEnabled)
          .toggleStyle(.switch)
          .controlSize(.small)
          .font(.system(size: 12, weight: .medium))
      }
      HStack(spacing: 5) {
        ForEach(SceneTrainingStage.allCases, id: \.self) { stage in
          Capsule()
            .fill(
              stage.rawValue <= model.stage.rawValue
                ? accent : border
            )
            .frame(height: 4)
            .accessibilityLabel(stage.titleZh)
        }
      }
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 18)
  }

  private var stageIntroduction: some View {
    HStack(alignment: .top, spacing: 16) {
      Text(String(format: "%02d", model.stage.rawValue + 1))
        .font(.system(size: 38, weight: .light, design: .serif))
        .foregroundStyle(accent)
      VStack(alignment: .leading, spacing: 4) {
        Text(model.stage.titleZh)
          .font(.system(size: 25, weight: .semibold, design: .serif))
        Text(stageInstruction)
          .font(.system(size: 13))
          .foregroundStyle(secondary)
      }
    }
  }

  @ViewBuilder
  private var stageContent: some View {
    switch model.stage {
    case .context:
      contextStage
    case .bilingual:
      sentenceStage(showChinese: true)
    case .englishOnly:
      sentenceStage(showChinese: false)
    case .audioFirst:
      audioFirstStage
    case .shadowing:
      shadowingStage
    case .retell:
      retellStage
    case .variants:
      variantsStage
    case .dialogue:
      dialogueStage
    case .selection:
      selectionStage
    }
  }

  private var contextStage: some View {
    sceneCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("SCENE")
          .sectionLabel(accent)
        Text(model.lesson.contextZh)
          .font(.system(size: 24, weight: .medium, design: .serif))
        HStack(spacing: 10) {
          tag("口语输出")
          tag("听力反应")
          tag("\(model.sentences.count) 个核心表达")
        }
        Text("先想象人物、地点和目的，不急着翻译。下一步再进入具体表达。")
          .font(.system(size: 13))
          .foregroundStyle(secondary)
      }
    }
  }

  private func sentenceStage(showChinese: Bool) -> some View {
    VStack(spacing: 14) {
      sentenceCard(
        model.currentSentence,
        showChinese: showChinese && model.chineseSupportEnabled,
        showTarget: true
      )
      sentenceNavigator
    }
  }

  private var audioFirstStage: some View {
    VStack(spacing: 14) {
      sceneCard {
        VStack(alignment: .leading, spacing: 16) {
          Text("LISTEN FIRST")
            .sectionLabel(accent)
          HStack(spacing: 10) {
            audioButton("正常播放", systemImage: "play.fill") {
              model.speakCurrent()
            }
            audioButton("慢速播放", systemImage: "tortoise.fill") {
              model.speakCurrent(slow: true)
            }
            audioButton(
              model.isTextHidden ? "显示文本" : "隐藏文本",
              systemImage: model.isTextHidden ? "eye" : "eye.slash"
            ) {
              model.toggleTextVisibility()
            }
          }
          if model.isTextHidden {
            Text("先听两遍：第一遍抓意图，第二遍抓句块和重音。")
              .font(.system(size: 20, weight: .medium, design: .serif))
              .foregroundStyle(secondary)
              .frame(maxWidth: .infinity, minHeight: 100)
          } else {
            targetText(model.currentSentence)
          }
        }
      }
      sentenceNavigator
    }
  }

  private var shadowingStage: some View {
    VStack(spacing: 14) {
      sentenceCard(
        model.currentSentence,
        showChinese: model.chineseSupportEnabled,
        showTarget: true
      )
      sceneCard {
        VStack(alignment: .leading, spacing: 12) {
          Text("SHADOWING")
            .sectionLabel(accent)
          Text("播放后几乎同时跟上，不要逐词停顿。先模仿节奏，再追求每个音。")
            .font(.system(size: 14))
          HStack {
            audioButton("跟读", systemImage: "waveform") {
              model.speakCurrent()
            }
            audioButton("慢速拆分", systemImage: "tortoise") {
              model.speakCurrent(slow: true)
            }
            audioButton("再来一次", systemImage: "repeat") {
              model.speakCurrent()
            }
          }
        }
      }
      sentenceNavigator
    }
  }

  private var retellStage: some View {
    sceneCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("RETELL WITHOUT TRANSLATING")
          .sectionLabel(accent)
        Text(model.currentSentence.promptZh)
          .font(.system(size: 21, weight: .medium, design: .serif))
        Text(model.currentSentence.cueText)
          .font(.system(size: 14))
          .foregroundStyle(secondary)
        Text("先完整说一遍，再点击核对。允许换词，但必须保留原意和自然语序。")
          .font(.system(size: 13))
          .foregroundStyle(secondary)
        Button(
          model.isTextHidden ? "核对参考表达" : "重新隐藏参考表达"
        ) {
          model.toggleTextVisibility()
        }
        .buttonStyle(SceneOutlineButtonStyle(accent: accent))
        if !model.isTextHidden {
          targetText(model.currentSentence)
        }
      }
    }
    .onAppear {
      if !model.isTextHidden {
        model.toggleTextVisibility()
      }
    }
  }

  private var variantsStage: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(
        Array(model.currentSentence.variants.enumerated()),
        id: \.offset
      ) { index, variant in
        sceneCard {
          VStack(alignment: .leading, spacing: 9) {
            Text("VARIATION \(index + 1)")
              .sectionLabel(accent)
            Text(variant.promptZh)
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(secondary)
            InteractiveTargetText(
              text: variant.targetText,
              language: .english,
              selectedTokenIndex: nil
            ) { _ in }
            .font(.system(size: 22, weight: .semibold, design: .serif))
            Text("把时间、地点或人物替换成你自己的真实信息，再说一遍。")
              .font(.system(size: 12))
              .foregroundStyle(secondary)
          }
        }
      }
      sentenceNavigator
    }
  }

  private var dialogueStage: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(model.dialogueSentences.prefix(4)) { sentence in
        sceneCard {
          VStack(alignment: .leading, spacing: 8) {
            Text(sentence.cueText)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(secondary)
            InteractiveTargetText(
              text: sentence.displayText,
              language: .english,
              selectedTokenIndex:
                sentence.id == model.currentSentence.id
                  ? model.selectedTokenIndex : nil
            ) { tokenIndex in
              Task { await model.selectWord(tokenIndex: tokenIndex) }
            }
            .font(.system(size: 20, weight: .semibold, design: .serif))
            if let reply = sentence.expectedReplies.first {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                  .foregroundStyle(accent)
                Text(reply)
                  .font(.system(size: 14, weight: .medium))
              }
            }
          }
        }
      }
      Text("交换角色：先说 A，再不看文本接出 B；第二轮从 B 开始反问。")
        .font(.system(size: 13))
        .foregroundStyle(secondary)
    }
  }

  private var selectionStage: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("只选择你愿意在未来几天反复主动提取的表达。")
        .font(.system(size: 14))
        .foregroundStyle(secondary)
      ForEach(model.sentences) { sentence in
        Button {
          model.toggleExpressionSelection(sentence.id)
        } label: {
          HStack(alignment: .top, spacing: 12) {
            Image(
              systemName: model.selectedExpressionIDs.contains(sentence.id)
                ? "checkmark.square.fill" : "square"
            )
            .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 4) {
              Text(sentence.displayText)
                .font(.system(size: 16, weight: .semibold))
              Text(sentence.promptZh)
                .font(.system(size: 12))
                .foregroundStyle(secondary)
            }
            Spacer()
          }
          .padding(13)
          .background(surface)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func sentenceCard(
    _ sentence: StudySentence,
    showChinese: Bool,
    showTarget: Bool
  ) -> some View {
    sceneCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("EXPRESSION \(model.currentSentenceIndex + 1)")
            .sectionLabel(accent)
          Spacer()
          audioButton("播放", systemImage: "speaker.wave.2") {
            model.speakCurrent()
          }
          audioButton("慢速", systemImage: "tortoise") {
            model.speakCurrent(slow: true)
          }
        }
        if showChinese {
          Text(sentence.promptZh)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(secondary)
        }
        if showTarget {
          targetText(sentence)
        }
        if showChinese {
          Text(sentence.cueText)
            .font(.system(size: 12))
            .foregroundStyle(secondary.opacity(0.85))
        }
      }
    }
  }

  private func targetText(_ sentence: StudySentence) -> some View {
    InteractiveTargetText(
      text: sentence.displayText,
      language: .english,
      selectedTokenIndex: model.selectedTokenIndex
    ) { tokenIndex in
      Task { await model.selectWord(tokenIndex: tokenIndex) }
    }
    .font(.system(size: 27, weight: .semibold, design: .serif))
    .foregroundStyle(primary)
    .tint(accent)
  }

  private var sentenceNavigator: some View {
    HStack {
      Button("上一句", systemImage: "chevron.left") {
        model.moveToPreviousSentence()
      }
      .disabled(model.currentSentenceIndex == 0)
      Spacer()
      Text(
        "\(model.currentSentenceIndex + 1) / \(model.sentences.count)"
      )
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(secondary)
      Spacer()
      Button("下一句", systemImage: "chevron.right") {
        model.moveToNextSentence()
      }
      .disabled(
        model.currentSentenceIndex == model.sentences.count - 1
      )
    }
    .buttonStyle(.plain)
    .font(.system(size: 13, weight: .medium))
    .foregroundStyle(accent)
  }

  private var dictionaryCard: some View {
    sceneCard {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(model.selectedWord ?? "")
            .font(.system(size: 28, weight: .semibold, design: .serif))
          Spacer()
          if let word = model.selectedWord,
            let url = OnlineDictionary.wiktionaryURL(
              for: word,
              language: .english
            )
          {
            Link("打开词典", destination: url)
              .font(.system(size: 12, weight: .semibold))
          }
        }
        if let result = model.wordLookupResult {
          if let partOfSpeech = result.partOfSpeech {
            Text(partOfSpeech)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(accent)
          }
          Text(result.translations.joined(separator: "；"))
            .font(.system(size: 18, weight: .medium))
          if !result.examples.isEmpty {
            ForEach(
              Array(result.examples.prefix(2).enumerated()),
              id: \.offset
            ) { _, example in
              VStack(alignment: .leading, spacing: 2) {
                Text(example.russian)
                  .font(.system(size: 13, design: .serif))
                if let translation = example.translationZh {
                  Text(translation)
                    .font(.system(size: 11))
                    .foregroundStyle(secondary)
                }
              }
            }
          }
        } else if let issue = model.wordLookupIssue {
          Text(issue)
            .font(.system(size: 13))
            .foregroundStyle(secondary)
        } else {
          ProgressView("正在查词…")
            .controlSize(.small)
        }
      }
    }
  }

  private var footer: some View {
    HStack {
      Button("重新开始") {
        model.restart()
      }
      .buttonStyle(.plain)
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(secondary)
      Spacer()
      if model.isComplete {
        Label("已加入日常复习", systemImage: "checkmark.circle.fill")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(accent)
      } else {
        Button(
          model.stage == .selection ? "完成并加入复习" : "进入下一步",
          systemImage: "arrow.right"
        ) {
          model.advanceStage()
        }
        .buttonStyle(ScenePrimaryButtonStyle(accent: accent))
      }
    }
    .padding(.horizontal, 28)
    .frame(height: 64)
  }

  private func sceneCard<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(surface)
      .clipShape(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(border, lineWidth: 1)
      }
  }

  private func tag(_ value: String) -> some View {
    Text(value)
      .font(.system(size: 11, weight: .semibold))
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(accent.opacity(0.12), in: Capsule())
      .foregroundStyle(accent)
  }

  private func audioButton(
    _ title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(title, systemImage: systemImage, action: action)
      .buttonStyle(.plain)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(accent)
  }

  private var stageInstruction: String {
    switch model.stage {
    case .context: "先建立真实交流目的，再进入语言。"
    case .bilingual: "理解意图和表达，不逐词翻译。"
    case .englishOnly: "让英语直接连接场景。"
    case .audioFirst: "先靠声音识别句块，再看文本。"
    case .shadowing: "模仿节奏、连读和重音。"
    case .retell: "脱离原句，用自己的嘴重新组织。"
    case .variants: "替换信息，让句型真正可迁移。"
    case .dialogue: "练习接话和交换角色。"
    case .selection: "把最值得掌握的表达送回每日队列。"
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
      : Color.white.opacity(0.58)
  }

  private var primary: Color {
    colorScheme == .dark
      ? Color(red: 0.94, green: 0.92, blue: 0.86)
      : Color(red: 0.08, green: 0.11, blue: 0.15)
  }

  private var secondary: Color {
    primary.opacity(0.64)
  }

  private var accent: Color {
    Color(red: 0.78, green: 0.31, blue: 0.18)
  }

  private var border: Color {
    primary.opacity(0.14)
  }
}

private extension View {
  func sectionLabel(_ color: Color) -> some View {
    font(.system(size: 10, weight: .bold))
      .tracking(1.5)
      .foregroundStyle(color)
  }
}

private struct ScenePrimaryButtonStyle: ButtonStyle {
  let accent: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .bold))
      .padding(.horizontal, 18)
      .frame(height: 38)
      .foregroundStyle(.white)
      .background(
        accent.opacity(configuration.isPressed ? 0.76 : 1),
        in: Capsule()
      )
  }
}

private struct SceneOutlineButtonStyle: ButtonStyle {
  let accent: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .padding(.horizontal, 14)
      .frame(height: 34)
      .foregroundStyle(accent)
      .background(accent.opacity(0.08), in: Capsule())
      .overlay {
        Capsule().stroke(accent.opacity(0.4), lineWidth: 1)
      }
  }
}
