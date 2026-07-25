import Foundation
import RussianCornerCore
import SwiftData

public enum ProgressRepositoryError: Error, Equatable, Sendable {
    case corruptedRecord(
        recordID: UUID,
        field: String,
        value: String
    )
    case corruptedDiagnosticRecord(recordID: UUID, message: String)
}

@MainActor
public protocol PracticeProgressStoring: AnyObject {
    func reviewEvents() throws -> [ReviewEvent]

    func progress(
        itemType: PracticeItemKind,
        itemId: String
    ) throws -> ReviewState?

    func dailyCompletedCount(
        on date: Date,
        calendar: Calendar
    ) throws -> Int?

    func commitReview(
        event: ReviewEvent,
        state: ReviewState,
        dailyCompletedCount: Int,
        calendar: Calendar
    ) throws
}

public enum DiagnosticRunKind:
    String,
    Codable,
    Equatable,
    Sendable
{
    case baseline
    case weekly
}

public struct DiagnosticHistoryEntry: Equatable, Sendable {
    public let id: UUID
    public let kind: DiagnosticRunKind
    public let report: DiagnosticReport

    public init(
        id: UUID,
        kind: DiagnosticRunKind,
        report: DiagnosticReport
    ) {
        self.id = id
        self.kind = kind
        self.report = report
    }
}

public struct DiagnosticHistorySnapshot: Equatable, Sendable {
    public let entries: [DiagnosticHistoryEntry]
    public let issueCount: Int

    public init(
        entries: [DiagnosticHistoryEntry],
        issueCount: Int
    ) {
        self.entries = entries
        self.issueCount = issueCount
    }
}

@MainActor
public protocol DiagnosticReportStoring: AnyObject {
    func saveDiagnosticReport(_ report: DiagnosticReport) throws
    func diagnosticHistory() throws -> DiagnosticHistorySnapshot
    func baselineDiagnosticReport() throws -> DiagnosticReport?
    func latestDiagnosticReport() throws -> DiagnosticReport?
}

@Model
public final class ReviewEventRecord {
    @Attribute(.unique) public var id: UUID
    public var itemTypeRawValue: String
    public var itemId: String
    public var gradeRawValue: String
    public var responseTimeMs: Int
    public var practiceModeRawValue: String
    public var createdAt: Date

    public init(id: UUID = UUID(), event: ReviewEvent) {
        self.id = id
        itemTypeRawValue = event.itemType.rawValue
        itemId = event.itemId
        gradeRawValue = event.grade.rawValue
        responseTimeMs = event.responseTimeMs
        practiceModeRawValue = event.practiceMode.rawValue
        createdAt = event.createdAt
    }

    public func decodedEvent() throws -> ReviewEvent {
        guard let itemType = PracticeItemKind(rawValue: itemTypeRawValue) else {
            throw ProgressRepositoryError.corruptedRecord(
                recordID: id,
                field: "itemTypeRawValue",
                value: itemTypeRawValue
            )
        }
        guard let grade = ReviewGrade(rawValue: gradeRawValue) else {
            throw ProgressRepositoryError.corruptedRecord(
                recordID: id,
                field: "gradeRawValue",
                value: gradeRawValue
            )
        }
        guard
            let practiceMode = PracticeMode(rawValue: practiceModeRawValue)
        else {
            throw ProgressRepositoryError.corruptedRecord(
                recordID: id,
                field: "practiceModeRawValue",
                value: practiceModeRawValue
            )
        }

        return ReviewEvent(
            itemType: itemType,
            itemId: itemId,
            grade: grade,
            responseTimeMs: responseTimeMs,
            practiceMode: practiceMode,
            createdAt: createdAt
        )
    }
}

@Model
public final class ItemProgressRecord {
    @Attribute(.unique) public var storageKey: String
    public var itemTypeRawValue: String
    public var itemId: String
    public var masteryLevel: Int
    public var dueAt: Date

    public init(
        itemType: PracticeItemKind,
        itemId: String,
        state: ReviewState
    ) {
        storageKey = Self.key(itemType: itemType, itemId: itemId)
        itemTypeRawValue = itemType.rawValue
        self.itemId = itemId
        masteryLevel = state.masteryLevel
        dueAt = state.dueAt
    }

