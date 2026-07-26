import Carbon
import Foundation

public enum GlobalHotKeyAction: UInt32, CaseIterable, Sendable {
  case toggleCard = 1
  case nextCard = 2
  case speak = 3
  case reveal = 4
  case gradeAgain = 5
  case gradeHard = 6
  case gradeEasy = 7
  case toggleCollapsed = 9

  public var title: String {
    switch self {
    case .toggleCard: "显示或隐藏"
    case .nextCard: "下一句"
    case .speak: "朗读"
    case .reveal: "显示答案"
    case .gradeAgain: "评分 Again"
    case .gradeHard: "评分 Hard"
    case .gradeEasy: "评分 Easy"
    case .toggleCollapsed: "收起或展开"
    }
  }

  public static let defaultShortcuts: [Self: GlobalHotKeyShortcut] = [
    .toggleCard: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_R)),
    .nextCard: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_N)),
    .speak: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_S)),
    .reveal: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_A)),
    .gradeAgain: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_1)),
    .gradeHard: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_2)),
    .gradeEasy: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_3)),
    .toggleCollapsed: GlobalHotKeyShortcut(keyCode: UInt32(kVK_ANSI_C)),
  ]
}

public struct GlobalHotKeyShortcut: Hashable, Sendable {
  public let keyCode: UInt32
  public let modifiers: UInt32

  public init(
    keyCode: UInt32,
    modifiers: UInt32 = UInt32(controlKey | optionKey)
  ) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }
}

public struct GlobalHotKeyRegistrationIssue: Equatable, Sendable {
  public let action: GlobalHotKeyAction
  public let status: OSStatus

  public init(action: GlobalHotKeyAction, status: OSStatus) {
    self.action = action
    self.status = status
  }
}

@MainActor
public final class GlobalHotKeyService {
  nonisolated(unsafe) private var eventHandler: EventHandlerRef?
  nonisolated(unsafe) private var hotKeyRefs: [EventHotKeyRef] = []
  private var actions: [GlobalHotKeyAction: () -> Void] = [:]

  public private(set) var registrationIssues: [GlobalHotKeyRegistrationIssue] = []

  public init() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    InstallEventHandler(
      GetApplicationEventTarget(),
      Self.eventCallback,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandler
    )
  }

  deinit {
    for hotKeyRef in hotKeyRefs {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let eventHandler {
      RemoveEventHandler(eventHandler)
    }
  }

  @discardableResult
  public func registerDefaults(
    actions: [GlobalHotKeyAction: () -> Void]
  ) -> [GlobalHotKeyRegistrationIssue] {
    self.actions = actions
    registrationIssues.removeAll()
    for hotKeyRef in hotKeyRefs {
      UnregisterEventHotKey(hotKeyRef)
    }
    hotKeyRefs.removeAll()

    for action in GlobalHotKeyAction.allCases {
      guard
        actions[action] != nil,
        let shortcut = GlobalHotKeyAction.defaultShortcuts[action]
      else {
        continue
      }
      register(action, shortcut: shortcut)
    }
    return registrationIssues
  }

  private func register(
    _ action: GlobalHotKeyAction,
    shortcut: GlobalHotKeyShortcut
  ) {
    var reference: EventHotKeyRef?
    let identifier = EventHotKeyID(
      signature: Self.signature,
      id: action.rawValue
    )
    let status = RegisterEventHotKey(
      shortcut.keyCode,
      shortcut.modifiers,
      identifier,
      GetApplicationEventTarget(),
      0,
      &reference
    )
    if status == noErr, let reference {
      hotKeyRefs.append(reference)
    } else {
      registrationIssues.append(
        GlobalHotKeyRegistrationIssue(
          action: action,
          status: status
        )
      )
    }
  }

  private func dispatch(id: UInt32) {
    guard let action = GlobalHotKeyAction(rawValue: id) else { return }
    actions[action]?()
  }

  private nonisolated static let signature: OSType = 0x5255_434F

  private nonisolated static let eventCallback: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
      return OSStatus(eventNotHandledErr)
    }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &identifier
    )
    guard status == noErr,
      identifier.signature == GlobalHotKeyService.signature
    else {
      return OSStatus(eventNotHandledErr)
    }
    let service = Unmanaged<GlobalHotKeyService>
      .fromOpaque(userData)
      .takeUnretainedValue()
    Task { @MainActor in
      service.dispatch(id: identifier.id)
    }
    return noErr
  }
}
