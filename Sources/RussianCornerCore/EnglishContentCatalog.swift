import Foundation

public struct StudyTopic:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let language: StudyLanguage
    public let titleTarget: String
    public let titleZh: String
    public let descriptionZh: String
    public let sentenceIDs: [String]

    public init(
        id: String,
        language: StudyLanguage,
        titleTarget: String,
        titleZh: String,
        descriptionZh: String,
        sentenceIDs: [String]
    ) {
        self.id = id
        self.language = language
        self.titleTarget = titleTarget
        self.titleZh = titleZh
        self.descriptionZh = descriptionZh
        self.sentenceIDs = sentenceIDs
    }
}

public struct SceneLesson:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let language: StudyLanguage
    public let topicID: String
    public let titleZh: String
    public let contextZh: String
    public let sentenceIDs: [String]
    public let dialogueOrder: [String]

    public init(
        id: String,
        language: StudyLanguage,
        topicID: String,
        titleZh: String,
        contextZh: String,
        sentenceIDs: [String],
        dialogueOrder: [String]
    ) {
        self.id = id
        self.language = language
        self.topicID = topicID
        self.titleZh = titleZh
        self.contextZh = contextZh
        self.sentenceIDs = sentenceIDs
        self.dialogueOrder = dialogueOrder
    }
}

public struct EnglishContentBundle: Sendable {
    public let catalog: LanguageContentCatalog
    public let topics: [StudyTopic]
    public let lessons: [SceneLesson]

    public init(resourceDirectory: URL) throws {
        let decoder = JSONDecoder()
        let lexemes = try Self.decode(
            [StudyLexeme].self,
            name: "english-lexemes",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let sentences = try Self.decode(
            [StudySentence].self,
            name: "english-sentences",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        topics = try Self.decode(
            [StudyTopic].self,
            name: "english-topics",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        lessons = try Self.decode(
            [SceneLesson].self,
            name: "english-lessons",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let catalog = LanguageContentCatalog(
            lexemes: lexemes,
            sentences: sentences
        )
        let issues = catalog.validate()
        guard issues.isEmpty else {
            throw ContentCatalogError.validationFailed(issues)
        }
        self.catalog = catalog
    }

    public init(
        catalog: LanguageContentCatalog,
        topics: [StudyTopic],
        lessons: [SceneLesson]
    ) {
        self.catalog = catalog
        self.topics = topics
        self.lessons = lessons
    }

    public static func defaultResourceDirectory(
        bundleIdentifier: String?,
        bundleResourceURL: URL?,
        currentDirectoryURL: URL
    ) throws -> URL {
        if bundleIdentifier != nil {
            guard let bundleResourceURL else {
                throw ContentCatalogError.missingResource(
                    "resourceDirectory"
                )
            }
            return bundleResourceURL
        }
        return currentDirectoryURL
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("RussianCornerCore", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        name: String,
        resourceDirectory: URL,
        decoder: JSONDecoder
    ) throws -> T {
        let url = resourceDirectory.appendingPathComponent(
            "\(name).json"
        )
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ContentCatalogError.missingResource(name)
        }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
