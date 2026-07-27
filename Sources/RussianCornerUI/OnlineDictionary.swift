import Foundation

public enum OnlineDictionary {
    public static func wiktionaryURL(for lemma: String) -> URL? {
        guard !lemma.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return URL(string: "https://ru.wiktionary.org")?
            .appendingPathComponent("wiki")
            .appendingPathComponent(lemma)
    }
}
