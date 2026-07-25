import Foundation

public enum ReviewGrade: String, Codable, Equatable, Sendable {
    case again
    case hard
    case easy
}

public struct ReviewState: Codable, Equatable, Sendable {
    public let masteryLevel: Int
    public let dueAt: Date

    public init(masteryLevel: Int, dueAt: Date) {
        self.masteryLevel = masteryLevel
        self.dueAt = dueAt
    }
}
