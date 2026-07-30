import Foundation
import XCTest
@testable import RussianCornerCore
@testable import RussianCornerPlatform
@testable import RussianCornerUI

@MainActor
final class LanguageRuntimeTests: XCTestCase {
    func testSwitchingLanguagesPreservesIndependentPracticeIndexes() throws {
        let defaults = isolatedDefaults()
        let russian = try makeRuntime(
            language: .russian,
            idPrefix: "ru"
        )
        let english = try makeRuntime(
            language: .english,
            idPrefix: "en"
        )
        let runtime = LanguageCornerRuntime(
            defaults: defaults,
            runtimes: [
                .russian: russian,
                .english: english,
            ]
        )

        russian.practice?.next()
        runtime.switchLanguage(to: .english)
        english.practice?.next()
        english.practice?.next()
        runtime.switchLanguage(to: .russian)

        XCTAssertEqual(runtime.activeLanguage, .russian)
        XCTAssertEqual(runtime.activeRuntime?.practice?.currentIndex, 1)
        runtime.switchLanguage(to: .english)
        XCTAssertEqual(runtime.activeRuntime?.practice?.currentIndex, 2)
    }

    func testActiveLanguagePersistsAndMissingEnglishLeavesRussianUsable()
        throws
    {
        let defaults = isolatedDefaults()
        let russian = try makeRuntime(
            language: .russian,
            idPrefix: "ru"
        )
        var runtime = LanguageCornerRuntime(
            defaults: defaults,
            runtimes: [.russian: russian]
        )

        runtime.switchLanguage(to: .english)
        XCTAssertEqual(runtime.activeLanguage, .russian)
        XCTAssertNotNil(runtime.activeRuntime?.practice)

        let english = try makeRuntime(
            language: .english,
            idPrefix: "en"
        )
        runtime = LanguageCornerRuntime(
            defaults: defaults,
            runtimes: [
                .russian: russian,
                .english: english,
            ]
        )
        runtime.switchLanguage(to: .english)
        XCTAssertEqual(runtime.activeLanguage, .english)

        let restored = LanguageCornerRuntime(
            defaults: defaults,
            runtimes: [
                .russian: russian,
                .english: english,
            ]
        )
        XCTAssertEqual(restored.activeLanguage, .english)
    }

    private func makeRuntime(
        language: StudyLanguage,
        idPrefix: String
    ) throws -> AppRuntime {
        let lexemes = (0..<4).map { index in
            Lexeme(
                id: "\(idPrefix).lexeme.\(index)",
                lemma: "\(idPrefix)-word-\(index)",
                stressedForm: "\(idPrefix)-word-\(index)",
                speechText: "\(idPrefix)-word-\(index)",
                partOfSpeech: "phrase",
                glossZh: "测试词条 \(index)",
                collocations: ["\(idPrefix) phrase \(index)"],
                example: "\(idPrefix) example \(index)",
                sentenceIDs: ["\(idPrefix).sentence.\(index)"],
                reviewStatus: .reviewed
            )
        }
        let sentences = (0..<4).map { index in
            SentenceCard(
                id: "\(idPrefix).sentence.\(index)",
                promptZh: "测试提示 \(index)",
                cueRu: "\(idPrefix) cue \(index)",
                practiceRu: "\(idPrefix) answer \(index)",
                speechText: "\(idPrefix) answer \(index)",
                theme: "test",
                lexemeIDs: ["\(idPrefix).lexeme.\(index)"],
                sourcePath: "fixture/\(idPrefix)",
                sourceText: "\(idPrefix) answer \(index)",
                reviewStatus: .reviewed
            )
        }
        return AppRuntime(
            defaults: isolatedDefaults(),
            language: language,
            catalog: ContentCatalog(
                lexemes: lexemes,
                sentences: sentences
            ),
            repository: ProgressRepository(
                container: try ProgressRepository.makeContainer(
                    inMemory: true,
                    language: language
                )
            ),
            enableSystemReminders: false
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "LanguageRuntimeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
