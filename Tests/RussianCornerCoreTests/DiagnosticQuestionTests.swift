import XCTest

@testable import RussianCornerCore

final class DiagnosticQuestionTests: XCTestCase {
    func testRecognitionQuestionHasOneCorrectUniqueOptionAndIsDeterministic() {
        let lexemes = makeLexemes()
        let builder = DiagnosticQuestionBuilder(seed: 42)

        let first = builder.recognitionQuestion(
            for: lexemes[0],
            pool: lexemes
        )
        let second = builder.recognitionQuestion(
            for: lexemes[0],
            pool: lexemes
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.correctOption.text, "学习")
        XCTAssertEqual(Set(first.options.map(\.text)).count, 4)
        XCTAssertEqual(
            first.options.filter { first.isCorrect($0.id) }.count,
            1
        )
    }

    func testListeningQuestionUsesChineseIntentAndUniqueAlternatives() {
        let sentences = makeSentences()
        let question = DiagnosticQuestionBuilder(seed: 7)
            .listeningQuestion(for: sentences[0], pool: sentences)

        XCTAssertEqual(question.correctOption.text, "我在学习。")
        XCTAssertEqual(Set(question.options.map(\.text)).count, 4)
        XCTAssertEqual(question.itemKind, .sentence)
    }

    func testCollocationQuestionUsesReviewedCollocationAsCorrectAnswer() {
        let lexemes = makeLexemes()
        let question = DiagnosticQuestionBuilder(seed: 99)
            .collocationQuestion(for: lexemes[0], pool: lexemes)

        XCTAssertEqual(question.correctOption.text, "учиться в школе")
        XCTAssertEqual(Set(question.options.map(\.text)).count, 4)
        XCTAssertEqual(question.itemKind, .lexeme)
    }

    func testProductionOutcomesMapToNormalReviewGrades() {
        XCTAssertEqual(
            DiagnosticProductionOutcome.completeFast.reviewGrade,
            .easy
        )
        XCTAssertEqual(
            DiagnosticProductionOutcome.partial.reviewGrade,
            .hard
        )
        XCTAssertEqual(
            DiagnosticProductionOutcome.recalledAfterReveal.reviewGrade,
            .again
        )
        XCTAssertEqual(
            DiagnosticProductionOutcome.unknown.reviewGrade,
            .again
        )
    }

    private func makeLexemes() -> [Lexeme] {
        [
            ("учиться", "учи́ться", "学习", "учиться в школе"),
            ("работать", "рабо́тать", "工作", "работать дома"),
            ("покупать", "покупа́ть", "购买", "покупать продукты"),
            ("встречаться", "встреча́ться", "见面", "встречаться с другом"),
        ].enumerated().map { index, value in
            Lexeme(
                id: "lexeme-\(index)",
                lemma: value.0,
                stressedForm: value.1,
                speechText: value.0,
                partOfSpeech: "verb",
                glossZh: value.2,
                collocations: [value.3],
                example: value.3,
                sentenceIDs: ["sentence-\(index)"],
                reviewStatus: .reviewed
            )
        }
    }

    private func makeSentences() -> [SentenceCard] {
        ["我在学习。", "我在工作。", "我要买东西。", "我们明天见。"]
            .enumerated()
            .map { index, prompt in
                SentenceCard(
                    id: "sentence-\(index)",
                    promptZh: prompt,
                    cueRu: "",
                    practiceRu: "Фраза \(index)",
                    speechText: "Фраза \(index)",
                    theme: "日常",
                    lexemeIDs: ["lexeme-\(index)"],
                    sourcePath: "fixture.md",
                    sourceText: "fixture",
                    reviewStatus: .reviewed
                )
            }
    }
}
