import Foundation

public enum MemoryNoteKind: String, Codable, Equatable, Sendable {
    case verifiedEtymology
    case morphologicalBreakdown
    case mnemonic
}

public struct MemoryNote: Codable, Equatable, Sendable {
    public let kind: MemoryNoteKind
    public let text: String

    public init(kind: MemoryNoteKind, text: String) {
        self.kind = kind
        self.text = text
    }
}

public struct SentenceVariant: Codable, Equatable, Sendable {
    public let promptZh: String
    public let targetText: String

    public init(promptZh: String, targetText: String) {
        self.promptZh = promptZh
        self.targetText = targetText
    }
}

public struct StudyLexeme: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let language: StudyLanguage
    public let lemma: String
    public let displayForm: String
    public let speechText: String
    public let phonetic: String?
    public let partOfSpeech: String
    public let glossZh: String
    public let inflections: [String]
    public let collocations: [String]
    public let phrasalVerbs: [String]
    public let wordFamily: [String]
    public let morphologyNotes: [String]
    public let memoryNotes: [MemoryNote]
    public let exampleSentenceIDs: [String]
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let sourcePath: String
    public let sourceText: String?
    public let qualityFlags: [ContentQualityFlag]

    public init(
        id: String,
        language: StudyLanguage,
        lemma: String,
        displayForm: String,
        speechText: String,
        phonetic: String? = nil,
        partOfSpeech: String,
        glossZh: String,
        inflections: [String] = [],
        collocations: [String] = [],
        phrasalVerbs: [String] = [],
        wordFamily: [String] = [],
        morphologyNotes: [String] = [],
        memoryNotes: [MemoryNote] = [],
        exampleSentenceIDs: [String] = [],
        reviewStatus: ReviewStatus,
        provenanceType: ProvenanceType,
        sourcePath: String,
        sourceText: String? = nil,
        qualityFlags: [ContentQualityFlag] = []
    ) {
        self.id = id
        self.language = language
        self.lemma = lemma
        self.displayForm = displayForm
        self.speechText = speechText
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.glossZh = glossZh
        self.inflections = inflections
        self.collocations = collocations
        self.phrasalVerbs = phrasalVerbs
        self.wordFamily = wordFamily
        self.morphologyNotes = morphologyNotes
        self.memoryNotes = memoryNotes
        self.exampleSentenceIDs = exampleSentenceIDs
        self.reviewStatus = reviewStatus
        self.provenanceType = provenanceType
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.qualityFlags = qualityFlags
    }
}

public struct StudySentence: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let language: StudyLanguage
    public let promptZh: String
    public let cueText: String
    public let targetText: String
    public let displayText: String
    public let speechText: String
    public let theme: String
    public let lexemeIDs: [String]
    public let dialogueAct: String?
    public let register: DialogueRegister?
    public let speakerRole: String?
    public let addressForm: AddressForm?
    public let expectedReplies: [String]
    public let variants: [SentenceVariant]
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let sourcePath: String
    public let sourceText: String?
    public let qualityFlags: [ContentQualityFlag]
    public let topicID: String?

    public init(
        id: String,
        language: StudyLanguage,
        promptZh: String,
        cueText: String,
        targetText: String,
        displayText: String,
        speechText: String,
        theme: String,
        lexemeIDs: [String],
        dialogueAct: String? = nil,
        register: DialogueRegister? = nil,
        speakerRole: String? = nil,
        addressForm: AddressForm? = nil,
        expectedReplies: [String] = [],
        variants: [SentenceVariant] = [],
        reviewStatus: ReviewStatus,
        provenanceType: ProvenanceType,
        sourcePath: String,
        sourceText: String? = nil,
        qualityFlags: [ContentQualityFlag] = [],
        topicID: String? = nil
    ) {
        self.id = id
        self.language = language
        self.promptZh = promptZh
        self.cueText = cueText
        self.targetText = targetText
        self.displayText = displayText
        self.speechText = speechText
        self.theme = theme
        self.lexemeIDs = lexemeIDs
        self.dialogueAct = dialogueAct
        self.register = register
        self.speakerRole = speakerRole
        self.addressForm = addressForm
        self.expectedReplies = expectedReplies
        self.variants = variants
        self.reviewStatus = reviewStatus
        self.provenanceType = provenanceType
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.qualityFlags = qualityFlags
        self.topicID = topicID
    }
}

