import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

public enum PracticeViewModelError:
  LocalizedError,
  Equatable,
  Sendable
{
  case answerNotRevealed

  public var errorDescription: String? {
    switch self {
    case .answerNotRevealed:
      return "请先显示答案，再提交评分"
    }
  }
}

@MainActor
@Observable
public final class PracticeViewModel {
  public private(set) var queue: [SentenceCard]
  public private(set) var currentIndex = 0
  public private(set) var isRevealed = false
  public private(set) var remainingRecallSeconds = 3
  public private(set) var completedToday: Int
  public private(set) var statusMessage: String?
  public let targetCount: Int
  public var mode: PracticeMode

  private let repository: any PracticeProgressStoring
  private let scheduler: ReviewScheduler
  private let speechService: SpeechService
  private let recordingService: any RecordingManaging
  private let playbackService: any RecordingPlaying
  private let recordingsDirectory: URL
  private let now: () -> Date
  private var states: [String: ReviewState]
  private var recallStartedAt: Date

  public var currentCard: SentenceCard? {
    queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
  }

  public var totalCount: Int {
    queue.count
  }

  public var prompt: String? {
    guard let card = currentCard else { return nil }
    let mastery = states[card.id]?.masteryLevel ?? 0
    let cueDiffersFromAnswer =
      card.cueRu.trimmingCharacters(in: .whitespacesAndNewlines)
      .caseInsensitiveCompare(
        card.practiceRu.trimmingCharacters(in: .whitespacesAndNewlines)
      ) != .orderedSame
    return mastery >= 3 && cueDiffersFromAnswer
      ? card.cueRu : card.promptZh
  }

  public var answer: String? {
    isRevealed ? currentCard?.practiceRu : nil
  }

  public init(
    catalog: ContentCatalog,
    repository: any PracticeProgressStoring,
    targetCount: Int = 7,
    mode: PracticeMode = .quiet,
    now: @escaping () -> Date = Date.init,
    scheduler: ReviewScheduler = ReviewScheduler(),
    speechService: SpeechService = SpeechService(),
    recordingService: any RecordingManaging = RecordingService(),
    playbackService: any RecordingPlaying = RecordingPlaybackService(),
    recordingsDirectory: URL? = nil
  ) throws {
    self.repository = repository
    self.targetCount = min(max(targetCount, 5), 10)
    self.mode = mode
    self.now = now
    self.scheduler = scheduler
    self.speechService = speechService
    self.recordingService = recordingService
    self.playbackService = playbackService
    self.recordingsDirectory =
      recordingsDirectory ?? Self.defaultRecordingsDirectory
    let instant = now()
    recallStartedAt = instant
    completedToday =
      try repository.dailyCompletedCount(
        on: instant,
        calendar: .current
      ) ?? 0

    var restored: [String: ReviewState] = [:]
    var due: [PracticeItem] = []
    var fresh: [PracticeItem] = []
    var review: [PracticeItem] = []
    for card in catalog.sentences {
      let item = PracticeItem(id: card.id, kind: .sentence)
      if let state = try repository.progress(
        itemType: .sentence,
        itemId: card.id
      ) {
        restored[card.id] = state
        if state.dueAt <= instant {
          due.append(item)
        } else {
          review.append(item)
        }
      } else {
        fresh.append(item)
      }
    }
    states = restored
    let items = DailyQueueBuilder().build(
      due: due,
      new: fresh,
      randomReview: review,
      targetCount: self.targetCount,
      retryIDs: []
    )
    let cardsByID = Dictionary(
      uniqueKeysWithValues: catalog.sentences.map { ($0.id, $0) }
    )
    queue = items.compactMap { cardsByID[$0.id] }
  }

  public func reveal() {
    isRevealed = true
    refreshRecallTimer()
  }

  public func refreshRecallTimer() {
    let elapsed = max(0, now().timeIntervalSince(recallStartedAt))
    remainingRecallSeconds = max(0, Int(ceil(3 - elapsed)))
  }

  public func grade(_ grade: ReviewGrade) throws {
    guard isRevealed else {
      throw PracticeViewModelError.answerNotRevealed
    }
    guard let card = currentCard else { return }
    let cleanupMessage = cleanupRecordingForTransition()
    let instant = now()
    let elapsed = max(0, instant.timeIntervalSince(recallStartedAt))
    let event = ReviewEvent(
      itemType: .sentence,
      itemId: card.id,
      grade: grade,
      responseTimeMs: Int((elapsed * 1_000).rounded()),
      practiceMode: mode,
      createdAt: instant
    )
    let oldState =
      states[card.id]
      ?? ReviewState(masteryLevel: 0, dueAt: instant)
    let newState = scheduler.next(
      state: oldState,
      grade: grade,
      now: instant
    )
    let newCompletedCount = completedToday + 1
    try repository.commitReview(
      event: event,
      state: newState,
      dailyCompletedCount: newCompletedCount,
      calendar: .current
    )
    states[card.id] = newState
    completedToday = newCompletedCount
    advance(status: cleanupMessage)
  }

