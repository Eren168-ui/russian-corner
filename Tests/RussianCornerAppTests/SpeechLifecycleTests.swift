import Foundation
import RussianCornerCore
import RussianCornerPlatform
import XCTest

@testable import RussianCornerUI

@MainActor
final class PracticeSpeechLifecycleTests: XCTestCase {
  func testSpeechStopsBeforeEachReadAndWhenCardAdvancesOrViewLeaves() throws {
    let synthesizer = PracticeSpeechSynthesizer()
    let model = try makeModel(
      sentenceCount: 2,
      speechService: SpeechService(
        voiceProvider: PracticeVoiceProvider(),
        synthesizer: synthesizer
      )
    )

    model.speak()
    model.speak()

    XCTAssertEqual(synthesizer.requests.count, 2)
    XCTAssertEqual(synthesizer.stopCallCount, 2)

    model.next()
    XCTAssertEqual(synthesizer.stopCallCount, 3)

    model.handleDisappear()
    XCTAssertEqual(synthesizer.stopCallCount, 4)
  }

  func testCompletingFinalCardStopsSpeech() throws {
    let synthesizer = PracticeSpeechSynthesizer()
    let model = try makeModel(
      speechService: SpeechService(
        voiceProvider: PracticeVoiceProvider(),
        synthesizer: synthesizer
      )
    )
    model.speak()
    model.reveal()

    try model.grade(.easy)

    XCTAssertTrue(model.isComplete)
    XCTAssertEqual(synthesizer.stopCallCount, 2)
  }

  private func makeModel(
    sentenceCount: Int = 1,
    speechService: SpeechService = SpeechService()
  ) throws -> PracticeViewModel {
    let sentences = (0..<sentenceCount).map { index in
      SentenceCard(
        id: "speech-sentence-\(index)",
        promptZh: "提示 \(index)",
        cueRu: "Что вы скажете?",
        practiceRu: "Я говорю.",
        speechText: "Я говорю.",
        theme: "日常",
        lexemeIDs: [],
        sourcePath: "fixture.md",
        sourceText: "fixture",
        reviewStatus: .reviewed
      )
    }
    return try PracticeViewModel(
      catalog: ContentCatalog(lexemes: [], sentences: sentences),
      repository: ProgressRepository(
        container: try ProgressRepository.makeInMemoryContainer()
      ),
      now: { Date(timeIntervalSince1970: 1_700_000_000) },
      speechService: speechService
    )
  }
}

private struct PracticeVoiceProvider: SpeechVoiceProviding {
  func availableVoices() -> [SpeechVoice] {
    [SpeechVoice(identifier: "russian", language: "ru-RU")]
  }
}

@MainActor
private final class PracticeSpeechSynthesizer: SpeechSynthesizing {
  struct Request {
    let text: String
    let voiceIdentifier: String
    let completion: @MainActor @Sendable (SpeechSynthesisOutcome) -> Void
  }

  private(set) var requests: [Request] = []
  private(set) var stopCallCount = 0

  func speak(
    _ text: String,
    voiceIdentifier: String,
    completion: @escaping @MainActor @Sendable (
      SpeechSynthesisOutcome
    ) -> Void
  ) {
    requests.append(
      Request(
        text: text,
        voiceIdentifier: voiceIdentifier,
        completion: completion
      )
    )
  }

  func stop() {
    stopCallCount += 1
  }
}
