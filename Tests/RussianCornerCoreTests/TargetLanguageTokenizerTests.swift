import XCTest
@testable import RussianCornerCore

final class TargetLanguageTokenizerTests: XCTestCase {
    func testEnglishKeepsInternalApostrophesAndHyphens() {
        XCTAssertEqual(
            TargetLanguageTokenizer.words(
                in: "I'm about to check-in.",
                language: .english
            ),
            ["I'm", "about", "to", "check-in"]
        )
    }

    func testRussianTokenizationRemainsCompatible() {
        let text = "Я хочу́ заброни́ровать столик."

        XCTAssertEqual(
            TargetLanguageTokenizer.words(
                in: text,
                language: .russian
            ),
            RussianWordTokenizer.words(in: text)
        )
        XCTAssertEqual(
            TargetLanguageTokenizer.words(
                in: text,
                language: .russian
            ),
            ["Я", "хочу́", "заброни́ровать", "столик"]
        )
    }

    func testSegmentsAssignIndexesOnlyToWords() {
        let segments = TargetLanguageTokenizer.segments(
            in: "Well, I'm ready!",
            language: .english
        )

        XCTAssertEqual(
            segments.compactMap(\.tokenIndex),
            [0, 1, 2]
        )
        XCTAssertEqual(
            segments.filter { $0.tokenIndex != nil }.map(\.text),
            ["Well", "I'm", "ready"]
        )
        XCTAssertEqual(segments.map(\.text).joined(), "Well, I'm ready!")
    }
}
