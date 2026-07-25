import AppKit
import Foundation

public struct ScreenDescriptor: Identifiable, Equatable, Sendable {
  public let identifier: String
  public let name: String
  public let visibleFrame: CGRect
  public let isMain: Bool

  public var id: String { identifier }

  public init(
    identifier: String,
    name: String,
    visibleFrame: CGRect,
    isMain: Bool
  ) {
    self.identifier = identifier
    self.name = name
    self.visibleFrame = visibleFrame
    self.isMain = isMain
  }
}

public enum ScreenPlacement {
  public static func identifier(screenNumber: NSNumber) -> String {
    screenNumber.stringValue
  }

  @MainActor
  public static func systemScreens() -> [ScreenDescriptor] {
    NSScreen.screens.compactMap { screen in
      descriptor(
        for: screen,
        isMain: screen == NSScreen.main
      )
    }
  }

  @MainActor
  public static func descriptor(
    for screen: NSScreen,
    isMain: Bool
  ) -> ScreenDescriptor? {
    guard
      let number = screen.deviceDescription[
        NSDeviceDescriptionKey("NSScreenNumber")
      ] as? NSNumber
    else {
      return nil
    }
    return ScreenDescriptor(
      identifier: identifier(screenNumber: number),
      name: screen.localizedName,
      visibleFrame: screen.visibleFrame,
      isMain: isMain
    )
  }

  public static func selectedScreen(
    preferredIdentifier: String?,
    screens: [ScreenDescriptor]
  ) -> ScreenDescriptor? {
    if let preferredIdentifier,
      let preferred = screens.first(where: {
        $0.identifier == preferredIdentifier
      })
    {
      return preferred
    }
    return screens.first(where: \.isMain) ?? screens.first
  }

  public static func nextScreen(
    after preferredIdentifier: String?,
    screens: [ScreenDescriptor]
  ) -> ScreenDescriptor? {
    guard screens.count > 1 else { return screens.first }
    guard
      let current = selectedScreen(
        preferredIdentifier: preferredIdentifier,
        screens: screens
      ),
      let index = screens.firstIndex(of: current)
    else {
      return screens.first
    }
    return screens[(index + 1) % screens.count]
  }
}
