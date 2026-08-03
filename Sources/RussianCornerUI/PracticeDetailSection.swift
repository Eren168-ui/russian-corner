import RussianCornerCore
import RussianCornerPlatform
import SwiftUI

public enum PracticeDetailTypography {
    public static let labelSize: CGFloat = 10
    public static let tagSize: CGFloat = 10
    public static let supportingSize: CGFloat = 12
    public static let bodySize: CGFloat = 14
    public static let relatedRussianSize: CGFloat = 16
    public static let wordHeadingSize: CGFloat = 18
}

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

    public static func visibleUsageNote(
        for word: ResolvedWordAnalysis
    ) -> String? {
        guard word.source == .reviewedContext else {
            return nil
        }
        let value = word.usageNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return value.isEmpty ? nil : value
    }

    public static func visibleMorphology(
        for word: ResolvedWordAnalysis
    ) -> String? {
        let value = word.morphology.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !value.isEmpty,
            !value.hasPrefix("当前词形：")
        else {
            return nil
        }
        return value
    }
}

public struct PracticeDetailSection: View {
    @Bindable private var appModel: AppModel
    @Bindable private var practice: PracticeViewModel
    private let palette: CardThemePalette
    private let onLayoutChanged: () -> Void

    public init(
        appModel: AppModel,
        practice: PracticeViewModel,
        palette: CardThemePalette,
        onLayoutChanged: @escaping () -> Void = {}
    ) {
        self.appModel = appModel
        self.practice = practice
        self.palette = palette
        self.onLayoutChanged = onLayoutChanged
    }

