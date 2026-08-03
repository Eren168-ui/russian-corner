import AppKit
import Observation
import SwiftUI

public enum PracticePanelPresentation: Equatable, Sendable {
  case collapsed
  case compact
  case details
  case detailsWithAssessment

  public var size: CGSize {
    switch self {
    case .collapsed:
      CGSize(width: 58, height: 58)
    case .compact:
      CGSize(width: 360, height: 240)
    case .details:
      CGSize(width: 360, height: 386)
    case .detailsWithAssessment:
      CGSize(width: 360, height: 510)
    }
  }

  public var allowsWindowBackgroundDragging: Bool {
    self != .collapsed
  }

  public static func resolve(
    isCollapsed: Bool,
    isDetailExpanded: Bool,
    hasSelectedWord: Bool = false,
    isTransferPresented: Bool = false,
    isReflectionPresented: Bool = false
  ) -> Self {
    if isCollapsed { return .collapsed }
    if isTransferPresented && (hasSelectedWord || isDetailExpanded) {
      return .detailsWithAssessment
    }
    return hasSelectedWord || isDetailExpanded
      || isTransferPresented || isReflectionPresented
      ? .details : .compact
  }
}

private final class PassiveFloatingPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
public final class FloatingPanelController: NSObject, NSWindowDelegate {
  private enum RuntimeSource {
    case single(AppRuntime)
    case bilingual(LanguageCornerRuntime)

    @MainActor
    var activeRuntime: AppRuntime? {
      switch self {
      case .single(let runtime): runtime
      case .bilingual(let runtime): runtime.activeRuntime
      }
    }
  }

  private let panel: PassiveFloatingPanel
  private let appModel: AppModel
  private let runtimeSource: RuntimeSource
  nonisolated(unsafe) private var screenObserver: NSObjectProtocol?
  private var moveDebounceTask: Task<Void, Never>?
  private var isSnapping = false
  private var suppressMoveRecordingUntil = Date.distantPast
  private let onOpenLearningHistory: () -> Void
  private let utilityActions: PracticeCardUtilityActions

  private var activeAppModel: AppModel {
    runtimeSource.activeRuntime?.appModel ?? appModel
  }

  public convenience init(
    runtime: AppRuntime,
    onOpenLearningHistory: @escaping () -> Void = {},
    utilityActions: PracticeCardUtilityActions = .init()
  ) {
    self.init(
      runtimeSource: .single(runtime),
      onOpenLearningHistory: onOpenLearningHistory,
      utilityActions: utilityActions
    )
  }

  public convenience init(
    runtime: LanguageCornerRuntime,
    onOpenLearningHistory: @escaping () -> Void = {},
    utilityActions: PracticeCardUtilityActions = .init()
  ) {
    self.init(
      runtimeSource: .bilingual(runtime),
      onOpenLearningHistory: onOpenLearningHistory,
      utilityActions: utilityActions
    )
  }

