import Foundation
import RussianCornerCore
import XCTest

@testable import RussianCornerPlatform

final class YandexDictionaryServiceTests: XCTestCase {
    func testDecodesChineseTranslationsSynonymsAndExamples() throws {
        let data = Data(
            """
            {
              "def": [{
                "text": "заплатить",
                "pos": "verb",
                "tr": [{
                  "text": "支付",
                  "syn": [{"text": "付钱"}],
                  "ex": [{
                    "text": "заплатить за ужин",
                    "tr": [{"text": "支付晚餐费用"}]
                  }]
                }]
              }]
            }
            """.utf8
        )

        let result = try YandexDictionaryService.decodeResponse(
            data,
            fallbackLemma: "заплатить"
        )

        XCTAssertEqual(result.lemma, "заплатить")
        XCTAssertEqual(result.partOfSpeech, "verb")
        XCTAssertEqual(result.translations, ["支付"])
        XCTAssertEqual(result.synonyms, ["付钱"])
        XCTAssertEqual(
            result.examples,
            [
                DictionaryExample(
                    russian: "заплатить за ужин",
                    translationZh: "支付晚餐费用"
                ),
            ]
        )
    }

    func testMissingKeyFailsWithoutNetworkRequest() async {
        let service = YandexDictionaryService(
            keyStore: EmptyDictionaryKeyStore()
        )

        do {
            _ = try await service.lookup(lemma: "заплатить")
            XCTFail("Expected missing API key")
        } catch {
            XCTAssertEqual(
                error as? YandexDictionaryError,
                .missingAPIKey
            )
        }
    }

    func testConfiguredKeyLiveLookupWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["RUN_YANDEX_DICTIONARY_LIVE_TEST"] == "1",
            let key = environment["YANDEX_DICTIONARY_API_KEY"],
            !key.isEmpty
        else {
            throw XCTSkip("Live dictionary test is opt-in")
        }

        let result = try await YandexDictionaryService(
            keyStore: RuntimeDictionaryKeyStore(key: key)
        ).lookup(
            lemma: "ладонь"
        )

        XCTAssertFalse(result.translations.isEmpty)
        XCTAssertEqual(result.lemma, "ладонь")
        XCTAssertEqual(
            result.translationLanguage,
            .chinese,
            "translations=\(result.translations) lemma=\(result.lemma)"
        )
    }

    func testConfiguredKeyLiveEnglishLookupWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["RUN_YANDEX_DICTIONARY_LIVE_TEST"] == "1",
            let key = environment["YANDEX_DICTIONARY_API_KEY"],
            !key.isEmpty
        else {
            throw XCTSkip("Live dictionary test is opt-in")
        }

        let result = try await YandexDictionaryService(
            keyStore: RuntimeDictionaryKeyStore(key: key)
        ).lookup(
            lemma: "cheaper",
            language: .english
        )

        XCTAssertFalse(result.translations.isEmpty)
        XCTAssertEqual(
            result.translationLanguage,
            .chinese,
            "translations=\(result.translations) lemma=\(result.lemma)"
        )
    }

    func testPreferenceStorePersistsWithoutKeychainAccess() throws {
        let suiteName = "YandexDictionaryServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DictionaryPreferenceKeyStore(defaults: defaults)

        XCTAssertNil(try store.loadKey())

        try store.saveKey("  test-key  ")
        XCTAssertEqual(try store.loadKey(), "test-key")

        try store.deleteKey()
        XCTAssertNil(try store.loadKey())
    }

    func testFallsBackToEnglishWhenChineseDictionaryHasNoEntry() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DictionaryFallbackURLProtocol.self]
        let service = YandexDictionaryService(
            session: URLSession(configuration: configuration),
            keyStore: FixedDictionaryKeyStore()
        )

        let result = try await service.lookup(lemma: "отсюда")

        XCTAssertEqual(result.lemma, "отсюда")
        XCTAssertEqual(result.translations, ["hence", "from here"])
        XCTAssertEqual(result.translationLanguage, .english)
    }

    func testLookupUsesLanguageSpecificPrimaryPairsAndCacheKeys() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DictionaryLanguageURLProtocol.self]
        let service = YandexDictionaryService(
            session: URLSession(configuration: configuration),
            keyStore: FixedDictionaryKeyStore()
        )
        DictionaryRequestRecorder.shared.reset()

        let english = try await service.lookup(
            lemma: "bank",
            language: .english
        )
        let russian = try await service.lookup(
            lemma: "bank",
            language: .russian
        )

        XCTAssertEqual(english.translations, ["银行"])
        XCTAssertEqual(russian.translations, ["岸"])
        XCTAssertEqual(
            DictionaryRequestRecorder.shared.languagePairs,
            ["en-zh", "ru-zh"]
        )
    }

    func testEnglishLookupFallsBackWhenChinesePairIsRejected() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DictionaryRejectedPairURLProtocol.self]
        let service = YandexDictionaryService(
            session: URLSession(configuration: configuration),
            keyStore: FixedDictionaryKeyStore()
        )
        DictionaryRequestRecorder.shared.reset()

        let result = try await service.lookup(
            lemma: "cheaper",
            language: .english
        )

        XCTAssertEqual(result.translations, ["更便宜"])
        XCTAssertEqual(result.translationLanguage, .chinese)
        XCTAssertEqual(
            DictionaryRequestRecorder.shared.languagePairs,
            ["en-zh", "en-ru", "ru-zh", "en-ru", "ru-zh"]
        )
    }
}

