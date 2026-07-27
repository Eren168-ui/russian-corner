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
        XCTAssertEqual(catalog.practiceSentences.count, 35)
        XCTAssertFalse(
            catalog.longTermManifest.contentGateClosed
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
