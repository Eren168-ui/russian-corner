import Foundation
import XCTest

@testable import RussianCornerCore

final class DiagnosticsTests: XCTestCase {
    private let completedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testMetricsAndReportRoundTripThroughCodable() throws {
        let baseline = metrics()
        let current = metrics(
            recognitionRate: 80,
            productionRate: 55,
            medianResponseSeconds: 2.5,
            listeningRate: 60,
            collocationRate: 58,
            selfMonitoringRate: 65
        )
        let report = DiagnosticEngine().report(
            baseline: baseline,
            current: current,
            seed: 42,
            sampleLexemeIDs: ["lexeme-1", "lexeme-2"],
            listeningSentenceIDs: ["sentence-1"],
            sampleWasRepaired: false
        )

        let data = try JSONEncoder().encode(report)
        let restored = try JSONDecoder().decode(
            DiagnosticReport.self,
            from: data
        )

        XCTAssertEqual(restored, report)
        XCTAssertEqual(restored.diagnosticVersion, 2)
        XCTAssertEqual(restored.seed, 42)
        XCTAssertEqual(restored.sampleLexemeIDs, ["lexeme-1", "lexeme-2"])
        XCTAssertEqual(restored.listeningSentenceIDs, ["sentence-1"])
        XCTAssertFalse(restored.sampleWasRepaired)
    }

    func testVocabularyBreadthTriggersBelowSeventyOnly() {
        let engine = DiagnosticEngine()

        XCTAssertTrue(
            engine.findings(for: metrics(recognitionRate: 69.99))
                .contains { $0.type == .vocabularyBreadth }
        )
        XCTAssertFalse(
            engine.findings(for: metrics(recognitionRate: 70))
                .contains { $0.type == .vocabularyBreadth }
        )
    }

    func testActiveRetrievalTriggersAtTwentyPointGap() {
        let engine = DiagnosticEngine()

        XCTAssertFalse(
            engine.findings(
                for: metrics(recognitionRate: 80, productionRate: 60.01)
            ).contains { $0.type == .activeRetrieval }
        )
        XCTAssertTrue(
            engine.findings(
                for: metrics(recognitionRate: 80, productionRate: 60)
            ).contains { $0.type == .activeRetrieval }
        )
    }

    func testSlowRetrievalTriggersAtThreeSeconds() {
        let engine = DiagnosticEngine()

        XCTAssertFalse(
            engine.findings(for: metrics(medianResponseSeconds: 2.99))
                .contains { $0.type == .slowRetrieval }
        )
        XCTAssertTrue(
            engine.findings(for: metrics(medianResponseSeconds: 3))
                .contains { $0.type == .slowRetrieval }
        )
    }

    func testListeningGapTriggersAtTwentyPointGap() {
        let engine = DiagnosticEngine()

        XCTAssertFalse(
            engine.findings(
                for: metrics(recognitionRate: 80, listeningRate: 60.01)
            ).contains { $0.type == .listeningGap }
        )
        XCTAssertTrue(
            engine.findings(
                for: metrics(recognitionRate: 80, listeningRate: 60)
            ).contains { $0.type == .listeningGap }
        )
    }

    func testListeningEvidenceBoundarySuppressesGapAndDeltaBelowFive() {
        let engine = DiagnosticEngine()

        for evidenceCount in [0, 1, 4] {
            let current = metrics(
                recognitionRate: 90,
                listeningRate: 0,
                listeningEvidenceCount: evidenceCount
            )
            let findings = engine.findings(for: current)
            let report = engine.report(
                baseline: metrics(listeningEvidenceCount: 5),
                current: current
            )

            XCTAssertFalse(findings.contains { $0.type == .listeningGap })
            XCTAssertNil(report.deltas?.listeningPoints)
            XCTAssertEqual(
                report.deltas?.listeningAvailability,
                .insufficient(
                    required: DiagnosticThresholds
                        .minimumListeningEvidenceCount,
                    actual: evidenceCount
                )
            )
        }
    }