public extension Lexeme {
    var studyContent: StudyLexeme {
        let morphologyNotes = [
            grammaticalGender.map { "性：\($0)" },
            aspect.map { "体：\($0)" },
            aspectPair.map { "体对：\($0)" },
            aspectPairNote,
            government.map { "支配：\($0)" },
        ].compactMap { $0 }

        return StudyLexeme(
            id: id,
            language: .russian,
            lemma: lemma,
            displayForm: stressedForm,
            speechText: speechText,
            partOfSpeech: partOfSpeech,
            glossZh: glossZh,
            inflections: (principalForms ?? []) + surfaceForms,
            collocations: collocations,
            morphologyNotes: morphologyNotes,
            exampleSentenceIDs: sentenceIDs,
            reviewStatus: reviewStatus,
            provenanceType: .courseMaterial,
            sourcePath: "bundled/russian/legacy-lexemes",
            sourceText: example
        )
    }
}

public extension SentenceCard {
    var studyContent: StudySentence {
        StudySentence(
            id: id,
            language: .russian,
            promptZh: promptZh,
            cueText: cueRu,
            targetText: practiceRu,
            displayText: stressedForm ?? practiceRu,
            speechText: speechText,
            theme: theme,
            lexemeIDs: lexemeIDs,
            dialogueAct: dialogueAct,
            register: register,
            speakerRole: speakerRole,
            addressForm: addressForm,
            expectedReplies: expectedReply.map { [$0] } ?? [],
            reviewStatus: reviewStatus,
            provenanceType: provenanceType ?? .courseMaterial,
            sourcePath: sourcePath,
            sourceText: sourceText,
            qualityFlags: qualityFlags,
            topicID: topicID
        )
    }
}

public struct LanguageContentCatalog: Sendable {
    public let lexemes: [StudyLexeme]
    public let sentences: [StudySentence]

    public init(
        lexemes: [StudyLexeme],
        sentences: [StudySentence]
    ) {
        let allowedStatuses: Set<ReviewStatus> = [.reviewed, .verified]
        self.lexemes = lexemes.filter {
            allowedStatuses.contains($0.reviewStatus)
        }
        self.sentences = sentences.filter {
            allowedStatuses.contains($0.reviewStatus)
        }
    }

    public func validate() -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        let lexemeIDs = Set(lexemes.map(\.id))
        let sentenceIDs = Set(sentences.map(\.id))

        if lexemeIDs.count != lexemes.count {
            issues.append(
                CatalogIssue(
                    itemID: "catalog.lexemes",
                    message: "lexeme IDs must be unique"
                )
            )
        }
        if sentenceIDs.count != sentences.count {
            issues.append(
                CatalogIssue(
                    itemID: "catalog.sentences",
                    message: "sentence IDs must be unique"
                )
            )
        }

        let lexemesByID = lexemes.reduce(
            into: [String: StudyLexeme]()
        ) { result, lexeme in
            if result[lexeme.id] == nil {
                result[lexeme.id] = lexeme
            }
        }
        for sentence in sentences {
            if sentence.targetText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                issues.append(
                    CatalogIssue(
                        itemID: sentence.id,
                        message: "target text must not be empty"
                    )
                )
            }
            if sentence.speechText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                issues.append(
                    CatalogIssue(
                        itemID: sentence.id,
                        message: "speech text must not be empty"
                    )
                )
            }
            if sentence.sourcePath.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                issues.append(
                    CatalogIssue(
                        itemID: sentence.id,
                        message: "source path must not be empty"
                    )
                )
            }
            for lexemeID in sentence.lexemeIDs {
                guard let lexeme = lexemesByID[lexemeID] else {
                    issues.append(
                        CatalogIssue(
                            itemID: sentence.id,
                            message: "missing lexeme \(lexemeID)"
                        )
                    )
                    continue
                }
                if lexeme.language != sentence.language {
                    issues.append(
                        CatalogIssue(
                            itemID: sentence.id,
                            message: "language mismatch for \(lexemeID)"
                        )
                    )
                }
            }
        }

        let linkedLexemeIDs = Set(sentences.flatMap(\.lexemeIDs))
        for lexeme in lexemes {
            if lexeme.speechText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                issues.append(
                    CatalogIssue(
                        itemID: lexeme.id,
                        message: "speech text must not be empty"
                    )
                )
            }
            if lexeme.sourcePath.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                issues.append(
                    CatalogIssue(
                        itemID: lexeme.id,
                        message: "source path must not be empty"
                    )
                )
            }
            if lexeme.collocations.isEmpty
                && !linkedLexemeIDs.contains(lexeme.id) {
                issues.append(
                    CatalogIssue(
                        itemID: lexeme.id,
                        message: "requires a collocation or linked sentence"
                    )
                )
            }
        }
        return issues
    }
}
