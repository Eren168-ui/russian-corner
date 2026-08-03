import Foundation
import XCTest
@testable import RussianCornerCore

final class EnglishContentValidationTests: XCTestCase {
    func testBundledEnglishCorpusMeetsLongTermQualityGate() throws {
        let bundle = try EnglishContentBundle(
            resourceDirectory: resourceDirectory
        )

        XCTAssertEqual(bundle.topics.count, 24)
        XCTAssertEqual(bundle.lessons.count, 24)
        XCTAssertEqual(bundle.catalog.sentences.count, 240)
        XCTAssertEqual(bundle.catalog.lexemes.count, 480)
        XCTAssertEqual(
            Array(bundle.topics.prefix(4).map(\.titleZh)),
            [
                "校园遇见老师",
                "请教老师与约时间",
                "课堂提问与澄清",
                "课堂回答与讨论",
            ]
        )
        XCTAssertEqual(
            Array(bundle.legacyCatalog.topics.prefix(4).map(\.titleZh)),
            [
                "校园遇见老师",
                "请教老师与约时间",
                "课堂提问与澄清",
                "课堂回答与讨论",
            ]
        )
        XCTAssertTrue(bundle.catalog.validate().isEmpty)
        XCTAssertTrue(
            bundle.catalog.lexemes.allSatisfy {
                [.reviewed, .verified].contains($0.reviewStatus)
                    && (
                        !$0.collocations.isEmpty
                            || !$0.exampleSentenceIDs.isEmpty
                    )
            }
        )
        XCTAssertTrue(
            bundle.catalog.sentences.allSatisfy {
                [.reviewed, .verified].contains($0.reviewStatus)
                    && (!$0.expectedReplies.isEmpty || !$0.variants.isEmpty)
                    && $0.language == .english
                    && isCleanEnglishSpeech($0.speechText)
                    && !isUnsafeSource($0.sourcePath)
            }
        )
    }

    func testEveryTopicAndLessonReferenceExistingSentences() throws {
        let bundle = try EnglishContentBundle(
            resourceDirectory: resourceDirectory
        )
        let sentenceIDs = Set(bundle.catalog.sentences.map(\.id))

        XCTAssertTrue(
            bundle.topics.allSatisfy {
                !$0.sentenceIDs.isEmpty
                    && Set($0.sentenceIDs).isSubset(of: sentenceIDs)
            }
        )
        XCTAssertTrue(
            bundle.lessons.allSatisfy {
                !$0.sentenceIDs.isEmpty
                    && Set($0.sentenceIDs).isSubset(of: sentenceIDs)
            }
        )
    }

    func testTopicSelectorStartsEnglishCourseWithCampusThemes() throws {
        let bundle = try EnglishContentBundle(
            resourceDirectory: resourceDirectory
        )
        let topics = bundle.legacyCatalog.topics
        let selector = TopicSelector()

        let selectedTitles = (0..<4).compactMap { dayIndex in
            selector.select(
                dayIndex: dayIndex,
                topics: topics,
                recentTopicIDs: [],
                weaknessByTopic: [:],
                manualTopicID: nil
            )?.titleZh
        }

        XCTAssertEqual(
            selectedTitles,
            [
                "校园遇见老师",
                "请教老师与约时间",
                "课堂提问与澄清",
                "课堂回答与讨论",
            ]
        )
    }

    func testCorpusAvoidsElementaryGreetingOnlyCards() throws {
        let bundle = try EnglishContentBundle(
            resourceDirectory: resourceDirectory
        )
        let elementary = Set([
            "hello",
            "hi",
            "good morning",
            "how are you",
            "thank you",
        ])

        XCTAssertFalse(
            bundle.catalog.sentences.contains {
                elementary.contains(
                    $0.targetText
                        .lowercased()
                        .trimmingCharacters(
                            in: .punctuationCharacters
                                .union(.whitespacesAndNewlines)
                        )
                )
            }
        )
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

    private func isCleanEnglishSpeech(_ text: String) -> Bool {
        !text.isEmpty
            && text.range(
                of: #"[A-Za-z]"#,
                options: .regularExpression
            ) != nil
            && text.range(
                of: #"[\u{3400}-\u{9FFF}\[\]*]"#,
                options: .regularExpression
            ) == nil
    }

    private func isUnsafeSource(_ path: String) -> Bool {
        let lowercased = path.lowercased()
        return lowercased.contains("conflict")
            || lowercased.contains("ai整理")
            || lowercased.contains("报告")
    }
}
