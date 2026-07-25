import AppKit
import Observation
import SwiftUI

private final class PassiveFloatingPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
public final class FloatingPanelController {
  private let panel: PassiveFloatingPanel
  private let appModel: AppModel
  nonisolated(unsafe) private var screenObserver: NSObjectProtocol?

  public init(runtime: AppRuntime) {
    appModel = runtime.appModel
    panel = PassiveFloatingPanel(
      contentRect: CGRect(origin: .zero, size: Self.expandedSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
    ]
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.animationBehavior = .utilityWindow

    panel.contentView = NSHostingView(
      rootView: FloatingPracticeRoot(
        runtime: runtime,
        onLayoutChanged: { [weak self] in
          self?.refreshLayout()
        }
      )
    )

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.snapToCorner()
      }
    }
    observeLayoutPreferences()
  }

  deinit {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
    }
  }

  public func show() {
    appModel.isCardVisible = true
    refreshLayout()
    panel.orderFrontRegardless()
  }

  public func hide() {
    appModel.isCardVisible = false
    panel.orderOut(nil)
  }

  public func toggle() {
    appModel.isCardVisible ? hide() : show()
  }

  public func refreshLayout() {
    let size =
      appModel.isCollapsed
      ? Self.collapsedSize : Self.expandedSize
    panel.setContentSize(size)
    snapToCorner()
    if appModel.isCardVisible {
      panel.orderFrontRegardless()
    }
  }

  public func snapToCorner() {
    guard let screen = targetScreen() else { return }
    let origin = Self.origin(
      for: appModel.corner,
      panelSize: panel.frame.size,
      visibleFrame: screen.visibleFrame
    )
    panel.setFrameOrigin(origin)
  }

  public static func origin(
    for corner: FloatingCorner,
    panelSize: CGSize,
    visibleFrame: CGRect,
    margin: CGFloat = 18
  ) -> CGPoint {
    let left = visibleFrame.minX + margin
    let right = visibleFrame.maxX - panelSize.width - margin
    let bottom = visibleFrame.minY + margin
    let top = visibleFrame.maxY - panelSize.height - margin
    switch corner {
    case .topLeft:
      return CGPoint(x: left, y: top)
    case .topRight:
      return CGPoint(x: right, y: top)
    case .bottomLeft:
      return CGPoint(x: left, y: bottom)
    case .bottomRight:
      return CGPoint(x: right, y: bottom)
    }
  }

  private func targetScreen() -> NSScreen? {
    let center = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
    return NSScreen.screens.first(where: {
      $0.frame.contains(center)
    }) ?? NSScreen.main ?? NSScreen.screens.first
  }

  private func observeLayoutPreferences() {
    withObservationTracking {
      _ = appModel.corner
      _ = appModel.isCollapsed
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.refreshLayout()
        self?.observeLayoutPreferences()
      }
    }
  }

  private static let expandedSize = CGSize(width: 430, height: 386)
  private static let collapsedSize = CGSize(width: 58, height: 58)

}

private struct FloatingPracticeRoot: View {
  @Bindable var runtime: AppRuntime
  let onLayoutChanged: () -> Void

  var body: some View {
    if let practice = runtime.practice {
      PracticeCardView(
        appModel: runtime.appModel,
        practice: practice,
        onLayoutChanged: onLayoutChanged
      )
    } else {
      unavailableCard
    }
  }

  private var unavailableCard: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("РУССКИЙ УГОЛОК")
        .font(.system(size: 10, design: .monospaced))
      Text("学习数据暂时无法载入")
        .font(.headline)
      Text("请从菜单栏退出后重新打开。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(22)
    .frame(width: 320, height: 150)
    .background(.regularMaterial)
  }
}
