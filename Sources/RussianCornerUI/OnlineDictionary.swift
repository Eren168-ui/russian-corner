import Foundation
import RussianCornerCore

public enum OnlineDictionary {
    public static func wiktionaryURL(for lemma: String) -> URL? {
        wiktionaryURL(for: lemma, language: .russian)
    }

    public static func wiktionaryURL(
        for lemma: String,
        language: StudyLanguage
    ) -> URL? {
        guard !lemma.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        let subdomain = language == .english ? "en" : "ru"
        return URL(string: "https://\(subdomain).wiktionary.org")?
            .appendingPathComponent("wiki")
            .appendingPathComponent(lemma)
    }
}
