import AppKit
import RussianCornerCore
import RussianCornerUI
import SwiftUI

@MainActor
private final class RussianCornerApplicationDelegate:
  NSObject,
  NSApplicationDelegate
{
  weak var runtime: LanguageCornerRuntime?

  func applicationWillTerminate(
    _ notification: Notification
  ) {
    runtime?.activeRuntime?.diagnostics?.handleDisappear()
    runtime?.closeAll(reason: .quit)
  }
}

@MainActor
private final class LearningHistoryWindowController:
  NSWindowController
{
  private let runtime: LanguageCornerRuntime

  init(runtime: LanguageCornerRuntime) {
    self.runtime = runtime
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 820, height: 720),
      styleMask: [
        .titled,
        .closable,
        .miniaturizable,
        .resizable,
      ],
      backing: .buffered,
      defer: false
    )
    window.title = "Language Corner 学习记录"
    window.minSize = NSSize(width: 720, height: 600)
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.setFrameAutosaveName("RussianCornerLearningHistory")
    window.center()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    guard let activeRuntime = runtime.activeRuntime else { return }
    do {
      try activeRuntime.refreshProgress()
    } catch {
      activeRuntime.appModel.transientStatus =
        "学习记录刷新失败：\(error.localizedDescription)"
    }
    window?.contentViewController = NSHostingController(
      rootView: RussianCornerProgressView(runtime: activeRuntime)
    )
    window?.title =
      "Language Corner · \(runtime.activeLanguage.displayName) 学习记录"
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

