import AppKit
import Observation
import SwiftUI

public enum PracticePanelPresentation: Equatable, Sendable {
  case collapsed
  case compact
  case details

  public var size: CGSize {
    switch self {
    case .collapsed:
      CGSize(width: 58, height: 58)
    case .compact:
      CGSize(width: 360, height: 240)
    case .details:
      CGSize(width: 430, height: 386)
    }
  }

  public static func resolve(
    isCollapsed: Bool,
    isDetailExpanded: Bool,
    isReflectionPresented: Bool = false
  ) -> Self {
    if isCollapsed { return .collapsed }
    return isDetailExpanded || isReflectionPresented
      ? .details : .compact
  }
}

private final class PassiveFloatingPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
public final class FloatingPanelController: NSObject, NSWindowDelegate {
  private let panel: PassiveFloatingPanel
  private let appModel: AppModel
  private weak var runtime: AppRuntime?
  nonisolated(unsafe) private var screenObserver: NSObjectProtocol?
  private var moveDebounceTask: Task<Void, Never>?
  private var isSnapping = false
  private var suppressMoveRecordingUntil = Date.distantPast

  public init(runtime: AppRuntime) {
    self.runtime = runtime
    appModel = runtime.appModel
    panel = PassiveFloatingPanel(
      contentRect: CGRect(
        origin: .zero,
        size: PracticePanelPresentation.compact.size
      ),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    super.init()
    panel.level = .floating
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
    ]
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.animationBehavior = .utilityWindow
    panel.isMovable = true
    panel.isMovableByWindowBackground = true
    panel.delegate = self

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
    moveDebounceTask?.cancel()
  }

  public func windowDidMove(_ notification: Notification) {
    guard !isSnapping, Date() >= suppressMoveRecordingUntil else {
      return
    }
    moveDebounceTask?.cancel()
    moveDebounceTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(180))
      guard !Task.isCancelled else { return }
      self?.recordDraggedScreenAndSnap()
    }
  }

  public func show() {
    appModel.isCardVisible = true
    refreshLayout()
    panel.orderFrontRegardless()
  }

  public func hide() {
    runtime?.practice?.handleDisappear()
    runtime?.closeTrialSession(reason: .hidden)
    appModel.isCardVisible = false
    panel.orderOut(nil)
  }

  public func toggle() {
    appModel.isCardVisible ? hide() : show()
  }

  public var canMoveToAnotherScreen: Bool {
    ScreenPlacement.systemScreens().count > 1
  }

  public func moveToNextScreen() {
    let descriptors = ScreenPlacement.systemScreens()
    guard
      let next = ScreenPlacement.nextScreen(
        after: appModel.preferredScreenIdentifier,
        screens: descriptors
      ),
      next.identifier != appModel.preferredScreenIdentifier
    else {
      return
    }
    appModel.preferredScreenIdentifier = next.identifier
    refreshLayout()
  }

  public func refreshLayout() {
    let presentation = PracticePanelPresentation.resolve(
      isCollapsed: appModel.isCollapsed,
      isDetailExpanded:
        runtime?.practice?.isDetailExpanded == true,
      isReflectionPresented:
        runtime?.dailyReflection?.isCompletionOfferPresented == true
    )
    panel.setContentSize(presentation.size)
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
    suppressMoveRecordingUntil = Date().addingTimeInterval(0.6)
    isSnapping = true
    panel.setFrameOrigin(origin)
    isSnapping = false
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

  nonisolated public static func nearestCorner(
    panelFrame: CGRect,
    visibleFrame: CGRect
  ) -> FloatingCorner {
    let isLeft = panelFrame.midX < visibleFrame.midX
    let isTop = panelFrame.midY >= visibleFrame.midY
    switch (isLeft, isTop) {
    case (true, true):
      return .topLeft
    case (false, true):
      return .topRight
    case (true, false):
      return .bottomLeft
    case (false, false):
      return .bottomRight
    }
  }

  private func targetScreen() -> NSScreen? {
    let pairs = systemScreenPairs()
    let descriptors = pairs.map(\.descriptor)
    guard
      let selected = ScreenPlacement.selectedScreen(
        preferredIdentifier: appModel.preferredScreenIdentifier,
        screens: descriptors
      )
    else {
      return NSScreen.main ?? NSScreen.screens.first
    }
    if appModel.preferredScreenIdentifier != selected.identifier {
      appModel.preferredScreenIdentifier = selected.identifier
    }
    return pairs.first(where: {
      $0.descriptor.identifier == selected.identifier
    })?.screen
  }

  private func recordDraggedScreenAndSnap() {
    guard
      let draggedScreen = panel.screen,
      let descriptor = ScreenPlacement.descriptor(
        for: draggedScreen,
        isMain: draggedScreen == NSScreen.main
      )
    else {
      snapToCorner()
      return
    }
    appModel.preferredScreenIdentifier = descriptor.identifier
    appModel.corner = Self.nearestCorner(
      panelFrame: panel.frame,
      visibleFrame: draggedScreen.visibleFrame
    )
    snapToCorner()
  }

  private func systemScreenPairs() -> [(screen: NSScreen, descriptor: ScreenDescriptor)] {
    NSScreen.screens.compactMap { screen in
      guard
        let descriptor = ScreenPlacement.descriptor(
          for: screen,
          isMain: screen == NSScreen.main
        )
      else {
        return nil
      }
      return (screen, descriptor)
    }
  }

  private func observeLayoutPreferences() {
    withObservationTracking {
      _ = appModel.corner
      _ = appModel.isCollapsed
      _ = appModel.preferredScreenIdentifier
      _ = runtime?.practice?.isDetailExpanded
      _ = runtime?.dailyReflection?.isCompletionOfferPresented
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.refreshLayout()
        self?.observeLayoutPreferences()
      }
    }
  }

}

private struct FloatingPracticeRoot: View {
  @Bindable var runtime: AppRuntime
  let onLayoutChanged: () -> Void

  var body: some View {
    if let practice = runtime.practice {
      PracticeCardView(
        appModel: runtime.appModel,
        practice: practice,
        reflectionModel: runtime.dailyReflection,
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
