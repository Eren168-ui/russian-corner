import Foundation
import XCTest

@testable import RussianCornerCore

final class SupplementalContentTests: XCTestCase {
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
}
