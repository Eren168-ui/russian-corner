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
}