private struct EmptyDictionaryKeyStore: DictionaryAPIKeyStoring {
    func loadKey() throws -> String? { nil }
    func saveKey(_ key: String) throws {}
    func deleteKey() throws {}
}

private struct FixedDictionaryKeyStore: DictionaryAPIKeyStoring {
    func loadKey() throws -> String? { "test-key" }
    func saveKey(_ key: String) throws {}
    func deleteKey() throws {}
}

private struct RuntimeDictionaryKeyStore: DictionaryAPIKeyStoring {
    let key: String

    func loadKey() throws -> String? { key }
    func saveKey(_ key: String) throws {}
    func deleteKey() throws {}
}

private final class DictionaryFallbackURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        let components = URLComponents(
            url: request.url!,
            resolvingAgainstBaseURL: false
        )
        let language = components?.queryItems?
            .first(where: { $0.name == "lang" })?.value
        let body: String
        if language == "ru-zh" {
            body = #"{"def":[]}"#
        } else {
            body = """
                {"def":[{"text":"отсюда","pos":"adverb","tr":[
                  {"text":"hence"},{"text":"from here"}
                ]}]}
                """
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class DictionaryRequestRecorder: @unchecked Sendable {
    static let shared = DictionaryRequestRecorder()

    private let lock = NSLock()
    private var storedPairs: [String] = []

    var languagePairs: [String] {
        lock.withLock { storedPairs }
    }

    func append(_ pair: String) {
        lock.withLock {
            storedPairs.append(pair)
        }
    }

    func reset() {
        lock.withLock {
            storedPairs.removeAll()
        }
    }
}

private final class DictionaryLanguageURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        let components = URLComponents(
            url: request.url!,
            resolvingAgainstBaseURL: false
        )
        let language = components?.queryItems?
            .first(where: { $0.name == "lang" })?.value ?? ""
        DictionaryRequestRecorder.shared.append(language)
        let translation = language == "en-zh" ? "银行" : "岸"
        let body = """
            {"def":[{"text":"bank","pos":"noun","tr":[
              {"text":"\(translation)"}
            ]}]}
            """
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class DictionaryRejectedPairURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        let components = URLComponents(
            url: request.url!,
            resolvingAgainstBaseURL: false
        )
        let language = components?.queryItems?
            .first(where: { $0.name == "lang" })?.value ?? ""
        DictionaryRequestRecorder.shared.append(language)
        let statusCode = language == "en-zh" ? 400 : 200
        let body: String
        switch language {
        case "en-zh":
            body = #"{"code":501,"message":"Unsupported direction"}"#
        case "en-ru":
            let text = components?.queryItems?
                .first(where: { $0.name == "text" })?.value
            body = text == "cheap"
                ? #"{"def":[{"text":"cheap","pos":"adjective","tr":[{"text":"дешёвый"}]}]}"#
                : #"{"def":[{"text":"cheaper","pos":"adjective","tr":[{"text":"выгоднее"}]}]}"#
        default:
            let text = components?.queryItems?
                .first(where: { $0.name == "text" })?.value
            body = text != "дешёвый"
                ? #"{"def":[]}"#
                : #"{"def":[{"text":"дешевле","pos":"adverb","tr":[{"text":"更便宜"}]}]}"#
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
