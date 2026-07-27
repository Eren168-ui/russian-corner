import RussianCornerCore
import RussianCornerPlatform
import SwiftUI

public struct WordDetailSummary: Equatable, Sendable {
    public let qualityLabel: String
    public let glossZh: String
    public let lemma: String
    public let partOfSpeech: String
}

public enum WordDetailSummaryBuilder {
    public static func make(
        word: ResolvedWordAnalysis,
        lookupState: OnlineWordLookupState
    ) -> WordDetailSummary {
        if word.source == .unavailable,
            case .result(let result) = lookupState
        {
            return WordDetailSummary(
                qualityLabel: "在线词典结果 · 未人工审核",
                glossZh: result.translations.joined(separator: "；"),
                lemma: result.lemma,
                partOfSpeech: result.partOfSpeech ?? word.partOfSpeech
            )
        }
        return WordDetailSummary(
            qualityLabel: qualityLabel(for: word.source),
            glossZh: word.glossZh,
            lemma: word.lemma,
            partOfSpeech: word.partOfSpeech
        )
    }

    public static func qualityLabel(
        for source: WordAnalysisSource
    ) -> String {
        switch source {
        case .reviewedContext:
            return "本句人工审核"
        case .reviewedLexeme:
            return "本地审核词条 · 本句词形未专项审核"
        case .onlineUnreviewed:
            return "在线词典结果 · 未人工审核"
        case .unavailable:
            return "本地暂无审核解析"
        }
    }
}

public struct PracticeDetailSection: View {
    @Bindable private var appModel: AppModel
    @Bindable private var practice: PracticeViewModel
    private let palette: CardThemePalette

    public init(
        appModel: AppModel,
        practice: PracticeViewModel,
        palette: CardThemePalette
    ) {
        self.appModel = appModel
        self.practice = practice
        self.palette = palette
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                if let word = practice.selectedWordAnalysis {
                    wordContent(word)
                } else if let lexeme = practice.currentLexeme {
                    lexemeContent(lexeme)
                } else {
                    dialogueContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .textSelection(.enabled)
        .accessibilityLabel("词汇和场景详情")
    }

    @ViewBuilder
    private func wordContent(_ word: ResolvedWordAnalysis) -> some View {
        let summary = WordDetailSummaryBuilder.make(
            word: word,
            lookupState: practice.onlineWordLookupState
        )
        Text(summary.qualityLabel)
            .font(.system(size: 9 * appModel.fontScale, weight: .medium))
            .foregroundStyle(palette.muted)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(word.stressedForm)
                .font(
                    .system(
                        size: 17 * appModel.fontScale,
                        weight: .semibold,
                        design: .serif
                    )
                )
                .foregroundStyle(palette.primary)
            Text(summary.glossZh)
                .font(.system(size: 12 * appModel.fontScale))
                .foregroundStyle(palette.secondary)
            Spacer()
            if let url = OnlineDictionary.wiktionaryURL(for: summary.lemma) {
                Link(destination: url) {
                    Label("词典", systemImage: "arrow.up.right.square")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(palette.accent)
            }
        }
        detail(
            "词形",
            "\(localizedPartOfSpeech(summary.partOfSpeech)) · \(word.morphology) · 原形 \(summary.lemma)"
        )
        if let pair = word.aspectPair, !pair.isEmpty {
            detail("体对", pair)
        }
        if let government = word.government, !government.isEmpty {
            detail("支配", government)
        }
        if !word.collocations.isEmpty {
            detail("搭配", word.collocations.joined(separator: " · "))
        }
        detail("在本句中", word.usageNote)
        onlineDictionaryContent
    }

    @ViewBuilder
    private var onlineDictionaryContent: some View {
        switch practice.onlineWordLookupState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("正在补充在线词典释义…")
                    .font(.system(size: 9 * appModel.fontScale))
                    .foregroundStyle(palette.muted)
            }
        case .result(let result):
            if practice.selectedWordAnalysis?.source != .unavailable,
                !result.translations.isEmpty
            {
                detail(
                    result.translationLanguage == .chinese
                        ? "Yandex 中文释义"
                        : "Yandex 英文释义（中文暂缺）",
                    result.translations.joined(separator: "；")
                )
            }
            if !result.synonyms.isEmpty {
                detail(
                    "近义表达",
                    result.synonyms.joined(separator: " · ")
                )
            }
            if let example = result.examples.first {
                detail(
                    "在线例句",
                    [
                        example.russian,
                        example.translationZh,
                    ]
                    .compactMap { $0 }
                    .joined(separator: " — ")
                )
            }
        case .unavailable(let message):
            Text(message)
                .font(.system(size: 9 * appModel.fontScale))
                .foregroundStyle(palette.muted)
        }
    }

    @ViewBuilder
    private func lexemeContent(_ lexeme: Lexeme) -> some View {
        if !practice.lexemeGrammarLabels.isEmpty {
            detail(
                "必要语法",
                practice.lexemeGrammarLabels.joined(separator: " · ")
            )
        }
        if lexeme.collocations.count > 1 {
            detail(
                "更多搭配",
                lexeme.collocations.dropFirst().joined(separator: " · ")
            )
        }
        if let government = lexeme.government, !government.isEmpty {
            detail("支配与用法", government)
        }
        if let note = lexeme.aspectPairNote, !note.isEmpty {
            detail("体对说明", note)
        }
        detail("例句", lexeme.example)
        if let context = practice.currentContextSentence {
            detail("场景 · \(context.theme)", context.practiceRu)
        }
    }

    @ViewBuilder
    private var dialogueContent: some View {
        if practice.microDialogueTurns.count >= 2 {
            ForEach(
                Array(practice.microDialogueTurns.enumerated()),
                id: \.element.id
            ) { index, turn in
                VStack(alignment: .leading, spacing: 2) {
                    Text("A\(index + 1) · \(turn.cue)")
                        .font(.system(size: 10 * appModel.fontScale))
                        .foregroundStyle(palette.muted)
                    Text("Вы · \(turn.response)")
                        .font(
                            .system(
                                size: 12 * appModel.fontScale,
                                design: .serif
                            )
                        )
                        .foregroundStyle(palette.secondary)
                }
            }
        } else if let card = practice.currentCard {
            detail("场景", card.theme)
            detail("俄语提示", card.cueRu)
        }
    }

    private func detail(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(palette.accent)
            Text(value)
                .font(.system(size: 11 * appModel.fontScale))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func localizedPartOfSpeech(_ value: String) -> String {
        switch value {
        case "noun": "名词"
        case "verb": "动词"
        case "adjective": "形容词"
        case "adverb": "副词"
        case "preposition": "介词"
        case "pronoun": "代词"
        case "conjunction": "连词"
        case "particle": "语气词"
        case "numeral": "数词"
        case "interjection": "感叹词"
        default: value
        }
    }
}