  private init(
    runtimeSource: RuntimeSource,
    onOpenLearningHistory: @escaping () -> Void,
    utilityActions: PracticeCardUtilityActions
  ) {
    self.runtimeSource = runtimeSource
    appModel = runtimeSource.activeRuntime?.appModel
      ?? AppModel()
    self.onOpenLearningHistory = onOpenLearningHistory
    self.utilityActions = utilityActions
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

    switch runtimeSource {
    case .single(let runtime):
      panel.contentView = NSHostingView(
        rootView: FloatingPracticeRoot(
          runtime: runtime,
          onLayoutChanged: { [weak self] in
            self?.refreshLayout()
          },
          onCollapsedCardActivated: { [weak self] in
            self?.expandCollapsedCard()
          },
          onOpenLearningHistory: onOpenLearningHistory,
          utilityActions: utilityActions
        )
      )
    case .bilingual(let runtime):
      panel.contentView = NSHostingView(
        rootView: FloatingLanguagePracticeRoot(
          runtime: runtime,
          onLayoutChanged: { [weak self] in
            self?.refreshLayout()
          },
          onCollapsedCardActivated: { [weak self] in
            self?.expandCollapsedCard()
          },
          onOpenLearningHistory: onOpenLearningHistory,
          utilityActions: utilityActions
        )
      )
    }

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refreshLayout()
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
      self?.recordDraggedPosition()
    }
  }

  public func show() {
    activeAppModel.isCardVisible = true
    refreshLayout()
    panel.orderFrontRegardless()
  }

  public func hide() {
    runtimeSource.activeRuntime?.practice?.handleDisappear()
    runtimeSource.activeRuntime?.closeTrialSession(reason: .hidden)
    activeAppModel.isCardVisible = false
    panel.orderOut(nil)
  }

  public func toggle() {
    activeAppModel.isCardVisible ? hide() : show()
  }

  public var canMoveToAnotherScreen: Bool {
    ScreenPlacement.systemScreens().count > 1
  }

  public func moveToNextScreen() {
    let descriptors = ScreenPlacement.systemScreens()
    guard
      let next = ScreenPlacement.nextScreen(
        after: activeAppModel.preferredScreenIdentifier,
        screens: descriptors
      ),
      next.identifier != activeAppModel.preferredScreenIdentifier
    else {
      return
    }
    activeAppModel.preferredScreenIdentifier = next.identifier
    refreshLayout()
  }

  public func refreshLayout() {
    let presentation = PracticePanelPresentation.resolve(
      isCollapsed: activeAppModel.isCollapsed,
      isDetailExpanded:
        runtimeSource.activeRuntime?.practice?.isDetailExpanded == true,
      hasSelectedWord:
        runtimeSource.activeRuntime?.practice?.selectedWordAnalysis != nil,
      isTransferPresented:
        runtimeSource.activeRuntime?.practice?
          .isStructuredRecallPresented == true,
      isReflectionPresented:
        runtimeSource.activeRuntime?.dailyReflection?
          .isCompletionOfferPresented == true
    )
    panel.appearance = activeAppModel.appearanceMode.nsAppearance
    panel.isMovableByWindowBackground =
      presentation.allowsWindowBackgroundDragging
    resizePanelAtomically(to: presentation.size)
    switch activeAppModel.placementMode {
    case .free:
      placeAtFreeOrigin()
    case .snap:
      snapToCorner()
    }
    if activeAppModel.isCardVisible {
      panel.orderFrontRegardless()
    }
  }

  public func snapToCorner() {
    guard let screen = targetScreen() else { return }
    let origin = Self.origin(
      for: activeAppModel.corner,
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

  nonisolated public static func constrainedOrigin(
    _ origin: CGPoint,
    panelSize: CGSize,
    visibleFrame: CGRect
  ) -> CGPoint {
    CGPoint(
      x: min(
        max(origin.x, visibleFrame.minX),
        max(visibleFrame.minX, visibleFrame.maxX - panelSize.width)
      ),
      y: min(
        max(origin.y, visibleFrame.minY),
        max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)
      )
    )
  }

  nonisolated public static func topAnchoredOrigin(
    currentFrame: CGRect,
    newPanelSize: CGSize
  ) -> CGPoint {
    CGPoint(
      x: currentFrame.origin.x,
      y: currentFrame.maxY - newPanelSize.height
    )
  }

  nonisolated public static func topAnchoredFrame(
    currentFrame: CGRect,
    newPanelSize: CGSize
  ) -> CGRect {
    CGRect(
      origin: topAnchoredOrigin(
        currentFrame: currentFrame,
        newPanelSize: newPanelSize
      ),
      size: newPanelSize
    )
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
        preferredIdentifier: activeAppModel.preferredScreenIdentifier,
        screens: descriptors
      )
    else {
      return NSScreen.main ?? NSScreen.screens.first
    }
    if activeAppModel.preferredScreenIdentifier != selected.identifier {
      activeAppModel.preferredScreenIdentifier = selected.identifier
    }
    return pairs.first(where: {
      $0.descriptor.identifier == selected.identifier
    })?.screen
  }

  private func resizePanelAtomically(to panelSize: CGSize) {
    let currentFrame = panel.frame
    guard currentFrame.size != panelSize else { return }

    let targetFrame: CGRect
    if let screen = targetScreen() {
      let origin: CGPoint
      switch activeAppModel.placementMode {
      case .free:
        origin = Self.constrainedOrigin(
          Self.topAnchoredFrame(
            currentFrame: currentFrame,
            newPanelSize: panelSize
          ).origin,
          panelSize: panelSize,
          visibleFrame: screen.visibleFrame
        )
        activeAppModel.freeOrigin = origin
      case .snap:
        origin = Self.origin(
          for: activeAppModel.corner,
          panelSize: panelSize,
          visibleFrame: screen.visibleFrame
        )
      }
      targetFrame = CGRect(origin: origin, size: panelSize)
    } else {
      targetFrame = Self.topAnchoredFrame(
        currentFrame: currentFrame,
        newPanelSize: panelSize
      )
    }

    suppressMoveRecordingUntil = Date().addingTimeInterval(0.6)
    isSnapping = true
    panel.setFrame(targetFrame, display: true, animate: false)
    isSnapping = false
  }

  private func placeAtFreeOrigin() {
    guard let screen = targetScreen() else { return }
    let requestedOrigin = activeAppModel.freeOrigin ?? Self.origin(
      for: activeAppModel.corner,
      panelSize: panel.frame.size,
      visibleFrame: screen.visibleFrame
    )
    let origin = Self.constrainedOrigin(
      requestedOrigin,
      panelSize: panel.frame.size,
      visibleFrame: screen.visibleFrame
    )
    if activeAppModel.freeOrigin != origin {
      activeAppModel.freeOrigin = origin
    }
    suppressMoveRecordingUntil = Date().addingTimeInterval(0.6)
    isSnapping = true
    panel.setFrameOrigin(origin)
    isSnapping = false
  }

  private func recordDraggedPosition() {
    guard
      let draggedScreen = panel.screen,
      let descriptor = ScreenPlacement.descriptor(
        for: draggedScreen,
        isMain: draggedScreen == NSScreen.main
      )
    else {
      placeAtFreeOrigin()
      return
    }
    let origin = Self.constrainedOrigin(
      panel.frame.origin,
      panelSize: panel.frame.size,
      visibleFrame: draggedScreen.visibleFrame
    )
    activeAppModel.preferredScreenIdentifier = descriptor.identifier
    activeAppModel.freeOrigin = origin
    activeAppModel.placementMode = .free
    if panel.frame.origin != origin {
      suppressMoveRecordingUntil = Date().addingTimeInterval(0.6)
      panel.setFrameOrigin(origin)
    }
  }

  private func expandCollapsedCard() {
    activeAppModel.isCollapsed = false
    refreshLayout()
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
      _ = activeAppModel.corner
      _ = activeAppModel.placementMode
      _ = activeAppModel.freeOrigin
      _ = activeAppModel.isCollapsed
      _ = activeAppModel.preferredScreenIdentifier
      _ = runtimeSource.activeRuntime?.practice?.isDetailExpanded
      _ = runtimeSource.activeRuntime?.practice?
        .isStructuredRecallPresented
      _ = runtimeSource.activeRuntime?.dailyReflection?
        .isCompletionOfferPresented
      if case .bilingual(let runtime) = runtimeSource {
        _ = runtime.activeLanguage
      }
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.refreshLayout()
        self?.observeLayoutPreferences()
      }
    }
  }

}

