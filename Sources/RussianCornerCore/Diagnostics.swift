import Foundation

public struct DiagnosticMetrics: Codable, Equatable, Sendable {
    public let recognitionRate: Double
    public let productionRate: Double
    public let medianResponseSeconds: Double
    public let listeningRate: Double
    public let listeningEvidenceCount: Int
    public let collocationRate: Double
    public let selfMonitoringRate: Double
    public let completedAt: Date

    public init(
        recognitionRate: Double,
        productionRate: Double,
        medianResponseSeconds: Double,
        listeningRate: Double,
        listeningEvidenceCount: Int = 10,
        collocationRate: Double,
        selfMonitoringRate: Double,
        completedAt: Date
    ) {
        self.recognitionRate = Self.percentage(recognitionRate)
        self.productionRate = Self.percentage(productionRate)
        self.medianResponseSeconds =
            medianResponseSeconds.isFinite && medianResponseSeconds >= 0
            ? medianResponseSeconds : 0
        self.listeningRate = Self.percentage(listeningRate)
        self.listeningEvidenceCount = max(0, listeningEvidenceCount)
        self.collocationRate = Self.percentage(collocationRate)
        self.selfMonitoringRate = Self.percentage(selfMonitoringRate)
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case recognitionRate
        case productionRate
        case medianResponseSeconds
        case listeningRate
        case listeningEvidenceCount
        case collocationRate
        case selfMonitoringRate
        case completedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            recognitionRate: try container.decode(
                Double.self,
                forKey: .recognitionRate
            ),
            productionRate: try container.decode(
                Double.self,
                forKey: .productionRate
            ),
            medianResponseSeconds: try container.decode(
                Double.self,
                forKey: .medianResponseSeconds
            ),
            listeningRate: try container.decode(
                Double.self,
                forKey: .listeningRate
            ),
            listeningEvidenceCount: try container.decodeIfPresent(
                Int.self,
                forKey: .listeningEvidenceCount
            ) ?? 0,
            collocationRate: try container.decode(
                Double.self,
                forKey: .collocationRate
            ),
            selfMonitoringRate: try container.decode(
                Double.self,
                forKey: .selfMonitoringRate
            ),
            completedAt: try container.decode(
                Date.self,
                forKey: .completedAt
            )
        )
    }

    private static func percentage(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 100)
    }
}

public enum DiagnosticFindingType:
    String,
    Codable,
    CaseIterable,
    Equatable,
    Sendable
{
    case vocabularyBreadth
    case activeRetrieval
    case slowRetrieval
    case listeningGap
    case collocationGap
    case selfMonitoring
}

public enum DiagnosticSeverity:
    String,
    Codable,
    Equatable,
    Sendable
{
    case notice
    case focus
}

public struct DiagnosticFinding: Codable, Equatable, Sendable {
    public let type: DiagnosticFindingType
    public let severity: DiagnosticSeverity
    public let evidence: String
    public let explanation: String

    public init(
        type: DiagnosticFindingType,
        severity: DiagnosticSeverity,
        evidence: String,
        explanation: String
    ) {
        self.type = type
        self.severity = severity
        self.evidence = evidence
        self.explanation = explanation
    }
}

public struct DiagnosticDeltas: Codable, Equatable, Sendable {
    public let recognitionPoints: Double
    public let productionPoints: Double
    public let responseSeconds: Double
    public let listeningPoints: Double
    public let collocationPoints: Double
    public let selfMonitoringPoints: Double

    public init(
        recognitionPoints: Double,
        productionPoints: Double,
        responseSeconds: Double,
        listeningPoints: Double,
        collocationPoints: Double,
        selfMonitoringPoints: Double
    ) {
        self.recognitionPoints = recognitionPoints
        self.productionPoints = productionPoints
        self.responseSeconds = responseSeconds
        self.listeningPoints = listeningPoints
        self.collocationPoints = collocationPoints
        self.selfMonitoringPoints = selfMonitoringPoints
    }
}

