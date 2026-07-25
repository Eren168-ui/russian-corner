import XCTest
@testable import RussianCornerCore

final class ContentCatalogTests: XCTestCase {
    private var sourceResourceDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("RussianCornerCore", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
    }

    func testExplicitResourceDirectoryLoadsReviewedCatalog() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )

        XCTAssertEqual(catalog.lexemes.count, 360)
        XCTAssertEqual(catalog.sentences.count, 72)
    }

    func testMissingExplicitResourcesFailWithoutFallback() throws {
        let emptyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: emptyDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: emptyDirectory)
        }

        XCTAssertThrowsError(
            try ContentCatalog(resourceDirectory: emptyDirectory)
        ) { error in
            XCTAssertEqual(
                error as? ContentCatalogError,
                .missingResource("lexemes")
            )
        }
    }

    func testExplicitResourceDirectoryFailsClosedOnValidationIssues() throws {
        let resourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: resourceDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: resourceDirectory)
        }
        for name in ["lexemes.json", "sentences.json"] {
            try FileManager.default.copyItem(
                at: sourceResourceDirectory.appendingPathComponent(name),
                to: resourceDirectory.appendingPathComponent(name)
            )
        }
        let sentencesURL = resourceDirectory
            .appendingPathComponent("sentences.json")
        let validSentences = try String(
            contentsOf: sentencesURL,
            encoding: .utf8
        )
        let corruptedSentences = validSentences.replacingOccurrences(
            of: "\"lexeme-emergencies-помочь\"",
            with: "\"lexeme-does-not-exist\""
        )
        XCTAssertNotEqual(validSentences, corruptedSentences)
        try Data(corruptedSentences.utf8).write(to: sentencesURL)

        XCTAssertThrowsError(
            try ContentCatalog(resourceDirectory: resourceDirectory)
        ) { error in
            guard case let ContentCatalogError.validationFailed(issues) = error
            else {
                return XCTFail("expected validation issues, got \(error)")
            }
            XCTAssertFalse(issues.isEmpty)
            XCTAssertTrue(
                issues.contains {
                    $0.itemID.hasPrefix("sentence-emergencies-")
                    && $0.message.contains("lexeme-does-not-exist")
                },
                "\(issues)"
            )
            XCTAssertTrue(
                error.localizedDescription.contains(
                    "lexeme-does-not-exist"
                )
            )
        }
    }

    func testInMemoryFixtureInitializerAllowsInvalidFixture() {
        let catalog = ContentCatalog(lexemes: [], sentences: [])

        XCTAssertFalse(catalog.validate().isEmpty)
    }

    func testProductionResourceResolutionIgnoresDevelopmentFallbacks() throws {
        let productionResources = URL(
            fileURLWithPath: "/Applications/Russian Corner.app/Contents/Resources",
            isDirectory: true
        )

        let result = try ContentCatalog.defaultResourceDirectory(
            bundleIdentifier: "com.openclaw.russiancorner",
            bundleResourceURL: productionResources,
            environment: [
                "RUSSIAN_CORNER_RESOURCE_DIRECTORY": "/tmp/development"
            ],
            currentDirectoryURL: URL(
                fileURLWithPath: "/tmp/repository",
                isDirectory: true
            )
        )

        XCTAssertEqual(result, productionResources)
    }

    func testBareBinaryResourceResolutionUsesEnvironmentOverride() throws {
        let result = try ContentCatalog.defaultResourceDirectory(
            bundleIdentifier: nil,
            bundleResourceURL: nil,
            environment: [
                "RUSSIAN_CORNER_RESOURCE_DIRECTORY": "/tmp/explicit-resources"
            ],
            currentDirectoryURL: URL(
                fileURLWithPath: "/tmp/repository",
                isDirectory: true
            )
        )

        XCTAssertEqual(
            result,
            URL(
                fileURLWithPath: "/tmp/explicit-resources",
                isDirectory: true
            )
        )
    }

    func testLegacySentenceWithoutRussianCueDecodesWithAnswerFallback() throws {
        let legacyJSON = """
            {
              "id": "sentence-legacy",
              "promptZh": "说：我今天在家工作。",
              "practiceRu": "Я сегодня работаю дома.",
              "speechText": "Я сегодня работаю дома.",
              "theme": "home",
              "lexemeIDs": ["lexeme-work"],
              "sourcePath": "legacy.json",
              "sourceText": "legacy",
              "reviewStatus": "reviewed"
            }
            """

        let card = try JSONDecoder().decode(
            SentenceCard.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertEqual(card.cueRu, card.practiceRu)
    }

    func testLexemeDeclaresSurfaceForms() {
        let item = Lexeme(
            id: "lexeme-svobodnyy",
            lemma: "свободный",
            stressedForm: "свобо́дный",
            speechText: "свободный",
            partOfSpeech: "adjective",
            glossZh: "空闲的；自由的",
            collocations: ["свободный вечер"],
            example: "Сегодня я свободен.",
            sentenceIDs: ["sentence-free"],
            reviewStatus: .reviewed,
            surfaceForms: ["свободен"]
        )

        XCTAssertEqual(item.surfaceForms, ["свободен"])
    }

    func testLegacyLexemeWithoutLinguisticMetadataStillDecodes() throws {
        let legacyJSON = """
            {
              "id": "lexeme-legacy",
              "lemma": "дом",
              "stressedForm": "до́м",
              "speechText": "дом",
              "partOfSpeech": "noun",
              "glossZh": "家",
              "collocations": ["уютный дом"],
              "example": "Это мой дом.",
              "sentenceIDs": ["sentence-home"],
              "reviewStatus": "reviewed",
              "surfaceForms": []
            }
            """

        let item = try JSONDecoder().decode(
            Lexeme.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertNil(item.government)
        XCTAssertNil(item.aspectPairNote)
    }

    func testEveryBundleNounDeclaresGrammaticalGender() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let nouns = catalog.lexemes.filter { $0.partOfSpeech == "noun" }
        let allowedGenders: Set<String> = [
            "masculine", "feminine", "neuter", "plural",
        ]

        XCTAssertEqual(nouns.count, 195)
        for noun in nouns {
            XCTAssertTrue(
                noun.grammaticalGender.map(allowedGenders.contains) == true,
                "\(noun.id): \(noun.grammaticalGender ?? "missing")"
            )
        }
    }

    func testEveryBundleVerbDeclaresAspectAndPairOrExplicitNote() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let verbs = catalog.lexemes.filter { $0.partOfSpeech == "verb" }
        let allowedAspects: Set<String> = [
            "perfective", "imperfective", "biaspectual",
        ]

        XCTAssertEqual(verbs.count, 93)
        for verb in verbs {
            XCTAssertTrue(
                verb.aspect.map(allowedAspects.contains) == true,
                "\(verb.id): \(verb.aspect ?? "missing")"
            )
            XCTAssertTrue(
                verb.aspectPair?.isEmpty == false
                    || verb.aspectPairNote?.isEmpty == false,
                "\(verb.id): missing aspect pair or explicit note"
            )
        }
    }

    func testEveryBundleVerbAndPrepositionDeclaresGovernment() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let governedItems = catalog.lexemes.filter {
            $0.partOfSpeech == "verb" || $0.partOfSpeech == "preposition"
        }

        XCTAssertEqual(governedItems.count, 95)
        for item in governedItems {
            XCTAssertTrue(
                item.government?.isEmpty == false,
                "\(item.id): missing government"
            )
        }
    }

    func testPomogiteBelongsToCanonicalPomochLexeme() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let pomochEntries = catalog.lexemes.filter { $0.lemma == "помочь" }
        let pomoch = try XCTUnwrap(pomochEntries.first)

        XCTAssertEqual(pomochEntries.count, 1)
        XCTAssertEqual(pomoch.id, "lexeme-emergencies-помочь")
        XCTAssertEqual(pomoch.stressedForm, "помо́чь")
        XCTAssertEqual(pomoch.speechText, "помочь")
        XCTAssertEqual(pomoch.partOfSpeech, "verb")
        XCTAssertEqual(pomoch.aspect, "perfective")
        XCTAssertEqual(pomoch.aspectPair, "помогать")
        XCTAssertTrue(pomoch.surfaceForms.contains("помогите"))
        XCTAssertFalse(
            catalog.lexemes
                .filter { $0.lemma == "помогать" }
                .contains { $0.surfaceForms.contains("помогите") }
        )
    }

    func testBundleCatalogMeetsReviewedDailyContentContract() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )

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
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
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
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let lexemeIDs = Set(catalog.lexemes.map(\.id))

        for sentence in catalog.sentences {
            XCTAssertFalse(sentence.promptZh.isEmpty, sentence.id)
            XCTAssertFalse(sentence.cueRu.isEmpty, sentence.id)
            XCTAssertNotEqual(
                sentence.cueRu
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased(),
                sentence.practiceRu
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased(),
                sentence.id
            )
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

    func testEveryRussianCueIsReviewedQuestionOrGuidance() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )

        XCTAssertEqual(catalog.sentences.count, 72)
        for sentence in catalog.sentences {
            XCTAssertEqual(sentence.reviewStatus, .reviewed, sentence.id)
            XCTAssertTrue(
                sentence.cueRu.hasSuffix("?")
                    || sentence.cueRu.hasSuffix("!")
                    || sentence.cueRu.hasSuffix("…"),
                "\(sentence.id): \(sentence.cueRu)"
            )
            XCTAssertGreaterThanOrEqual(
                sentence.cueRu.split(separator: " ").count,
                3,
                "\(sentence.id): \(sentence.cueRu)"
            )
        }
    }

    func testProfessionalConflictAndGeneratedReportSourcesAreExcluded() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
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
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )

        XCTAssertEqual(catalog.validate(), [])
    }

    func testBundleCollocationsAreShortCompleteAndBalanced() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let forbiddenEndings: Set<String> = [
            "в", "на", "к", "с", "из", "от", "до", "для", "без",
            "о", "об", "по", "за", "у", "при", "через", "перед",
            "между", "и", "или",
        ]

        for lexeme in catalog.lexemes {
            for collocation in lexeme.collocations {
                let tokens = russianTokens(in: collocation)
                XCTAssertTrue(
                    (2...6).contains(tokens.count),
                    "\(lexeme.id): \(collocation)"
                )
                XCTAssertFalse(
                    forbiddenEndings.contains(tokens.last ?? ""),
                    "\(lexeme.id): \(collocation)"
                )
                XCTAssertEqual(
                    collocation.filter { $0 == "«" }.count,
                    collocation.filter { $0 == "»" }.count,
                    "\(lexeme.id): \(collocation)"
                )
                XCTAssertEqual(
                    collocation.filter { $0 == "\"" }.count % 2,
                    0,
                    "\(lexeme.id): \(collocation)"
                )
            }
        }
    }

    func testBundleExamplesAreUniqueAndContainOwnLexicalForm() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let normalizedExamples = catalog.lexemes.map {
            normalizedRussianText($0.example)
        }

        XCTAssertEqual(
            Set(normalizedExamples).count,
            catalog.lexemes.count,
            "every lexeme needs an independent example"
        )
        for lexeme in catalog.lexemes {
            XCTAssertTrue(
                containsLexeme(lexeme, in: lexeme.example),
                "\(lexeme.id): \(lexeme.example)"
            )
        }
    }

    func testBundleSentenceLinksVaryAndEveryLinkedLexemeAppears() throws {
        let catalog = try ContentCatalog(
            resourceDirectory: sourceResourceDirectory
        )
        let lexemesByID = Dictionary(
            uniqueKeysWithValues: catalog.lexemes.map { ($0.id, $0) }
        )
        let linkCounts = Set(catalog.sentences.map { $0.lexemeIDs.count })

        XCTAssertGreaterThanOrEqual(
            linkCounts.count,
            3,
            "sentence link counts must have a real distribution"
        )
        for sentence in catalog.sentences {
            XCTAssertTrue(
                (3...8).contains(sentence.lexemeIDs.count),
                sentence.id
            )
            for lexemeID in sentence.lexemeIDs {
                let lexeme = try XCTUnwrap(lexemesByID[lexemeID])
                XCTAssertTrue(
                    containsLexeme(lexeme, in: sentence.practiceRu),
                    "\(sentence.id) does not contain \(lexemeID)"
                )
            }
        }
    }

    func testValidationReportsTruncatedOrUnbalancedCollocations() {
        let linkedSentence = sentence(
            id: "sentence-home",
            lexemeIDs: ["lexeme-play", "lexeme-greeting"],
            status: .reviewed,
            practiceRu: "Я люблю играть и говорить привет."
        )
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-play",
                    lemma: "играть",
                    stressedForm: "игра́ть",
                    collocations: ["играть на"],
                    example: "Дети любят играть во дворе.",
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed
                ),
                lexeme(
                    id: "lexeme-greeting",
                    lemma: "привет",
                    stressedForm: "приве́т",
                    collocations: ["сказать «привет"],
                    example: "Я передал соседу привет.",
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed
                ),
            ],
            sentences: [linkedSentence]
        )

        let issues = catalog.validate()

        XCTAssertTrue(issues.contains {
            $0.itemID == "lexeme-play"
                && $0.message.contains("ends with a function word")
        })
        XCTAssertTrue(issues.contains {
            $0.itemID == "lexeme-greeting"
                && $0.message.contains("unbalanced quotes")
        })
    }

    func testValidationReportsDuplicateExamples() {
        let linkedSentence = sentence(
            id: "sentence-home",
            lexemeIDs: ["lexeme-home", "lexeme-window"],
            status: .reviewed,
            practiceRu: "Это мой дом, и в нём есть окно."
        )
        let sharedExample = "В доме есть большое окно."
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-home",
                    example: sharedExample,
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed
                ),
                lexeme(
                    id: "lexeme-window",
                    lemma: "окно",
                    stressedForm: "окно́",
                    collocations: ["большое окно"],
                    example: sharedExample,
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed
                ),
            ],
            sentences: [linkedSentence]
        )

        XCTAssertTrue(catalog.validate().contains {
            $0.itemID == "lexeme-window"
                && $0.message.contains("duplicate example")
        })
    }

    func testValidationReportsUniformSentenceLinkCounts() {
        let catalog = ContentCatalog(
            lexemes: [],
            sentences: [
                sentence(
                    id: "sentence-one",
                    lexemeIDs: ["one", "two", "three"],
                    status: .reviewed
                ),
                sentence(
                    id: "sentence-two",
                    lexemeIDs: ["four", "five", "six"],
                    status: .reviewed
                ),
            ]
        )

        XCTAssertTrue(catalog.validate().contains {
            $0.itemID == "catalog.sentences"
                && $0.message.contains("link counts must vary")
        })
    }

    func testValidationReportsSentenceSideLinkWhoseFormIsAbsent() {
        let linkedSentence = sentence(
            id: "sentence-home",
            lexemeIDs: ["lexeme-home", "lexeme-cat"],
            status: .reviewed,
            practiceRu: "Это мой дом."
        )
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-home",
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed
                ),
                lexeme(
                    id: "lexeme-cat",
                    lemma: "кошка",
                    stressedForm: "ко́шка",
                    collocations: ["домашняя кошка"],
                    example: "На диване спит кошка.",
                    sentenceIDs: [],
                    status: .reviewed
                ),
            ],
            sentences: [linkedSentence]
        )

        XCTAssertTrue(catalog.validate().contains {
            $0.itemID == "sentence-home"
                && $0.message.contains("linked lexeme form is absent")
        })
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

    func testValidationReportsMissingRequiredLinguisticMetadata() {
        let entries = [
            Lexeme(
                id: "noun-without-gender",
                lemma: "дом",
                stressedForm: "до́м",
                speechText: "дом",
                partOfSpeech: "noun",
                glossZh: "家",
                collocations: ["уютный дом"],
                example: "Это мой дом.",
                sentenceIDs: [],
                reviewStatus: .reviewed
            ),
            Lexeme(
                id: "verb-without-usage",
                lemma: "читать",
                stressedForm: "чита́ть",
                speechText: "читать",
                partOfSpeech: "verb",
                glossZh: "读",
                collocations: ["читать книгу"],
                example: "Я люблю читать.",
                sentenceIDs: [],
                reviewStatus: .reviewed
            ),
            Lexeme(
                id: "preposition-without-government",
                lemma: "через",
                stressedForm: "че́рез",
                speechText: "через",
                partOfSpeech: "preposition",
                glossZh: "穿过；过……之后",
                collocations: ["через пять минут"],
                example: "Автобус будет через пять минут.",
                sentenceIDs: [],
                reviewStatus: .reviewed
            ),
        ]
        let issues = ContentCatalog(
            lexemes: entries,
            sentences: []
        ).validate()

        XCTAssertTrue(issues.contains {
            $0.itemID == "noun-without-gender"
                && $0.message.contains("grammatical gender")
        })
        XCTAssertTrue(issues.contains {
            $0.itemID == "verb-without-usage"
                && $0.message.contains("verbal aspect")
        })
        XCTAssertTrue(issues.contains {
            $0.itemID == "verb-without-usage"
                && $0.message.contains("aspect pair")
        })
        XCTAssertTrue(issues.contains {
            $0.itemID == "verb-without-usage"
                && $0.message.contains("government")
        })
        XCTAssertTrue(issues.contains {
            $0.itemID == "preposition-without-government"
                && $0.message.contains("government")
        })
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

    func testValidationReportsLexemeMissingFromLinkedSentenceText() {
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-cat",
                    lemma: "кошка",
                    stressedForm: "ко́шка",
                    collocations: ["домашняя кошка"],
                    example: "У меня дома живёт кошка.",
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed,
                    surfaceForms: ["кошку"]
                ),
            ],
            sentences: [
                sentence(
                    id: "sentence-home",
                    lexemeIDs: ["lexeme-cat"],
                    status: .reviewed,
                    practiceRu: "Это мой дом."
                ),
            ]
        )

        XCTAssertTrue(
            catalog.validate().contains {
                $0.itemID == "lexeme-cat"
                    && $0.message.contains("linked sentence text")
            }
        )
    }

    func testValidationReportsExampleWithoutLemmaOrSurfaceForm() {
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-home",
                    lemma: "дом",
                    stressedForm: "до́м",
                    collocations: ["уютный дом"],
                    example: "Я читаю книгу.",
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed,
                    surfaceForms: ["дома"]
                ),
            ],
            sentences: [
                sentence(
                    id: "sentence-home",
                    lexemeIDs: ["lexeme-home"],
                    status: .reviewed,
                    practiceRu: "Это мой дом."
                ),
            ]
        )

        XCTAssertTrue(
            catalog.validate().contains {
                $0.itemID == "lexeme-home"
                    && $0.message.contains("example does not contain")
            }
        )
    }

    func testValidationReportsCollocationWithoutLemmaOrSurfaceForm() {
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-home",
                    lemma: "дом",
                    stressedForm: "до́м",
                    collocations: ["читать книгу"],
                    example: "Это мой дом.",
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed
                ),
            ],
            sentences: [
                sentence(
                    id: "sentence-home",
                    lexemeIDs: ["lexeme-home"],
                    status: .reviewed,
                    practiceRu: "Это мой дом."
                ),
            ]
        )

        XCTAssertTrue(
            catalog.validate().contains {
                $0.itemID == "lexeme-home"
                    && $0.message.contains("collocation does not contain")
            }
        )
    }

    func testValidationReportsCollocationIdenticalToExample() {
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-home",
                    lemma: "дом",
                    stressedForm: "до́м",
                    collocations: ["Это мой дом."],
                    example: "Это мой дом.",
                    sentenceIDs: ["sentence-home"],
                    status: .reviewed
                ),
            ],
            sentences: [
                sentence(
                    id: "sentence-home",
                    lexemeIDs: ["lexeme-home"],
                    status: .reviewed,
                    practiceRu: "Это мой дом."
                ),
            ]
        )

        XCTAssertTrue(
            catalog.validate().contains {
                $0.itemID == "lexeme-home"
                    && $0.message.contains("collocation equals example")
            }
        )
    }

    func testValidationReportsLemmaDuplicatedByAnotherSurfaceForm() {
        let linkedSentence = sentence(
            id: "sentence-free",
            lexemeIDs: ["lexeme-free", "lexeme-short-free"],
            status: .reviewed,
            practiceRu: "Сегодня я свободен."
        )
        let catalog = ContentCatalog(
            lexemes: [
                lexeme(
                    id: "lexeme-free",
                    lemma: "свободный",
                    stressedForm: "свобо́дный",
                    collocations: ["свободный вечер"],
                    example: "Сегодня я свободен.",
                    sentenceIDs: ["sentence-free"],
                    status: .reviewed,
                    surfaceForms: ["свободен"]
                ),
                lexeme(
                    id: "lexeme-short-free",
                    lemma: "свободен",
                    stressedForm: "свобо́ден",
                    collocations: ["свободен сегодня"],
                    example: "Сегодня я свободен.",
                    sentenceIDs: ["sentence-free"],
                    status: .reviewed
                ),
            ],
            sentences: [linkedSentence]
        )

        XCTAssertTrue(
            catalog.validate().contains {
                $0.itemID == "lexeme-short-free"
                    && $0.message.contains("morphological duplicate")
            }
        )
    }

    private func lexeme(
        id: String,
        lemma: String = "дом",
        stressedForm: String = "до́м",
        collocations: [String] = ["уютный дом"],
        example: String = "Это мой дом.",
        sentenceIDs: [String],
        status: ReviewStatus,
        surfaceForms: [String] = []
    ) -> Lexeme {
        Lexeme(
            id: id,
            lemma: lemma,
            stressedForm: stressedForm,
            speechText: lemma,
            partOfSpeech: "noun",
            glossZh: "家",
            collocations: collocations,
            example: example,
            sentenceIDs: sentenceIDs,
            reviewStatus: status,
            surfaceForms: surfaceForms
        )
    }

    private func sentence(
        id: String,
        lexemeIDs: [String],
        status: ReviewStatus,
        practiceRu: String = "Это мой дом."
    ) -> SentenceCard {
        SentenceCard(
            id: id,
            promptZh: "这是我的家。",
            cueRu: "Что вы скажете о своём доме?",
            practiceRu: practiceRu,
            speechText: practiceRu,
            theme: "home",
            lexemeIDs: lexemeIDs,
            sourcePath: "curated://daily-russian-a1-b1/home",
            sourceText: practiceRu,
            reviewStatus: status
        )
    }

    private func russianTokens(in value: String) -> [String] {
        normalizedRussianText(value)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    private func normalizedRussianText(_ value: String) -> String {
        value
            .decomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\u{301}", with: "")
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }

    private func containsLexeme(_ lexeme: Lexeme, in text: String) -> Bool {
        let textTokens = russianTokens(in: text)
        return ([lexeme.lemma] + lexeme.surfaceForms).contains { form in
            let formTokens = russianTokens(in: form)
            guard !formTokens.isEmpty, textTokens.count >= formTokens.count
            else {
                return false
            }
            return (0...(textTokens.count - formTokens.count)).contains {
                Array(textTokens[$0..<($0 + formTokens.count)]) == formTokens
            }
        }
    }
}
