import XCTest
@testable import RussianCornerCore

final class StudyLanguageTests: XCTestCase {
    func testEnglishAndRussianProfilesUseIndependentNamespaces() {
        XCTAssertEqual(StudyLanguage.english.storageNamespace, "english")
        XCTAssertEqual(StudyLanguage.russian.storageNamespace, "russian")
        XCTAssertNotEqual(
            StudyLanguage.english.storageNamespace,
            StudyLanguage.russian.storageNamespace
        )
    }

    func testDefaultVoicePreferences() {
        XCTAssertEqual(StudyLanguage.english.preferredVoiceLanguages.first, "en-US")
        XCTAssertEqual(StudyLanguage.russian.preferredVoiceLanguages.first, "ru-RU")
    }
}
