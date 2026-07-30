import Foundation

public struct SupplementalContentManifest:
    Codable,
    Equatable,
    Sendable
{
    public let schemaVersion: Int
    public let contentGateClosed: Bool
    public let allowedSourceRoots: [String]
    public let sourceHashes: [String: String]
    public let candidateCount: Int
    public let reviewedSentenceCount: Int
    public let reviewedLexemeCount: Int
    public let excludedCount: Int

    public init(
        schemaVersion: Int,
        contentGateClosed: Bool,
        allowedSourceRoots: [String],
        sourceHashes: [String: String],
        candidateCount: Int,
        reviewedSentenceCount: Int,
        reviewedLexemeCount: Int,
        excludedCount: Int
    ) {
        self.schemaVersion = schemaVersion
        self.contentGateClosed = contentGateClosed
        self.allowedSourceRoots = allowedSourceRoots
        self.sourceHashes = sourceHashes
        self.candidateCount = candidateCount
        self.reviewedSentenceCount = reviewedSentenceCount
        self.reviewedLexemeCount = reviewedLexemeCount
        self.excludedCount = excludedCount
    }
}

public struct SpeakingChallenge:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let promptRu: String
    public let promptZh: String
    public let structureHintsZh: [String]
    public let replacementSlots: [String]
    public let lexemeIDs: [String]
    public let sourcePath: String
    public let sourceText: String
    public let sourceHash: String
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let qualityFlags: [ContentQualityFlag]

    public init(
        id: String,
        promptRu: String,
        promptZh: String,
        structureHintsZh: [String],
        replacementSlots: [String],
        lexemeIDs: [String],
        sourcePath: String,
        sourceText: String,
        sourceHash: String,
        reviewStatus: ReviewStatus,
        provenanceType: ProvenanceType,
        qualityFlags: [ContentQualityFlag]
    ) {
        self.id = id
        self.promptRu = promptRu
        self.promptZh = promptZh
        self.structureHintsZh = structureHintsZh
        self.replacementSlots = replacementSlots
        self.lexemeIDs = lexemeIDs
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.sourceHash = sourceHash
        self.reviewStatus = reviewStatus
        self.provenanceType = provenanceType
        self.qualityFlags = qualityFlags
    }
}

public struct SupplementalContentBundle: Equatable, Sendable {
    public let manifest: SupplementalContentManifest
    public let lexemes: [Lexeme]
    public let sentences: [SentenceCard]
    public let speakingChallenges: [SpeakingChallenge]

    public init(
        manifest: SupplementalContentManifest,
        lexemes: [Lexeme],
        sentences: [SentenceCard],
        speakingChallenges: [SpeakingChallenge]
    ) {
        self.manifest = manifest
        self.lexemes = lexemes
        self.sentences = sentences
        self.speakingChallenges = speakingChallenges
    }
}

public enum SupplementalContentError: LocalizedError, Equatable {
    case partialResources
    case validationFailed([String])

    public var errorDescription: String? {
        switch self {
        case .partialResources:
            "补充语料资源不完整，已仅加载核心语料"
        case .validationFailed(let issues):
            "补充语料未通过安全检查：\(issues.joined(separator: "；"))"
        }
    }
}
