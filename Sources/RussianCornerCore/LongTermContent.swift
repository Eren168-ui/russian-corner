import Foundation

public struct TopicDefinition:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let number: Int
    public let titleRu: String
    public let titleZh: String
    public let sourcePath: String

    public init(
        id: String,
        number: Int,
        titleRu: String,
        titleZh: String,
        sourcePath: String
    ) {
        self.id = id
        self.number = number
        self.titleRu = titleRu
        self.titleZh = titleZh
        self.sourcePath = sourcePath
    }
}

public struct LongTermContentManifest:
    Codable,
    Equatable,
    Sendable
{
    public let schemaVersion: Int
    public let sourceRoot: String
    public let sourceCorpusSHA256: String
    public let contentGateClosed: Bool
    public let sentences: [SentenceCard]

    public init(
        schemaVersion: Int,
        sourceRoot: String,
        sourceCorpusSHA256: String,
        contentGateClosed: Bool,
        sentences: [SentenceCard]
    ) {
        self.schemaVersion = schemaVersion
        self.sourceRoot = sourceRoot
        self.sourceCorpusSHA256 = sourceCorpusSHA256
        self.contentGateClosed = contentGateClosed
        self.sentences = sentences
    }
}
