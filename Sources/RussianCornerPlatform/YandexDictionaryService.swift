import Foundation
import RussianCornerCore

public struct DictionaryExample: Equatable, Sendable {
    public let russian: String
    public let translationZh: String?

    public init(russian: String, translationZh: String? = nil) {
        self.russian = russian
        self.translationZh = translationZh
    }
}

public enum DictionaryTranslationLanguage:
    String,
    Equatable,
    Sendable
{
    case chinese
    case english
    case russian
}

public struct OnlineDictionaryResult: Equatable, Sendable {
    public let lemma: String
    public let partOfSpeech: String?
    public let translations: [String]
    public let synonyms: [String]
    public let examples: [DictionaryExample]
    public let translationLanguage: DictionaryTranslationLanguage

    public init(
        lemma: String,
        partOfSpeech: String?,
        translations: [String],
        synonyms: [String],
        examples: [DictionaryExample],
        translationLanguage: DictionaryTranslationLanguage = .chinese
    ) {
        self.lemma = lemma
        self.partOfSpeech = partOfSpeech
        self.translations = translations
        self.synonyms = synonyms
        self.examples = examples
        self.translationLanguage = translationLanguage
    }
}

public enum YandexDictionaryError:
    Error,
    Equatable,
    LocalizedError,
    Sendable
{
    case missingAPIKey
    case invalidRequest
    case invalidResponse
    case networkUnavailable
    case httpStatus(Int)
    case noResults

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "尚未配置在线词典密钥，本地词义仍可正常使用"
        case .invalidRequest:
            "无法创建在线词典请求"
        case .invalidResponse:
            "在线词典返回了无法识别的数据"
        case .networkUnavailable:
            "网络暂时不可用，本地词义仍可正常使用"
        case .httpStatus(let status):
            "在线词典暂时不可用（HTTP \(status)）"
        case .noResults:
            "在线词典没有找到这个词"
        }
    }
}

public protocol DictionaryAPIKeyStoring: Sendable {
    func loadKey() throws -> String?
    func saveKey(_ key: String) throws
    func deleteKey() throws
}

public struct DictionaryPreferenceKeyStore:
    DictionaryAPIKeyStoring,
    @unchecked Sendable
{
    public static let defaultsKey =
        "RussianCorner.YandexDictionaryAPIKey"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadKey() throws -> String? {
        defaults.string(forKey: Self.defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func saveKey(_ key: String) throws {
        let normalized = key.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if normalized.isEmpty {
            try deleteKey()
        } else {
            defaults.set(normalized, forKey: Self.defaultsKey)
        }
    }

    public func deleteKey() throws {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}

public protocol OnlineDictionaryLookingUp: Sendable {
    func lookup(
        lemma: String,
        language: StudyLanguage
    ) async throws -> OnlineDictionaryResult
}

public extension OnlineDictionaryLookingUp {
    func lookup(lemma: String) async throws -> OnlineDictionaryResult {
        try await lookup(lemma: lemma, language: .russian)
    }
}

public actor YandexDictionaryService: OnlineDictionaryLookingUp {
    private let session: URLSession
    private let keyStore: any DictionaryAPIKeyStoring
    private var cache: [String: OnlineDictionaryResult] = [:]

    public init(
        session: URLSession = .shared,
        keyStore: any DictionaryAPIKeyStoring =
            DictionaryPreferenceKeyStore()
    ) {
        self.session = session
        self.keyStore = keyStore
    }

    public func lookup(
        lemma: String,
        language: StudyLanguage
    ) async throws -> OnlineDictionaryResult {
        let normalized = lemma.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        guard !normalized.isEmpty else {
            throw YandexDictionaryError.invalidRequest
        }
        let cacheKey = "\(language.storageNamespace):\(normalized)"
        if let cached = cache[cacheKey] {
            return cached
        }
        guard
            let key = try keyStore.loadKey()?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else {
            throw YandexDictionaryError.missingAPIKey
        }
        let languages: [
            (DictionaryTranslationLanguage, String)
        ] = language.dictionaryLanguagePairs.map { languagePair in
            let translationLanguage: DictionaryTranslationLanguage
            if languagePair.hasSuffix("-zh") {
                translationLanguage = .chinese
            } else if languagePair.hasSuffix("-ru") {
                translationLanguage = .russian
            } else {
                translationLanguage = .english
            }
            return (translationLanguage, languagePair)
        }
        for (translationLanguage, languagePair) in languages {
            let data = try await requestData(
                text: normalized,
                key: key,
                languagePair: languagePair
            )
            let result = try Self.decodeResponse(
                data,
                fallbackLemma: normalized,
                translationLanguage: translationLanguage
            )
            if !result.translations.isEmpty {
                cache[cacheKey] = result
                return result
            }
        }
        throw YandexDictionaryError.noResults
    }

    public nonisolated static func decodeResponse(
        _ data: Data,
        fallbackLemma: String,
        translationLanguage: DictionaryTranslationLanguage = .chinese
    ) throws -> OnlineDictionaryResult {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw YandexDictionaryError.invalidResponse
        }
        let first = response.definitions.first
        let translations = unique(
            response.definitions.flatMap { definition in
                definition.translations.map(\.text)
            }
        )
        let synonyms = unique(
            response.definitions.flatMap { definition in
                definition.translations.flatMap { translation in
                    translation.synonyms?.map(\.text) ?? []
                }
            }
        )
        let examples = response.definitions.flatMap { definition in
            definition.translations.flatMap { translation in
                translation.examples?.map {
                    DictionaryExample(
                        russian: $0.text,
                        translationZh: $0.translations?.first?.text
                    )
                } ?? []
            }
        }
        return OnlineDictionaryResult(
            lemma: first?.text ?? fallbackLemma,
            partOfSpeech: first?.partOfSpeech,
            translations: translations,
            synonyms: synonyms,
            examples: examples,
            translationLanguage: translationLanguage
        )
    }

    private func requestData(
        text: String,
        key: String,
        languagePair: String
    ) async throws -> Data {
        guard var components = URLComponents(
            string:
                "https://dictionary.yandex.net/api/v1/dicservice.json/lookup"
        ) else {
            throw YandexDictionaryError.invalidRequest
        }
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "lang", value: languagePair),
            URLQueryItem(name: "ui", value: "zh"),
            URLQueryItem(name: "text", value: text),
        ]
        guard let url = components.url else {
            throw YandexDictionaryError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw YandexDictionaryError.networkUnavailable
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YandexDictionaryError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw YandexDictionaryError.httpStatus(
                httpResponse.statusCode
            )
        }
        return data
    }

    private nonisolated static func unique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private struct Response: Decodable {
        let definitions: [Definition]

        private enum CodingKeys: String, CodingKey {
            case definitions = "def"
        }
    }

    private struct Definition: Decodable {
        let text: String
        let partOfSpeech: String?
        let translations: [Translation]

        private enum CodingKeys: String, CodingKey {
            case text
            case partOfSpeech = "pos"
            case translations = "tr"
        }
    }

    private struct Translation: Decodable {
        let text: String
        let synonyms: [TextValue]?
        let examples: [Example]?

        private enum CodingKeys: String, CodingKey {
            case text
            case synonyms = "syn"
            case examples = "ex"
        }
    }

    private struct Example: Decodable {
        let text: String
        let translations: [TextValue]?

        private enum CodingKeys: String, CodingKey {
            case text
            case translations = "tr"
        }
    }

    private struct TextValue: Decodable {
        let text: String
    }
}
