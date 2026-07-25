import XCTest
@testable import RussianCornerCore

final class ContentCatalogTests: XCTestCase {
    func testBundleCatalogMeetsReviewedDailyContentContract() throws {
        let catalog = try ContentCatalog()

        XCTAssertGreaterThanOrEqual(catalog.lexemes.count, 350)
        XCTAssertTrue((60...80).contains(catalog.sentences.count))
        XCTAssertTrue(
            catalog.lexemes.allSatisfy {
                $0.reviewStatus == .reviewed || $0.reviewStatus == .verified
            }
        )
        XCTAssertTrue(
            catalog.sentences.allSatisfy {
                $0.reviewStatus == .reviewed || $0.reviewStatus == .verified
            }
        )
    }

    func testDraftContentIsNeverServed() {
        let reviewedSentence = sentence(
            id: "sentence-reviewed",
            lexemeIDs: ["lexeme-reviewed"],
            status: .reviewed
        )
        let draftSentence = sentence(
            id: "sentence-draft",
            lexemeIDs: ["lexeme-draft"],
            status: .draft
        )
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-reviewed",
                    sentenceIDs: ["sentence-reviewed"],
                    status: .reviewed
                ),
                lexeme(
                    id: "lexeme-draft",
                    sentenceIDs: ["sentence-draft"],
                    status: .draft
                ),
            ],
            sentences: [reviewedSentence, draftSentence]
        )

        XCTAssertEqual(catalog.lexemes.map(\.id), ["lexeme-reviewed"])
        XCTAssertEqual(catalog.sentences.map(\.id), ["sentence-reviewed"])
    }

    func testEveryLexemeHasRequiredLearningFieldsAndReciprocalSentenceLink() throws {
        let catalog = try ContentCatalog()
        let sentencesByID = Dictionary(
            uniqueKeysWithValues: catalog.sentences.map { ($0.id, $0) }
        )

        for lexeme in catalog.lexemes {
            XCTAssertFalse(lexeme.stressedForm.isEmpty, lexeme.id)
            XCTAssertFalse(lexeme.speechText.isEmpty, lexeme.id)
            XCTAssertFalse(lexeme.partOfSpeech.isEmpty, lexeme.id)
            XCTAssertFalse(lexeme.glossZh.isEmpty, lexeme.id)
            XCTAssertFalse(lexeme.collocations.isEmpty, lexeme.id)
            XCTAssertTrue(
                lexeme.collocations.allSatisfy { !$0.isEmpty },
                lexeme.id
            )
            XCTAssertFalse(lexeme.example.isEmpty, lexeme.id)
            XCTAssertFalse(lexeme.sentenceIDs.isEmpty, lexeme.id)

            for sentenceID in lexeme.sentenceIDs {
                let sentence = try XCTUnwrap(
                    sentencesByID[sentenceID],
                    "\(lexeme.id) links missing \(sentenceID)"
                )
                XCTAssertTrue(sentence.lexemeIDs.contains(lexeme.id))
            }
        }
    }

    func testEverySentenceHasRequiredSourceAndLexemeLinks() throws {
        let catalog = try ContentCatalog()
        let lexemeIDs = Set(catalog.lexemes.map(\.id))

        for sentence in catalog.sentences {
            XCTAssertFalse(sentence.promptZh.isEmpty, sentence.id)
            XCTAssertFalse(sentence.practiceRu.isEmpty, sentence.id)
            XCTAssertFalse(sentence.speechText.isEmpty, sentence.id)
            XCTAssertFalse(sentence.theme.isEmpty, sentence.id)
            XCTAssertFalse(sentence.lexemeIDs.isEmpty, sentence.id)
            XCTAssertFalse(sentence.sourcePath.isEmpty, sentence.id)
            XCTAssertFalse(sentence.sourceText.isEmpty, sentence.id)
            XCTAssertTrue(
                sentence.lexemeIDs.allSatisfy(lexemeIDs.contains),
                sentence.id
            )
        }
    }

    func testProfessionalConflictAndGeneratedReportSourcesAreExcluded() throws {
        let catalog = try ContentCatalog()
        let excludedFragments = [
            "professional", "生物", "化学", "物理", "组织学",
            "conflict", "双链报告", "ai计划",
        ]

        for sentence in catalog.sentences {
            let normalized = sentence.sourcePath.lowercased()
            XCTAssertFalse(
                excludedFragments.contains { normalized.contains($0) },
                sentence.sourcePath
            )
        }
    }

    func testBundleCatalogValidatesWithoutIssues() throws {
        let catalog = try ContentCatalog()

        XCTAssertEqual(catalog.validate(), [])
    }

    func testValidationReportsBrokenLinksAndMissingFields() {
        let catalog = ContentCatalog(
            lexemes: [
                Lexeme(
                    id: "broken",
                    lemma: "",
                    stressedForm: "",
                    speechText: "",
                    partOfSpeech: "",
                    glossZh: "",
                    collocations: [],
                    example: "",
                    sentenceIDs: ["missing-sentence"],
                    reviewStatus: .reviewed
                ),
            ],
            sentences: []
        )

        let issues = catalog.validate()

        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.contains { $0.itemID == "broken" })
    }

    func testValidationReportsDuplicateLemmaRecords() {
        let linkedSentence = sentence(
            id: "sentence-shared",
            lexemeIDs: ["lexeme-one", "lexeme-two"],
            status: .reviewed
        )
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-one",
                    sentenceIDs: ["sentence-shared"],
                    status: .reviewed
                ),
                lexeme(
                    id: "lexeme-two",
                    sentenceIDs: ["sentence-shared"],
                    status: .reviewed
                ),
            ],
            sentences: [linkedSentence]
        )

        XCTAssertTrue(
            catalog.validate().contains {
                $0.itemID == "lexeme-two"
                    && $0.message.contains("duplicate lemma")
            }
        )
    }

    func testValidationReportsDuplicateSentenceIDsWithoutCrashing() {
        let duplicate = sentence(
            id: "sentence-shared",
            lexemeIDs: [],
            status: .reviewed
        )
        let catalog = ContentCatalog(
            lexemes: [],
            sentences: [duplicate, duplicate]
        )

        XCTAssertTrue(
            catalog.validate().contains {
                $0.itemID == "catalog.sentences"
                    && $0.message.contains("unique")
            }
        )
    }

    private func lexeme(
        id: String,
        sentenceIDs: [String],
        status: ReviewStatus
    ) -> Lexeme {
        Lexeme(
            id: id,
            lemma: "дом",
            stressedForm: "до́м",
            speechText: "дом",
            partOfSpeech: "noun",
            glossZh: "家",
            collocations: ["уютный дом"],
            example: "Это мой дом.",
            sentenceIDs: sentenceIDs,
            reviewStatus: status
        )
    }

    private func sentence(
        id: String,
        lexemeIDs: [String],
        status: ReviewStatus
    ) -> SentenceCard {
        SentenceCard(
            id: id,
            promptZh: "这是我的家。",
            practiceRu: "Это мой дом.",
            speechText: "Это мой дом.",
            theme: "home",
            lexemeIDs: lexemeIDs,
            sourcePath: "curated://daily-russian-a1-b1/home",
            sourceText: "Это мой дом.",
            reviewStatus: status
        )
    }
}
