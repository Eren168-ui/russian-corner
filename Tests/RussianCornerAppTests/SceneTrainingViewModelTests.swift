import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
final class SceneTrainingViewModelTests: XCTestCase {
  func testLessonFollowsApprovedSpeakingAndListeningStages() throws {
    let fixture = makeFixture()
    let model = try SceneTrainingViewModel(
      lesson: fixture.lesson,
      catalog: fixture.catalog,
      defaults: fixture.defaults
    )

    XCTAssertEqual(model.stage, .context)
    let expected: [SceneTrainingStage] = [
      .bilingual,
      .englishOnly,
      .audioFirst,
      .shadowing,
      .retell,
      .variants,
      .dialogue,
      .selection,
    ]
    for stage in expected {
      model.advanceStage()
      XCTAssertEqual(model.stage, stage)
    }
  }

  func testReopeningRestoresCurrentStageAndSentence() throws {
    let fixture = makeFixture()
    let first = try SceneTrainingViewModel(
      lesson: fixture.lesson,
      catalog: fixture.catalog,
      defaults: fixture.defaults
    )
    first.advanceStage()
    first.advanceStage()
    first.moveToNextSentence()

    let reopened = try SceneTrainingViewModel(
      lesson: fixture.lesson,
      catalog: fixture.catalog,
      defaults: fixture.defaults
    )

    XCTAssertEqual(reopened.stage, .englishOnly)
    XCTAssertEqual(reopened.currentSentenceIndex, 1)
  }

  func testCompletingLessonOffersSelectedExpressionsToQueue() throws {
    let fixture = makeFixture()
    var offered: [String] = []
    let model = try SceneTrainingViewModel(
      lesson: fixture.lesson,
      catalog: fixture.catalog,
      defaults: fixture.defaults,
      onOfferSelectedExpressions: { offered = $0 }
    )
    model.toggleExpressionSelection("sentence-one")
    while model.stage != .selection {
      model.advanceStage()
    }

    model.advanceStage()

    XCTAssertTrue(model.isComplete)
    XCTAssertEqual(offered, ["sentence-one"])
  }

  func testEveryEnglishWordCanOpenDictionaryLookup() async throws {
    let fixture = makeFixture()
    let dictionary = SceneRecordingDictionary()
    let model = try SceneTrainingViewModel(
      lesson: fixture.lesson,
      catalog: fixture.catalog,
      defaults: fixture.defaults,
      onlineDictionary: dictionary
    )

    await model.selectWord(tokenIndex: 1)

    XCTAssertEqual(model.selectedWord, "we")
    XCTAssertEqual(
      try XCTUnwrap(model.wordLookupResult).translations,
      ["我们"]
    )
    let queries = await dictionary.queries()
    XCTAssertEqual(queries, ["we"])
  }

  func testEnglishRuntimeBuildsTodaySceneTraining() throws {
    let fixture = makeFixture()
    let runtime = AppRuntime(
      defaults: fixture.defaults,
      language: .english,
      catalog: ContentCatalog(
        lexemes: [],
        sentences: fixture.catalog.sentences.map(\.legacyContent)
      ),
      studyCatalog: fixture.catalog,
      sceneLessons: [fixture.lesson],
      repository: ProgressRepository(
        container: try ProgressRepository.makeContainer(
          inMemory: true,
          language: .english
        )
      ),
      enableSystemReminders: false
    )

    XCTAssertEqual(runtime.sceneLessons.count, 1)
    XCTAssertNotNil(try runtime.makeTodaySceneTraining())
  }

  private func makeFixture() -> (
    lesson: SceneLesson,
    catalog: LanguageContentCatalog,
    defaults: UserDefaults
  ) {
    let suite = "SceneTrainingViewModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    addTeardownBlock {
      defaults.removePersistentDomain(forName: suite)
    }
    let sentences = [
      makeSentence(id: "sentence-one", index: 1),
      makeSentence(id: "sentence-two", index: 2),
    ]
    return (
      SceneLesson(
        id: "lesson-one",
        language: .english,
        topicID: "topic-one",
        titleZh: "改期",
        contextZh: "和朋友重新约时间。",
        sentenceIDs: sentences.map(\.id),
        dialogueOrder: sentences.map(\.id)
      ),
      LanguageContentCatalog(lexemes: [], sentences: sentences),
      defaults
    )
  }

  private func makeSentence(
    id: String,
    index: Int
  ) -> StudySentence {
    StudySentence(
      id: id,
      language: .english,
      promptZh: "中文意图 \(index)",
      cueText: "Cue \(index)",
      targetText: "Could we move it to Friday \(index)?",
      displayText: "Could we move it to Friday \(index)?",
      speechText: "Could we move it to Friday \(index)?",
      theme: "Scheduling",
      lexemeIDs: [],
      expectedReplies: ["Friday works for me."],
      variants: [
        SentenceVariant(
          promptZh: "换到周六",
          targetText: "Could we move it to Saturday?"
        ),
      ],
      reviewStatus: .reviewed,
      provenanceType: .derived,
      sourcePath: "bundled/english/scheduling"
    )
  }
}

private actor SceneRecordingDictionary: OnlineDictionaryLookingUp {
  private var recorded: [String] = []

  func lookup(
    lemma: String,
    language: StudyLanguage
  ) async throws -> OnlineDictionaryResult {
    recorded.append(lemma)
    return OnlineDictionaryResult(
      lemma: lemma,
      partOfSpeech: "pronoun",
      translations: ["我们"],
      synonyms: [],
      examples: []
    )
  }

  func queries() -> [String] {
    recorded
  }
}
