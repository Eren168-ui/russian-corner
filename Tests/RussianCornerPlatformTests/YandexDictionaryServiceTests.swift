import Foundation
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
        XCTAssertEqual(result.translationLanguage, .chinese)
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