private struct FloatingLanguagePracticeRoot: View {
  @Bindable var runtime: LanguageCornerRuntime
  let onLayoutChanged: () -> Void
  let onCollapsedCardActivated: () -> Void
  let onOpenLearningHistory: () -> Void
  let utilityActions: PracticeCardUtilityActions

  var body: some View {
    if let activeRuntime = runtime.activeRuntime,
      let practice = activeRuntime.practice
    {
      PracticeCardView(
        appModel: activeRuntime.appModel,
        practice: practice,
        reflectionModel: activeRuntime.dailyReflection,
        onLayoutChanged: onLayoutChanged,
        onCollapsedCardActivated: onCollapsedCardActivated,
        onReminderPermissionAction: {
          Task {
            await activeRuntime.performReminderPermissionAction()
          }
        },
        onOpenLearningHistory: onOpenLearningHistory,
        utilityActions: utilityActions,
        languageActions: PracticeCardLanguageActions(
          availableLanguages: runtime.availableLanguages,
          switchLanguage: { language in
            runtime.switchLanguage(to: language)
            onLayoutChanged()
          }
        )
      )
      .id(runtime.activeLanguage)
    } else {
      unavailableCard
    }
  }

  private var unavailableCard: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("LANGUAGE CORNER")
        .font(.system(size: 10, design: .monospaced))
      Text("学习数据暂时无法载入")
        .font(.headline)
      Text("俄语或英语语料不可用，请从菜单栏重启。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(22)
    .frame(width: 320, height: 150)
    .background(.regularMaterial)
  }
}

private struct FloatingPracticeRoot: View {
  @Bindable var runtime: AppRuntime
  let onLayoutChanged: () -> Void
  let onCollapsedCardActivated: () -> Void
  let onOpenLearningHistory: () -> Void
  let utilityActions: PracticeCardUtilityActions

  var body: some View {
    if let practice = runtime.practice {
      PracticeCardView(
        appModel: runtime.appModel,
        practice: practice,
        reflectionModel: runtime.dailyReflection,
        onLayoutChanged: onLayoutChanged,
        onCollapsedCardActivated: onCollapsedCardActivated,
        onReminderPermissionAction: {
          Task {
            await runtime.performReminderPermissionAction()
          }
        },
        onOpenLearningHistory: onOpenLearningHistory,
        utilityActions: utilityActions
      )
    } else {
      unavailableCard
    }
  }

  private var unavailableCard: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("LANGUAGE CORNER")
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
