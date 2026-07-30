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

public enum ProvenanceType: String, Codable, Equatable, Sendable {
    case courseMaterial
    case userNote
    case aiGenerated
    case derived
}

public enum CorpusLayer: String, Codable, Equatable, Sendable {
    case core
    case dailySupplement
    case speakingChallenge
}

public enum ContentQualityFlag: String, Codable, Equatable, Sendable {
    case typo
    case grammarSuspect
    case unnatural
    case ambiguousTranslation
    case incomplete
    case emptyDialogue
    case mixedAnnotation
    case possiblyDated
    case needsNativeReview
}

public enum DialogueRegister: String, Codable, Equatable, Sendable {
    case informal
    case neutral
    case polite
    case formal
    case textbook
    case possiblyDated
}

public enum AddressForm: String, Codable, Equatable, Sendable {
    case `ты`
    case `вы`
    case notApplicable
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
    public let aspectPairNote: String?
    public let government: String?
    public let principalForms: [String]?
    public let surfaceForms: [String]
    public let sourcePaths: [String]
    public let sourceTexts: [String]
    public let provenanceTypes: [ProvenanceType]
    public let qualityFlags: [ContentQualityFlag]
    public let usageNote: String?
    public let contrastNote: String?
    public let commonMistakes: [String]
    public let contrastGroupID: String?
    public let corpusLayer: CorpusLayer

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
        aspectPairNote: String? = nil,
        government: String? = nil,
        principalForms: [String]? = nil,
        surfaceForms: [String] = [],
        sourcePaths: [String] = [],
        sourceTexts: [String] = [],
        provenanceTypes: [ProvenanceType] = [],
        qualityFlags: [ContentQualityFlag] = [],
        usageNote: String? = nil,
        contrastNote: String? = nil,
        commonMistakes: [String] = [],
        contrastGroupID: String? = nil,
        corpusLayer: CorpusLayer = .core
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
        self.aspectPairNote = aspectPairNote
        self.government = government
        self.principalForms = principalForms
        self.surfaceForms = surfaceForms
        self.sourcePaths = sourcePaths
        self.sourceTexts = sourceTexts
        self.provenanceTypes = provenanceTypes
        self.qualityFlags = qualityFlags
        self.usageNote = usageNote
        self.contrastNote = contrastNote
        self.commonMistakes = commonMistakes
        self.contrastGroupID = contrastGroupID
        self.corpusLayer = corpusLayer
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case lemma
        case stressedForm
        case speechText
        case partOfSpeech
        case glossZh
        case collocations
        case example
        case sentenceIDs
        case reviewStatus
        case grammaticalGender
        case aspect
        case aspectPair
        case aspectPairNote
        case government
        case principalForms
        case surfaceForms
        case sourcePaths
        case sourceTexts
        case provenanceTypes
        case qualityFlags
        case usageNote
        case contrastNote
        case commonMistakes
        case contrastGroupID
        case corpusLayer
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lemma = try container.decode(String.self, forKey: .lemma)
        stressedForm = try container.decode(
            String.self,
            forKey: .stressedForm
        )
        speechText = try container.decode(String.self, forKey: .speechText)
        partOfSpeech = try container.decode(
            String.self,
            forKey: .partOfSpeech
        )
        glossZh = try container.decode(String.self, forKey: .glossZh)
        collocations = try container.decode(
            [String].self,
            forKey: .collocations
        )
        example = try container.decode(String.self, forKey: .example)
        sentenceIDs = try container.decode(
            [String].self,
            forKey: .sentenceIDs
        )
        reviewStatus = try container.decode(
            ReviewStatus.self,
            forKey: .reviewStatus
        )
        grammaticalGender = try container.decodeIfPresent(
            String.self,
            forKey: .grammaticalGender
        )
        aspect = try container.decodeIfPresent(
            String.self,
            forKey: .aspect
        )
        aspectPair = try container.decodeIfPresent(
            String.self,
            forKey: .aspectPair
        )
        aspectPairNote = try container.decodeIfPresent(
            String.self,
            forKey: .aspectPairNote
        )
        government = try container.decodeIfPresent(
            String.self,
            forKey: .government
        )
        principalForms = try container.decodeIfPresent(
            [String].self,
            forKey: .principalForms
        )
        surfaceForms = try container.decodeIfPresent(
            [String].self,
            forKey: .surfaceForms
        ) ?? []
        sourcePaths = try container.decodeIfPresent(
            [String].self,
            forKey: .sourcePaths
        ) ?? []
        sourceTexts = try container.decodeIfPresent(
            [String].self,
            forKey: .sourceTexts
        ) ?? []
        provenanceTypes = try container.decodeIfPresent(
            [ProvenanceType].self,
            forKey: .provenanceTypes
        ) ?? []
        qualityFlags = try container.decodeIfPresent(
            [ContentQualityFlag].self,
            forKey: .qualityFlags
        ) ?? []
        usageNote = try container.decodeIfPresent(
            String.self,
            forKey: .usageNote
        )
        contrastNote = try container.decodeIfPresent(
            String.self,
            forKey: .contrastNote
        )
        commonMistakes = try container.decodeIfPresent(
            [String].self,
            forKey: .commonMistakes
        ) ?? []
        contrastGroupID = try container.decodeIfPresent(
            String.self,
            forKey: .contrastGroupID
        )
        corpusLayer = try container.decodeIfPresent(
            CorpusLayer.self,
            forKey: .corpusLayer
        ) ?? .core
    }
}

