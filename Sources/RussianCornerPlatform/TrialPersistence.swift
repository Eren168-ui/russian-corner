import Foundation
import RussianCornerCore
import SwiftData

public enum TrialRepositoryError: Error, Equatable, Sendable {
    case corruptedRecord(
        recordID: UUID,
        field: String,
        value: String
    )
}

@MainActor
public protocol TrialDataStoring: AnyObject {
    func save(session: TrialSession) throws
    func save(interaction: TrialInteraction) throws
    func upsert(
        reflection: DailyReflection,
        calendar: Calendar
    ) throws
    func save(oralAttempt: OralActivityAttempt) throws
    func fetchSnapshot(
        from start: Date,
        through end: Date
    ) throws -> TrialReportSnapshot
    func reflection(
        on day: Date,
        calendar: Calendar
    ) throws -> DailyReflection?
}

@Model
final class TrialSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var endReasonRaw: String
    var startQueueCount: Int
    var endQueueCount: Int
    var completedLexemeCount: Int
    var completedSentenceCount: Int
    var newItemCount: Int
    var reviewItemCount: Int
    var remainingBacklogCount: Int
    var exitItemTypeRaw: String?
    var exitQueuePosition: Int?

    init(session: TrialSession) {
        id = session.id
        startedAt = session.startedAt
        endedAt = session.endedAt
        endReasonRaw = session.endReason.rawValue
        startQueueCount = session.startQueueCount
        endQueueCount = session.endQueueCount
        completedLexemeCount = session.completedLexemeCount
        completedSentenceCount = session.completedSentenceCount
        newItemCount = session.newItemCount
        reviewItemCount = session.reviewItemCount
        remainingBacklogCount = session.remainingBacklogCount
        exitItemTypeRaw = session.exitItemType?.rawValue
        exitQueuePosition = session.exitQueuePosition
    }

    func value() throws -> TrialSession {
        guard
            let endReason = TrialSessionEndReason(
                rawValue: endReasonRaw
            )
        else {
            throw TrialRepositoryError.corruptedRecord(
                recordID: id,
                field: "endReason",
                value: endReasonRaw
            )
        }
        let exitItemType: PracticeItemKind?
        if let exitItemTypeRaw {
            guard
                let decoded = PracticeItemKind(rawValue: exitItemTypeRaw)
            else {
                throw TrialRepositoryError.corruptedRecord(
                    recordID: id,
                    field: "exitItemType",
                    value: exitItemTypeRaw
                )
            }
            exitItemType = decoded
        } else {
            exitItemType = nil
        }
        return TrialSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            endReason: endReason,
            startQueueCount: startQueueCount,
            endQueueCount: endQueueCount,
            completedLexemeCount: completedLexemeCount,
            completedSentenceCount: completedSentenceCount,
            newItemCount: newItemCount,
            reviewItemCount: reviewItemCount,
            remainingBacklogCount: remainingBacklogCount,
            exitItemType: exitItemType,
            exitQueuePosition: exitQueuePosition
        )
    }
}

@Model
final class TrialInteractionRecord {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var itemTypeRaw: String
    var itemID: String
    var kindRaw: String
    var directionRaw: String
    var promptLevelRaw: String
    var gradeRaw: String?
    var responseTimeMs: Int?
    var usedSpeech: Bool
    var openedDetails: Bool
    var practiceModeRaw: String
    var createdAt: Date

    init(interaction: TrialInteraction) {
        id = UUID()
        sessionID = interaction.sessionID
        itemTypeRaw = interaction.itemType.rawValue
        itemID = interaction.itemID
        kindRaw = interaction.kind.rawValue
        directionRaw = interaction.direction.rawValue
        promptLevelRaw = interaction.promptLevel.rawValue
        gradeRaw = interaction.grade?.rawValue
        responseTimeMs = interaction.responseTimeMs
        usedSpeech = interaction.usedSpeech
        openedDetails = interaction.openedDetails
        practiceModeRaw = interaction.practiceMode.rawValue
        createdAt = interaction.createdAt
    }

