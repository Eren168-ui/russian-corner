import RussianCornerCore
import XCTest

final class UniversalWordResolutionTests: XCTestCase {
    func testUnknownSentenceStillResolvesEveryRussianToken() {
        let sentence = SentenceCard(
            id: "future-sentence",
            promptZh: "说明计划改变了。",
            cueRu: "",
            practiceRu: "Наши планы неожиданно изменились.",
            speechText: "Наши планы неожиданно изменились.",
            theme: "future",
            lexemeIDs: [],
            sourcePath: "future/source.md",
            sourceText: "Наши планы неожиданно изменились.",
            reviewStatus: .reviewed
        )
        let catalog = ContentCatalog(
            lexemes: [],
            sentences: [sentence]
        )

        let analyses = catalog.wordAnalyses(for: sentence)

        XCTAssertEqual(analyses.count, 4)
        XCTAssertEqual(
            analyses.map(\.surfaceText),
            ["Наши", "планы", "неожиданно", "изменились"]
        )
        XCTAssertTrue(
            analyses.allSatisfy { $0.source == .unavailable }
        )
    }

    func testUnknownInflectedWordUsesBundledLemmaMap() {
        let sentence = SentenceCard(
            id: "inflected-noun",
            promptZh: "从这里一览无余。",
            cueRu: "",
            practiceRu: "Всё как на ладони.",
            speechText: "Всё как на ладони.",
            theme: "city",
            lexemeIDs: [],
            sourcePath: "source.md",
            sourceText: "Всё как на ладони.",
            reviewStatus: .reviewed
        )
        let catalog = ContentCatalog(
            lexemes: [],
            sentences: [sentence],
            surfaceLemmas: ["ладони": "ладонь"]
        )

        let analysis = catalog.wordAnalyses(for: sentence)[3]

        XCTAssertEqual(analysis.surfaceText, "ладони")
        XCTAssertEqual(analysis.lemma, "ладонь")
        XCTAssertEqual(analysis.source, .unavailable)
    }
}