public struct DiagnosticReport: Codable, Equatable, Sendable {
    public let diagnosticVersion: Int
    public let seed: UInt64
    public let sampleLexemeIDs: [String]
    public let listeningSentenceIDs: [String]
    public let sampleWasRepaired: Bool
    public let baseline: DiagnosticMetrics
    public let current: DiagnosticMetrics
    public let findings: [DiagnosticFinding]
    public let deltas: DiagnosticDeltas

    public init(
        diagnosticVersion: Int = 2,
        seed: UInt64 = 0,
        sampleLexemeIDs: [String] = [],
        listeningSentenceIDs: [String] = [],
        sampleWasRepaired: Bool = false,
        baseline: DiagnosticMetrics,
        current: DiagnosticMetrics,
        findings: [DiagnosticFinding],
        deltas: DiagnosticDeltas
    ) {
        self.diagnosticVersion = diagnosticVersion
        self.seed = seed
        self.sampleLexemeIDs = sampleLexemeIDs
        self.listeningSentenceIDs = listeningSentenceIDs
        self.sampleWasRepaired = sampleWasRepaired
        self.baseline = baseline
        self.current = current
        self.findings = findings
        self.deltas = deltas
    }

    private enum CodingKeys: String, CodingKey {
        case diagnosticVersion
        case seed
        case sampleLexemeIDs
        case listeningSentenceIDs
        case sampleWasRepaired
        case baseline
        case current
        case findings
        case deltas
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            diagnosticVersion: try container.decodeIfPresent(
                Int.self,
                forKey: .diagnosticVersion
            ) ?? 1,
            seed: try container.decodeIfPresent(
                UInt64.self,
                forKey: .seed
            ) ?? 0,
            sampleLexemeIDs: try container.decodeIfPresent(
                [String].self,
                forKey: .sampleLexemeIDs
            ) ?? [],
            listeningSentenceIDs: try container.decodeIfPresent(
                [String].self,
                forKey: .listeningSentenceIDs
            ) ?? [],
            sampleWasRepaired: try container.decodeIfPresent(
                Bool.self,
                forKey: .sampleWasRepaired
            ) ?? false,
            baseline: try container.decode(
                DiagnosticMetrics.self,
                forKey: .baseline
            ),
            current: try container.decode(
                DiagnosticMetrics.self,
                forKey: .current
            ),
            findings: try container.decode(
                [DiagnosticFinding].self,
                forKey: .findings
            ),
            deltas: try container.decode(
                DiagnosticDeltas.self,
                forKey: .deltas
            )
        )
    }
}

public struct DiagnosticThresholds: Equatable, Sendable {
    public static let vocabularyRecognitionMinimum = 70.0
    public static let retrievalGapMinimum = 20.0
    public static let slowRetrievalSeconds = 3.0
    public static let listeningGapMinimum = 20.0
    public static let collocationRecognitionMinimum = 70.0
    public static let collocationRateMinimum = 60.0
    public static let selfMonitoringMinimum = 60.0

    public init() {}
}

public struct DiagnosticEngine: Sendable {
    public init() {}

