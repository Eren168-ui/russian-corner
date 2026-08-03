import Foundation

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
