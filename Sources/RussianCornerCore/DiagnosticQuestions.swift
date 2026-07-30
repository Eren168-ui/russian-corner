import Foundation

public struct DiagnosticChoiceOption:
    Identifiable,
    Equatable,
    Hashable,
    Sendable
{
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct DiagnosticChoiceQuestion:
    Identifiable,
    Equatable,
    Sendable
{
    public let id: String
    public let prompt: String
    public let itemKind: PracticeItemKind
    public let itemID: String
    public let options: [DiagnosticChoiceOption]
    public let correctOptionID: String

    public init(
        id: String,
        prompt: String,
        itemKind: PracticeItemKind,
        itemID: String,
        options: [DiagnosticChoiceOption],
        correctOptionID: String
    ) {
        self.id = id
        self.prompt = prompt
        self.itemKind = itemKind
        self.itemID = itemID
        self.options = options
        self.correctOptionID = correctOptionID
    }

    public var correctOption: DiagnosticChoiceOption {
        options.first { $0.id == correctOptionID }
            ?? DiagnosticChoiceOption(id: correctOptionID, text: "")
    }

    public func isCorrect(_ optionID: String) -> Bool {
        optionID == correctOptionID
    }
}

public enum DiagnosticProductionOutcome:
    String,
    CaseIterable,
    Equatable,
    Sendable
{
    case completeFast
    case partial
    case recalledAfterReveal
    case unknown

    public var reviewGrade: ReviewGrade {
        switch self {
        case .completeFast: .easy
        case .partial: .hard
        case .recalledAfterReveal, .unknown: .again
        }
    }

    public var isSuccessful: Bool {
        self == .completeFast
    }
}

public struct DiagnosticQuestionBuilder: Sendable {
    private let seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
    }

    public func recognitionQuestion(
        for lexeme: Lexeme,
        pool: [Lexeme]
    ) -> DiagnosticChoiceQuestion {
        let preferred = pool.filter {
            $0.id != lexeme.id
                && $0.partOfSpeech == lexeme.partOfSpeech
        }
        let fallback = pool.filter {
            $0.id != lexeme.id
                && $0.partOfSpeech != lexeme.partOfSpeech
        }
        return question(
            id: "recognition-\(lexeme.id)",
            prompt: lexeme.stressedForm,
            itemKind: .lexeme,
            itemID: lexeme.id,
            correctText: lexeme.glossZh,
            distractorTexts: (preferred + fallback).map(\.glossZh)
        )
    }

    public func listeningQuestion(
        for sentence: SentenceCard,
        pool: [SentenceCard]
    ) -> DiagnosticChoiceQuestion {
        question(
            id: "listening-\(sentence.id)",
            prompt: "选择最接近的中文意图",
            itemKind: .sentence,
            itemID: sentence.id,
            correctText: sentence.promptZh,
            distractorTexts: pool
                .filter { $0.id != sentence.id }
                .map(\.promptZh)
        )
    }

    public func collocationQuestion(
        for lexeme: Lexeme,
        pool: [Lexeme]
    ) -> DiagnosticChoiceQuestion {
        let correct = lexeme.collocations.first ?? lexeme.example
        return question(
            id: "collocation-\(lexeme.id)",
            prompt: "请选择与 \(lexeme.stressedForm) 自然搭配的表达",
            itemKind: .lexeme,
            itemID: lexeme.id,
            correctText: correct,
            distractorTexts: pool
                .filter { $0.id != lexeme.id }
                .compactMap { $0.collocations.first ?? $0.example }
        )
    }

    private func question(
        id: String,
        prompt: String,
        itemKind: PracticeItemKind,
        itemID: String,
        correctText: String,
        distractorTexts: [String]
    ) -> DiagnosticChoiceQuestion {
        var seen = Set([correctText])
        let distractors = distractorTexts.filter {
            seen.insert($0).inserted
        }
        var options = [
            DiagnosticChoiceOption(
                id: "\(id)-correct",
                text: correctText
            )
        ]
        options.append(
            contentsOf: distractors.prefix(3).enumerated().map {
                DiagnosticChoiceOption(
                    id: "\(id)-distractor-\($0.offset)",
                    text: $0.element
                )
            }
        )
        var generator = DiagnosticOptionGenerator(
            seed: seed ^ Self.stableHash(id)
        )
        options.shuffle(using: &generator)
        return DiagnosticChoiceQuestion(
            id: id,
            prompt: prompt,
            itemKind: itemKind,
            itemID: itemID,
            options: options,
            correctOptionID: "\(id)-correct"
        )
    }

    private static func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(1_469_598_103_934_665_603) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
    }
}

private struct DiagnosticOptionGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
