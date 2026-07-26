import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

public struct TrialInteractionContext: Equatable, Sendable {
    public let itemType: PracticeItemKind
    public let itemID: String
    public let direction: TrialPromptDirection
    public let promptLevel: TrialPromptLevel
    public let grade: ReviewGrade?
    public let responseTimeMs: Int?
    public let usedSpeech: Bool
    public let openedDetails: Bool
    public let practiceMode: PracticeMode
    public let occurredAt: Date
    public let queueCountBeforeAction: Int
    public let queueCountAfterAction: Int
    public let queuePosition: Int
    public let remainingBacklogCount: Int
    public let isNewItem: Bool

    public init(
        itemType: PracticeItemKind,
        itemID: String,
        direction: TrialPromptDirection,
        promptLevel: TrialPromptLevel,
        grade: ReviewGrade?,
        responseTimeMs: Int?,
        usedSpeech: Bool,
        openedDetails: Bool,
        practiceMode: PracticeMode,
        occurredAt: Date,
        queueCountBeforeAction: Int,
        queueCountAfterAction: Int,
        queuePosition: Int,
        remainingBacklogCount: Int,
        isNewItem: Bool
    ) {
        self.itemType = itemType
        self.itemID = itemID
        self.direction = direction
        self.promptLevel = promptLevel
        self.grade = grade
        self.responseTimeMs = responseTimeMs
        self.usedSpeech = usedSpeech
        self.openedDetails = openedDetails
        self.practiceMode = practiceMode
        self.occurredAt = occurredAt
        self.queueCountBeforeAction = max(0, queueCountBeforeAction)
        self.queueCountAfterAction = max(0, queueCountAfterAction)
        self.queuePosition = max(0, queuePosition)
        self.remainingBacklogCount = max(0, remainingBacklogCount)
        self.isNewItem = isNewItem
    }
}

@MainActor
public protocol PracticeTrialTracking: AnyObject {
    func record(
        kind: TrialInteractionKind,
        context: TrialInteractionContext
    )
    func close(reason: TrialSessionEndReason)
}

@MainActor
@Observable
public final class TrialSessionCoordinator: PracticeTrialTracking {
    private struct OpenSession {
        let id: UUID
        let startedAt: Date
        let startQueueCount: Int
        var lastInteractionAt: Date
        var lastContext: TrialInteractionContext
        var completedItemKeys: Set<String> = []
        var gradedItemKeys: Set<String> = []
        var completedLexemeCount = 0
        var completedSentenceCount = 0
        var newItemCount = 0
        var reviewItemCount = 0
    }

    public private(set) var lastIssue: String?
    public var hasOpenSession: Bool { openSession != nil }

    private let repository: any TrialDataStoring
    private let now: () -> Date
    private let calendar: Calendar
    private let idleInterval: TimeInterval
    private let onIssue: ((String) -> Void)?
    private var openSession: OpenSession?
    private var idleTask: Task<Void, Never>?

    public init(
        repository: any TrialDataStoring,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        idleInterval: TimeInterval = 3 * 60,
        onIssue: ((String) -> Void)? = nil
    ) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        self.idleInterval = idleInterval
        self.onIssue = onIssue
    }

    public func record(
        kind: TrialInteractionKind,
        context: TrialInteractionContext
    ) {
        closeForDayChangeIfNeeded(at: context.occurredAt)
        if openSession == nil {
            openSession = OpenSession(
                id: UUID(),
                startedAt: context.occurredAt,
                startQueueCount: context.queueCountBeforeAction,
                lastInteractionAt: context.occurredAt,
                lastContext: context
            )
        }
        guard var session = openSession else { return }
        session.lastInteractionAt = context.occurredAt
        session.lastContext = context
        updateCounts(
            in: &session,
            kind: kind,
            context: context
        )
        openSession = session

        let interaction = TrialInteraction(
            sessionID: session.id,
            itemType: context.itemType,
            itemID: context.itemID,
            kind: kind,
            direction: context.direction,
            promptLevel: context.promptLevel,
            grade: context.grade,
            responseTimeMs: kind == .grade
                ? context.responseTimeMs : nil,
            usedSpeech: context.usedSpeech,
            openedDetails: context.openedDetails,
            practiceMode: context.practiceMode,
            createdAt: context.occurredAt
        )
        do {
            try repository.save(interaction: interaction)
        } catch {
            report(
                "试用统计暂时无法记录：\(error.localizedDescription)"
            )
        }
        scheduleIdleExpiration()
    }

    public func close(reason: TrialSessionEndReason) {
        let endedAt =
            reason == .idle
            ? openSession?.lastInteractionAt
            : now()
        persistClose(reason: reason, endedAt: endedAt)
    }

    public func expireIdleSession(at instant: Date) {
        guard let openSession else { return }
        let idleDuration = instant.timeIntervalSince(
            openSession.lastInteractionAt
        )
        guard idleDuration >= idleInterval else { return }
        persistClose(
            reason: .idle,
            endedAt: openSession.lastInteractionAt
        )
    }

    private func updateCounts(
        in session: inout OpenSession,
        kind: TrialInteractionKind,
        context: TrialInteractionContext
    ) {
        guard kind == .grade, let grade = context.grade else {
            return
        }
        let key = "\(context.itemType.rawValue):\(context.itemID)"
        if session.gradedItemKeys.insert(key).inserted {
            if context.isNewItem {
                session.newItemCount += 1
            } else {
                session.reviewItemCount += 1
            }
        }
        guard
            grade != .again,
            session.completedItemKeys.insert(key).inserted
        else {
            return
        }
        switch context.itemType {
        case .lexeme:
            session.completedLexemeCount += 1
        case .sentence:
            session.completedSentenceCount += 1
        }
    }

    private func closeForDayChangeIfNeeded(at instant: Date) {
        guard
            let openSession,
            calendar.startOfDay(for: openSession.startedAt)
                != calendar.startOfDay(for: instant)
        else {
            return
        }
        persistClose(
            reason: .dayChanged,
            endedAt: openSession.lastInteractionAt
        )
    }

    private func persistClose(
        reason: TrialSessionEndReason,
        endedAt: Date?
    ) {
        idleTask?.cancel()
        idleTask = nil
        guard let session = openSession else { return }
        openSession = nil
        let lastContext = session.lastContext
        let value = TrialSession(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: endedAt ?? session.lastInteractionAt,
            endReason: reason,
            startQueueCount: session.startQueueCount,
            endQueueCount: lastContext.queueCountAfterAction,
            completedLexemeCount: session.completedLexemeCount,
            completedSentenceCount: session.completedSentenceCount,
            newItemCount: session.newItemCount,
            reviewItemCount: session.reviewItemCount,
            remainingBacklogCount: lastContext.remainingBacklogCount,
            exitItemType: lastContext.itemType,
            exitQueuePosition: lastContext.queuePosition
        )
        do {
            try repository.save(session: value)
        } catch {
            report(
                "试用会话暂时无法保存：\(error.localizedDescription)"
            )
        }
    }

    private func scheduleIdleExpiration() {
        idleTask?.cancel()
        let delay = idleInterval
        idleTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(delay)
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.expireIdleSession(at: self?.now() ?? Date())
        }
    }

    private func report(_ message: String) {
        lastIssue = message
        onIssue?(message)
    }
}
