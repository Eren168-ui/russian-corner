import Foundation

public let significantOverdueThreshold = 20

public enum ReviewScheduler {
    private static let day: TimeInterval = 24 * 60 * 60
    private static let easyIntervalsInDays = [1, 3, 7, 14, 30]

    public static func next(
        state: ReviewState,
        grade: ReviewGrade,
        now: Date
    ) -> ReviewState {
        switch grade {
        case .again:
            ReviewState(
                masteryLevel: 0,
                dueAt: now.addingTimeInterval(day)
            )
        case .hard:
            ReviewState(
                masteryLevel: state.masteryLevel,
                dueAt: now.addingTimeInterval(day)
            )
        case .easy:
            easyState(after: state, now: now)
        }
    }

    private static func easyState(
        after state: ReviewState,
        now: Date
    ) -> ReviewState {
        let currentLevel = min(max(state.masteryLevel, 0), easyIntervalsInDays.count)
        let intervalIndex = min(currentLevel, easyIntervalsInDays.count - 1)
        let nextLevel = min(currentLevel + 1, easyIntervalsInDays.count)
        let interval = TimeInterval(easyIntervalsInDays[intervalIndex]) * day

        return ReviewState(
            masteryLevel: nextLevel,
            dueAt: now.addingTimeInterval(interval)
        )
    }
}

public func adaptiveNewWordLimit(
    previousRecallRate: Double,
    strongDayStreak: Int,
    overdueCount: Int
) -> Int {
    if previousRecallRate < 0.75
        || overdueCount >= significantOverdueThreshold
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
