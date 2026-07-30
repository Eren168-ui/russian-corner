import Foundation

public enum EnglishCandidateKind:
    String,
    Codable,
    Equatable,
    Sendable
{
    case word
    case expression
    case example
    case mnemonic
    case unknown
}

public struct EnglishCandidateContent:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let kind: EnglishCandidateKind
    public let targetText: String
    public let sourcePath: String
    public let sourceText: String
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let qualityFlags: [ContentQualityFlag]

    public init(
        id: String,
        kind: EnglishCandidateKind,
        targetText: String,
        sourcePath: String,
        sourceText: String,
        reviewStatus: ReviewStatus = .draft,
        provenanceType: ProvenanceType = .userNote,
        qualityFlags: [ContentQualityFlag] = []
    ) {
        self.id = id
        self.kind = kind
        self.targetText = targetText
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.reviewStatus = reviewStatus
        self.provenanceType = provenanceType
        self.qualityFlags = qualityFlags
    }
}

public struct EnglishCorpusAudit:
    Codable,
    Equatable,
    Sendable
{
    public let totalMarkdownFileCount: Int
    public let excludedFileCount: Int
    public let excludedReasons: [String: Int]
    public let snapshots: [EnglishSourceSnapshot]
    public let candidates: [EnglishCandidateContent]

    public init(
        totalMarkdownFileCount: Int,
        excludedFileCount: Int,
        excludedReasons: [String: Int],
        snapshots: [EnglishSourceSnapshot],
        candidates: [EnglishCandidateContent]
    ) {
        self.totalMarkdownFileCount = totalMarkdownFileCount
        self.excludedFileCount = excludedFileCount
        self.excludedReasons = excludedReasons
        self.snapshots = snapshots
        self.candidates = candidates
    }
}

public struct EnglishSourceSnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let relativePath: String
    public let sha256: String

    public init(relativePath: String, sha256: String) {
        self.relativePath = relativePath
        self.sha256 = sha256
    }
}