    func testFivePlayedListeningItemsEnableGapAndDelta() {
        let engine = DiagnosticEngine()
        let baseline = metrics(
            recognitionRate: 90,
            listeningRate: 60,
            listeningEvidenceCount: 5
        )
        let current = metrics(
            recognitionRate: 90,
            listeningRate: 40,
            listeningEvidenceCount: 5
        )

        let report = engine.report(baseline: baseline, current: current)

        XCTAssertTrue(
            report.findings.contains { $0.type == .listeningGap }
        )
        XCTAssertEqual(report.deltas?.listeningPoints, -20)
        XCTAssertEqual(
            report.deltas?.listeningAvailability,
            .sufficient
        )
    }

    func testCollocationGapRequiresRecognitionAtLeastSeventyAndCollocationBelowSixty() {
        let engine = DiagnosticEngine()

        XCTAssertFalse(
            engine.findings(
                for: metrics(recognitionRate: 69.99, collocationRate: 59)
            ).contains { $0.type == .collocationGap }
        )
        XCTAssertFalse(
            engine.findings(
                for: metrics(recognitionRate: 70, collocationRate: 60)
            ).contains { $0.type == .collocationGap }
        )
        XCTAssertTrue(
            engine.findings(
                for: metrics(recognitionRate: 70, collocationRate: 59.99)
            ).contains { $0.type == .collocationGap }
        )
    }

    func testSelfMonitoringTriggersAtSixtyPercent() {
        let engine = DiagnosticEngine()

        XCTAssertFalse(
            engine.findings(for: metrics(selfMonitoringRate: 59.99))
                .contains { $0.type == .selfMonitoring }
        )
        XCTAssertTrue(
            engine.findings(for: metrics(selfMonitoringRate: 60))
                .contains { $0.type == .selfMonitoring }
        )
    }

    func testDeltaUsesPercentagePointsAndResponseSeconds() throws {
        let baseline = metrics(
            recognitionRate: 70,
            productionRate: 50,
            medianResponseSeconds: 4,
            listeningRate: 45,
            collocationRate: 40,
            selfMonitoringRate: 70
        )
        let current = metrics(
            recognitionRate: 80,
            productionRate: 65,
            medianResponseSeconds: 2.5,
            listeningRate: 60,
            collocationRate: 55,
            selfMonitoringRate: 50
        )

        let deltas = try XCTUnwrap(DiagnosticEngine().report(
            baseline: baseline,
            current: current
        ).deltas)

        XCTAssertEqual(deltas.recognitionPoints, 10)
        XCTAssertEqual(deltas.productionPoints, 15)
        XCTAssertEqual(deltas.responseSeconds, -1.5)
        XCTAssertEqual(deltas.listeningPoints, 15)
        XCTAssertEqual(deltas.collocationPoints, 15)
        XCTAssertEqual(deltas.selfMonitoringPoints, -20)
    }

