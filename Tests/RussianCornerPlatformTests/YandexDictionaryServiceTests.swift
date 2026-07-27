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
        guard ProcessInfo.processInfo.environment[
            "RUN_YANDEX_DICTIONARY_LIVE_TEST"
        ] == "1" else {
            throw XCTSkip("Live dictionary test is opt-in")
        }

        let result = try await YandexDictionaryService().lookup(
            lemma: "заплатить"
        )

        XCTAssertFalse(result.translations.isEmpty)
        XCTAssertEqual(result.lemma, "заплатить")
    }
}

private struct EmptyDictionaryKeyStore: DictionaryAPIKeyStoring {
    func loadKey() throws -> String? { nil }
    func saveKey(_ key: String) throws {}
    func deleteKey() throws {}
}
