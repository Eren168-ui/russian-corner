import Foundation

public struct ImportedExpression:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let language: StudyLanguage
    public let targetText: String
    public let promptZh: String
    public let scene: String
    public let speakerRole: String?
    public let register: DialogueRegister
    public let expectedReply: String?
    public let sourcePath: String
    public let sourceText: String
    public let reviewStatus: ReviewStatus
    public let provenanceType: ProvenanceType
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        language: StudyLanguage = .english,
        targetText: String,
        promptZh: String,
        scene: String,
        speakerRole: String? = nil,
        register: DialogueRegister = .neutral,
        expectedReply: String? = nil,
        sourcePath: String,
        sourceText: String,
        reviewStatus: ReviewStatus = .draft,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.language = language
        self.targetText = targetText
        self.promptZh = promptZh
        self.scene = scene
        self.speakerRole = speakerRole
        self.register = register
        self.expectedReply = expectedReply
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.reviewStatus = reviewStatus
        provenanceType = .userNote
        self.createdAt = createdAt
    }

    public func withReviewStatus(
        _ reviewStatus: ReviewStatus
    ) -> ImportedExpression {
        ImportedExpression(
            id: id,
            language: language,
            targetText: targetText,
            promptZh: promptZh,
            scene: scene,
            speakerRole: speakerRole,
            register: register,
            expectedReply: expectedReply,
            sourcePath: sourcePath,
            sourceText: sourceText,
            reviewStatus: reviewStatus,
            createdAt: createdAt
        )
    }
}

public extension ImportedExpression {
    var studySentence: StudySentence {
        StudySentence(
            id: "\(language.storageNamespace).imported.\(id)",
            language: language,
            promptZh: promptZh,
            cueText: scene,
            targetText: targetText,
            displayText: targetText,
            speechText: targetText,
            theme: scene,
            lexemeIDs: [],
            register: register,
            speakerRole: speakerRole,
            expectedReplies: expectedReply.map { [$0] } ?? [],
            reviewStatus: reviewStatus,
            provenanceType: provenanceType,
            sourcePath: sourcePath,
            sourceText: sourceText
        )
    }
}
