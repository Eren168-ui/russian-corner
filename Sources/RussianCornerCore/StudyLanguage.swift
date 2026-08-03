import Foundation

public enum StudyLanguage: String, Codable, CaseIterable, Sendable {
    case english
    case russian

    public var storageNamespace: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .english: "EN"
        case .russian: "RU"
        }
    }

    public var displayName: String {
        switch self {
        case .english: "English"
        case .russian: "Русский"
        }
    }

    public var preferredVoiceLanguages: [String] {
        switch self {
        case .english: ["en-US", "en-GB", "en"]
        case .russian: ["ru-RU", "ru"]
        }
    }

    public var dictionaryLanguagePairs: [String] {
        switch self {
        case .english: ["en-zh", "en-ru"]
        case .russian: ["ru-zh", "ru-en"]
        }
    }
}
