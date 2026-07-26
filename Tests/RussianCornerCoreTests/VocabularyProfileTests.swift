import XCTest
@testable import RussianCornerCore

final class VocabularyProfileTests: XCTestCase {
    func testA2ToB1ProfileSuppressesAbsoluteBeginnerLemmas() {
        let profile = LearnerVocabularyProfile.a2ToB1Bridge

        for lemma in [
            "привет",
            "здравствуйте",
            "спасибо",
            "понимать",
            "знать",
            "семья",
            "вода",
        ] {
            XCTAssertFalse(
                profile.shouldServeAsStandalone(lemma: lemma),
                "\(lemma) should not consume a new-word slot"
            )
        }
    }

    func testA2ToB1ProfileKeepsHighValueBridgeLemmas() {
        let profile = LearnerVocabularyProfile.a2ToB1Bridge

        for lemma in [
            "успевать",
            "задерживаться",
            "связаться",
            "соглашаться",
            "местонахождение",
            "поддерживать",
        ] {
            XCTAssertTrue(
                profile.shouldServeAsStandalone(lemma: lemma),
                "\(lemma) should remain in the A2-to-B1 queue"
            )
        }
    }

    func testReviewedBundleStillHasAtLeastTwoHundredFiftyEligibleWords() throws {
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
        let profile = LearnerVocabularyProfile.a2ToB1Bridge

        let eligible = catalog.lexemes.filter {
            profile.shouldServeAsStandalone(lexeme: $0)
        }

        XCTAssertGreaterThanOrEqual(eligible.count, 250)
    }
}