public struct SentenceCard: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let promptZh: String
    public let cueRu: String
    public let practiceRu: String
    public let stressedForm: String?
    public let speechText: String
    public let theme: String
    public let lexemeIDs: [String]
    public let sourcePath: String
    public let sourceText: String
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType?
    public let qualityFlags: [ContentQualityFlag]
    public let dialogueAct: String?
    public let register: DialogueRegister?
    public let speakerRole: String?
    public let addressForm: AddressForm?
    public let expectedReply: String?
    public let alternativeReplyIDs: [String]
    public let topicID: String?
    public let sourceHash: String?
    public let corpusLayer: CorpusLayer

    public init(
        id: String,
        promptZh: String,
        cueRu: String,
        practiceRu: String,
        stressedForm: String? = nil,
        speechText: String,
        theme: String,
        lexemeIDs: [String],
        sourcePath: String,
        sourceText: String,
        reviewStatus: ReviewStatus,
        provenanceType: ProvenanceType? = nil,
        qualityFlags: [ContentQualityFlag] = [],
        dialogueAct: String? = nil,
        register: DialogueRegister? = nil,
        speakerRole: String? = nil,
        addressForm: AddressForm? = nil,
        expectedReply: String? = nil,
        alternativeReplyIDs: [String] = [],
        topicID: String? = nil,
        sourceHash: String? = nil,
        corpusLayer: CorpusLayer = .core
    ) {
        self.id = id
        self.promptZh = promptZh
        self.cueRu = cueRu
        self.practiceRu = practiceRu
        self.stressedForm = stressedForm
        self.speechText = speechText
        self.theme = theme
        self.lexemeIDs = lexemeIDs
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.reviewStatus = reviewStatus
        self.provenanceType = provenanceType
        self.qualityFlags = qualityFlags
        self.dialogueAct = dialogueAct
        self.register = register
        self.speakerRole = speakerRole
        self.addressForm = addressForm
        self.expectedReply = expectedReply
        self.alternativeReplyIDs = alternativeReplyIDs
        self.topicID = topicID
        self.sourceHash = sourceHash
        self.corpusLayer = corpusLayer
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case promptZh
        case cueRu
        case practiceRu
        case stressedForm
        case speechText
        case theme
        case lexemeIDs
        case sourcePath
        case sourceText
        case reviewStatus
        case provenanceType
        case qualityFlags
        case dialogueAct
        case register
        case speakerRole
        case addressForm
        case expectedReply
        case alternativeReplyIDs
        case topicID
        case sourceHash
        case corpusLayer
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        promptZh = try container.decode(String.self, forKey: .promptZh)
        practiceRu = try container.decode(
            String.self,
            forKey: .practiceRu
        )
        stressedForm = try container.decodeIfPresent(
            String.self,
            forKey: .stressedForm
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
        provenanceType = try container.decodeIfPresent(
            ProvenanceType.self,
            forKey: .provenanceType
        )
        qualityFlags = try container.decodeIfPresent(
            [ContentQualityFlag].self,
            forKey: .qualityFlags
        ) ?? []
        dialogueAct = try container.decodeIfPresent(
            String.self,
            forKey: .dialogueAct
        )
        register = try container.decodeIfPresent(
            DialogueRegister.self,
            forKey: .register
        )
        speakerRole = try container.decodeIfPresent(
            String.self,
            forKey: .speakerRole
        )
        addressForm = try container.decodeIfPresent(
            AddressForm.self,
            forKey: .addressForm
        )
        expectedReply = try container.decodeIfPresent(
            String.self,
            forKey: .expectedReply
        )
        alternativeReplyIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .alternativeReplyIDs
        ) ?? []
        topicID = try container.decodeIfPresent(
            String.self,
            forKey: .topicID
        )
        sourceHash = try container.decodeIfPresent(
            String.self,
            forKey: .sourceHash
        )
        corpusLayer = try container.decodeIfPresent(
            CorpusLayer.self,
            forKey: .corpusLayer
        ) ?? .core
    }
}

