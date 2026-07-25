import Foundation

public struct ReviewScheduler: Sendable {
    public static let significantOverdueThreshold = 20

    private static let day: TimeInterval = 24 * 60 * 60
    private static let easyIntervalsInDays = [1, 3, 7, 14, 30]

    public init() {}

    public func next(
        state: ReviewState,
        grade: ReviewGrade,
        now: Date
    ) -> ReviewState {
        switch grade {
        case .again:
            ReviewState(
                masteryLevel: 0,
                dueAt: now.addingTimeInterval(Self.day)
            )
        case .hard:
            ReviewState(
                masteryLevel: state.masteryLevel,
                dueAt: now.addingTimeInterval(Self.day)
            )
        case .easy:
            easyState(after: state, now: now)
        }
    }

    public func adaptiveNewWordLimit(
        previousRecallRate: Double,
        strongDayStreak: Int,
        overdueCount: Int
    ) -> Int {
        if previousRecallRate < 0.75
            || overdueCount >= Self.significantOverdueThreshold
        {
            return 6
        }

        if previousRecallRate > 0.90
            && strongDayStreak >= 3
        {
            return 12
        }

        return 10
    }

    private func easyState(
        after state: ReviewState,
        now: Date
    ) -> ReviewState {
        let currentLevel = min(
            max(state.masteryLevel, 0),
            Self.easyIntervalsInDays.count
        )
        let intervalIndex = min(
            currentLevel,
            Self.easyIntervalsInDays.count - 1
        )
        let nextLevel = min(
            currentLevel + 1,
            Self.easyIntervalsInDays.count
        )
        let interval = TimeInterval(
            Self.easyIntervalsInDays[intervalIndex]
        ) * Self.day

        return ReviewState(
            masteryLevel: nextLevel,
            dueAt: now.addingTimeInterval(interval)
        )
    }
}
