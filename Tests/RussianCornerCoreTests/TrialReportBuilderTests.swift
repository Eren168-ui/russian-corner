import Foundation
import XCTest
@testable import RussianCornerCore

final class TrialReportBuilderTests: XCTestCase {
    func testAgainIsFailureAndHardEasyAreSuccess() {
        XCTAssertFalse(TrialGradeOutcome(grade: .again).isSuccess)
        XCTAssertTrue(TrialGradeOutcome(grade: .hard).isSuccess)
        XCTAssertTrue(TrialGradeOutcome(grade: .easy).isSuccess)
    }

    func testTrialInteractionRoundTripsWithoutLocalPaths() throws {
        let value = TrialInteraction(
            sessionID: UUID(),
            itemType: .lexeme,
            itemID: "lex-001",
            kind: .grade,
            direction: .production,
            promptLevel: .chinese,
            grade: .hard,
            responseTimeMs: 2_900,
            usedSpeech: true,
            openedDetails: false,
            practiceMode: .speaking,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(
            TrialInteraction.self,
            from: data
        )

        XCTAssertEqual(decoded, value)
        let serialized = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(serialized.contains("file://"))
        XCTAssertFalse(serialized.contains("sourcePath"))
    }
}
