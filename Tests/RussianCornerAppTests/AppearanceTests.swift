import Foundation
import XCTest

@testable import RussianCornerUI

@MainActor
final class AppearanceTests: XCTestCase {
    func testAppearanceModesExposeIndependentUserChoices() {
        XCTAssertEqual(AppAppearanceMode.system.title, "跟随系统")
        XCTAssertEqual(AppAppearanceMode.dark.title, "深色模式")
        XCTAssertEqual(AppAppearanceMode.light.title, "浅色模式")
        XCTAssertNil(AppAppearanceMode.system.nsAppearance)
        XCTAssertNotNil(AppAppearanceMode.dark.nsAppearance)
        XCTAssertNotNil(AppAppearanceMode.light.nsAppearance)
    }

    func testAppearanceModePersistsAndDirectToggleSwitchesBetweenThemes() {
        let suiteName = "RussianCornerAppTests.Appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            AppAppearanceMode.apply(.system)
        }

        var model = AppModel(defaults: defaults)
        XCTAssertEqual(model.appearanceMode, .system)

        model.appearanceMode = .light
        model = AppModel(defaults: defaults)
        XCTAssertEqual(model.appearanceMode, .light)

        model.toggleAppearance()
        XCTAssertEqual(model.appearanceMode, .dark)
    }

    func testSettingsOffersIndependentAppearanceModes() throws {
        let source = try source(named: "SettingsView.swift")

        XCTAssertTrue(source.contains("外观"))
        XCTAssertTrue(source.contains("Picker(\"主题\""))
        XCTAssertTrue(source.contains("AppAppearanceMode.allCases"))
    }

    func testPracticeCardOffersDirectAppearanceToggle() throws {
        let source = try source(named: "PracticeCardView.swift")

        XCTAssertTrue(source.contains("切换外观"))
    }

    func testFloatingPanelInheritsApplicationAppearance() throws {
        let source = try source(named: "FloatingPanelController.swift")

        XCTAssertFalse(
            source.contains(
                "panel.appearance = activeAppModel.appearanceMode.nsAppearance"
            )
        )
    }

    private func source(named fileName: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot
                .appendingPathComponent("Sources")
                .appendingPathComponent("RussianCornerUI")
                .appendingPathComponent(fileName),
            encoding: .utf8
        )
    }
}