public struct TrialLexemeReview: Codable, Equatable, Sendable {
    public let lexemeID: String
    public let supportingSentenceID: String
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let qualityFlags: [ContentQualityFlag]

    public init(
        lexemeID: String,
        supportingSentenceID: String,
        reviewStatus: ReviewStatus,
        provenanceType: ProvenanceType,
        qualityFlags: [ContentQualityFlag] = []
    ) {
        self.lexemeID = lexemeID
        self.supportingSentenceID = supportingSentenceID
        self.reviewStatus = reviewStatus
        self.provenanceType = provenanceType
        self.qualityFlags = qualityFlags
    }
}

public struct TrialWordEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let lookupForm: String
    public let stressedForm: String
    public let lemma: String
    public let glossZh: String
    public let partOfSpeech: String
    public let aspectPair: String?
    public let government: String?
    public let collocations: [String]
    public let usageNote: String
    public let lexemeID: String?
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let qualityFlags: [ContentQualityFlag]

    public init(
        id: String,
        lookupForm: String,
        stressedForm: String,
        lemma: String,
        glossZh: String,
        partOfSpeech: String,
        aspectPair: String? = nil,
        government: String? = nil,
        collocations: [String] = [],
        usageNote: String,
        lexemeID: String? = nil,
        reviewStatus: ReviewStatus,
        provenanceType: ProvenanceType,
        qualityFlags: [ContentQualityFlag] = []
    ) {
        self.id = id
        self.lookupForm = lookupForm
        self.stressedForm = stressedForm
        self.lemma = lemma
        self.glossZh = glossZh
        self.partOfSpeech = partOfSpeech
        self.aspectPair = aspectPair
        self.government = government
        self.collocations = collocations
        self.usageNote = usageNote
        self.lexemeID = lexemeID
        self.reviewStatus = reviewStatus
        self.provenanceType = provenanceType
        self.qualityFlags = qualityFlags
    }
}

public struct SentenceWordToken: Codable, Equatable, Sendable {
    public let cardID: String
    public let tokenIndex: Int
    public let surfaceText: String
    public let wordEntryID: String
    public let morphology: String

    public init(
        cardID: String,
        tokenIndex: Int,
        surfaceText: String,
        wordEntryID: String,
        morphology: String
    ) {
        self.cardID = cardID
        self.tokenIndex = tokenIndex
        self.surfaceText = surfaceText
        self.wordEntryID = wordEntryID
        self.morphology = morphology
    }
}

public enum WordAnalysisSource: String, Codable, Equatable, Sendable {
    case reviewedContext
    case reviewedLexeme
    case onlineUnreviewed
    case unavailable
}