@MainActor
private final class ActiveRuntimeFeatureWindowController:
  NSWindowController
{
  private let runtime: LanguageCornerRuntime
  private let baseTitle: String
  private let content: (AppRuntime) -> AnyView

  init(
    runtime: LanguageCornerRuntime,
    title: String,
    size: NSSize,
    minimumSize: NSSize,
    content: @escaping (AppRuntime) -> AnyView
  ) {
    self.runtime = runtime
    baseTitle = title
    self.content = content
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [
        .titled,
        .closable,
        .miniaturizable,
        .resizable,
      ],
      backing: .buffered,
      defer: false
    )
    window.title = title
    window.minSize = minimumSize
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.center()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    guard let activeRuntime = runtime.activeRuntime else { return }
    window?.title =
      "\(baseTitle) · \(runtime.activeLanguage.displayName)"
    window?.contentViewController = NSHostingController(
      rootView: content(activeRuntime)
    )
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

@MainActor
private final class FeatureWindowController: NSWindowController {
  init(
    title: String,
    size: NSSize,
    minimumSize: NSSize,
    content: AnyView
  ) {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [
        .titled,
        .closable,
        .miniaturizable,
        .resizable,
      ],
      backing: .buffered,
      defer: false
    )
    window.title = title
    window.minSize = minimumSize
    window.isReleasedWhenClosed = false
    window.contentViewController = NSHostingController(rootView: content)
    super.init(window: window)
    window.center()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

@MainActor
private final class SceneTrainingWindowController:
  NSWindowController
{
  private let runtime: LanguageCornerRuntime

  init(runtime: LanguageCornerRuntime) {
    self.runtime = runtime
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
      styleMask: [
        .titled,
        .closable,
        .miniaturizable,
        .resizable,
      ],
      backing: .buffered,
      defer: false
    )
    window.title = "Language Corner · 今日英语场景"
    window.minSize = NSSize(width: 680, height: 600)
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.setFrameAutosaveName("LanguageCornerEnglishScene")
    window.center()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    guard let englishRuntime = runtime.languageRuntimes[.english] else {
      showUnavailable(
        title: "英语场景暂时不可用",
        message: "英语学习数据没有成功载入，俄语功能不受影响。"
      )
      return
    }
    do {
      guard let model = try englishRuntime.makeTodaySceneTraining() else {
        showUnavailable(
          title: "今天还没有英语场景",
          message: "英语语料仍可在角落卡中正常学习。"
        )
        return
      }
      window?.contentViewController = NSHostingController(
        rootView: SceneTrainingView(model: model)
      )
      showWindow(nil)
      window?.makeKeyAndOrderFront(nil)
      NSApplication.shared.activate(ignoringOtherApps: true)
    } catch {
      showUnavailable(
        title: "英语场景无法打开",
        message: error.localizedDescription
      )
    }
  }

  private func showUnavailable(title: String, message: String) {
    window?.contentViewController = NSHostingController(
      rootView: ContentUnavailableView(
        title,
        systemImage: "person.2.wave.2",
        description: Text(message)
      )
    )
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

@main
@MainActor
struct RussianCornerApp: App {
  @NSApplicationDelegateAdaptor(
    RussianCornerApplicationDelegate.self
  ) private var applicationDelegate

  private let runtime: LanguageCornerRuntime
  private let panelController: FloatingPanelController
  private let hotKeyService: GlobalHotKeyService
  private let learningHistoryWindowController:
    LearningHistoryWindowController
  private let settingsWindowController:
    ActiveRuntimeFeatureWindowController
  private let reflectionWindowController:
    ActiveRuntimeFeatureWindowController
  private let diagnosticsWindowController:
    ActiveRuntimeFeatureWindowController
  private let sceneTrainingWindowController:
    SceneTrainingWindowController
  private let expressionCaptureWindowController:
    FeatureWindowController
  private let utilityActions: PracticeCardUtilityActions

  init() {
    let runtime = LanguageCornerRuntime(
      enableRussianSourceSync: true
    )
    let learningHistoryWindowController =
      LearningHistoryWindowController(runtime: runtime)
    let settingsWindowController = ActiveRuntimeFeatureWindowController(
      runtime: runtime,
      title: "Language Corner 设置",
      size: NSSize(width: 560, height: 620),
      minimumSize: NSSize(width: 520, height: 500),
      content: { activeRuntime in
        AnyView(RussianCornerSettingsView(runtime: activeRuntime))
      }
    )
    let reflectionWindowController = ActiveRuntimeFeatureWindowController(
      runtime: runtime,
      title: "今日反馈",
      size: NSSize(width: 500, height: 470),
      minimumSize: NSSize(width: 500, height: 470),
      content: { activeRuntime in AnyView(
        Group {
          if let dailyReflection = activeRuntime.dailyReflection {
            DailyReflectionView(model: dailyReflection)
          } else {
            ContentUnavailableView(
              "今日反馈暂时不可用",
              systemImage: "square.and.pencil",
              description: Text(
                activeRuntime.trialError ?? "核心学习功能仍可正常使用"
              )
            )
          }
        }
      ) }
    )
    let diagnosticsWindowController = ActiveRuntimeFeatureWindowController(
      runtime: runtime,
      title: "Language Corner 诊断",
      size: NSSize(width: 620, height: 650),
      minimumSize: RussianCornerDiagnosticView.minimumSize,
      content: { activeRuntime in AnyView(
        Group {
          if let diagnostics = activeRuntime.diagnostics {
            RussianCornerDiagnosticView(model: diagnostics)
          } else {
            ContentUnavailableView(
              "诊断暂时无法载入",
              systemImage: "exclamationmark.triangle",
              description: Text(
                activeRuntime.diagnosticError
                  ?? activeRuntime.launchError
                  ?? "请稍后重新打开应用"
              )
            )
          }
        }
      ) }
    )
    let sceneTrainingWindowController =
      SceneTrainingWindowController(runtime: runtime)
    let expressionCaptureWindowController: FeatureWindowController
    do {
      let captureModel = try ExpressionCaptureViewModel(
        onReviewed: { _ in
          runtime.languageRuntimes[.english]?
            .reloadEnglishImportedExpressions()
        }
      )
      expressionCaptureWindowController = FeatureWindowController(
        title: "Language Corner · 收集英语表达",
        size: NSSize(width: 900, height: 680),
        minimumSize: NSSize(width: 780, height: 600),
        content: AnyView(ExpressionCaptureView(model: captureModel))
      )
    } catch {
      expressionCaptureWindowController = FeatureWindowController(
        title: "Language Corner · 收集英语表达",
        size: NSSize(width: 620, height: 420),
        minimumSize: NSSize(width: 520, height: 360),
        content: AnyView(
          ContentUnavailableView(
            "表达收集暂时不可用",
            systemImage: "text.badge.xmark",
            description: Text(error.localizedDescription)
          )
        )
      )
    }
    let utilityActions = PracticeCardUtilityActions(
      openSceneTraining: {
        sceneTrainingWindowController.show()
      },
      openExpressionCapture: {
        expressionCaptureWindowController.show()
      },
      openSettings: {
        settingsWindowController.show()
      },
      openHistory: {
        learningHistoryWindowController.show()
      },
      openReflection: {
        runtime.activeRuntime?.dailyReflection?.openForEditing()
        reflectionWindowController.show()
      },
      openDiagnostics: {
        diagnosticsWindowController.show()
      },
      exportReport: {
        guard
          let activeRuntime = runtime.activeRuntime,
          let trialRepository = activeRuntime.trialRepository
        else {
          runtime.activeRuntime?.appModel.transientStatus =
            runtime.activeRuntime?.trialError ?? "学习报告暂时不可用"
          return
        }
        Task {
          let exporter = TrialReportExporter(
            appModel: activeRuntime.appModel
          )
          await exporter.exportLastSevenDays(
            repository: trialRepository
          )
        }
      }
    )
    let panelController = FloatingPanelController(
      runtime: runtime,
      onOpenLearningHistory: {
        learningHistoryWindowController.show()
      },
      utilityActions: utilityActions
    )
    let hotKeyService = GlobalHotKeyService()
    self.runtime = runtime
    self.panelController = panelController
    self.hotKeyService = hotKeyService
    self.learningHistoryWindowController =
      learningHistoryWindowController
    self.settingsWindowController = settingsWindowController
    self.reflectionWindowController = reflectionWindowController
    self.diagnosticsWindowController = diagnosticsWindowController
    self.sceneTrainingWindowController =
      sceneTrainingWindowController
    self.expressionCaptureWindowController =
      expressionCaptureWindowController
    self.utilityActions = utilityActions
    applicationDelegate.runtime = runtime

    let issues = hotKeyService.registerDefaults(
      actions: [
        .toggleCard: { [weak panelController] in
          panelController?.toggle()
        },
        .nextCard: { [weak runtime] in
          runtime?.activeRuntime?.practice?.next()
        },
        .speak: { [weak runtime] in
          runtime?.activeRuntime?.practice?.speak()
        },
        .reveal: { [weak runtime] in
          runtime?.activeRuntime?.practice?.reveal()
        },
        .gradeAgain: { [weak runtime] in
          Self.submitRecall(.unknown, runtime: runtime)
        },
        .gradeHard: { [weak runtime] in
          Self.submitRecall(
            .coreMeaningWithUsageIssue,
            runtime: runtime
          )
        },
        .gradeEasy: { [weak runtime] in
          Self.submitRecall(
            .fluentWithinThreeSeconds,
            runtime: runtime
          )
        },
        .toggleCollapsed: { [weak runtime] in
          runtime?.activeRuntime?.appModel.isCollapsed.toggle()
        },
      ]
    )
    if !issues.isEmpty {
      let names = issues.map(\.action.title).joined(separator: "、")
      runtime.activeRuntime?.appModel.transientStatus =
        "部分全局快捷键被占用：\(names)"
    }

    DispatchQueue.main.async {
      panelController.show()
    }
    Task {
      for languageRuntime in runtime.languageRuntimes.values
      where languageRuntime.appModel.remindersEnabled {
        await languageRuntime.reconcileRemindersOnLaunch()
      }
    }
    Task { [weak runtime] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled else { return }
        runtime?.refreshPracticeForTemporalBoundary()
      }
    }
  }

  private static func submitRecall(
    _ outcome: RecallOutcome,
    runtime: LanguageCornerRuntime?
  ) {
    do {
      try runtime?.activeRuntime?.practice?.submitRecallOutcome(
        outcome
      )
    } catch {
      runtime?.activeRuntime?.practice?.showStatus(
        "主动回忆结果未提交：\(error.localizedDescription)"
      )
    }
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarContent(
        runtime: runtime,
        panelController: panelController,
        utilityActions: utilityActions
      )
    } label: {
      Label(
        "Language Corner",
        systemImage: "character.book.closed.fill"
      )
      .accessibilityLabel("Language Corner 英语与俄语练习")
    }

  }
}

private struct MenuBarContent: View {
  @Bindable var runtime: LanguageCornerRuntime
  let panelController: FloatingPanelController
  let utilityActions: PracticeCardUtilityActions

  private var activeRuntime: AppRuntime? {
    runtime.activeRuntime
  }

  var body: some View {
    Button(
      runtime.activeRuntime?.appModel.isCardVisible == true
        ? "隐藏练习卡" : "显示练习卡",
      systemImage: runtime.activeRuntime?.appModel.isCardVisible == true
        ? "eye.slash" : "eye"
    ) {
      panelController.toggle()
    }
    .keyboardShortcut("r", modifiers: [.control, .option])

    Button(
      activeRuntime?.appModel.appearanceMode.toggleTitle ?? "切换外观",
      systemImage:
        activeRuntime?.appModel.appearanceMode.toggleSymbolName
          ?? "circle.lefthalf.filled"
    ) {
      activeRuntime?.appModel.toggleAppearance()
    }
    .disabled(activeRuntime == nil)

    Button("下一项", systemImage: "arrow.right") {
      runtime.activeRuntime?.practice?.next()
    }
    .keyboardShortcut("n", modifiers: [.control, .option])
    .disabled(runtime.activeRuntime?.practice == nil)

    Button("移到下一块显示器", systemImage: "display.2") {
      panelController.moveToNextScreen()
    }
    .disabled(!panelController.canMoveToAnotherScreen)

    Divider()

    Menu(
      "学习语言：\(runtime.activeLanguage.displayName)",
      systemImage: "character.bubble"
    ) {
      ForEach(runtime.availableLanguages, id: \.self) { language in
        Button {
          runtime.switchLanguage(to: language)
          panelController.refreshLayout()
        } label: {
          if language == runtime.activeLanguage {
            Label(language.displayName, systemImage: "checkmark")
          } else {
            Text(language.displayName)
          }
        }
      }
    }

    Menu(
      activeRuntime?.selectedTopic.map {
        "今天的话题：\($0.number). \($0.titleZh)"
      } ?? "今天的话题"
    ) {
      Button("自动轮换") {
        activeRuntime?.selectTopicForToday(nil)
      }
      Divider()
      ForEach(activeRuntime?.topics ?? []) { topic in
        Button("\(topic.number). \(topic.titleZh)") {
          activeRuntime?.selectTopicForToday(topic.id)
        }
      }
    }

    Divider()

    Button("今日英语场景…", systemImage: "person.2.wave.2") {
      utilityActions.openSceneTraining()
    }
    .disabled(runtime.languageRuntimes[.english] == nil)
    Button("收集英语表达…", systemImage: "text.badge.plus") {
      utilityActions.openExpressionCapture()
    }

    Button("设置…", systemImage: "gearshape") {
      utilityActions.openSettings()
    }
    Button("学习记录…", systemImage: "chart.bar") {
      utilityActions.openHistory()
    }
    Button("今日反馈…", systemImage: "square.and.pencil") {
      utilityActions.openReflection()
    }
    Button("学习诊断…", systemImage: "waveform.badge.magnifyingglass") {
      utilityActions.openDiagnostics()
    }
    Button(
      "导出近 7 天学习报告…",
      systemImage: "square.and.arrow.up"
    ) {
      utilityActions.exportReport()
    }
    .disabled(activeRuntime?.trialRepository == nil)

    if let status = activeRuntime?.appModel.transientStatus
      ?? activeRuntime?.launchError
    {
      Divider()
      Text(status)
        .foregroundStyle(.secondary)
    }

    Divider()

    Button("退出 Language Corner", systemImage: "power") {
      runtime.closeAll(reason: .quit)
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
