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

  func testViewDisappearStopsPlaybackAndDiscardsTemporaryRecording() throws {
    let recording = PracticeRecordingManager()
    recording.isRecording = true
    recording.temporaryRecordingURL = URL(
      fileURLWithPath: "/tmp/practice-disappear.m4a"
    )
    let playback = PracticeRecordingPlayer()
    playback.isPlaying = true
    let model = try makeModel(
      recordingService: recording,
      playbackService: playback
    )

    model.handleDisappear()

    XCTAssertEqual(playback.stopCallCount, 1)
    XCTAssertEqual(recording.stopCallCount, 1)
    XCTAssertEqual(recording.discardCallCount, 1)
    XCTAssertFalse(recording.isRecording)
    XCTAssertNil(recording.temporaryRecordingURL)
  }

  private func makeModel(
    sentenceCount: Int = 1,
    speechService: SpeechService = SpeechService(),
    recordingService: any RecordingManaging = RecordingService(),
    playbackService: any RecordingPlaying = RecordingPlaybackService()
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
      speechService: speechService,
      recordingService: recordingService,
      playbackService: playbackService
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

@MainActor
private final class PracticeRecordingManager: RecordingManaging {
  var isRecording = false
  var temporaryRecordingURL: URL?
  private(set) var stopCallCount = 0
  private(set) var discardCallCount = 0

  func permissionStatus() -> MicrophonePermissionStatus { .granted }
  func requestPermission() async -> MicrophonePermissionStatus { .granted }
  func start() async -> RecordingStartResult { .unavailable }

  func stop() {
    stopCallCount += 1
    isRecording = false
  }

  func discard() throws {
    discardCallCount += 1
    temporaryRecordingURL = nil
    isRecording = false
  }

  func save(to destinationURL: URL) throws -> RecordingSaveOutcome {
    .saved(
      destinationURL: destinationURL,
      temporaryCleanupPending: false
    )
  }
}

@MainActor
private final class PracticeRecordingPlayer: RecordingPlaying {
  var isPlaying = false
  private(set) var stopCallCount = 0

  func play(url: URL) -> RecordingPlaybackResult {
    isPlaying = true
    return .playing(url)
  }

  func stop() {
    stopCallCount += 1
    isPlaying = false
  }
}
