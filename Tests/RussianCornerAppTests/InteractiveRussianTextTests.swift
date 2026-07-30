import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

final class InteractiveRussianTextTests: XCTestCase {
    func testTargetBuilderLinksEveryEnglishWordAndPreservesPunctuation() {
        let value = InteractiveTargetTextBuilder.make(
            text: "I'm ready—are you?",
            language: .english,
            selectedTokenIndex: 1
        )

        XCTAssertEqual(String(value.characters), "I'm ready—are you?")
        let links = value.runs.compactMap(\.link)
        XCTAssertEqual(links.count, 4)
        XCTAssertEqual(
            InteractiveTargetTextBuilder.tokenIndex(from: links[0]),
            0
        )
        XCTAssertEqual(
            InteractiveTargetTextBuilder.tokenIndex(from: links[3]),
            3
        )
    }

    func testDetailTypographyIsReadableButSmallerThanMainAnswer() {
        XCTAssertEqual(PracticeDetailTypography.bodySize, 14)
        XCTAssertEqual(PracticeDetailTypography.relatedRussianSize, 16)
        XCTAssertEqual(PracticeDetailTypography.supportingSize, 12)
        XCTAssertEqual(PracticeDetailTypography.labelSize, 10)
        XCTAssertLessThan(
            PracticeDetailTypography.relatedRussianSize,
            20
        )
    }

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

    func testOnlineResultReplacesUnavailablePlaceholderSummary() {
        let word = ResolvedWordAnalysis(
            cardID: "city",
            tokenIndex: 0,
            surfaceText: "ладони",
            stressedForm: "ладо́ни",
            lemma: "ладонь",
            glossZh: "本地暂无审核释义",
            partOfSpeech: "待查询",
            morphology: "当前词形：ладони",
            usageNote: "可查询在线词典",
            reviewStatus: .draft,
            source: .unavailable
        )
        let result = OnlineDictionaryResult(
            lemma: "ладонь",
            partOfSpeech: "noun",
            translations: ["手", "手掌", "手心"],
            synonyms: [],
            examples: []
        )

        let summary = WordDetailSummaryBuilder.make(
            word: word,
            lookupState: .result(result)
        )

        XCTAssertEqual(summary.qualityLabel, "在线词典结果 · 未人工审核")
        XCTAssertEqual(summary.glossZh, "手；手掌；手心")
        XCTAssertEqual(summary.lemma, "ладонь")
        XCTAssertEqual(summary.partOfSpeech, "noun")
        XCTAssertFalse(summary.glossZh.contains("暂无"))
        XCTAssertFalse(summary.partOfSpeech.contains("待查询"))
    }

    func testUnavailableWordHidesInternalLookupUsageNote() {
        let word = ResolvedWordAnalysis(
            cardID: "city",
            tokenIndex: 0,
            surfaceText: "выглядит",
            stressedForm: "выглядит",
            lemma: "выглядеть",
            glossZh: "本地暂无审核释义",
            partOfSpeech: "待查询",
            morphology: "当前词形：выглядит",
            usageNote: "可查询在线词典；在线结果不会自动标记为已审核",
            reviewStatus: .draft,
            source: .unavailable
        )

        XCTAssertNil(
            WordDetailSummaryBuilder.visibleUsageNote(for: word)
        )
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
