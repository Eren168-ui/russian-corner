import Foundation
import XCTest

@testable import RussianCornerCore

final class SupplementalContentTests: XCTestCase {
    private let allowedRoot =
        "01-按学期/大二上/基础俄语"

    func testLegacyLexemeDecodesWithoutSupplementalFields() throws {
        let data = Data(
            """
            {
              "id": "legacy",
              "lemma": "верить",
              "stressedForm": "ве́рить",
              "speechText": "верить",
              "partOfSpeech": "verb",
              "glossZh": "相信",
              "collocations": ["верить в себя"],
              "example": "Важно верить в себя.",
              "sentenceIDs": ["legacy-sentence"],
              "reviewStatus": "reviewed",
              "aspect": "imperfective",
              "aspectPairNote": "常用中性体对缺失",
              "government": "кому；в кого/что",
              "surfaceForms": []
            }
            """.utf8
        )

        let lexeme = try JSONDecoder().decode(Lexeme.self, from: data)

        XCTAssertEqual(lexeme.corpusLayer, .core)
        XCTAssertEqual(lexeme.sourcePaths, [])
        XCTAssertEqual(lexeme.sourceTexts, [])
        XCTAssertEqual(lexeme.provenanceTypes, [])
        XCTAssertEqual(lexeme.qualityFlags, [])
        XCTAssertNil(lexeme.usageNote)
        XCTAssertNil(lexeme.contrastNote)
        XCTAssertEqual(lexeme.commonMistakes, [])
        XCTAssertNil(lexeme.contrastGroupID)
    }

    func testLegacySentenceDefaultsToCoreLayer() throws {
        let data = Data(
            """
            {
              "id": "legacy-sentence",
              "promptZh": "表达相信自己。",
              "cueRu": "Во что важно верить?",
              "practiceRu": "Важно верить в себя.",
              "speechText": "Важно верить в себя.",
              "theme": "feelings",
              "lexemeIDs": ["legacy"],
              "sourcePath": "legacy.md",
              "sourceText": "Важно верить в себя.",
              "reviewStatus": "reviewed"
            }
            """.utf8
        )

        let sentence = try JSONDecoder().decode(
            SentenceCard.self,
            from: data
        )

        XCTAssertEqual(sentence.corpusLayer, .core)
    }

