import Foundation
import RussianCornerCore
import XCTest

@testable import RussianCornerUI

final class InteractiveRussianTextTests: XCTestCase {
    func testBuilderLinksEveryWordAndPreservesPunctuation() throws {
        let analyses = [
            analysis(index: 0, surface: "Как"),
            analysis(index: 1, surface: "дела"),
        ]

        let value = InteractiveRussianTextBuilder.make(
            text: "Как дела?",
            analyses: analyses,
            selectedTokenIndex: 1
        )

        XCTAssertEqual(String(value.characters), "Как дела?")
        let links = value.runs.compactMap(\.link)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(
            InteractiveRussianTextBuilder.tokenIndex(from: links[0]),
            0
        )
        XCTAssertEqual(
            InteractiveRussianTextBuilder.tokenIndex(from: links[1]),
            1
        )
        XCTAssertNil(
            InteractiveRussianTextBuilder.tokenIndex(
                from: URL(string: "https://example.com")!
            )
        )
    }

    func testBuilderLinksWordsEvenWhenAnalysesAreEmpty() {
        let value = InteractiveRussianTextBuilder.make(
            text: "Новый разговор.",
            analyses: [],
            selectedTokenIndex: nil
        )

        XCTAssertEqual(value.runs.compactMap(\.link).count, 2)
    }

    func testWiktionaryURLUsesHTTPSAndEncodesLemma() throws {
        let url = try XCTUnwrap(
            OnlineDictionary.wiktionaryURL(for: "чувствовать себя")
        )

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "ru.wiktionary.org")
        XCTAssertTrue(
            url.absoluteString.contains(
                "%D1%87%D1%83%D0%B2%D1%81%D1%82%D0%B2%D0%BE%D0%B2%D0%B0%D1%82%D1%8C"
            )
        )
    }

    func testEveryBundledTrialSentenceRendersEveryWordAsALink() throws {
        let resourceDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(
                "RussianCornerCore",
                isDirectory: true
            )
            .appendingPathComponent("Resources", isDirectory: true)
        let catalog = try ContentCatalog(
            resourceDirectory: resourceDirectory
        )

        for sentence in catalog.practiceSentences {
            let answer = sentence.stressedForm ?? sentence.practiceRu
            let value = InteractiveRussianTextBuilder.make(
                text: answer,
                analyses: catalog.wordAnalyses(for: sentence.id),
                selectedTokenIndex: nil
            )

            XCTAssertEqual(
                value.runs.compactMap(\.link).count,
                RussianWordTokenizer.words(in: answer).count,
                sentence.id
            )
        }
    }

    private func analysis(
        index: Int,
        surface: String
    ) -> ResolvedWordAnalysis {
        ResolvedWordAnalysis(
            cardID: "trial",
            tokenIndex: index,
            surfaceText: surface,
            stressedForm: surface,
            lemma: surface.lowercased(),
            glossZh: "测试",
            partOfSpeech: "test",
            morphology: "测试词形",
            usageNote: "测试用法",
            reviewStatus: .reviewed
        )
    }
}