    func value() throws -> TrialInteraction {
        let itemType = try decoded(
            PracticeItemKind.self,
            raw: itemTypeRaw,
            field: "itemType"
        )
        let kind = try decoded(
            TrialInteractionKind.self,
            raw: kindRaw,
            field: "kind"
        )
        let direction = try decoded(
            TrialPromptDirection.self,
            raw: directionRaw,
            field: "direction"
        )
        let promptLevel = try decoded(
            TrialPromptLevel.self,
            raw: promptLevelRaw,
            field: "promptLevel"
        )
        let practiceMode = try decoded(
            PracticeMode.self,
            raw: practiceModeRaw,
            field: "practiceMode"
        )
        let grade: ReviewGrade?
        if let gradeRaw {
            grade = try decoded(
                ReviewGrade.self,
                raw: gradeRaw,
                field: "grade"
            )
        } else {
            grade = nil
        }
        return TrialInteraction(
            sessionID: sessionID,
            itemType: itemType,
            itemID: itemID,
            kind: kind,
            direction: direction,
            promptLevel: promptLevel,
            grade: grade,
            responseTimeMs: responseTimeMs,
            usedSpeech: usedSpeech,
            openedDetails: openedDetails,
            practiceMode: practiceMode,
            createdAt: createdAt
        )
    }

    private func decoded<Value>(
        _ type: Value.Type,
        raw: String,
        field: String
    ) throws -> Value
    where Value: RawRepresentable, Value.RawValue == String {
        guard let value = Value(rawValue: raw) else {
            throw TrialRepositoryError.corruptedRecord(
                recordID: id,
                field: field,
                value: raw
            )
        }
        return value
    }
}

@Model
final class DailyReflectionRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var day: Date
    var mostBlocked: String
    var spokeNaturally: Bool?
    var spokeNaturallyNote: String
    var completionReasonRaw: String
    var completionReasonNote: String
    var updatedAt: Date

    init(reflection: DailyReflection, day: Date) {
        id = UUID()
        self.day = day
        mostBlocked = reflection.mostBlocked
        spokeNaturally = reflection.spokeNaturally
        spokeNaturallyNote = reflection.spokeNaturallyNote
        completionReasonRaw = reflection.completionReason.rawValue
        completionReasonNote = reflection.completionReasonNote
        updatedAt = reflection.updatedAt
    }

    func update(from reflection: DailyReflection) {
        mostBlocked = reflection.mostBlocked
        spokeNaturally = reflection.spokeNaturally
        spokeNaturallyNote = reflection.spokeNaturallyNote
        completionReasonRaw = reflection.completionReason.rawValue
        completionReasonNote = reflection.completionReasonNote
        updatedAt = reflection.updatedAt
    }

    func value() throws -> DailyReflection {
        guard
            let completionReason = DailyCompletionReason(
                rawValue: completionReasonRaw
            )
        else {
            throw TrialRepositoryError.corruptedRecord(
                recordID: id,
                field: "completionReason",
                value: completionReasonRaw
            )
        }
        return DailyReflection(
            day: day,
            mostBlocked: mostBlocked,
            spokeNaturally: spokeNaturally,
            spokeNaturallyNote: spokeNaturallyNote,
            completionReason: completionReason,
            completionReasonNote: completionReasonNote,
            updatedAt: updatedAt
        )
    }
}

@Model
final class OralActivityAttemptRecord {
    @Attribute(.unique) var id: UUID
    var topic: String
    var attemptedAt: Date
    var elapsedMs: Int
    var estimatedSpeakingMs: Int?
    var longPauseCount: Int?
    var selfRating: Int
    var usedMicrophoneMeter: Bool

    init(attempt: OralActivityAttempt) {
        id = UUID()
        topic = attempt.topic
        attemptedAt = attempt.attemptedAt
        elapsedMs = attempt.elapsedMs
        estimatedSpeakingMs = attempt.estimatedSpeakingMs
        longPauseCount = attempt.longPauseCount
        selfRating = attempt.selfRating
        usedMicrophoneMeter = attempt.usedMicrophoneMeter
    }

