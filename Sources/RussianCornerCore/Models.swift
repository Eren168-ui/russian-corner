import Foundation

public enum ReviewGrade: String, Codable, Equatable, Sendable {
    case again
    case hard
    case easy
}

public struct ReviewState: Codable, Equatable, Sendable {
    public var masteryLevel: Int
    public var dueAt: Date

    public init(masteryLevel: Int, dueAt: Date) {
        self.masteryLevel = masteryLevel
        self.dueAt = dueAt
    }
}

public enum ReviewStatus: String, Codable, Equatable, Sendable {
    case draft
    case reviewed
    case verified
}

public enum PracticeItemKind: String, Codable, Equatable, Sendable {
    case lexeme
    case sentence
}

public struct PracticeItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: PracticeItemKind

    public init(id: String, kind: PracticeItemKind) {
        self.id = id
        self.kind = kind
    }
}

public struct Lexeme: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let lemma: String
    public let stressedForm: String
    public let speechText: String
    public let partOfSpeech: String
    public let glossZh: String
    public let collocations: [String]
    public let example: String
    public let sentenceIDs: [String]
    public let reviewStatus: ReviewStatus
    public let grammaticalGender: String?
    public let aspect: String?
    public let principalForms: [String]?
    public let surfaceForms: [String]

    public init(
        id: String,
        lemma: String,
        stressedForm: String,
        speechText: String,
        partOfSpeech: String,
        glossZh: String,
        collocations: [String],
        example: String,
        sentenceIDs: [String],
        reviewStatus: ReviewStatus,
        grammaticalGender: String? = nil,
        aspect: String? = nil,
        principalForms: [String]? = nil,
        surfaceForms: [String] = []
    ) {
        self.id = id
        self.lemma = lemma
        self.stressedForm = stressedForm
        self.speechText = speechText
        self.partOfSpeech = partOfSpeech
        self.glossZh = glossZh
        self.collocations = collocations
        self.example = example
        self.sentenceIDs = sentenceIDs
        self.reviewStatus = reviewStatus
        self.grammaticalGender = grammaticalGender
        self.aspect = aspect
        self.principalForms = principalForms
        self.surfaceForms = surfaceForms
    }
}

public struct SentenceCard: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let promptZh: String
    public let practiceRu: String
    public let speechText: String
    public let theme: String
    public let lexemeIDs: [String]
    public let sourcePath: String
    public let sourceText: String
    public let reviewStatus: ReviewStatus

    public init(
        id: String,
        promptZh: String,
        practiceRu: String,
        speechText: String,
        theme: String,
        lexemeIDs: [String],
        sourcePath: String,
        sourceText: String,
        reviewStatus: ReviewStatus
    ) {
        self.id = id
        self.promptZh = promptZh
        self.practiceRu = practiceRu
        self.speechText = speechText
        self.theme = theme
        self.lexemeIDs = lexemeIDs
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.reviewStatus = reviewStatus
    }
}
