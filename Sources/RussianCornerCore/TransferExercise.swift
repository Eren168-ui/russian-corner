import Foundation

public enum TransferExerciseKind:
    String,
    Codable,
    Equatable,
    Sendable
{
    case slotReplacement
    case collocationCompletion
    case nextReplySelection
}

public struct TransferOption:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public enum TransferExerciseValidationError:
    Error,
    Equatable,
    Sendable
{
    case emptyID
    case emptyPrompt
    case insufficientOptions
    case duplicateOptionID
    case duplicateOptionText
    case missingCorrectOption
}

public struct TransferExercise:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let kind: TransferExerciseKind
    public let prompt: String
    public let options: [TransferOption]
    public let correctOptionID: String

    public init(
        id: String,
        kind: TransferExerciseKind,
        prompt: String,
        options: [TransferOption],
        correctOptionID: String
    ) throws {
        let trimmedID = id.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedID.isEmpty else {
            throw TransferExerciseValidationError.emptyID
        }
        let trimmedPrompt = prompt.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedPrompt.isEmpty else {
            throw TransferExerciseValidationError.emptyPrompt
        }
        guard options.count >= 2 else {
            throw TransferExerciseValidationError.insufficientOptions
        }
        let optionIDs = options.map(\.id)
        guard Set(optionIDs).count == optionIDs.count else {
            throw TransferExerciseValidationError.duplicateOptionID
        }
        let normalizedTexts = options.map {
            $0.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased()
        }
        guard
            normalizedTexts.allSatisfy({ !$0.isEmpty }),
            Set(normalizedTexts).count == normalizedTexts.count
        else {
            throw TransferExerciseValidationError.duplicateOptionText
        }
        guard optionIDs.contains(correctOptionID) else {
            throw TransferExerciseValidationError.missingCorrectOption
        }
        self.id = trimmedID
        self.kind = kind
        self.prompt = trimmedPrompt
        self.options = options
        self.correctOptionID = correctOptionID
    }

    public func isCorrect(optionID: String) -> Bool {
        optionID == correctOptionID
    }
}
