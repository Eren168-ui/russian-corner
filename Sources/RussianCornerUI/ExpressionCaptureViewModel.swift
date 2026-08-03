import Foundation
import Observation
import RussianCornerCore
import RussianCornerPlatform

public enum ExpressionCaptureError:
  LocalizedError,
  Equatable,
  Sendable
{
  case noSelection
  case missingChineseIntent
  case missingScene
  case phraseOutsideSelection
  case candidateNotFound

  public var errorDescription: String? {
    switch self {
    case .noSelection: "请先选择一条表达"
    case .missingChineseIntent: "请补充这句话的中文意图"
    case .missingScene: "请补充这句话适合使用的场景"
    case .phraseOutsideSelection: "所选短语必须来自勾选的原句"
    case .candidateNotFound: "没有找到这条候选表达"
    }
  }
}

@MainActor
@Observable
public final class ExpressionCaptureViewModel {
  public private(set) var preview: SubtitleParseResult?
  public private(set) var selectedSegmentIDs: Set<Int> = []
  public private(set) var candidates: [ImportedExpression]
  public private(set) var statusMessage: String?
  public var selectedPhrase = ""
  public var promptZh = ""
  public var scene = ""
  public var speakerRole = ""
  public var register: DialogueRegister = .neutral
  public var expectedReply = ""
  public var pastedText = ""

  private let store: ExpressionCaptureStore
  private let onReviewed: (String) -> Void

  public init(
    store: ExpressionCaptureStore,
    onReviewed: @escaping (String) -> Void = { _ in }
  ) {
    self.store = store
    self.onReviewed = onReviewed
    candidates = (try? store.load()) ?? []
  }

  public convenience init(
    onReviewed: @escaping (String) -> Void = { _ in }
  ) throws {
    self.init(
      store: ExpressionCaptureStore(
        fileURL: try ExpressionCaptureStore.defaultFileURL()
      ),
      onReviewed: onReviewed
    )
  }

  public func loadFile(_ url: URL) throws {
    preview = try SubtitleParser.parse(fileURL: url)
    selectedSegmentIDs = []
    selectedPhrase = ""
    statusMessage = "已读取 \(preview?.segments.count ?? 0) 条候选"
  }

  public func loadPastedText(_ text: String? = nil) {
    let sourceText = text ?? pastedText
    preview = SubtitleParser.parse(
      text: sourceText,
      fileExtension: "txt",
      sourcePath: "pasted://local"
    )
    selectedSegmentIDs = []
    selectedPhrase = ""
    statusMessage = "已拆分为 \(preview?.segments.count ?? 0) 条候选"
  }

  public func toggleSegmentSelection(_ id: Int) {
    if selectedSegmentIDs.contains(id) {
      selectedSegmentIDs.remove(id)
    } else {
      selectedSegmentIDs.insert(id)
    }
  }

  @discardableResult
  public func saveSelectedAsDraft() throws -> ImportedExpression {
    guard let preview else {
      throw ExpressionCaptureError.noSelection
    }
    let selected = preview.segments.filter {
      selectedSegmentIDs.contains($0.id)
    }
    guard !selected.isEmpty else {
      throw ExpressionCaptureError.noSelection
    }
    let selectedSource = selected.map(\.text)
      .joined(separator: " ")
    let phrase = selectedPhrase.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    if !phrase.isEmpty,
      selectedSource.range(
        of: phrase,
        options: [.caseInsensitive, .diacriticInsensitive]
      ) == nil
    {
      throw ExpressionCaptureError.phraseOutsideSelection
    }
    let intent = promptZh.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !intent.isEmpty else {
      throw ExpressionCaptureError.missingChineseIntent
    }
    let sceneValue = scene.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !sceneValue.isEmpty else {
      throw ExpressionCaptureError.missingScene
    }
    let expression = ImportedExpression(
      targetText: phrase.isEmpty ? selectedSource : phrase,
      promptZh: intent,
      scene: sceneValue,
      speakerRole: nilIfEmpty(speakerRole),
      register: register,
      expectedReply: nilIfEmpty(expectedReply),
      sourcePath: preview.sourcePath,
      sourceText: preview.sourceText,
      reviewStatus: .draft
    )
    try store.append(expression)
    candidates = try store.load()
    statusMessage = "已保存为本地待审核候选，不会自动进入练习"
    return expression
  }

  public func markReviewed(_ id: String) throws {
    guard let candidate = candidates.first(where: { $0.id == id }) else {
      throw ExpressionCaptureError.candidateNotFound
    }
    let reviewed = candidate.withReviewStatus(.reviewed)
    try store.replace(reviewed)
    candidates = try store.load()
    onReviewed(id)
    statusMessage = "已审核，可在后续队列中使用"
  }

  public func showStatus(_ message: String) {
    statusMessage = message
  }

  private func nilIfEmpty(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    return trimmed.isEmpty ? nil : trimmed
  }
}
