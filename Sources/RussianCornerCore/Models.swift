import Foundation

public enum ReviewGrade: String, Codable, Equatable, Sendable {
    case again
    case hard
    case easy
}

public enum PracticeMode: String, Codable, Equatable, Sendable {
    case quiet
    case speaking
}

public struct ReviewEvent: Codable, Equatable, Sendable {
    public let itemType: PracticeItemKind
    public let itemId: String
    public let grade: ReviewGrade
    public let responseTimeMs: Int
    public let practiceMode: PracticeMode
    public let createdAt: Date

    public init(
        itemType: PracticeItemKind,
        itemId: String,
        grade: ReviewGrade,
        responseTimeMs: Int,
        practiceMode: PracticeMode,
        createdAt: Date
    ) {
        self.itemType = itemType
        self.itemId = itemId
        self.grade = grade
        self.responseTimeMs = responseTimeMs
        self.practiceMode = practiceMode
        self.createdAt = createdAt
    }
}

public struct ReminderTime: Codable, Equatable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

public struct RussianCornerSettings: Codable, Equatable, Sendable {
    public var morningReminder: ReminderTime
    public var eveningReminder: ReminderTime

    public var reminderTimes: [ReminderTime] {
        [morningReminder, eveningReminder]
    }

    public init(
        morningReminder: ReminderTime = ReminderTime(hour: 11, minute: 30),
        eveningReminder: ReminderTime = ReminderTime(hour: 17, minute: 30)
    ) {
        self.morningReminder = morningReminder
        self.eveningReminder = eveningReminder
    }
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
    public let aspectPair: String?
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
        aspectPair: String? = nil,
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
        self.aspectPair = aspectPair
        self.principalForms = principalForms
        self.surfaceForms = surfaceForms
    }
}

public struct SentenceCard: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let promptZh: String
    public let cueRu: String
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
        cueRu: String,
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
        self.cueRu = cueRu
        self.practiceRu = practiceRu
        self.speechText = speechText
        self.theme = theme
        self.lexemeIDs = lexemeIDs
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.reviewStatus = reviewStatus
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case promptZh
        case cueRu
        case practiceRu
        case speechText
        case theme
        case lexemeIDs
        case sourcePath
        case sourceText
        case reviewStatus
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        promptZh = try container.decode(String.self, forKey: .promptZh)
        practiceRu = try container.decode(
            String.self,
            forKey: .practiceRu
        )
        cueRu = try container.decodeIfPresent(
            String.self,
            forKey: .cueRu
        ) ?? practiceRu
        speechText = try container.decode(
            String.self,
            forKey: .speechText
        )
        theme = try container.decode(String.self, forKey: .theme)
        lexemeIDs = try container.decode(
            [String].self,
            forKey: .lexemeIDs
        )
        sourcePath = try container.decode(
            String.self,
            forKey: .sourcePath
        )
        sourceText = try container.decode(
            String.self,
            forKey: .sourceText
        )
        reviewStatus = try container.decode(
            ReviewStatus.self,
            forKey: .reviewStatus
        )
    }
}
