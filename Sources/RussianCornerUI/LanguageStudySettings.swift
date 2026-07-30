import Foundation
import RussianCornerCore

public enum LanguageStudySettings {
    public static func storageKey(
        _ baseKey: String,
        for language: StudyLanguage
    ) -> String {
        switch language {
        case .russian:
            baseKey
        case .english:
            "\(language.storageNamespace).\(baseKey)"
        }
    }

    public static func dailyQueueKey(
        for language: StudyLanguage
    ) -> String {
        storageKey(
            "practice.dailyQueueSnapshot.v1",
            for: language
        )
    }

    public static func remindersEnabledByDefault(
        for language: StudyLanguage
    ) -> Bool {
        language == .russian
    }

    public static func preferredVoiceLanguageByDefault(
        for language: StudyLanguage
    ) -> String {
        language.preferredVoiceLanguages.first ?? language.rawValue
    }
}