  public func next() {
    let cleanupMessage = cleanupRecordingForTransition()
    advance(status: cleanupMessage)
  }

  private func advance(status: String?) {
    guard !queue.isEmpty else { return }
    currentIndex = (currentIndex + 1) % queue.count
    isRevealed = false
    remainingRecallSeconds = 3
    recallStartedAt = now()
    statusMessage = status
  }

  public func showStatus(_ message: String) {
    statusMessage = message
  }

  public var isRecording: Bool {
    recordingService.isRecording
  }

  public var hasRecording: Bool {
    recordingService.temporaryRecordingURL != nil
  }

  public var isPlayingRecording: Bool {
    playbackService.isPlaying
  }

  public func speak() {
    guard let text = currentCard?.speechText else { return }
    switch speechService.speak(text) {
    case .russianVoice:
      statusMessage = "正在朗读俄语"
    case .fallbackVoice(_, let language):
      statusMessage = "未找到俄语语音，使用 \(language) 朗读"
    case .unavailable:
      statusMessage = "系统中没有可用语音，练习可继续"
    case .emptyText:
      statusMessage = "本卡没有可朗读内容"
    }
  }

  public func toggleRecording() async {
    if recordingService.isRecording {
      recordingService.stop()
      statusMessage = "录音已停止，可播放、保存或丢弃"
      return
    }
    var result = await recordingService.start()
    if result == .permissionUndetermined {
      let permission = await recordingService.requestPermission()
      if permission == .granted {
        result = await recordingService.start()
      }
    }
    switch result {
    case .started:
      statusMessage = "正在录音"
    case .permissionDenied:
      statusMessage = "麦克风权限未开启，仍可继续练习"
    case .permissionUndetermined:
      statusMessage = "尚未取得麦克风权限，仍可继续练习"
    case .unavailable:
      statusMessage = "当前设备无法录音，仍可继续练习"
    case .failed(let message):
      statusMessage = "录音未开始：\(message)"
    }
  }

  public func playRecording() {
    guard let url = recordingService.temporaryRecordingURL else {
      statusMessage = "没有可播放的录音"
      return
    }
    if recordingService.isRecording {
      recordingService.stop()
    }
    switch playbackService.play(url: url) {
    case .playing:
      statusMessage = "正在播放录音"
    case .failed(let message):
      statusMessage = "录音播放失败：\(message)"
    }
  }

  @discardableResult
  public func saveRecording() throws -> URL {
    guard recordingService.temporaryRecordingURL != nil else {
      throw RecordingServiceError.noTemporaryRecording
    }
    if recordingService.isRecording {
      recordingService.stop()
    }
    playbackService.stop()
    try FileManager.default.createDirectory(
      at: recordingsDirectory,
      withIntermediateDirectories: true
    )
    let destination =
      recordingsDirectory
      .appendingPathComponent(
        "recording-\(UUID().uuidString)",
        isDirectory: false
      )
      .appendingPathExtension("m4a")
    let outcome = try recordingService.save(to: destination)
    switch outcome {
    case .saved(_, let cleanupPending):
      statusMessage =
        cleanupPending
        ? "录音已保存，临时文件稍后清理"
        : "录音已保存"
    }
    return destination
  }

  public func discardRecording() {
    playbackService.stop()
    if recordingService.isRecording {
      recordingService.stop()
    }
    do {
      try recordingService.discard()
      statusMessage = "录音已丢弃"
    } catch {
      statusMessage = "录音暂未清理：\(error.localizedDescription)"
    }
  }

  private func cleanupRecordingForTransition() -> String? {
    playbackService.stop()
    guard
      recordingService.isRecording
        || recordingService.temporaryRecordingURL != nil
    else {
      return nil
    }
    if recordingService.isRecording {
      recordingService.stop()
    }
    do {
      try recordingService.discard()
      return nil
    } catch {
      return "切换已继续，录音暂未清理：\(error.localizedDescription)"
    }
  }

  private static var defaultRecordingsDirectory: URL {
    let base =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    return
      base
      .appendingPathComponent("RussianCorner", isDirectory: true)
      .appendingPathComponent("Recordings", isDirectory: true)
  }
}