    public var state: ReviewState {
        ReviewState(masteryLevel: masteryLevel, dueAt: dueAt)
    }

    public static func key(
        itemType: PracticeItemKind,
        itemId: String
    ) -> String {
        "\(itemType.rawValue):\(itemId)"
    }
}

@Model
public final class DailyCompletionRecord {
    @Attribute(.unique) public var day: Date
    public var completedCount: Int

    public init(day: Date, completedCount: Int) {
        self.day = day
        self.completedCount = completedCount
    }
}

@Model
public final class SettingsRecord {
    @Attribute(.unique) public var key: String
    public var morningHour: Int
    public var morningMinute: Int
    public var eveningHour: Int
    public var eveningMinute: Int

    public init(
        key: String = "settings",
        settings: RussianCornerSettings
    ) {
        self.key = key
        morningHour = settings.morningReminder.hour
        morningMinute = settings.morningReminder.minute
        eveningHour = settings.eveningReminder.hour
        eveningMinute = settings.eveningReminder.minute
    }

    public var settings: RussianCornerSettings {
        RussianCornerSettings(
            morningReminder: ReminderTime(
                hour: morningHour,
                minute: morningMinute
            ),
            eveningReminder: ReminderTime(
                hour: eveningHour,
                minute: eveningMinute
            )
        )
    }
}

@Model
public final class DiagnosticReportRecord {
    @Attribute(.unique) public var id: UUID
    public var kindRawValue: String
    public var completedAt: Date
    public var reportJSON: Data

    public init(
        id: UUID = UUID(),
        kind: DiagnosticRunKind,
        report: DiagnosticReport,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        self.id = id
        kindRawValue = kind.rawValue
        completedAt = report.current.completedAt
        reportJSON = try encoder.encode(report)
    }

