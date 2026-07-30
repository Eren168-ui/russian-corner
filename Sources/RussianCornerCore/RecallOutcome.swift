import Foundation

public enum RecallOutcome: String, Codable, Equatable, Sendable {
    case fluentWithinThreeSeconds
    case coreMeaningWithUsageIssue
    case rememberedAfterReveal
    case unknown

    public func reviewGrade(
        responseTimeMs: Int,
        transferCorrect: Bool
    ) -> ReviewGrade {
        switch self {
        case .fluentWithinThreeSeconds:
            return responseTimeMs <= 3_000 && transferCorrect
                ? .easy : .hard
        case .coreMeaningWithUsageIssue:
            return .hard
        case .rememberedAfterReveal, .unknown:
            return .again
        }
    }

    public var requiresTransferCheck: Bool {
        switch self {
        case .fluentWithinThreeSeconds,
            .coreMeaningWithUsageIssue:
            true
        case .rememberedAfterReveal, .unknown:
            false
        }
    }
}