    public var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: practice.selectedWordAnalysis == nil ? 9 : 7
            ) {
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(word.stressedForm)
                        .font(
                            .system(
                                size: PracticeDetailTypography.wordHeadingSize
                                    * appModel.fontScale,
                                weight: .semibold,
                                design: .serif
                            )
                        )
                        .foregroundStyle(palette.primary)
                    Button {
                        practice.speakWord()
                    } label: {
                        Label("朗读单词", systemImage: "speaker.wave.2.fill")
                            .font(
                                .system(
                                    size: PracticeDetailTypography.labelSize
                                        * appModel.fontScale,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(palette.accentSurface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("朗读当前词形")
                    .accessibilityLabel("朗读单词")
                    .accessibilityHint("只朗读当前选中的词，不朗读整句")
                }
                Text(summary.glossZh)
                    .font(
                        .system(
                            size: 15 * appModel.fontScale,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(palette.accent)
                Text(summary.qualityLabel)
                    .font(
                        .system(
                            size: PracticeDetailTypography.labelSize
                                * appModel.fontScale,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 7) {
                if let url = OnlineDictionary.wiktionaryURL(
                    for: summary.lemma,
                    language: appModel.language
                ) {
                    Link(destination: url) {
                        Label("词典", systemImage: "arrow.up.right.square")
                            .font(
                                .system(
                                    size: PracticeDetailTypography.labelSize,
                                    weight: .medium
                                )
                            )
                    }
                    .foregroundStyle(palette.accent)
                }
                Button {
                    practice.clearWordAnalysis()
                    onLayoutChanged()
                } label: {
                    Label(
                        PracticeCardMetrics.wordCloseActionTitle,
                        systemImage: "xmark"
                    )
                    .font(
                        .system(
                            size: PracticeDetailTypography.labelSize,
                            weight: .semibold
                        )
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.muted)
                .accessibilityHint("保留原句并收起下方词义")
            }
        }

        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 7),
                GridItem(.flexible(), spacing: 7),
            ],
            spacing: 7
        ) {
            factCell("原形", summary.lemma)
            factCell("当前词形", word.surfaceText)
            factCell(
                "词性",
                localizedPartOfSpeech(summary.partOfSpeech)
            )
            if let morphology =
                WordDetailSummaryBuilder.visibleMorphology(for: word)
            {
                factCell("语法身份", morphology)
            } else if let pair = word.aspectPair, !pair.isEmpty {
                factCell("体对", pair)
            }
        }
        if WordDetailSummaryBuilder.visibleMorphology(for: word) != nil,
            let pair = word.aspectPair,
            !pair.isEmpty
        {
            factCell("体对", pair)
        }
        if let government = word.government,
            !government.isEmpty
        {
            learningBlock("常见支配", government)
        }
        if !word.collocations.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                sectionTitle("固定搭配")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        ForEach(word.collocations, id: \.self) {
                            collocationChip($0)
                        }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(word.collocations, id: \.self) {
                            collocationChip($0)
                        }
                    }
                }
            }
        }
        if let usageNote = WordDetailSummaryBuilder.visibleUsageNote(
            for: word
        ) {
            learningBlock("在本句中怎么用", usageNote)
        }
        if !practice.selectedWordExamples.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("场景例句")
                ForEach(
                    Array(practice.selectedWordExamples.enumerated()),
                    id: \.offset
                ) { _, example in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(example.russian)
                            .font(
                                .system(
                                    size: PracticeDetailTypography.bodySize
                                        * appModel.fontScale,
                                    weight: .medium,
                                    design: .serif
                                )
                            )
                            .foregroundStyle(palette.primary)
                        if let translation = example.translationZh {
                            Text(translation)
                                .font(
                                    .system(
                                        size: PracticeDetailTypography.supportingSize
                                            * appModel.fontScale
                                    )
                                )
                                .foregroundStyle(palette.muted)
                        }
                    }
                    .padding(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.accentSurface)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                    )
                }
            }
        }
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
                    .font(
                        .system(
                            size: PracticeDetailTypography.supportingSize
                                * appModel.fontScale
                        )
                    )
                    .foregroundStyle(palette.muted)
            }
        case .result(let result):
            if practice.selectedWordAnalysis?.source != .unavailable,
                !result.translations.isEmpty
            {
                detail(
                    result.translationLanguage == .chinese
                        ? "Yandex 中文释义"
                        : result.translationLanguage == .english
                            ? "Yandex 英文释义（中文暂缺）"
                            : "Yandex 俄语释义（中文暂缺）",
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
                .font(
                    .system(
                        size: PracticeDetailTypography.supportingSize
                            * appModel.fontScale
                    )
                )
                .foregroundStyle(palette.muted)
        }
    }

    @ViewBuilder
    private func lexemeContent(_ lexeme: Lexeme) -> some View {
        if let study = practice.currentStudyLexeme,
            study.language == .english
        {
            if let phonetic = study.phonetic, !phonetic.isEmpty {
                detail("发音", phonetic)
            }
            if !study.inflections.isEmpty {
                detail("常见词形", study.inflections.joined(separator: " · "))
            }
            if !study.collocations.isEmpty {
                detail("固定搭配", study.collocations.joined(separator: " · "))
            }
            if !study.phrasalVerbs.isEmpty {
                detail("短语动词", study.phrasalVerbs.joined(separator: " · "))
            }
            if !study.wordFamily.isEmpty {
                detail("词族", study.wordFamily.joined(separator: " · "))
            }
            if !study.morphologyNotes.isEmpty {
                detail(
                    "构词与用法",
                    study.morphologyNotes.joined(separator: " · ")
                )
            }
            ForEach(
                Array(study.memoryNotes.enumerated()),
                id: \.offset
            ) { _, note in
                detail(memoryNoteTitle(note.kind), note.text)
            }
        }
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
        if !lexeme.example.isEmpty {
            detail("例句", lexeme.example)
        }
        if let context = practice.currentContextSentence {
            detail("场景 · \(context.theme)", context.practiceRu)
        }
    }

    @ViewBuilder
    private var dialogueContent: some View {
        if let source = practice.currentSentenceSource {
            HStack(spacing: 5) {
                sourceTag(source.provenanceLabel)
                if let act = source.dialogueActLabel {
                    sourceTag(act)
                }
                ForEach(source.usageLabels, id: \.self) {
                    sourceTag($0)
                }
            }
            detail(
                "来源",
                "\(source.theme) · \(source.fileName)"
            )
        }

        if !practice.isRevealed {
            Text(
                appModel.language == .english
                    ? "显示答案后，可查看同场景延伸表达；其中每个英语词都可以点击。"
                    : "显示答案后，可查看同场景延伸表达；其中每个俄语词都可以点击。"
            )
                .font(
                    .system(
                        size: PracticeDetailTypography.supportingSize
                            * appModel.fontScale
                    )
                )
                .foregroundStyle(palette.muted)
        } else if practice.relatedSentenceExpressions.isEmpty {
            Text(
                appModel.language == .english
                    ? "点击上方答案中的任意英语词，可查看词义、词形和用法。"
                    : "点击上方答案中的任意俄语词，可查看词义、词形和用法。"
            )
                .font(
                    .system(
                        size: PracticeDetailTypography.supportingSize
                            * appModel.fontScale
                    )
                )
                .foregroundStyle(palette.muted)
        } else {
            Text(
                appModel.language == .english
                    ? "同场景延伸 · 点击任意英语词"
                    : "同场景延伸 · 点击任意俄语词"
            )
                .font(
                    .system(
                        size: PracticeDetailTypography.labelSize,
                        weight: .semibold
                    )
                )
                .tracking(0.6)
                .foregroundStyle(palette.accent)
            ForEach(practice.relatedSentenceExpressions) { expression in
                VStack(alignment: .leading, spacing: 2) {
                    Text(expression.promptZh)
                        .font(
                            .system(
                                size: PracticeDetailTypography.supportingSize
                                    * appModel.fontScale
                            )
                        )
                        .foregroundStyle(palette.muted)
                    InteractiveTargetText(
                        text: expression.text,
                        language: appModel.language,
                        selectedTokenIndex:
                            practice.selectedWordAnalysis?.cardID
                                == expression.cardID
                            ? practice.selectedWordAnalysis?.tokenIndex
                            : nil
                    ) { tokenIndex in
                        practice.toggleWordAnalysis(
                            cardID: expression.cardID,
                            tokenIndex: tokenIndex
                        )
                        onLayoutChanged()
                    }
                    .font(
                        .system(
                            size: PracticeDetailTypography.relatedRussianSize
                                * appModel.fontScale,
                            design: .serif
                        )
                    )
                    .foregroundStyle(palette.secondary)
                }
            }
        }
    }

    private func sourceTag(_ value: String) -> some View {
        Text(value)
            .font(
                .system(
                    size: PracticeDetailTypography.tagSize,
                    weight: .medium
                )
            )
            .foregroundStyle(palette.secondary)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(palette.accentSurface)
            .clipShape(Capsule())
    }

    private func factCell(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle(title)
            Text(value)
                .font(
                    .system(
                        size: PracticeDetailTypography.bodySize
                            * appModel.fontScale,
                        weight: .medium
                    )
                )
                .foregroundStyle(palette.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .background(palette.accentSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func learningBlock(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle(title)
            Text(value)
                .font(
                    .system(
                        size: PracticeDetailTypography.bodySize
                            * appModel.fontScale
                    )
                )
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accentSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func collocationChip(_ value: String) -> some View {
        Text(value)
            .font(
                .system(
                    size: PracticeDetailTypography.bodySize
                        * appModel.fontScale,
                    weight: .medium,
                    design: .serif
                )
            )
            .foregroundStyle(palette.primary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(palette.accentSurface)
            .clipShape(Capsule())
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value.uppercased())
            .font(
                .system(
                    size: PracticeDetailTypography.labelSize,
                    weight: .semibold
                )
            )
            .tracking(0.7)
            .foregroundStyle(palette.accent)
    }

    private func detail(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(
                    .system(
                        size: PracticeDetailTypography.labelSize,
                        weight: .semibold
                    )
                )
                .tracking(0.8)
                .foregroundStyle(palette.accent)
            Text(value)
                .font(
                    .system(
                        size: PracticeDetailTypography.bodySize
                            * appModel.fontScale
                    )
                )
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

    private func memoryNoteTitle(_ kind: MemoryNoteKind) -> String {
        switch kind {
        case .verifiedEtymology:
            "可靠词源"
        case .morphologicalBreakdown:
            "构词拆分"
        case .mnemonic:
            "联想助记（不是词源）"
        }
    }
}
