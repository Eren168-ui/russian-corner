import Foundation

public struct LearnerVocabularyProfile: Equatable, Sendable {
    public let suppressedStandaloneLemmas: Set<String>

    public init(suppressedStandaloneLemmas: Set<String>) {
        self.suppressedStandaloneLemmas = Set(
            suppressedStandaloneLemmas.map(Self.normalized)
        )
    }

    public func shouldServeAsStandalone(lexeme: Lexeme) -> Bool {
        shouldServeAsStandalone(lemma: lexeme.lemma)
    }

    public func shouldServeAsStandalone(lemma: String) -> Bool {
        !suppressedStandaloneLemmas.contains(Self.normalized(lemma))
    }

    public static let a2ToB1Bridge = LearnerVocabularyProfile(
        suppressedStandaloneLemmas: [
            "да",
            "нет",
            "понимать",
            "знать",
            "здравствуйте",
            "привет",
            "спасибо",
            "пожалуйста",
            "пока",
            "семья",
            "мама",
            "папа",
            "брат",
            "сестра",
            "бабушка",
            "дедушка",
            "квартира",
            "кухня",
            "спальня",
            "балкон",
            "диван",
            "окно",
            "вставать",
            "душ",
            "рано",
            "завтрак",
            "одеваться",
            "спать",
            "обед",
            "суп",
            "салат",
            "хлеб",
            "ужин",
            "рис",
            "рыба",
            "чай",
            "магазин",
            "цена",
            "карта",
            "меню",
            "чашка",
            "кофе",
            "автобус",
            "остановка",
            "минута",
            "метро",
            "такси",
            "центр",
            "город",
            "музей",
            "улица",
            "парк",
            "прямо",
            "потом",
            "налево",
            "аптека",
            "банк",
            "вход",
            "справа",
            "сегодня",
            "тепло",
            "ветер",
            "дождь",
            "зонт",
            "весна",
            "снег",
            "цветок",
            "осень",
            "лист",
            "воздух",
            "сейчас",
            "неделя",
            "месяц",
            "день",
            "студент",
            "читать",
            "учебник",
            "библиотека",
            "вопрос",
            "новый",
            "слово",
            "слушать",
            "диалог",
            "голова",
            "врач",
            "пить",
            "вода",
        ]
    )

    private static func normalized(_ value: String) -> String {
        let withoutStress = value.unicodeScalars.filter {
            $0.value != 0x0301
        }
        return String(String.UnicodeScalarView(withoutStress))
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