    func testSamplerIsDeterministicAndSpansThemes() {
        let catalog = makeCatalog()
        let sampler = DiagnosticSampler()

        let first = sampler.sample(
            from: catalog,
            seed: 42,
            vocabularyCount: 4,
            listeningCount: 3
        )
        let second = sampler.sample(
            from: catalog,
            seed: 42,
            vocabularyCount: 4,
            listeningCount: 3
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first.listening.map(\.theme)).count, 3)
        XCTAssertEqual(first.recognition.count, 4)
        XCTAssertEqual(first.production.count, 4)
        XCTAssertEqual(
            first.recognition.map(\.id),
            first.production.map(\.id)
        )
    }

    func testMetricsExposeInvalidFieldsAndSuppressFindingsAndDeltas() throws {
        let invalid = DiagnosticMetrics(
            recognitionRate: .nan,
            productionRate: .infinity,
            medianResponseSeconds: -.infinity,
            listeningRate: -10,
            listeningEvidenceCount: -3,
            collocationRate: 120,
            selfMonitoringRate: .nan,
            completedAt: completedAt
        )

        XCTAssertEqual(
            Set(invalid.invalidFields),
            Set([
                .recognitionRate,
                .productionRate,
                .medianResponseSeconds,
                .listeningRate,
                .listeningEvidenceCount,
                .collocationRate,
                .selfMonitoringRate,
            ])
        )
        XCTAssertFalse(invalid.isValid)

        let report = DiagnosticEngine().report(
            baseline: invalid,
            current: invalid
        )
        let encoded = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            DiagnosticReport.self,
            from: encoded
        )

        XCTAssertEqual(decoded.comparisonStatus, .invalidMetrics)
        XCTAssertTrue(decoded.findings.isEmpty)
        XCTAssertNil(decoded.deltas)
    }

    func testRepairedSampleIsNotComparableAndHasNoDeltas() {
        let baseline = metrics(recognitionRate: 70)
        let current = metrics(recognitionRate: 90)

        let report = DiagnosticEngine().report(
            baseline: baseline,
            current: current,
            sampleWasRepaired: true
        )

        XCTAssertEqual(report.comparisonStatus, .sampleChanged)
        XCTAssertNil(report.deltas)
    }

    func testFindingsAreTentativeAndNeverClaimAutomaticPronunciationJudgment() {
        let findings = DiagnosticEngine().findings(
            for: metrics(
                recognitionRate: 50,
                productionRate: 20,
                medianResponseSeconds: 4,
                listeningRate: 20,
                collocationRate: 20,
                selfMonitoringRate: 80
            )
        )
        let text = findings
            .flatMap { [$0.evidence, $0.explanation] }
            .joined(separator: " ")

        XCTAssertTrue(text.contains("可能") || text.contains("提示"))
        XCTAssertFalse(text.contains("自动判断发音"))
        XCTAssertFalse(text.contains("母语地道"))
    }

    private func metrics(
        recognitionRate: Double = 80,
        productionRate: Double = 70,
        medianResponseSeconds: Double = 2,
        listeningRate: Double = 75,
        listeningEvidenceCount: Int = 10,
        collocationRate: Double = 70,
        selfMonitoringRate: Double = 30
    ) -> DiagnosticMetrics {
        DiagnosticMetrics(
            recognitionRate: recognitionRate,
            productionRate: productionRate,
            medianResponseSeconds: medianResponseSeconds,
            listeningRate: listeningRate,
            listeningEvidenceCount: listeningEvidenceCount,
            collocationRate: collocationRate,
            selfMonitoringRate: selfMonitoringRate,
            completedAt: completedAt
        )
    }

    private func makeCatalog() -> ContentCatalog {
        let themes = ["日常", "学习", "出行", "饮食"]
        let sentences = themes.enumerated().map { index, theme in
            SentenceCard(
                id: "sentence-\(index)",
                promptZh: "中文 \(index)",
                cueRu: "Подсказка \(index)",
                practiceRu: "Фраза \(index)",
                speechText: "Фраза \(index)",
                theme: theme,
                lexemeIDs: ["lexeme-\(index)"],
                sourcePath: "fixture.md",
                sourceText: "fixture",
                reviewStatus: .reviewed
            )
        }
        let lexemes = themes.indices.map { index in
            Lexeme(
                id: "lexeme-\(index)",
                lemma: "слово\(index)",
                stressedForm: "сло́во\(index)",
                speechText: "слово\(index)",
                partOfSpeech: "noun",
                glossZh: "词\(index)",
                collocations: ["слово\(index) рядом"],
                example: "Это слово\(index).",
                sentenceIDs: ["sentence-\(index)"],
                reviewStatus: .reviewed
            )
        }
        return ContentCatalog(lexemes: lexemes, sentences: sentences)
    }
}
