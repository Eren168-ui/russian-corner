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

public struct EnglishContentBundle: Sendable {
    private static let priorityTopicIDs: [String] = [
        "en.topic.21.campus-teacher-greetings",
        "en.topic.22.asking-teacher-help",
        "en.topic.23.classroom-questions",
        "en.topic.24.classroom-answers",
    ]

    public let catalog: LanguageContentCatalog
    public let topics: [StudyTopic]
    public let lessons: [SceneLesson]

    public var legacyCatalog: ContentCatalog {
        let sentences = catalog.sentences.map(\.legacyContent)
        let topicDefinitions = topics.enumerated().map { index, topic in
            TopicDefinition(
                id: topic.id,
                number: index + 1,
                titleRu: topic.titleTarget,
                titleZh: topic.titleZh,
                sourcePath: "bundled/english/\(topic.id)"
            )
        }
        return ContentCatalog(
            lexemes: catalog.lexemes.map(\.legacyContent),
            sentences: sentences,
            topics: topicDefinitions,
            longTermManifest: LongTermContentManifest(
                schemaVersion: 2,
                sourceRoot: "",
                sourceCorpusSHA256: "",
                contentGateClosed: true,
                sentences: sentences
            )
        )
    }

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
        let decodedTopics = try Self.decode(
            [StudyTopic].self,
            name: "english-topics",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let decodedLessons = try Self.decode(
            [SceneLesson].self,
            name: "english-lessons",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let orderedTopics = Self.prioritizedTopics(decodedTopics)
        topics = orderedTopics
        lessons = Self.prioritizedLessons(
            decodedLessons,
            topicOrder: orderedTopics
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
        let orderedTopics = Self.prioritizedTopics(topics)
        self.topics = orderedTopics
        self.lessons = Self.prioritizedLessons(
            lessons,
            topicOrder: orderedTopics
        )
    }

    private static func prioritizedTopics(
        _ topics: [StudyTopic]
    ) -> [StudyTopic] {
        topics.sorted { left, right in
            let leftRank = priorityRank(for: left.id)
            let rightRank = priorityRank(for: right.id)
            if leftRank == rightRank {
                return left.id < right.id
            }
            return leftRank < rightRank
        }
    }

    private static func prioritizedLessons(
        _ lessons: [SceneLesson],
        topicOrder: [StudyTopic]
    ) -> [SceneLesson] {
        let ranks = Dictionary(
            uniqueKeysWithValues: topicOrder.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )
        return lessons.sorted {
            let leftRank = ranks[$0.topicID, default: Int.max]
            let rightRank = ranks[$1.topicID, default: Int.max]
            if leftRank == rightRank {
                return $0.id < $1.id
            }
            return leftRank < rightRank
        }
    }

    private static func priorityRank(for topicID: String) -> Int {
        if let index = priorityTopicIDs.firstIndex(of: topicID) {
            return index
        }
        return priorityTopicIDs.count + 1
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
