import RussianCornerCore
import SwiftUI

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
                if let lexeme = practice.currentLexeme {
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
}
