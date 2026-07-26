import AppKit
import RussianCornerCore
import RussianCornerUI
import SwiftUI

@main
@MainActor
struct RussianCornerApp: App {
  private let runtime: AppRuntime
  private let panelController: FloatingPanelController
  private let hotKeyService: GlobalHotKeyService
  private let reportExporter: TrialReportExporter

  init() {
    let runtime = AppRuntime()
    let panelController = FloatingPanelController(runtime: runtime)
    let hotKeyService = GlobalHotKeyService()
    let reportExporter = TrialReportExporter(
      appModel: runtime.appModel
    )
    self.runtime = runtime
    self.panelController = panelController
    self.hotKeyService = hotKeyService
    self.reportExporter = reportExporter

    let issues = hotKeyService.registerDefaults(
      actions: [
        .toggleCard: { [weak panelController] in
          panelController?.toggle()
        },
        .nextCard: { [weak runtime] in
          runtime?.practice?.next()
        },
        .speak: { [weak runtime] in
          runtime?.practice?.speak()
        },
        .reveal: { [weak runtime] in
          runtime?.practice?.reveal()
        },
        .gradeAgain: { [weak runtime] in
          Self.grade(.again, runtime: runtime)
        },
        .gradeHard: { [weak runtime] in
          Self.grade(.hard, runtime: runtime)
        },
        .gradeEasy: { [weak runtime] in
          Self.grade(.easy, runtime: runtime)
        },
        .toggleCollapsed: { [weak runtime] in
          runtime?.appModel.isCollapsed.toggle()
        },
      ]
    )
    if !issues.isEmpty {
      let names = issues.map(\.action.title).joined(separator: "、")
      runtime.appModel.transientStatus =
        "部分全局快捷键被占用：\(names)"
    }

    DispatchQueue.main.async {
      panelController.show()
    }
    Task {
      await runtime.reconcileRemindersOnLaunch()
    }
    Task { [weak runtime] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled else { return }
        runtime?.refreshPracticeForTemporalBoundary()
      }
    }
  }

  private static func grade(
    _ grade: RussianCornerCore.ReviewGrade,
    runtime: AppRuntime?
  ) {
    do {
      try runtime?.practice?.grade(grade)
    } catch {
      runtime?.practice?.showStatus(
        "评分未提交：\(error.localizedDescription)"
      )
    }
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarContent(
        runtime: runtime,
        panelController: panelController,
        reportExporter: reportExporter
      )
    } label: {
      Label(
        "Russian Corner",
        systemImage: "character.book.closed.fill"
      )
      .accessibilityLabel("Russian Corner 俄语练习")
    }

    Window("Russian Corner 设置", id: "settings") {
      RussianCornerSettingsView(runtime: runtime)
    }
    .windowResizability(.contentSize)

    Window("Russian Corner 进度", id: "progress") {
      RussianCornerProgressView(runtime: runtime)
    }
    .windowResizability(.contentSize)

    Window("今日反馈", id: "daily-reflection") {
      if let dailyReflection = runtime.dailyReflection {
        DailyReflectionView(model: dailyReflection)
      } else {
        ContentUnavailableView(
          "今日反馈暂时不可用",
          systemImage: "square.and.pencil",
          description: Text(
            runtime.trialError ?? "核心学习功能仍可正常使用"
          )
        )
        .frame(width: 420, height: 260)
      }
    }
    .windowResizability(.contentSize)

    Window("Russian Corner 诊断", id: "diagnostics") {
      if let diagnostics = runtime.diagnostics {
        RussianCornerDiagnosticView(model: diagnostics)
      } else {
        ContentUnavailableView(
          "诊断暂时无法载入",
          systemImage: "exclamationmark.triangle",
          description: Text(
            runtime.diagnosticError
              ?? runtime.launchError
              ?? "请稍后重新打开应用"
          )
        )
        .frame(width: 440, height: 300)
      }
    }
    .windowResizability(.contentMinSize)
  }
}

private struct MenuBarContent: View {
  @Bindable var runtime: AppRuntime
  let panelController: FloatingPanelController
  let reportExporter: TrialReportExporter

  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button(
      runtime.appModel.isCardVisible ? "隐藏练习卡" : "显示练习卡",
      systemImage: runtime.appModel.isCardVisible ? "eye.slash" : "eye"
    ) {
      panelController.toggle()
    }
    .keyboardShortcut("r", modifiers: [.control, .option])

    Button("下一项", systemImage: "arrow.right") {
      runtime.practice?.next()
    }
    .keyboardShortcut("n", modifiers: [.control, .option])
    .disabled(runtime.practice == nil)

    Button("移到下一块显示器", systemImage: "display.2") {
      panelController.moveToNextScreen()
    }
    .disabled(!panelController.canMoveToAnotherScreen)

    Divider()

    Button("设置…", systemImage: "gearshape") {
      openWindow(id: "settings")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
    Button("学习进度…", systemImage: "chart.bar") {
      try? runtime.refreshProgress()
      openWindow(id: "progress")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
    Button("今日反馈…", systemImage: "square.and.pencil") {
      runtime.dailyReflection?.openForEditing()
      openWindow(id: "daily-reflection")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
    Button("学习诊断…", systemImage: "waveform.badge.magnifyingglass") {
      openWindow(id: "diagnostics")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
    Button(
      "导出 7 天试用报告…",
      systemImage: "square.and.arrow.up"
    ) {
      guard let trialRepository = runtime.trialRepository else {
        runtime.appModel.transientStatus =
          runtime.trialError ?? "试用报告暂时不可用"
        return
      }
      Task {
        await reportExporter.exportLastSevenDays(
          repository: trialRepository
        )
      }
    }
    .disabled(runtime.trialRepository == nil)

    if let status = runtime.appModel.transientStatus
      ?? runtime.launchError
    {
      Divider()
      Text(status)
        .foregroundStyle(.secondary)
    }

    Divider()

    Button("退出 Russian Corner", systemImage: "power") {
      runtime.practice?.handleDisappear()
      runtime.closeTrialSession(reason: .quit)
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
