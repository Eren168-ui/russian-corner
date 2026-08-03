import Foundation
import RussianCornerCore
import XCTest

final class LongTermContentTests: XCTestCase {
    func testLongTermManifestCoversAllThirtyTwoTopics() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: resourceDirectory
        )

        XCTAssertEqual(catalog.topics.count, 32)
        XCTAssertEqual(
            Set(catalog.topics.map(\.number)),
            Set(1...32)
        )
    }

    func testTrialSliceNoLongerControlsPracticeContent() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: resourceDirectory
        )

        XCTAssertEqual(
            catalog.practiceSentences,
            catalog.longTermSentences
        )
        XCTAssertGreaterThan(catalog.practiceSentences.count, 35)
        XCTAssertTrue(
            catalog.longTermManifest.contentGateClosed
        )
    }

    func testClosedManifestMeetsLongTermContentGate() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: resourceDirectory
        )

        XCTAssertTrue(
            catalog.longTermManifest.contentGateClosed
        )
        XCTAssertGreaterThanOrEqual(
            catalog.longTermSentences.count,
            200
        )
        for topic in catalog.topics {
            XCTAssertGreaterThanOrEqual(
                catalog.longTermSentences.filter {
                    $0.topicID == topic.id
                }.count,
                4,
                topic.id
            )
        }
    }

    func testUniversityInteractionExpressionsAreInTheLongTermQueue() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: resourceDirectory
        )
        let campus = catalog.longTermSentences.filter {
            $0.id.hasPrefix("longterm-campus-")
        }

        XCTAssertEqual(campus.count, 17)
        XCTAssertTrue(
            campus.allSatisfy {
                    ["topic-21", "topic-22", "topic-24"].contains(
                        $0.topicID ?? ""
                    )
                    && $0.reviewStatus == .reviewed
                    && $0.practiceRu == $0.speechText
                    && $0.stressedForm?.isEmpty == false
                    && $0.expectedReply?.isEmpty == false
                    && $0.sourcePath.hasPrefix("具体场景对话/")
            }
        )
        XCTAssertTrue(
            campus.contains {
                $0.theme == "classroom-question"
                    && $0.dialogueAct == "clarification"
            }
        )
        XCTAssertTrue(
            campus.contains {
                $0.theme == "classroom-answer"
                    && $0.dialogueAct == "selfCorrection"
            }
        )
    }

    private var resourceDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(
                "RussianCornerCore",
                isDirectory: true
            )
            .appendingPathComponent("Resources", isDirectory: true)
    }
}
