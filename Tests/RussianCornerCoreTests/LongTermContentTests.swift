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