    func testSupplementalManifestCarriesClosedGateAndAllowlist() throws {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "contentGateClosed": true,
              "allowedSourceRoots": ["a", "b", "c"],
              "sourceHashes": {"a/example.md": "abc"},
              "candidateCount": 120,
              "reviewedSentenceCount": 60,
              "reviewedLexemeCount": 80,
              "excludedCount": 60
            }
            """.utf8
        )

        let manifest = try JSONDecoder().decode(
            SupplementalContentManifest.self,
            from: data
        )

        XCTAssertTrue(manifest.contentGateClosed)
        XCTAssertEqual(manifest.allowedSourceRoots, ["a", "b", "c"])
        XCTAssertEqual(manifest.sourceHashes["a/example.md"], "abc")
        XCTAssertEqual(manifest.reviewedSentenceCount, 60)
        XCTAssertEqual(manifest.reviewedLexemeCount, 80)
    }

    func testSpeakingChallengeRoundTripsWithoutAudio() throws {
        let challenge = SpeakingChallenge(
            id: "challenge-travel",
            promptRu: "Как вы готовитесь к путешествию?",
            promptZh: "你如何为旅行做准备？",
            structureHintsZh: ["先说目的地", "再说准备事项"],
            replacementSlots: ["目的地", "时间"],
            lexemeIDs: ["lexeme-travel"],
            sourcePath: "基础俄语/口语题.md",
            sourceText: "Как вы готовитесь к путешествию?",
            sourceHash: "abc",
            reviewStatus: .reviewed,
            provenanceType: .courseMaterial,
            qualityFlags: []
        )

        let encoded = try JSONEncoder().encode(challenge)
        let decoded = try JSONDecoder().decode(
            SpeakingChallenge.self,
            from: encoded
        )

        XCTAssertEqual(decoded, challenge)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(
            "audio"
        ))
    }

    func testClosedSupplementMergesReviewedItemsWithoutChangingCore()
        throws
    {
        let fixture = try makeResourceFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        try writeSupplement(to: fixture)

        let catalog = try ContentCatalog(resourceDirectory: fixture)

        XCTAssertNil(catalog.supplementalLoadIssue)
        XCTAssertEqual(catalog.supplementalSentences.count, 1)
        XCTAssertEqual(catalog.supplementalLexemes.count, 1)
        XCTAssertEqual(catalog.speakingChallenges.count, 1)
        XCTAssertTrue(
            catalog.practiceSentences.contains {
                $0.id == "supplement-sentence-believe"
            }
        )
        XCTAssertTrue(
            catalog.practiceLexemes.contains {
                $0.id == "supplement-lexeme-believe"
            }
        )
        XCTAssertEqual(
            catalog.coreSentences.count,
            catalog.longTermManifest.sentences.count
        )
    }

    func testInvalidSupplementFailsClosedToCore() throws {
        let fixture = try makeResourceFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        try writeSupplement(to: fixture, gateClosed: false)

        let catalog = try ContentCatalog(resourceDirectory: fixture)

        XCTAssertNotNil(catalog.supplementalLoadIssue)
        XCTAssertTrue(catalog.supplementalSentences.isEmpty)
        XCTAssertTrue(catalog.supplementalLexemes.isEmpty)
        XCTAssertTrue(catalog.speakingChallenges.isEmpty)
        XCTAssertEqual(
            catalog.practiceSentences.map(\.id),
            catalog.coreSentences.map(\.id)
        )
    }

    func testProfessionalSourceNeverMerges() throws {
        let fixture = try makeResourceFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        try writeSupplement(
            to: fixture,
            sourcePath: "01-按学期/大二上/专业俄语/实验室.md"
        )

        let catalog = try ContentCatalog(resourceDirectory: fixture)

        XCTAssertNotNil(catalog.supplementalLoadIssue)
        XCTAssertTrue(catalog.supplementalSentences.isEmpty)
        XCTAssertFalse(
            catalog.practiceSentences.contains {
                $0.id == "supplement-sentence-believe"
            }
        )
    }

    func testPartialSupplementFailsClosedToCore() throws {
        let fixture = try makeResourceFixture()
        defer { try? FileManager.default.removeItem(at: fixture) }
        try writeSupplement(to: fixture)
        try FileManager.default.removeItem(
            at: fixture.appendingPathComponent(
                "speaking-challenges.json"
            )
        )

        let catalog = try ContentCatalog(resourceDirectory: fixture)

        XCTAssertNotNil(catalog.supplementalLoadIssue)
        XCTAssertTrue(catalog.supplementalSentences.isEmpty)
    }

    func testProductionSupplementUsesItsOwnGateAndKeepsCoreValidationClean()
        throws
    {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("RussianCornerCore")
            .appendingPathComponent("Resources")

        let catalog = try ContentCatalog(resourceDirectory: resources)

        XCTAssertEqual(catalog.supplementalLexemes.count, 80)
        XCTAssertEqual(catalog.supplementalSentences.count, 60)
        XCTAssertEqual(catalog.speakingChallenges.count, 24)
        XCTAssertNil(catalog.supplementalLoadIssue)
        XCTAssertTrue(catalog.validate().isEmpty)
    }

    private func makeResourceFixture() throws -> URL {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("RussianCornerCore")
            .appendingPathComponent("Resources")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )
        for name in [
            "lexemes.json",
            "sentences.json",
            "trial-slice.json",
            "topics.json",
            "long-term-sentences.json",
        ] {
            try FileManager.default.copyItem(
                at: source.appendingPathComponent(name),
                to: destination.appendingPathComponent(name)
            )
        }
        return destination
    }

    private func writeSupplement(
        to directory: URL,
        gateClosed: Bool = true,
        sourcePath: String? = nil
    ) throws {
        let path = sourcePath
            ?? "\(allowedRoot)/верить в + Acc.md"
        let hash = "fixture-source-hash"
        let manifest = SupplementalContentManifest(
            schemaVersion: 1,
            contentGateClosed: gateClosed,
            allowedSourceRoots: [allowedRoot],
            sourceHashes: [path: hash],
            candidateCount: 1,
            reviewedSentenceCount: 1,
            reviewedLexemeCount: 1,
            excludedCount: 0
        )
        let lexeme = Lexeme(
            id: "supplement-lexeme-believe",
            lemma: "уверенность",
            stressedForm: "уве́ренность",
            speechText: "уверенность",
            partOfSpeech: "noun",
            glossZh: "信心；确信",
            collocations: ["уверенность в себе"],
            example: "Уверенность в себе приходит с практикой.",
            sentenceIDs: ["supplement-sentence-believe"],
            reviewStatus: .reviewed,
            grammaticalGender: "feminine",
            sourcePaths: [path],
            sourceTexts: ["верить в себя"],
            provenanceTypes: [.userNote],
            qualityFlags: [],
            usageNote: "常与 в + 第四格/前置格结构搭配。",
            corpusLayer: .dailySupplement
        )
        let sentence = SentenceCard(
            id: "supplement-sentence-believe",
            promptZh: "说明练习能带来自信。",
            cueRu: "Что даёт регулярная практика?",
            practiceRu: "Уверенность в себе приходит с практикой.",
            stressedForm:
                "Уве́ренность в себе́ прихо́дит с пра́ктикой.",
            speechText:
                "Уверенность в себе приходит с практикой.",
            theme: "language-learning",
            lexemeIDs: [lexeme.id],
            sourcePath: path,
            sourceText: "верить в себя",
            reviewStatus: .reviewed,
            provenanceType: .derived,
            qualityFlags: [],
            dialogueAct: "explanation",
            register: .neutral,
            speakerRole: "学生",
            addressForm: .notApplicable,
            expectedReply: "Согласен, главное — не бояться ошибок.",
            topicID: "topic-06",
            sourceHash: hash,
            corpusLayer: .dailySupplement
        )
        let challenge = SpeakingChallenge(
            id: "supplement-challenge-believe",
            promptRu: "Почему важно верить в себя?",
            promptZh: "为什么相信自己很重要？",
            structureHintsZh: ["说明原因", "举一个例子"],
            replacementSlots: ["个人经历"],
            lexemeIDs: [lexeme.id],
            sourcePath: path,
            sourceText: "верить в себя",
            sourceHash: hash,
            reviewStatus: .reviewed,
            provenanceType: .derived,
            qualityFlags: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: directory.appendingPathComponent(
                "supplemental-manifest.json"
            )
        )
        try encoder.encode([lexeme]).write(
            to: directory.appendingPathComponent(
                "supplemental-lexemes.json"
            )
        )
        try encoder.encode([sentence]).write(
            to: directory.appendingPathComponent(
                "supplemental-sentences.json"
            )
        )
        try encoder.encode([challenge]).write(
            to: directory.appendingPathComponent(
                "speaking-challenges.json"
            )
        )
    }
}
