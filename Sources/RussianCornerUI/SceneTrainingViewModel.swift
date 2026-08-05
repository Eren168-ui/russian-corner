import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

public enum SceneTrainingStage:
  Int,
  Codable,
  CaseIterable,
  Equatable,
  Sendable
{
  case context
  case bilingual
  case englishOnly
  case audioFirst
  case shadowing
  case retell
  case variants
  case dialogue
  case selection

  public var titleZh: String {
    titleZh(for: .english)
  }

  public func titleZh(for language: StudyLanguage) -> String {
    switch self {
    case .context: "进入场景"
    case .bilingual: "理解表达"
    case .englishOnly: language == .russian ? "只看俄语" : "只看英语"
    case .audioFirst: "先听后看"
    case .shadowing: "逐句跟读"
    case .retell: "脱稿复述"
    case .variants: "替换信息"
    case .dialogue: "接下一轮"
    case .selection: "加入日常复习"
    }
  }
}

public enum SceneTrainingViewModelError:
  LocalizedError,
  Equatable,
  Sendable
{
  case noResolvedSentences

  public var errorDescription: String? {
    switch self {
    case .noResolvedSentences:
      "这个场景暂时没有可用表达"
    }
  }
}

private struct SceneTrainingProgress: Codable {
  var stageRawValue: Int
  var currentSentenceIndex: Int
  var selectedExpressionIDs: [String]
  var isComplete: Bool
  var chineseSupportEnabled: Bool
}

@MainActor
@Observable
public final class SceneTrainingViewModel {
  public let lesson: SceneLesson
  public let sentences: [StudySentence]
  public private(set) var stage: SceneTrainingStage
  public private(set) var currentSentenceIndex: Int
  public private(set) var selectedExpressionIDs: Set<String>
  public private(set) var isComplete: Bool
  public private(set) var selectedTokenIndex: Int?
  public private(set) var selectedWord: String?
  public private(set) var wordLookupResult: OnlineDictionaryResult?
  public private(set) var wordLookupIssue: String?
  public var chineseSupportEnabled: Bool {
    didSet { persist() }
  }
  public var isTextHidden = false

  public var currentSentence: StudySentence {
    sentences[currentSentenceIndex]
  }

  public var dialogueSentences: [StudySentence] {
    let byID = Dictionary(
      uniqueKeysWithValues: sentences.map { ($0.id, $0) }
    )
    return lesson.dialogueOrder.compactMap { byID[$0] }
  }

  public var stageProgress: Double {
    let lastIndex = max(SceneTrainingStage.allCases.count - 1, 1)
    return Double(stage.rawValue) / Double(lastIndex)
  }

  private let defaults: UserDefaults
  private let progressKey: String
  private let speechService: SpeechService
  private let onlineDictionary: any OnlineDictionaryLookingUp
  private let onOfferSelectedExpressions: ([String]) -> Void

  public init(
    lesson: SceneLesson,
    catalog: LanguageContentCatalog,
    defaults: UserDefaults = .standard,
    speechService: SpeechService = SpeechService(),
    onlineDictionary: any OnlineDictionaryLookingUp =
      YandexDictionaryService(),
    onOfferSelectedExpressions: @escaping ([String]) -> Void = { _ in }
  ) throws {
    let sentencesByID = Dictionary(
      uniqueKeysWithValues: catalog.sentences
        .filter { $0.language == lesson.language }
        .map { ($0.id, $0) }
    )
    let resolved = lesson.sentenceIDs.compactMap {
      sentencesByID[$0]
    }
    guard !resolved.isEmpty else {
      throw SceneTrainingViewModelError.noResolvedSentences
    }
    self.lesson = lesson
    sentences = resolved
    self.defaults = defaults
    self.speechService = speechService
    self.onlineDictionary = onlineDictionary
    self.onOfferSelectedExpressions = onOfferSelectedExpressions
    progressKey = "\(lesson.language.storageNamespace).sceneTraining.\(lesson.id)"

    if let data = defaults.data(forKey: progressKey),
      let progress = try? JSONDecoder().decode(
        SceneTrainingProgress.self,
        from: data
      )
    {
      stage = SceneTrainingStage(
        rawValue: progress.stageRawValue
      ) ?? .context
      currentSentenceIndex = min(
        max(progress.currentSentenceIndex, 0),
        resolved.count - 1
      )
      selectedExpressionIDs = Set(
        progress.selectedExpressionIDs.filter {
          sentencesByID[$0] != nil
        }
      )
      isComplete = progress.isComplete
      chineseSupportEnabled = progress.chineseSupportEnabled
    } else {
      stage = .context
      currentSentenceIndex = 0
      selectedExpressionIDs = []
      isComplete = false
      chineseSupportEnabled = true
    }
  }