    func value() -> OralActivityAttempt {
        OralActivityAttempt(
            topic: topic,
            attemptedAt: attemptedAt,
            elapsedMs: elapsedMs,
            estimatedSpeakingMs: estimatedSpeakingMs,
            longPauseCount: longPauseCount,
            selfRating: selfRating,
            usedMicrophoneMeter: usedMicrophoneMeter
        )
    }
}

@MainActor
public final class TrialRepository: TrialDataStoring {
    public let container: ModelContainer
    private let context: ModelContext
    private let saveContext: (ModelContext) throws -> Void

    public init(
        container: ModelContainer,
        saveContext: @escaping (ModelContext) throws -> Void = {
            try $0.save()
        }
    ) {
        self.container = container
        context = ModelContext(container)
        self.saveContext = saveContext
    }

    public static func makeContainer(
        inMemory: Bool = false,
        applicationSupportDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> ModelContainer {
        let schema = Schema([
            TrialSessionRecord.self,
            TrialInteractionRecord.self,
            DailyReflectionRecord.self,
            OralActivityAttemptRecord.self,
        ])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            let supportDirectory =
                try applicationSupportDirectory
                ?? fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            let appDirectory = supportDirectory.appendingPathComponent(
                "com.openclaw.russiancorner",
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: appDirectory,
                withIntermediateDirectories: true
            )
            let storeURL = appDirectory.appendingPathComponent(
                "RussianCornerTrial.store",
                isDirectory: false
            )
            configuration = ModelConfiguration(
                "RussianCornerTrial",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    public func save(session: TrialSession) throws {
        try transaction {
            context.insert(TrialSessionRecord(session: session))
        }
    }

    public func save(interaction: TrialInteraction) throws {
        try transaction {
            context.insert(
                TrialInteractionRecord(interaction: interaction)
            )
        }
    }

    public func upsert(
        reflection: DailyReflection,
        calendar: Calendar
    ) throws {
        let day = calendar.startOfDay(for: reflection.day)
        let descriptor = FetchDescriptor<DailyReflectionRecord>(
            predicate: #Predicate { $0.day == day }
        )
        try transaction {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: reflection)
            } else {
                context.insert(
                    DailyReflectionRecord(
                        reflection: reflection,
                        day: day
                    )
                )
            }
        }
    }

    public func save(oralAttempt: OralActivityAttempt) throws {
        try transaction {
            context.insert(
                OralActivityAttemptRecord(attempt: oralAttempt)
            )
        }
    }

    public func fetchSnapshot(
        from start: Date,
        through end: Date
    ) throws -> TrialReportSnapshot {
        let sessions = try context.fetch(
            FetchDescriptor<TrialSessionRecord>(
                predicate: #Predicate {
                    $0.startedAt >= start && $0.startedAt <= end
                },
                sortBy: [SortDescriptor(\.startedAt)]
            )
        ).map { try $0.value() }
        let interactions = try context.fetch(
            FetchDescriptor<TrialInteractionRecord>(
                predicate: #Predicate {
                    $0.createdAt >= start && $0.createdAt <= end
                },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        ).map { try $0.value() }
        let reflections = try context.fetch(
            FetchDescriptor<DailyReflectionRecord>(
                predicate: #Predicate {
                    $0.day >= start && $0.day <= end
                },
                sortBy: [SortDescriptor(\.day)]
            )
        ).map { try $0.value() }
        let oralAttempts = try context.fetch(
            FetchDescriptor<OralActivityAttemptRecord>(
                predicate: #Predicate {
                    $0.attemptedAt >= start && $0.attemptedAt <= end
                },
                sortBy: [SortDescriptor(\.attemptedAt)]
            )
        ).map { $0.value() }
        return TrialReportSnapshot(
            sessions: sessions,
            interactions: interactions,
            reflections: reflections,
            oralAttempts: oralAttempts
        )
    }

    public func reflection(
        on day: Date,
        calendar: Calendar
    ) throws -> DailyReflection? {
        let start = calendar.startOfDay(for: day)
        let descriptor = FetchDescriptor<DailyReflectionRecord>(
            predicate: #Predicate { $0.day == start }
        )
        return try context.fetch(descriptor).first.map {
            try $0.value()
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        do {
            try body()
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
