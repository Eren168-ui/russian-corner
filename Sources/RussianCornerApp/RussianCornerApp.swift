import AppKit
import RussianCornerUI
import SwiftUI

@main
@MainActor
struct RussianCornerApp: App {
  private let runtime: AppRuntime
  private let panelController: FloatingPanelController
  private let hotKeyService: GlobalHotKeyService

  init() {
    let runtime = AppRuntime()
    let panelController = FloatingPanelController(runtime: runtime)
    let hotKeyService = GlobalHotKeyService()
    self.runtime = runtime
    self.panelController = panelController
    self.hotKeyService = hotKeyService

    let issues = hotKeyService.registerDefaults(
      toggleCard: { [weak panelController] in
        panelController?.toggle()
      },
      nextCard: { [weak runtime] in
        runtime?.practice?.next()
      },
      speak: { [weak runtime] in
        runtime?.practice?.speak()
      },
      reveal: { [weak runtime] in
        runtime?.practice?.reveal()
      }
    )
    if !issues.isEmpty {
      let names = issues.map(\.action.title).joined(separator: "、")
      runtime.appModel.transientStatus =
        "部分全局快捷键被占用：\(names)"
    }

    DispatchQueue.main.async {
      panelController.show()
    }
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarContent(
        runtime: runtime,
        panelController: panelController
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

    Window("Russian Corner 诊断", id: "diagnostics") {
      DiagnosticsEmptyView()
    }
    .windowResizability(.contentSize)
  }
}

private struct MenuBarContent: View {
  @Bindable var runtime: AppRuntime
  let panelController: FloatingPanelController

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
    Button("发音诊断…", systemImage: "waveform.badge.magnifyingglass") {
      openWindow(id: "diagnostics")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }

    if let status = runtime.appModel.transientStatus
      ?? runtime.launchError
    {
      Divider()
      Text(status)
        .foregroundStyle(.secondary)
    }

    Divider()

    Button("退出 Russian Corner", systemImage: "power") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}

private struct DiagnosticsEmptyView: View {
  var body: some View {
    ContentUnavailableView {
      Label(
        "发音诊断尚未启用",
        systemImage: "waveform.badge.magnifyingglass"
      )
    } description: {
      Text("当前版本保留录音入口；语音诊断能力将在后续阶段接入。")
    } actions: {
      Text("练习、朗读与录音功能不受影响")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(width: 440, height: 300)
  }
}