  public func advanceStage() {
    guard !isComplete else { return }
    if stage == .selection {
      isComplete = true
      let orderedSelection = lesson.sentenceIDs.filter {
        selectedExpressionIDs.contains($0)
      }
      onOfferSelectedExpressions(orderedSelection)
      persist()
      return
    }
    stage = SceneTrainingStage(rawValue: stage.rawValue + 1)
      ?? .selection
    currentSentenceIndex = 0
    isTextHidden = stage == .audioFirst
    persist()
  }

  public func moveToNextSentence() {
    currentSentenceIndex = min(
      currentSentenceIndex + 1,
      sentences.count - 1
    )
    persist()
  }

  public func moveToPreviousSentence() {
    currentSentenceIndex = max(currentSentenceIndex - 1, 0)
    persist()
  }

  public func toggleExpressionSelection(_ sentenceID: String) {
    guard sentences.contains(where: { $0.id == sentenceID }) else {
      return
    }
    if selectedExpressionIDs.contains(sentenceID) {
      selectedExpressionIDs.remove(sentenceID)
    } else {
      selectedExpressionIDs.insert(sentenceID)
    }
    persist()
  }

  public func toggleTextVisibility() {
    isTextHidden.toggle()
  }

  public func selectWord(tokenIndex: Int) async {
    let words = TargetLanguageTokenizer.words(
      in: currentSentence.displayText,
      language: lesson.language
    )
    guard words.indices.contains(tokenIndex) else { return }
    if selectedTokenIndex == tokenIndex {
      selectedTokenIndex = nil
      selectedWord = nil
      wordLookupResult = nil
      wordLookupIssue = nil
      return
    }
    let word = words[tokenIndex]
    selectedTokenIndex = tokenIndex
    selectedWord = word
    wordLookupResult = nil
    wordLookupIssue = nil
    do {
      wordLookupResult = try await onlineDictionary.lookup(
        lemma: word,
        language: lesson.language
      )
    } catch {
      wordLookupIssue =
        (error as? LocalizedError)?.errorDescription
        ?? "在线词典暂时不可用"
    }
  }

  public func speakCurrent(slow: Bool = false) {
    _ = speechService.speak(
      currentSentence.speechText,
      language: lesson.language,
      playbackRate: slow ? 0.38 : 0.5,
      allowUnrelatedFallback: false
    )
  }

  public func stopSpeech() {
    speechService.stop()
  }

  public func restart() {
    stage = .context
    currentSentenceIndex = 0
    selectedExpressionIDs = []
    isComplete = false
    chineseSupportEnabled = true
    isTextHidden = false
    selectedTokenIndex = nil
    selectedWord = nil
    wordLookupResult = nil
    wordLookupIssue = nil
    persist()
  }

  private func persist() {
    let progress = SceneTrainingProgress(
      stageRawValue: stage.rawValue,
      currentSentenceIndex: currentSentenceIndex,
      selectedExpressionIDs: Array(selectedExpressionIDs).sorted(),
      isComplete: isComplete,
      chineseSupportEnabled: chineseSupportEnabled
    )
    guard let data = try? JSONEncoder().encode(progress) else {
      return
    }
    defaults.set(data, forKey: progressKey)
  }
}