    public func findings(
        for metrics: DiagnosticMetrics
    ) -> [DiagnosticFinding] {
        var findings: [DiagnosticFinding] = []

        if metrics.recognitionRate
            < DiagnosticThresholds.vocabularyRecognitionMinimum
        {
            findings.append(
                DiagnosticFinding(
                    type: .vocabularyBreadth,
                    severity: .focus,
                    evidence: "认词率低于 70%，提示当前抽样中仍有较多生词。",
                    explanation: "可能需要先扩大高频词覆盖，再增加新词量。"
                )
            )
        }
        if metrics.recognitionRate - metrics.productionRate
            >= DiagnosticThresholds.retrievalGapMinimum
        {
            findings.append(
                DiagnosticFinding(
                    type: .activeRetrieval,
                    severity: .focus,
                    evidence: "认词率与中文到俄语产出率相差至少 20 个百分点。",
                    explanation: "这可能提示主动提取弱于被动识别，建议优先练中文到俄语。"
                )
            )
        }
        if metrics.medianResponseSeconds
            >= DiagnosticThresholds.slowRetrievalSeconds
        {
            findings.append(
                DiagnosticFinding(
                    type: .slowRetrieval,
                    severity: .notice,
                    evidence: "回答时间中位数达到或超过 3 秒。",
                    explanation: "这可能提示提取仍不够自动化，可用短时限回忆训练。"
                )
            )
        }
        if metrics.listeningEvidenceCount > 0
            && metrics.recognitionRate - metrics.listeningRate
            >= DiagnosticThresholds.listeningGapMinimum
        {
            findings.append(
                DiagnosticFinding(
                    type: .listeningGap,
                    severity: .focus,
                    evidence: "认词率与听句理解率相差至少 20 个百分点。",
                    explanation: "这可能提示声音到词义的连接偏弱，建议增加听句和开口模式。"
                )
            )
        }
        if metrics.recognitionRate
            >= DiagnosticThresholds.collocationRecognitionMinimum
            && metrics.collocationRate
                < DiagnosticThresholds.collocationRateMinimum
        {
            findings.append(
                DiagnosticFinding(
                    type: .collocationGap,
                    severity: .notice,
                    evidence: "认词率达到 70%，但搭配自评低于 60%。",
                    explanation: "这可能提示单词认识多于搭配运用，建议以短语块复习。"
                )
            )
        }
        if metrics.selfMonitoringRate
            >= DiagnosticThresholds.selfMonitoringMinimum
        {
            findings.append(
                DiagnosticFinding(
                    type: .selfMonitoring,
                    severity: .notice,
                    evidence: "自评卡顿或过度检查达到 60%。",
                    explanation: "这可能提示表达时自我监控偏多，可先完整说完再回看。"
                )
            )
        }
        return findings
    }

    public func report(
        baseline: DiagnosticMetrics,
        current: DiagnosticMetrics,
        seed: UInt64 = 0,
        sampleLexemeIDs: [String] = [],
        listeningSentenceIDs: [String] = [],
        sampleWasRepaired: Bool = false
    ) -> DiagnosticReport {
        DiagnosticReport(
            diagnosticVersion: 2,
            seed: seed,
            sampleLexemeIDs: sampleLexemeIDs,
            listeningSentenceIDs: listeningSentenceIDs,
            sampleWasRepaired: sampleWasRepaired,
            baseline: baseline,
            current: current,
            findings: findings(for: current),
            deltas: DiagnosticDeltas(
                recognitionPoints:
                    current.recognitionRate - baseline.recognitionRate,
                productionPoints:
                    current.productionRate - baseline.productionRate,
                responseSeconds:
                    current.medianResponseSeconds
                    - baseline.medianResponseSeconds,
                listeningPoints:
                    current.listeningRate - baseline.listeningRate,
                collocationPoints:
                    current.collocationRate - baseline.collocationRate,
                selfMonitoringPoints:
                    current.selfMonitoringRate
                    - baseline.selfMonitoringRate
            )
        )
    }
}

public struct DiagnosticSample: Equatable, Sendable {
    public let recognition: [Lexeme]
    public let production: [Lexeme]
    public let listening: [SentenceCard]

    public init(
        recognition: [Lexeme],
        production: [Lexeme],
        listening: [SentenceCard]
    ) {
        self.recognition = recognition
        self.production = production
        self.listening = listening
    }
}

public struct DiagnosticSampler: Sendable {
    public init() {}

