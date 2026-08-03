import Foundation
import XCTest

@testable import RussianCornerCore

final class EnglishNaturalCorpusTests: XCTestCase {
    func testEnglishCorpusUsesNaturalDailyExpressions() throws {
        let bundle = try EnglishContentBundle(resourceDirectory: resourceDirectory)
        let texts = bundle.catalog.sentences.map { $0.targetText }
        let normalized = texts.map { $0.lowercased() }

        XCTAssertTrue(normalized.contains("no way!"))
        XCTAssertTrue(normalized.contains("i know, right?"))
        XCTAssertTrue(normalized.contains("want to grab a coffee?"))
        XCTAssertFalse(normalized.contains("if anything changes with the return policy, just give me a heads-up."))
        XCTAssertEqual(Set(texts).count, texts.count)
        let conversationalMarkers = [
            "no way",
            "i know, right",
            "want to",
            "let's",
            "i'm",
            "i've",
            "i'll",
            "can i",
            "could you",
            "do you",
            "i think",
            "no worries",
            "my bad",
            "what have",
            "sounds",
        ]
        XCTAssertGreaterThanOrEqual(
            normalized.filter { text in
                conversationalMarkers.contains { text.contains($0) }
            }.count,
            40
        )
    }

    func testEnglishTopicsPrioritizeEverydayScenes() throws {
        let bundle = try EnglishContentBundle(resourceDirectory: resourceDirectory)
        let titles = Set(bundle.topics.map { $0.titleZh })

        XCTAssertTrue(titles.contains("朋友与近况"))
        XCTAssertTrue(titles.contains("吃饭与咖啡"))
        XCTAssertTrue(titles.contains("电话与消息"))
        XCTAssertTrue(titles.contains("购物与退换"))
    }

    private var resourceDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("RussianCornerCore", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
    }
}
