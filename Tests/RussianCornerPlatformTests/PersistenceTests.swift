import Foundation
import XCTest
@testable import RussianCornerCore
@testable import RussianCornerPlatform

@MainActor
final class LanguagePersistenceIsolationTests: XCTestCase {
    func testLanguageStoresUseExistingRussianAndNewEnglishNames() throws {
        let support = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: support) }

        let russian = ProgressRepository(
            container: try ProgressRepository.makeContainer(
                language: .russian,
                applicationSupportDirectory: support
            )
        )
        let english = ProgressRepository(
            container: try ProgressRepository.makeContainer(
                language: .english,
                applicationSupportDirectory: support
            )
        )

        try russian.save(
            reviewEvent: makeEvent(id: "same", grade: .easy)
        )
        try english.save(
            reviewEvent: makeEvent(id: "same", grade: .hard)
        )

        XCTAssertEqual(try russian.reviewEvents().map(\.grade), [.easy])
        XCTAssertEqual(try english.reviewEvents().map(\.grade), [.hard])
        let files = try FileManager.default.contentsOfDirectory(
            atPath: support.appendingPathComponent(
                "com.openclaw.russiancorner"
            ).path
        )
        XCTAssertTrue(files.contains("RussianCorner.store"))
        XCTAssertTrue(files.contains("EnglishCorner.store"))
    }

    func testRussianLegacyStoreReopensWithoutLanguageMigration() throws {
        let support = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: support) }
        let event = makeEvent(id: "legacy-russian", grade: .easy)

        do {
            let repository = ProgressRepository(
                container: try ProgressRepository.makeContainer(
                    applicationSupportDirectory: support
                )
            )
            try repository.save(reviewEvent: event)
        }

        let reopened = ProgressRepository(
            container: try ProgressRepository.makeContainer(
                language: .russian,
                applicationSupportDirectory: support
            )
        )
        XCTAssertEqual(try reopened.reviewEvents(), [event])
    }

    func testTrialStoresAreIsolatedByLanguage() throws {
        let support = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: support) }

        _ = try TrialRepository.makeContainer(
            language: .russian,
            applicationSupportDirectory: support
        )
        _ = try TrialRepository.makeContainer(
            language: .english,
            applicationSupportDirectory: support
        )

        let files = try FileManager.default.contentsOfDirectory(
            atPath: support.appendingPathComponent(
                "com.openclaw.russiancorner"
            ).path
        )
        XCTAssertTrue(files.contains("RussianCornerTrial.store"))
        XCTAssertTrue(files.contains("EnglishCornerTrial.store"))
    }

    private func makeEvent(
        id: String,
        grade: ReviewGrade
    ) -> ReviewEvent {
        ReviewEvent(
            itemType: .sentence,
            itemId: id,
            grade: grade,
            responseTimeMs: 1_200,
            practiceMode: .speaking,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
