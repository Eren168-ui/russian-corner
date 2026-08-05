import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
final class ExpressionCaptureViewModelTests: XCTestCase {
  func testImportedSelectionStartsAsDraftAndKeepsSource() throws {
    let store = try makeStore()
    let model = ExpressionCaptureViewModel(store: store)
    model.loadPastedText(
      """
      I was just about to call you.
      Let me get back to you.
      """
    )
    model.toggleSegmentSelection(1)
    model.promptZh = "我稍后回复你。"
    model.scene = "与朋友确认计划"

    let candidate = try model.saveSelectedAsDraft()

    XCTAssertEqual(candidate.targetText, "Let me get back to you.")
    XCTAssertEqual(candidate.reviewStatus, .draft)
    XCTAssertEqual(candidate.sourcePath, "pasted://local")
    XCTAssertTrue(candidate.sourceText.contains("about to call"))
    XCTAssertTrue(try store.practiceEligibleExpressions().isEmpty)
  }

  func testUserCanSelectPhraseInsteadOfImportingWholeSentence() throws {
    let store = try makeStore()
    let model = ExpressionCaptureViewModel(store: store)
    model.loadPastedText("I haven't made up my mind yet.")
    model.toggleSegmentSelection(0)
    model.selectedPhrase = "made up my mind"
    model.promptZh = "拿定主意"
    model.scene = "讨论选择"

    let candidate = try model.saveSelectedAsDraft()

    XCTAssertEqual(candidate.targetText, "made up my mind")
    XCTAssertEqual(
      candidate.sourceText,
      "I haven't made up my mind yet."
    )
  }

  func testOnlyExplicitlyReviewedCandidateCanEnterPractice() throws {
    let store = try makeStore()
    var reviewedIDs: [String] = []
    let model = ExpressionCaptureViewModel(
      store: store,
      onReviewed: { reviewedIDs.append($0) }
    )
    model.loadPastedText("That works for me.")
    model.toggleSegmentSelection(0)
    model.promptZh = "这样我可以。"
    model.scene = "确认安排"
    let candidate = try model.saveSelectedAsDraft()

    try model.markReviewed(candidate.id)

    XCTAssertEqual(
      try store.practiceEligibleExpressions().map(\.id),
      [candidate.id]
    )
    XCTAssertEqual(reviewedIDs, [candidate.id])
  }

  func testRussianCaptureKeepsLanguageThroughReview() throws {
    let store = try makeStore()
    let model = ExpressionCaptureViewModel(store: store, language: .russian)
    model.loadPastedText("Мне нужно уточнить время встречи.")
    model.toggleSegmentSelection(0)
    model.promptZh = "我需要确认见面时间。"
    model.scene = "确认安排"

    let candidate = try model.saveSelectedAsDraft()
    try model.markReviewed(candidate.id)

    XCTAssertEqual(candidate.language, .russian)
    XCTAssertEqual(try store.load().first?.language, .russian)
  }

  private func makeStore() throws -> ExpressionCaptureStore {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directory)
    }
    return ExpressionCaptureStore(
      fileURL: directory.appendingPathComponent("expressions.json")
    )
  }
}
