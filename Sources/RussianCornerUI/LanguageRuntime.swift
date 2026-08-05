import Foundation
import Observation
import RussianCornerCore

@MainActor
@Observable
public final class LanguageCornerRuntime {
    private static let activeLanguageKey =
        "languageCorner.activeLanguage"

    private let defaults: UserDefaults
    public private(set) var activeLanguage: StudyLanguage
    public private(set) var languageRuntimes:
        [StudyLanguage: AppRuntime]

    public var activeRuntime: AppRuntime? {
        languageRuntimes[activeLanguage]
    }

    public var availableLanguages: [StudyLanguage] {
        [.english, .russian].filter {
            languageRuntimes[$0] != nil
        }
    }

    public init(
        defaults: UserDefaults = .standard,
        runtimes: [StudyLanguage: AppRuntime]
    ) {
        self.defaults = defaults
        languageRuntimes = runtimes
        let storedLanguage = defaults.string(
            forKey: Self.activeLanguageKey
        ).flatMap(StudyLanguage.init(rawValue:))
        if let storedLanguage, runtimes[storedLanguage] != nil {
            activeLanguage = storedLanguage
        } else if runtimes[.russian] != nil {
            activeLanguage = .russian
        } else {
            activeLanguage = runtimes.keys.sorted {
                $0.rawValue < $1.rawValue
            }.first ?? .russian
        }
    }

    public convenience init(
        defaults: UserDefaults = .standard,
        enableSystemReminders: Bool = true,
        enableRussianSourceSync: Bool = true
    ) {
        let russian = AppRuntime(
            defaults: defaults,
            language: .russian,
            enableSystemReminders: enableSystemReminders,
            enableSourceSync: enableRussianSourceSync
        )
        let english = AppRuntime(
            defaults: defaults,
            language: .english,
            enableSystemReminders: false,
            enableSourceSync: false
        )
        var runtimes: [StudyLanguage: AppRuntime] = [:]
        if russian.practice != nil {
            runtimes[.russian] = russian
        }
        if english.practice != nil {
            runtimes[.english] = english
        }
        self.init(defaults: defaults, runtimes: runtimes)
    }

    public func switchLanguage(to language: StudyLanguage) {
        guard language != activeLanguage,
              let next = languageRuntimes[language]
        else {
            return
        }
        if let current = activeRuntime {
            current.practice?.handleDisappear()
            synchronizeGlobalPresentation(
                from: current.appModel,
                to: next.appModel
            )
        }
        activeLanguage = language
        defaults.set(language.rawValue, forKey: Self.activeLanguageKey)
    }

    public func refreshPracticeForTemporalBoundary(
        now: Date = Date()
    ) {
        for runtime in languageRuntimes.values {
            runtime.refreshPracticeForTemporalBoundary(now: now)
        }
    }

    public func closeAll(reason: TrialSessionEndReason) {
        for runtime in languageRuntimes.values {
            runtime.practice?.handleDisappear()
            runtime.closeTrialSession(reason: reason)
        }
    }

    private func synchronizeGlobalPresentation(
        from source: AppModel,
        to destination: AppModel
    ) {
        destination.corner = source.corner
        destination.placementMode = source.placementMode
        destination.freeOrigin = source.freeOrigin
        destination.preferredScreenIdentifier =
            source.preferredScreenIdentifier
        destination.opacity = source.opacity
        destination.fontScale = source.fontScale
        destination.isCollapsed = source.isCollapsed
        destination.isCardVisible = source.isCardVisible
        destination.appearanceMode = source.appearanceMode
    }
}
