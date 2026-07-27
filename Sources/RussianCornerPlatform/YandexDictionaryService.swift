import Foundation
import Security

public struct DictionaryExample: Equatable, Sendable {
    public let russian: String
    public let translationZh: String?

    public init(russian: String, translationZh: String? = nil) {
        self.russian = russian
        self.translationZh = translationZh
    }
}

public struct OnlineDictionaryResult: Equatable, Sendable {
    public let lemma: String
    public let partOfSpeech: String?
    public let translations: [String]
    public let synonyms: [String]
    public let examples: [DictionaryExample]

    public init(
        lemma: String,
        partOfSpeech: String?,
        translations: [String],
        synonyms: [String],
        examples: [DictionaryExample]
    ) {
        self.lemma = lemma
        self.partOfSpeech = partOfSpeech
        self.translations = translations
        self.synonyms = synonyms
        self.examples = examples
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
    case keychain(Int32)

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
        case .keychain:
            "无法访问在线词典密钥"
        }
    }
}

public protocol DictionaryAPIKeyStoring: Sendable {
    func loadKey() throws -> String?
    func saveKey(_ key: String) throws
    func deleteKey() throws
}

public struct YandexDictionaryKeychainStore:
    DictionaryAPIKeyStoring,
    @unchecked Sendable
{
    public static let service =
        "com.openclaw.russiancorner.yandex-dictionary"
    public static let account = "russian-corner"

    public init() {}

    public func loadKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &item
        )
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw YandexDictionaryError.keychain(status)
        }
        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw YandexDictionaryError.keychain(errSecDecode)
        }
        return value
    }

    public func saveKey(_ key: String) throws {
        let normalized = key.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else {
            try deleteKey()
            return
        }
        let value = Data(normalized.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: value] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw YandexDictionaryError.keychain(updateStatus)
        }
        var insert = baseQuery
        insert[kSecValueData as String] = value
        insert[kSecAttrLabel as String] =
            "Russian Corner Yandex Dictionary API"
        let insertStatus = SecItemAdd(insert as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw YandexDictionaryError.keychain(insertStatus)
        }
    }

    public func deleteKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound
        else {
            throw YandexDictionaryError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
    }
}

public protocol OnlineDictionaryLookingUp: Sendable {
    func lookup(lemma: String) async throws -> OnlineDictionaryResult
}

public actor YandexDictionaryService: OnlineDictionaryLookingUp {
    private let session: URLSession
    private let keyStore: any DictionaryAPIKeyStoring
    private var cache: [String: OnlineDictionaryResult] = [:]

    public init(
        session: URLSession = .shared,
        keyStore: any DictionaryAPIKeyStoring =
            YandexDictionaryKeychainStore()
    ) {
        self.session = session
        self.keyStore = keyStore
    }

    public func lookup(
        lemma: String
    ) async throws -> OnlineDictionaryResult {
        let normalized = lemma.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        guard !normalized.isEmpty else {
            throw YandexDictionaryError.invalidRequest
        }
        if let cached = cache[normalized] {
            return cached
        }
        guard
            let key = try keyStore.loadKey()?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else {
            throw YandexDictionaryError.missingAPIKey
        }
        guard var components = URLComponents(
            string:
                "https://dictionary.yandex.net/api/v1/dicservice.json/lookup"
        ) else {
            throw YandexDictionaryError.invalidRequest
        }
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "lang", value: "ru-zh"),
            URLQueryItem(name: "ui", value: "zh"),
            URLQueryItem(name: "text", value: normalized),
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
        let result = try Self.decodeResponse(
            data,
            fallbackLemma: normalized
        )
        guard !result.translations.isEmpty else {
            throw YandexDictionaryError.noResults
        }
        cache[normalized] = result
        return result
    }

    public nonisolated static func decodeResponse(
        _ data: Data,
        fallbackLemma: String
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
            examples: examples
        )
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
