import Foundation

public enum TrialInteractionKind:
    String,
    Codable,
    Equatable,
    Sendable
{
    case reveal
    case grade
    case speak
    case detailsOpened
    case next
}

public enum TrialPromptDirection:
    String,
    Codable,
    Equatable,
    Sendable
{
    case recognition
    case production
    case sentenceProduction
}

public enum TrialPromptLevel:
    String,
    Codable,
    Equatable,
    Sendable
{
    case chinese
    case russian
    case scene
}

public enum TrialSessionEndReason:
    String,
    Codable,
    Equatable,
    Sendable
{
    case completed
    case hidden
    case quit
    case dayChanged
    case idle
}

public enum DailyCompletionReason:
    String,
    Codable,
    CaseIterable,
    Equatable,
    Sendable
{
    case completed
    case time
    case fatigue
    case tooHard
    case interrupted
    case other

    public var titleZh: String {
        switch self {
        case .completed: "已完成"
        case .time: "时间不足"
        case .fatigue: "疲劳"
        case .tooHard: "内容太难"
        case .interrupted: "被打断"
        case .other: "其他"
        }
    }
}

public struct TrialGradeOutcome: Equatable, Sendable {
    public let grade: ReviewGrade

    public init(grade: ReviewGrade) {
        self.grade = grade
    }

    public var isSuccess: Bool {
        grade != .again
    }
}

public struct TrialInteraction: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let itemType: PracticeItemKind
    public let itemID: String
    public let kind: TrialInteractionKind
    public let direction: TrialPromptDirection
    public let promptLevel: TrialPromptLevel
    public let grade: ReviewGrade?
    public let responseTimeMs: Int?
    public let usedSpeech: Bool
    public let openedDetails: Bool
    public let practiceMode: PracticeMode
    public let createdAt: Date
    public let recallOutcome: RecallOutcome?
    public let transferExerciseID: String?
    public let transferAnswerID: String?
    public let transferCorrect: Bool?

    public init(
        sessionID: UUID,
        itemType: PracticeItemKind,
        itemID: String,
        kind: TrialInteractionKind,
        direction: TrialPromptDirection,
        promptLevel: TrialPromptLevel,
        grade: ReviewGrade? = nil,
        responseTimeMs: Int? = nil,
        usedSpeech: Bool,
        openedDetails: Bool,
        practiceMode: PracticeMode,
        createdAt: Date,
        recallOutcome: RecallOutcome? = nil,
        transferExerciseID: String? = nil,
        transferAnswerID: String? = nil,
        transferCorrect: Bool? = nil
    ) {
        self.sessionID = sessionID
        self.itemType = itemType
        self.itemID = itemID
        self.kind = kind
        self.direction = direction
        self.promptLevel = promptLevel
        self.grade = grade
        self.responseTimeMs = responseTimeMs.map { max(0, $0) }
        self.usedSpeech = usedSpeech
        self.openedDetails = openedDetails
        self.practiceMode = practiceMode
        self.createdAt = createdAt
        self.recallOutcome = recallOutcome
        self.transferExerciseID = transferExerciseID
        self.transferAnswerID = transferAnswerID
        self.transferCorrect = transferCorrect
    }
}

public struct TrialSession: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let endReason: TrialSessionEndReason
    public let startQueueCount: Int
    public let endQueueCount: Int
    public let completedLexemeCount: Int
    public let completedSentenceCount: Int
    public let newItemCount: Int
    public let reviewItemCount: Int
    public let remainingBacklogCount: Int
    public let exitItemType: PracticeItemKind?
    public let exitQueuePosition: Int?

    public init(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        endReason: TrialSessionEndReason,
        startQueueCount: Int,
        endQueueCount: Int,
        completedLexemeCount: Int,
        completedSentenceCount: Int,
        newItemCount: Int,
        reviewItemCount: Int,
        remainingBacklogCount: Int,
        exitItemType: PracticeItemKind?,
        exitQueuePosition: Int?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = max(endedAt, startedAt)
        self.endReason = endReason
        self.startQueueCount = max(0, startQueueCount)
        self.endQueueCount = max(0, endQueueCount)
        self.completedLexemeCount = max(0, completedLexemeCount)
        self.completedSentenceCount = max(0, completedSentenceCount)
        self.newItemCount = max(0, newItemCount)
        self.reviewItemCount = max(0, reviewItemCount)
        self.remainingBacklogCount = max(0, remainingBacklogCount)
        self.exitItemType = exitItemType
        self.exitQueuePosition = exitQueuePosition.map { max(0, $0) }
    }

    public var durationMs: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt) * 1_000))
    }
}

public struct DailyReflection: Codable, Equatable, Sendable {
    public let day: Date
    public let mostBlocked: String
    public let spokeNaturally: Bool?
    public let spokeNaturallyNote: String
    public let completionReason: DailyCompletionReason
    public let completionReasonNote: String
    public let updatedAt: Date

    public init(
        day: Date,
        mostBlocked: String,
        spokeNaturally: Bool?,
        spokeNaturallyNote: String,
        completionReason: DailyCompletionReason,
        completionReasonNote: String,
        updatedAt: Date
    ) {
        self.day = day
        self.mostBlocked = Self.sanitized(mostBlocked)
        self.spokeNaturally = spokeNaturally
        self.spokeNaturallyNote = Self.sanitized(spokeNaturallyNote)
        self.completionReason = completionReason
        self.completionReasonNote = Self.sanitized(completionReasonNote)
        self.updatedAt = updatedAt
    }

    private static func sanitized(_ value: String) -> String {
        String(
            value.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(200)
        )
    }
}

public struct OralActivityAttempt: Codable, Equatable, Sendable {
    public let topic: String
    public let attemptedAt: Date
    public let elapsedMs: Int
    public let estimatedSpeakingMs: Int?
    public let longPauseCount: Int?
    public let selfRating: Int
    public let usedMicrophoneMeter: Bool

    public init(
        topic: String,
        attemptedAt: Date,
        elapsedMs: Int,
        estimatedSpeakingMs: Int?,
        longPauseCount: Int?,
        selfRating: Int,
        usedMicrophoneMeter: Bool
    ) {
        self.topic = String(
            topic.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(100)
        )
        self.attemptedAt = attemptedAt
        self.elapsedMs = max(0, elapsedMs)
        self.estimatedSpeakingMs = estimatedSpeakingMs.map { max(0, $0) }
        self.longPauseCount = longPauseCount.map { max(0, $0) }
        self.selfRating = min(max(selfRating, 1), 5)
        self.usedMicrophoneMeter = usedMicrophoneMeter
    }
}

public struct TrialReportSnapshot: Equatable, Sendable {
    public let sessions: [TrialSession]
    public let interactions: [TrialInteraction]
    public let reflections: [DailyReflection]
    public let oralAttempts: [OralActivityAttempt]

    public init(
        sessions: [TrialSession],
        interactions: [TrialInteraction],
        reflections: [DailyReflection],
        oralAttempts: [OralActivityAttempt]
    ) {
        self.sessions = sessions
        self.interactions = interactions
        self.reflections = reflections
        self.oralAttempts = oralAttempts
    }

    public static let empty = TrialReportSnapshot(
        sessions: [],
        interactions: [],
        reflections: [],
        oralAttempts: []
    )
}