    public func sample(
        from catalog: ContentCatalog,
        seed: UInt64,
        vocabularyCount: Int = 10,
        listeningCount: Int = 10,
        preferredLexemeIDs: [String] = [],
        preferredListeningSentenceIDs: [String] = []
    ) -> DiagnosticSample {
        var generator = SeededDiagnosticGenerator(seed: seed)
        let fallbackListening = themeRoundRobin(
            catalog.sentences,
            count: listeningCount,
            generator: &generator
        )
        let fallbackLexemes = themeRoundRobin(
            catalog.lexemes,
            sentences: catalog.sentences,
            count: min(catalog.lexemes.count, vocabularyCount),
            generator: &generator
        )
        let lexemesByID = Dictionary(
            uniqueKeysWithValues: catalog.lexemes.map { ($0.id, $0) }
        )
        let sentencesByID = Dictionary(
            uniqueKeysWithValues: catalog.sentences.map { ($0.id, $0) }
        )
        let recognition = resolve(
            preferredIDs: preferredLexemeIDs,
            itemsByID: lexemesByID,
            fallback: fallbackLexemes,
            count: vocabularyCount
        )
        let listening = resolve(
            preferredIDs: preferredListeningSentenceIDs,
            itemsByID: sentencesByID,
            fallback: fallbackListening,
            count: listeningCount
        )
        return DiagnosticSample(
            recognition: recognition,
            production: recognition,
            listening: listening
        )
    }

    private func resolve<Element: Identifiable>(
        preferredIDs: [String],
        itemsByID: [String: Element],
        fallback: [Element],
        count: Int
    ) -> [Element] where Element.ID == String {
        guard count > 0 else { return [] }
        var seen: Set<String> = []
        var result: [Element] = []
        for id in preferredIDs {
            guard let item = itemsByID[id], seen.insert(id).inserted else {
                continue
            }
            result.append(item)
            if result.count == count {
                return result
            }
        }
        for item in fallback where seen.insert(item.id).inserted {
            result.append(item)
            if result.count == count {
                break
            }
        }
        return result
    }

    private func themeRoundRobin(
        _ sentences: [SentenceCard],
        count: Int,
        generator: inout SeededDiagnosticGenerator
    ) -> [SentenceCard] {
        var groups = Dictionary(grouping: sentences, by: \.theme)
        var themes = Array(groups.keys).sorted()
        themes.shuffle(using: &generator)
        for theme in themes {
            groups[theme]?.shuffle(using: &generator)
        }
        return roundRobin(
            groups: groups,
            keys: themes,
            count: count
        )
    }

    private func themeRoundRobin(
        _ lexemes: [Lexeme],
        sentences: [SentenceCard],
        count: Int,
        generator: inout SeededDiagnosticGenerator
    ) -> [Lexeme] {
        let themesBySentenceID = Dictionary(
            uniqueKeysWithValues: sentences.map { ($0.id, $0.theme) }
        )
        var groups = Dictionary(grouping: lexemes) { lexeme in
            lexeme.sentenceIDs.compactMap { themesBySentenceID[$0] }.first
                ?? "其他"
        }
        var themes = Array(groups.keys).sorted()
        themes.shuffle(using: &generator)
        for theme in themes {
            groups[theme]?.shuffle(using: &generator)
        }
        return roundRobin(
            groups: groups,
            keys: themes,
            count: count
        )
    }

    private func roundRobin<Element>(
        groups: [String: [Element]],
        keys: [String],
        count: Int
    ) -> [Element] {
        guard count > 0 else { return [] }
        var indices = Dictionary(
            uniqueKeysWithValues: keys.map { ($0, 0) }
        )
        var result: [Element] = []
        while result.count < count {
            var added = false
            for key in keys {
                let index = indices[key, default: 0]
                guard let values = groups[key], values.indices.contains(index)
                else {
                    continue
                }
                result.append(values[index])
                indices[key] = index + 1
                added = true
                if result.count == count {
                    break
                }
            }
            if !added {
                break
            }
        }
        return result
    }
}

private struct SeededDiagnosticGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
