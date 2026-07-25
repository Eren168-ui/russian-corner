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
            current: current
        )

        let data = try JSONEncoder().encode(report)
        let restored = try JSONDecoder().decode(
            DiagnosticReport.self,
            from: data
        )

        XCTAssertEqual(restored, report)
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

    func testDeltaUsesPercentagePointsAndResponseSeconds() {
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

        let deltas = DiagnosticEngine().report(
            baseline: baseline,
            current: current
        ).deltas

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
        collocationRate: Double = 70,
        selfMonitoringRate: Double = 30
    ) -> DiagnosticMetrics {
        DiagnosticMetrics(
            recognitionRate: recognitionRate,
            productionRate: productionRate,
            medianResponseSeconds: medianResponseSeconds,
            listeningRate: listeningRate,
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