    public func decodedEntry(
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> DiagnosticHistoryEntry {
        guard let kind = DiagnosticRunKind(rawValue: kindRawValue) else {
            throw ProgressRepositoryError.corruptedDiagnosticRecord(
                recordID: id,
                message: "invalid kind \(kindRawValue)"
            )
        }
        do {
            return DiagnosticHistoryEntry(
                id: id,
                kind: kind,
                report: try decoder.decode(
                    DiagnosticReport.self,
                    from: reportJSON
                )
            )
        } catch let error as ProgressRepositoryError {
            throw error
        } catch {
            throw ProgressRepositoryError.corruptedDiagnosticRecord(
                recordID: id,
                message: error.localizedDescription
            )
        }
    }
}

@MainActor
public final class ProgressRepository {
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
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema([
            ReviewEventRecord.self,
            ItemProgressRecord.self,
            DailyCompletionRecord.self,
            SettingsRecord.self,
            DiagnosticReportRecord.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    public static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    public func save(reviewEvent: ReviewEvent) throws {
        context.insert(ReviewEventRecord(event: reviewEvent))
        try context.save()
    }

    public func commitReview(
        event: ReviewEvent,
        state: ReviewState,
        dailyCompletedCount: Int,
        calendar: Calendar = .current
    ) throws {
        do {
            context.insert(ReviewEventRecord(event: event))
            try upsertProgress(
                itemType: event.itemType,
                itemId: event.itemId,
                state: state
            )
            try upsertDailyCompletion(
                date: event.createdAt,
                completedCount: dailyCompletedCount,
                calendar: calendar
            )
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func reviewEvents() throws -> [ReviewEvent] {
        let descriptor = FetchDescriptor<ReviewEventRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map {
            try $0.decodedEvent()
        }
    }

    public func saveProgress(
        itemType: PracticeItemKind,
        itemId: String,
        state: ReviewState
    ) throws {
        try upsertProgress(
            itemType: itemType,
            itemId: itemId,
            state: state
        )
        try context.save()
    }

    public func progress(
        itemType: PracticeItemKind,
        itemId: String
    ) throws -> ReviewState? {
        let key = ItemProgressRecord.key(
            itemType: itemType,
            itemId: itemId
        )
        let descriptor = FetchDescriptor<ItemProgressRecord>(
            predicate: #Predicate { $0.storageKey == key }
        )
        return try context.fetch(descriptor).first?.state
    }

    public func saveDailyCompletion(
        date: Date,
        completedCount: Int,
        calendar: Calendar = .current
    ) throws {
        try upsertDailyCompletion(
            date: date,
            completedCount: completedCount,
            calendar: calendar
        )
        try context.save()
    }

    public func dailyCompletedCount(
        on date: Date,
        calendar: Calendar = .current
    ) throws -> Int? {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyCompletionRecord>(
            predicate: #Predicate { $0.day == day }
        )
        return try context.fetch(descriptor).first?.completedCount
    }

    public func save(settings: RussianCornerSettings) throws {
        do {
            let settingsKey = "settings"
            let descriptor = FetchDescriptor<SettingsRecord>(
                predicate: #Predicate { $0.key == settingsKey }
            )

            if let record = try context.fetch(descriptor).first {
                record.morningHour = settings.morningReminder.hour
                record.morningMinute = settings.morningReminder.minute
                record.eveningHour = settings.eveningReminder.hour
                record.eveningMinute = settings.eveningReminder.minute
            } else {
                context.insert(SettingsRecord(settings: settings))
            }
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    public func settings() throws -> RussianCornerSettings {
        let settingsKey = "settings"
        let descriptor = FetchDescriptor<SettingsRecord>(
            predicate: #Predicate { $0.key == settingsKey }
        )
        return try context.fetch(descriptor).first?.settings
            ?? RussianCornerSettings()
    }

    public func saveDiagnosticReport(
        _ report: DiagnosticReport
    ) throws {
        do {
            let kind: DiagnosticRunKind =
                report.sampleWasRepaired
                ? .baseline
                : try diagnosticHistory().entries.contains {
                    $0.kind == .baseline
                }
                == false
                ? .baseline : .weekly
            context.insert(
                try DiagnosticReportRecord(kind: kind, report: report)
            )
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    public func diagnosticHistory() throws -> DiagnosticHistorySnapshot {
        let descriptor = FetchDescriptor<DiagnosticReportRecord>(
            sortBy: [SortDescriptor(\.completedAt)]
        )
        var entries: [DiagnosticHistoryEntry] = []
        var issueCount = 0
        for record in try context.fetch(descriptor) {
            do {
                entries.append(try record.decodedEntry())
            } catch {
                issueCount += 1
            }
        }
        return DiagnosticHistorySnapshot(
            entries: entries,
            issueCount: issueCount
        )
    }

    public func baselineDiagnosticReport() throws -> DiagnosticReport? {
        try diagnosticHistory().entries.last(where: {
            $0.kind == .baseline
        })?.report
    }

    public func latestDiagnosticReport() throws -> DiagnosticReport? {
        try diagnosticHistory().entries.last?.report
    }

    private func upsertProgress(
        itemType: PracticeItemKind,
        itemId: String,
        state: ReviewState
    ) throws {
        let key = ItemProgressRecord.key(
            itemType: itemType,
            itemId: itemId
        )
        let descriptor = FetchDescriptor<ItemProgressRecord>(
            predicate: #Predicate { $0.storageKey == key }
        )
        if let record = try context.fetch(descriptor).first {
            record.masteryLevel = state.masteryLevel
            record.dueAt = state.dueAt
        } else {
            context.insert(
                ItemProgressRecord(
                    itemType: itemType,
                    itemId: itemId,
                    state: state
                )
            )
        }
    }

    private func upsertDailyCompletion(
        date: Date,
        completedCount: Int,
        calendar: Calendar
    ) throws {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyCompletionRecord>(
            predicate: #Predicate { $0.day == day }
        )
        if let record = try context.fetch(descriptor).first {
            record.completedCount = completedCount
        } else {
            context.insert(
                DailyCompletionRecord(
                    day: day,
                    completedCount: completedCount
                )
            )
        }
    }
}

extension ProgressRepository: PracticeProgressStoring {}
extension ProgressRepository: DiagnosticReportStoring {}
