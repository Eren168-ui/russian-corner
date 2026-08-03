import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

@MainActor
@Observable
public final class DailyReflectionViewModel {
    public var mostBlocked = ""
    public var spokeNaturally: Bool?
    public var spokeNaturallyNote = ""
    public var completionReason: DailyCompletionReason = .completed
    public var completionReasonNote = ""
    public private(set) var hasSavedToday = false
    public private(set) var statusMessage: String?
    public private(set) var isCompletionOfferPresented = false
    public let language: StudyLanguage

    private let repository: any TrialDataStoring
    private let now: () -> Date
    private let calendar: Calendar
    private var loadedDay: Date?
    private var offeredDay: Date?

    public init(
        repository: any TrialDataStoring,
        language: StudyLanguage = .russian,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.language = language
        self.now = now
        self.calendar = calendar
    }

    public var languageLabel: String {
        language == .english ? "ENGLISH" : "РУССКИЙ"
    }

    @discardableResult
    public func loadToday() -> Bool {
        let instant = now()
        let day = calendar.startOfDay(for: instant)
        resetOfferIfDayChanged(day)
        do {
            if let reflection = try repository.reflection(
                on: day,
                calendar: calendar
            ) {
                apply(reflection)
                hasSavedToday = true
            } else {
                clearForm()
                hasSavedToday = false
            }
            loadedDay = day
            statusMessage = nil
            return true
        } catch {
            loadedDay = day
            hasSavedToday = false
            statusMessage =
                "今日反馈暂时无法读取：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    public func saveToday() -> Bool {
        let instant = now()
        let day = calendar.startOfDay(for: instant)
        let reflection = DailyReflection(
            day: day,
            mostBlocked: mostBlocked,
            spokeNaturally: spokeNaturally,
            spokeNaturallyNote: spokeNaturallyNote,
            completionReason: completionReason,
            completionReasonNote: completionReasonNote,
            updatedAt: instant
        )
        do {
            try repository.upsert(
                reflection: reflection,
                calendar: calendar
            )
            apply(reflection)
            hasSavedToday = true
            loadedDay = day
            offeredDay = day
            isCompletionOfferPresented = false
            statusMessage = "今日反馈已保存"
            return true
        } catch {
            statusMessage =
                "今日反馈暂时无法保存：\(error.localizedDescription)"
            return false
        }
    }

    public func shouldOfferAfterCompletion() -> Bool {
        let day = calendar.startOfDay(for: now())
        resetOfferIfDayChanged(day)
        if loadedDay != day {
            _ = loadToday()
        }
        return !hasSavedToday && offeredDay != day
    }

    @discardableResult
    public func presentAfterCompletionIfNeeded() -> Bool {
        guard shouldOfferAfterCompletion() else {
            isCompletionOfferPresented = false
            return false
        }
        let day = calendar.startOfDay(for: now())
        offeredDay = day
        isCompletionOfferPresented = true
        return true
    }

    public func dismissCompletionOffer() {
        offeredDay = calendar.startOfDay(for: now())
        isCompletionOfferPresented = false
    }

    public func openForEditing() {
        _ = loadToday()
        isCompletionOfferPresented = false
    }

    private func resetOfferIfDayChanged(_ day: Date) {
        if let offeredDay, offeredDay != day {
            self.offeredDay = nil
            isCompletionOfferPresented = false
        }
        if let loadedDay, loadedDay != day {
            self.loadedDay = nil
            hasSavedToday = false
        }
    }

    private func apply(_ reflection: DailyReflection) {
        mostBlocked = reflection.mostBlocked
        spokeNaturally = reflection.spokeNaturally
        spokeNaturallyNote = reflection.spokeNaturallyNote
        completionReason = reflection.completionReason
        completionReasonNote = reflection.completionReasonNote
    }

    private func clearForm() {
        mostBlocked = ""
        spokeNaturally = nil
        spokeNaturallyNote = ""
        completionReason = .completed
        completionReasonNote = ""
    }
}