public struct ResolvedWordAnalysis: Identifiable, Equatable, Sendable {
    public let cardID: String
    public let tokenIndex: Int
    public let surfaceText: String
    public let stressedForm: String
    public let lemma: String
    public let glossZh: String
    public let partOfSpeech: String
    public let morphology: String
    public let aspectPair: String?
    public let government: String?
    public let collocations: [String]
    public let usageNote: String
    public let lexemeID: String?
    public let reviewStatus: ReviewStatus
    public let source: WordAnalysisSource

    public var id: String {
        "\(cardID):\(tokenIndex)"
    }

    public init(
        cardID: String,
        tokenIndex: Int,
        surfaceText: String,
        stressedForm: String,
        lemma: String,
        glossZh: String,
        partOfSpeech: String,
        morphology: String,
        aspectPair: String? = nil,
        government: String? = nil,
        collocations: [String] = [],
        usageNote: String,
        lexemeID: String? = nil,
        reviewStatus: ReviewStatus,
        source: WordAnalysisSource = .reviewedContext
    ) {
        self.cardID = cardID
        self.tokenIndex = tokenIndex
        self.surfaceText = surfaceText
        self.stressedForm = stressedForm
        self.lemma = lemma
        self.glossZh = glossZh
        self.partOfSpeech = partOfSpeech
        self.morphology = morphology
        self.aspectPair = aspectPair
        self.government = government
        self.collocations = collocations
        self.usageNote = usageNote
        self.lexemeID = lexemeID
        self.reviewStatus = reviewStatus
        self.source = source
    }
}

public enum RussianWordTokenizer {
    public static func words(in text: String) -> [String] {
        var words: [String] = []
        var current = ""

        for character in text {
            if character.unicodeScalars.allSatisfy(isRussianLetter) {
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words
    }

    private static func isRussianLetter(_ scalar: UnicodeScalar) -> Bool {
        (0x0410...0x044F).contains(scalar.value)
            || scalar.value == 0x0401
            || scalar.value == 0x0451
            || scalar.value == 0x0301
    }
}

public struct TrialContentSlice: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sourceRoot: String
    public let sentences: [SentenceCard]
    public let lexemeReviews: [TrialLexemeReview]
    public let manualReviewSampleIDs: [String]
    public let wordEntries: [TrialWordEntry]
    public let sentenceWordTokens: [SentenceWordToken]

    public init(
        schemaVersion: Int,
        sourceRoot: String,
        sentences: [SentenceCard],
        lexemeReviews: [TrialLexemeReview],
        manualReviewSampleIDs: [String],
        wordEntries: [TrialWordEntry] = [],
        sentenceWordTokens: [SentenceWordToken] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sourceRoot = sourceRoot
        self.sentences = sentences
        self.lexemeReviews = lexemeReviews
        self.manualReviewSampleIDs = manualReviewSampleIDs
        self.wordEntries = wordEntries
        self.sentenceWordTokens = sentenceWordTokens
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sourceRoot
        case sentences
        case lexemeReviews
        case manualReviewSampleIDs
        case wordEntries
        case sentenceWordTokens
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(
            Int.self,
            forKey: .schemaVersion
        )
        sourceRoot = try container.decode(
            String.self,
            forKey: .sourceRoot
        )
        sentences = try container.decode(
            [SentenceCard].self,
            forKey: .sentences
        )
        lexemeReviews = try container.decode(
            [TrialLexemeReview].self,
            forKey: .lexemeReviews
        )
        manualReviewSampleIDs = try container.decode(
            [String].self,
            forKey: .manualReviewSampleIDs
        )
        wordEntries = try container.decodeIfPresent(
            [TrialWordEntry].self,
            forKey: .wordEntries
        ) ?? []
        sentenceWordTokens = try container.decodeIfPresent(
            [SentenceWordToken].self,
            forKey: .sentenceWordTokens
        ) ?? []
    }

    public var cardCount: Int {
        sentences.count + lexemeReviews.count
    }

    public var lexemeIDs: Set<String> {
        Set(lexemeReviews.map(\.lexemeID))
    }
}
