import XCTest
@testable import RussianCornerCore

final class StudyContentTests: XCTestCase {
    func testLegacyRussianLexemeMapsWithoutChangingReviewStatus() {
        let legacy = Lexeme(
            id: "ru.book",
            lemma: "забронировать",
            stressedForm: "заброни́ровать",
            speechText: "забронировать",
            partOfSpeech: "动词",
            glossZh: "预订",
            collocations: ["забронировать столик"],
            example: "Я хочу забронировать столик.",
            sentenceIDs: ["ru.book-table"],
            reviewStatus: .verified,
            aspect: "完成体",
            government: "забронировать что"
        )

        let mapped = legacy.studyContent

        XCTAssertEqual(mapped.language, .russian)
        XCTAssertEqual(mapped.displayForm, "заброни́ровать")
        XCTAssertEqual(mapped.reviewStatus, .verified)
        XCTAssertEqual(mapped.exampleSentenceIDs, ["ru.book-table"])
        XCTAssertEqual(mapped.collocations, ["забронировать столик"])
    }

    func testLegacyRussianSentenceUsesPracticeTextAsTarget() {
        let legacy = SentenceCard(
            id: "ru.book-table",
            promptZh: "我想预订一张双人桌。",
            cueRu: "В ресторане",
            practiceRu: "Я хочу забронировать столик на двоих.",
            stressedForm: "Я хочу́ заброни́ровать сто́лик на двои́х.",
            speechText: "Я хочу забронировать столик на двоих.",
            theme: "餐厅",
            lexemeIDs: ["ru.book"],
            sourcePath: "口语Диалоги/餐厅.md",
            sourceText: "Я хочу забронировать столик на двоих.",
            reviewStatus: .reviewed,
            provenanceType: .courseMaterial
        )

        let mapped = legacy.studyContent

        XCTAssertEqual(mapped.language, .russian)
        XCTAssertEqual(mapped.targetText, legacy.practiceRu)
        XCTAssertEqual(mapped.displayText, legacy.stressedForm)
        XCTAssertEqual(mapped.reviewStatus, .reviewed)
        XCTAssertEqual(mapped.sourcePath, legacy.sourcePath)
    }

    func testEnglishV2LexemeDecodesExtendedLearningFields() throws {
        let data = Data(
            """
            {
              "id": "en.about-to",
              "language": "english",
              "lemma": "about to",
              "displayForm": "about to",
              "speechText": "about to",
              "phonetic": "/əˈbaʊt tə/",
              "partOfSpeech": "phrase",
              "glossZh": "正要；即将",
              "inflections": [],
              "collocations": ["be just about to do something"],
              "phrasalVerbs": ["be about to"],
              "wordFamily": [],
              "morphologyNotes": ["be about to + 动词原形"],
              "memoryNotes": [
                {"kind": "mnemonic", "text": "把它作为一个整体句块记忆"}
              ],
              "exampleSentenceIDs": ["en.sentence.about-to-call"],
              "reviewStatus": "reviewed",
              "provenanceType": "derived",
              "sourcePath": "bundled/english/daily-plans",
              "qualityFlags": []
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(StudyLexeme.self, from: data)

        XCTAssertEqual(decoded.language, .english)
        XCTAssertEqual(decoded.phonetic, "/əˈbaʊt tə/")
        XCTAssertEqual(decoded.phrasalVerbs, ["be about to"])
        XCTAssertEqual(decoded.memoryNotes.first?.kind, .mnemonic)
    }

    func testLanguageCatalogFiltersDraftsAndValidatesReferences() {
        let reviewedLexeme = makeLexeme(
            id: "en.about-to",
            status: .reviewed
        )
        let draftLexeme = makeLexeme(
            id: "en.draft",
            status: .draft
        )
        let reviewedSentence = makeSentence(
            id: "en.call",
            lexemeIDs: [reviewedLexeme.id],
            status: .verified
        )
        let draftSentence = makeSentence(
            id: "en.draft-sentence",
            lexemeIDs: [draftLexeme.id],
            status: .draft
        )

        let catalog = LanguageContentCatalog(
            lexemes: [reviewedLexeme, draftLexeme],
            sentences: [reviewedSentence, draftSentence]
        )

        XCTAssertEqual(catalog.lexemes.map(\.id), [reviewedLexeme.id])
        XCTAssertEqual(catalog.sentences.map(\.id), [reviewedSentence.id])
        XCTAssertTrue(catalog.validate().isEmpty)
    }

    func testLanguageCatalogRejectsMissingSentenceReference() {
        let sentence = makeSentence(
            id: "en.call",
            lexemeIDs: ["en.missing"],
            status: .reviewed
        )

        let issues = LanguageContentCatalog(
            lexemes: [],
            sentences: [sentence]
        ).validate()

        XCTAssertTrue(
            issues.contains {
                $0.itemID == sentence.id
                    && $0.message.contains("en.missing")
            }
        )
    }

    private func makeLexeme(
        id: String,
        status: ReviewStatus
    ) -> StudyLexeme {
        StudyLexeme(
            id: id,
            language: .english,
            lemma: "about to",
            displayForm: "about to",
            speechText: "about to",
            phonetic: "/əˈbaʊt tə/",
            partOfSpeech: "phrase",
            glossZh: "正要；即将",
            inflections: [],
            collocations: ["be just about to do something"],
            phrasalVerbs: [],
            wordFamily: [],
            morphologyNotes: ["be about to + 动词原形"],
            memoryNotes: [],
            exampleSentenceIDs: ["en.call"],
            reviewStatus: status,
            provenanceType: .derived,
            sourcePath: "bundled/english/daily-plans"
        )
    }

    private func makeSentence(
        id: String,
        lexemeIDs: [String],
        status: ReviewStatus
    ) -> StudySentence {
        StudySentence(
            id: id,
            language: .english,
            promptZh: "我本来正想给你打电话。",
            cueText: "You were going to call a friend right now.",
            targetText: "I was just about to call you.",
            displayText: "I was just about to call you.",
            speechText: "I was just about to call you.",
            theme: "Changing plans",
            lexemeIDs: lexemeIDs,
            dialogueAct: "informing",
            register: .neutral,
            speakerRole: "friend",
            expectedReplies: ["Really? What's up?"],
            variants: [],
            reviewStatus: status,
            provenanceType: .derived,
            sourcePath: "bundled/english/changing-plans"
        )
    }
}
