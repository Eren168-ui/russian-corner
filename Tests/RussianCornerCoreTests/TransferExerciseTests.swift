import XCTest

@testable import RussianCornerCore

final class TransferExerciseTests: XCTestCase {
    func testFastFluentRecallNeedsCorrectTransferForEasy() {
        XCTAssertEqual(
            RecallOutcome.fluentWithinThreeSeconds.reviewGrade(
                responseTimeMs: 2_400,
                transferCorrect: true
            ),
            .easy
        )
        XCTAssertEqual(
            RecallOutcome.fluentWithinThreeSeconds.reviewGrade(
                responseTimeMs: 2_400,
                transferCorrect: false
            ),
            .hard
        )
    }

    func testSlowOrPartialRecallCannotBecomeEasy() {
        XCTAssertEqual(
            RecallOutcome.fluentWithinThreeSeconds.reviewGrade(
                responseTimeMs: 3_500,
                transferCorrect: true
            ),
            .hard
        )
        XCTAssertEqual(
            RecallOutcome.coreMeaningWithUsageIssue.reviewGrade(
                responseTimeMs: 1_800,
                transferCorrect: true
            ),
            .hard
        )
    }

    func testRevealOnlyAndUnknownReturnAgain() {
        XCTAssertEqual(
            RecallOutcome.rememberedAfterReveal.reviewGrade(
                responseTimeMs: 2_000,
                transferCorrect: true
            ),
            .again
        )
        XCTAssertEqual(
            RecallOutcome.unknown.reviewGrade(
                responseTimeMs: 1_000,
                transferCorrect: false
            ),
            .again
        )
    }

    func testExerciseRequiresOneResolvableCorrectAnswer() throws {
        let exercise = try TransferExercise(
            id: "reply-check",
            kind: .nextReplySelection,
            prompt: "What would be a natural reply?",
            options: [
                TransferOption(id: "a", text: "That works for me."),
                TransferOption(id: "b", text: "I haven't decided yet."),
                TransferOption(id: "c", text: "Could you say that again?"),
            ],
            correctOptionID: "a"
        )

        XCTAssertTrue(exercise.isCorrect(optionID: "a"))
        XCTAssertFalse(exercise.isCorrect(optionID: "b"))
        XCTAssertThrowsError(
            try TransferExercise(
                id: "invalid",
                kind: .collocationCompletion,
                prompt: "Complete it",
                options: [
                    TransferOption(id: "same", text: "one"),
                    TransferOption(id: "same", text: "two"),
                ],
                correctOptionID: "same"
            )
        )
    }
}
