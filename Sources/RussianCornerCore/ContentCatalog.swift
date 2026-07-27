import Foundation

public struct CatalogIssue: Equatable, Sendable {
    public let itemID: String
    public let message: String

    public init(itemID: String, message: String) {
        self.itemID = itemID
        self.message = message
    }
}

public enum ContentCatalogError: LocalizedError, Equatable {
    case missingResource(String)
    case validationFailed([CatalogIssue])

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing content resource: \(name).json"
        case .validationFailed(let issues):
            let details = issues.map {
                "\($0.itemID): \($0.message)"
            }.joined(separator: "; ")
            return "Content catalog validation failed: \(details)"
        }
    }
}

public struct ContentCatalog: Sendable {
    public let lexemes: [Lexeme]
    public let sentences: [SentenceCard]
    public let trialSlice: TrialContentSlice?
    public let topics: [TopicDefinition]
    public let longTermManifest: LongTermContentManifest
    public let longTermSentences: [SentenceCard]
    public let surfaceLemmas: [String: String]

    public init() throws {
        try self.init(
            resourceDirectory: Self.defaultResourceDirectory(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                bundleResourceURL: Bundle.main.resourceURL,
                environment: ProcessInfo.processInfo.environment,
                currentDirectoryURL: URL(
                    fileURLWithPath: FileManager.default.currentDirectoryPath,
                    isDirectory: true
                )
            )
        )
    }

    public init(resourceDirectory: URL) throws {
        let decoder = JSONDecoder()
        let lexemes = try Self.decode(
            [Lexeme].self,
            resource: "lexemes",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let sentences = try Self.decode(
            [SentenceCard].self,
            resource: "sentences",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let trialSlice = try Self.decode(
            TrialContentSlice.self,
            resource: "trial-slice",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let topics = try Self.decode(
            [TopicDefinition].self,
            resource: "topics",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let longTermManifest = try Self.decode(
            LongTermContentManifest.self,
            resource: "long-term-sentences",
            resourceDirectory: resourceDirectory,
            decoder: decoder
        )
        let catalog = ContentCatalog(
            lexemes: lexemes,
            sentences: sentences,
            trialSlice: trialSlice,
            topics: topics,
            longTermManifest: longTermManifest,
            surfaceLemmas: longTermManifest.surfaceLemmas ?? [:]
        )
        let issues = catalog.validate()
        guard issues.isEmpty else {
            throw ContentCatalogError.validationFailed(issues)
        }
        self = catalog
    }

    static func defaultResourceDirectory(
        bundleIdentifier: String?,
        bundleResourceURL: URL?,
        environment: [String: String],
        currentDirectoryURL: URL
    ) throws -> URL {
        if bundleIdentifier != nil {
            guard let bundleResourceURL else {
                throw ContentCatalogError.missingResource(
                    "resourceDirectory"
                )
            }
            return bundleResourceURL
        }

        if let override = environment[
            "RUSSIAN_CORNER_RESOURCE_DIRECTORY"
        ], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        return currentDirectoryURL
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("RussianCornerCore", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
    }

    public init(
        lexemes: [Lexeme],
        sentences: [SentenceCard],
        trialSlice: TrialContentSlice? = nil,
        topics: [TopicDefinition] = [],
        longTermManifest: LongTermContentManifest? = nil,
        surfaceLemmas: [String: String] = [:]
    ) {
        let allowedStatuses: Set<ReviewStatus> = [.reviewed, .verified]
        self.lexemes = lexemes.filter {
            allowedStatuses.contains($0.reviewStatus)
        }
        self.sentences = sentences.filter {
            allowedStatuses.contains($0.reviewStatus)
        }
        self.trialSlice = trialSlice
        self.topics = topics
        let fallbackManifest = LongTermContentManifest(
            schemaVersion: 1,
            sourceRoot: "",
            sourceCorpusSHA256: "",
            contentGateClosed: false,
            sentences: self.sentences
        )
        self.longTermManifest = longTermManifest ?? fallbackManifest
        self.longTermSentences = (
            longTermManifest?.sentences ?? self.sentences
        ).filter {
            allowedStatuses.contains($0.reviewStatus)
        }
        self.surfaceLemmas = Dictionary(
            uniqueKeysWithValues: surfaceLemmas.map {
                (Self.normalizedForm($0.key), Self.normalizedForm($0.value))
            }
        )
    }

    public var practiceLexemes: [Lexeme] {
        guard let trialSlice else {
            return lexemes
        }
        return lexemes.filter {
            trialSlice.lexemeIDs.contains($0.id)
        }
    }

    public var practiceSentences: [SentenceCard] {
        longTermSentences
    }

    public func wordAnalyses(
        for cardID: String
    ) -> [ResolvedWordAnalysis] {
        guard let trialSlice else {
            return []
        }
        let entriesByID = Dictionary(
            uniqueKeysWithValues: trialSlice.wordEntries.map {
                ($0.id, $0)
            }
        )
        return trialSlice.sentenceWordTokens
            .filter { $0.cardID == cardID }
            .sorted { $0.tokenIndex < $1.tokenIndex }
            .compactMap { token in
                guard let entry = entriesByID[token.wordEntryID] else {
                    return nil
                }
                return ResolvedWordAnalysis(
                    cardID: token.cardID,
                    tokenIndex: token.tokenIndex,
                    surfaceText: token.surfaceText,
                    stressedForm: entry.stressedForm,
                    lemma: entry.lemma,
                    glossZh: entry.glossZh,
                    partOfSpeech: entry.partOfSpeech,
                    morphology: token.morphology,
                    aspectPair: entry.aspectPair,
                    government: entry.government,
                    collocations: entry.collocations,
                    usageNote: entry.usageNote,
                    lexemeID: entry.lexemeID,
                    reviewStatus: entry.reviewStatus
                )
            }
    }

    public func wordAnalyses(
        for sentence: SentenceCard
    ) -> [ResolvedWordAnalysis] {
        let exactByIndex = Dictionary(
            uniqueKeysWithValues: wordAnalyses(for: sentence.id).map {
                ($0.tokenIndex, $0)
            }
        )
        return RussianWordTokenizer.words(in: sentence.practiceRu)
            .enumerated()
            .map { index, surface in
                if let exact = exactByIndex[index] {
                    return exact
                }
                if let lexeme = matchingLexeme(for: surface) {
                    return ResolvedWordAnalysis(
                        cardID: sentence.id,
                        tokenIndex: index,
                        surfaceText: surface,
                        stressedForm: lexeme.stressedForm,
                        lemma: lexeme.lemma,
                        glossZh: lexeme.glossZh,
                        partOfSpeech: lexeme.partOfSpeech,
                        morphology: "当前词形：\(surface)",
                        aspectPair: lexeme.aspectPair,
                        government: lexeme.government,
                        collocations: lexeme.collocations,
                        usageNote: "通用审核词条；本句词形尚无人工语境解析",
                        lexemeID: lexeme.id,
                        reviewStatus: lexeme.reviewStatus,
                        source: .reviewedLexeme
                    )
                }
                return ResolvedWordAnalysis(
                    cardID: sentence.id,
                    tokenIndex: index,
                    surfaceText: surface,
                    stressedForm: surface,
                    lemma: surfaceLemmas[
                        Self.normalizedForm(surface)
                    ] ?? Self.normalizedForm(surface),
                    glossZh: "本地暂无审核释义",
                    partOfSpeech: "待查询",
                    morphology: "当前词形：\(surface)",
                    usageNote: "可查询在线词典；在线结果不会自动标记为已审核",
                    reviewStatus: .draft,
                    source: .unavailable
                )
            }
    }

    private func matchingLexeme(for surface: String) -> Lexeme? {
        let normalized = Self.normalizedForm(surface)
        return lexemes.first { lexeme in
            ([lexeme.lemma] + lexeme.surfaceForms).contains {
                Self.normalizedForm($0) == normalized
            }
        }
    }

    public func validate() -> [CatalogIssue] {
        var issues: [CatalogIssue] = []

        if lexemes.count < 350 {
            issues.append(
                CatalogIssue(
                    itemID: "catalog.lexemes",
                    message: "expected at least 350 reviewed lexemes"
                )
            )
        }
        if !(60...80).contains(sentences.count) {
            issues.append(
                CatalogIssue(
                    itemID: "catalog.sentences",
                    message: "expected 60 through 80 reviewed sentences"
                )
            )
        }

        let lexemeIDs = Set(lexemes.map(\.id))
        let sentenceIDs = Set(sentences.map(\.id))
        if lexemeIDs.count != lexemes.count {
            issues.append(
                CatalogIssue(
                    itemID: "catalog.lexemes",
                    message: "lexeme IDs must be unique"
                )
            )
        }
        if sentenceIDs.count != sentences.count {
            issues.append(
                CatalogIssue(
                    itemID: "catalog.sentences",
                    message: "sentence IDs must be unique"
                )
            )
        }

        let sentencesByID = sentences.reduce(
            into: [String: SentenceCard]()
        ) { result, sentence in
            if result[sentence.id] == nil {
                result[sentence.id] = sentence
            }
        }
        let lexemesByID = lexemes.reduce(
            into: [String: Lexeme]()
        ) { result, lexeme in
            if result[lexeme.id] == nil {
                result[lexeme.id] = lexeme
            }
        }
        let excludedSourceFragments = [
            "professional", "生物", "化学", "物理", "组织学",
            "conflict", "双链报告", "ai计划",
        ]
        var seenLemmas: Set<String> = []
        var seenExamples: Set<String> = []
        let surfaceFormOwners = lexemes.reduce(
            into: [String: Set<String>]()
        ) { result, lexeme in
            for surfaceForm in lexeme.surfaceForms {
                let normalizedForm = Self.normalizedForm(surfaceForm)
                guard !normalizedForm.isEmpty else {
                    continue
                }
                result[normalizedForm, default: []].insert(lexeme.id)
            }
        }

        for lexeme in lexemes {
            let normalizedLemma = Self.normalizedForm(lexeme.lemma)
            if !normalizedLemma.isEmpty
                && !seenLemmas.insert(normalizedLemma).inserted
            {
                issues.append(
                    CatalogIssue(
                        itemID: lexeme.id,
                        message: "duplicate lemma \(lexeme.lemma)"
                    )
                )
            }
            if let owners = surfaceFormOwners[normalizedLemma],
                owners.contains(where: { $0 != lexeme.id })
            {
                issues.append(
                    CatalogIssue(
                        itemID: lexeme.id,
                        message: "morphological duplicate lemma \(lexeme.lemma)"
                    )
                )
            }
            require(
                !lexeme.id.isEmpty,
                itemID: lexeme.id,
                message: "missing id",
                issues: &issues
            )
            require(
                !lexeme.lemma.isEmpty,
                itemID: lexeme.id,
                message: "missing lemma",
                issues: &issues
            )
            require(
                !lexeme.stressedForm.isEmpty,
                itemID: lexeme.id,
                message: "missing stressed form",
                issues: &issues
            )
            require(
                !lexeme.speechText.isEmpty,
                itemID: lexeme.id,
                message: "missing speech text",
                issues: &issues
            )
            require(
                !lexeme.partOfSpeech.isEmpty,
                itemID: lexeme.id,
                message: "missing part of speech",
                issues: &issues
            )
            require(
                !lexeme.glossZh.isEmpty,
                itemID: lexeme.id,
                message: "missing Chinese gloss",
                issues: &issues
            )
            if lexeme.partOfSpeech == "noun" {
                require(
                    Self.allowedGrammaticalGenders.contains(
                        lexeme.grammaticalGender ?? ""
                    ),
                    itemID: lexeme.id,
                    message: "missing or invalid grammatical gender",
                    issues: &issues
                )
            }
            if lexeme.partOfSpeech == "verb" {
                require(
                    Self.allowedVerbalAspects.contains(
                        lexeme.aspect ?? ""
                    ),
                    itemID: lexeme.id,
                    message: "missing or invalid verbal aspect",
                    issues: &issues
                )
                require(
                    Self.isNonempty(lexeme.aspectPair)
                        || Self.isNonempty(lexeme.aspectPairNote),
                    itemID: lexeme.id,
                    message: "missing aspect pair or explicit pair note",
                    issues: &issues
                )
                require(
                    Self.isNonempty(lexeme.government),
                    itemID: lexeme.id,
                    message: "missing verb government",
                    issues: &issues
                )
            }
            if lexeme.partOfSpeech == "preposition" {
                require(
                    Self.isNonempty(lexeme.government),
                    itemID: lexeme.id,
                    message: "missing preposition government",
                    issues: &issues
                )
            }
            require(
                !lexeme.collocations.isEmpty
                    && lexeme.collocations.allSatisfy { !$0.isEmpty },
                itemID: lexeme.id,
                message: "missing collocation",
                issues: &issues
            )
            require(
                !lexeme.example.isEmpty,
                itemID: lexeme.id,
                message: "missing example",
                issues: &issues
            )
            require(
                Self.containsLexeme(lexeme, in: lexeme.example),
                itemID: lexeme.id,
                message: "example does not contain lemma or surface form",
                issues: &issues
            )
            let normalizedExample = Self.normalizedText(lexeme.example)
            if !normalizedExample.isEmpty
                && !seenExamples.insert(normalizedExample).inserted
            {
                issues.append(
                    CatalogIssue(
                        itemID: lexeme.id,
                        message: "duplicate example"
                    )
                )
            }
            for collocation in lexeme.collocations {
                let collocationTokens = Self.tokens(in: collocation)
                require(
                    (2...6).contains(collocationTokens.count),
                    itemID: lexeme.id,
                    message: "collocation must contain 2 through 6 words",
                    issues: &issues
                )
                require(
                    !Self.forbiddenCollocationEndings.contains(
                        collocationTokens.last ?? ""
                    ),
                    itemID: lexeme.id,
                    message: "collocation ends with a function word",
                    issues: &issues
                )
                require(
                    Self.hasBalancedQuotes(collocation),
                    itemID: lexeme.id,
                    message: "collocation has unbalanced quotes",
                    issues: &issues
                )
                require(
                    Self.containsLexeme(lexeme, in: collocation),
                    itemID: lexeme.id,
                    message: "collocation does not contain lemma or surface form",
                    issues: &issues
                )
                require(
                    Self.normalizedText(collocation)
                        != Self.normalizedText(lexeme.example),
                    itemID: lexeme.id,
                    message: "collocation equals example",
                    issues: &issues
                )
            }
            require(
                !lexeme.sentenceIDs.isEmpty,
                itemID: lexeme.id,
                message: "missing sentence link",
                issues: &issues
            )

            for sentenceID in lexeme.sentenceIDs {
                guard let sentence = sentencesByID[sentenceID] else {
                    issues.append(
                        CatalogIssue(
                            itemID: lexeme.id,
                            message: "missing sentence \(sentenceID)"
                        )
                    )
                    continue
                }
                require(
                    sentence.lexemeIDs.contains(lexeme.id),
                    itemID: lexeme.id,
                    message: "sentence \(sentenceID) does not link back",
                    issues: &issues
                )
                require(
                    Self.containsLexemeFamily(
                        lexeme,
                        in: sentence.practiceRu
                    )
                        && Self.containsLexemeFamily(
                            lexeme,
                            in: sentence.speechText
                        ),
                    itemID: lexeme.id,
                    message: "linked sentence text does not contain lemma or surface form",
                    issues: &issues
                )
            }
        }

        for sentence in sentences {
            require(
                !sentence.id.isEmpty,
                itemID: sentence.id,
                message: "missing id",
                issues: &issues
            )
            require(
                !sentence.promptZh.isEmpty,
                itemID: sentence.id,
                message: "missing Chinese prompt",
                issues: &issues
            )
            require(
                !sentence.cueRu.isEmpty,
                itemID: sentence.id,
                message: "missing Russian cue",
                issues: &issues
            )
            require(
                Self.normalizedText(sentence.cueRu)
                    != Self.normalizedText(sentence.practiceRu),
                itemID: sentence.id,
                message: "Russian cue equals practice text",
                issues: &issues
            )
            require(
                !sentence.practiceRu.isEmpty,
                itemID: sentence.id,
                message: "missing Russian practice text",
                issues: &issues
            )
            require(
                !sentence.speechText.isEmpty,
                itemID: sentence.id,
                message: "missing speech text",
                issues: &issues
            )
            require(
                !sentence.theme.isEmpty,
                itemID: sentence.id,
                message: "missing theme",
                issues: &issues
            )
            require(
                !sentence.lexemeIDs.isEmpty,
                itemID: sentence.id,
                message: "missing lexeme link",
                issues: &issues
            )
            require(
                !sentence.sourcePath.isEmpty,
                itemID: sentence.id,
                message: "missing source path",
                issues: &issues
            )
            require(
                !sentence.sourceText.isEmpty,
                itemID: sentence.id,
                message: "missing source text",
                issues: &issues
            )

            require(
                (3...8).contains(sentence.lexemeIDs.count),
                itemID: sentence.id,
                message: "sentence must link 3 through 8 lexemes",
                issues: &issues
            )
            let normalizedPath = sentence.sourcePath.lowercased()
            for fragment in excludedSourceFragments
            where normalizedPath.contains(fragment) {
                issues.append(
                    CatalogIssue(
                        itemID: sentence.id,
                        message: "excluded source path fragment: \(fragment)"
                    )
                )
            }

            for lexemeID in sentence.lexemeIDs
            where !lexemeIDs.contains(lexemeID) {
                issues.append(
                    CatalogIssue(
                        itemID: sentence.id,
                        message: "missing lexeme \(lexemeID)"
                    )
                )
            }
            for lexemeID in sentence.lexemeIDs {
                guard let lexeme = lexemesByID[lexemeID] else {
                    continue
                }
                require(
                    Self.containsLexemeFamily(
                        lexeme,
                        in: sentence.practiceRu
                    )
                        && Self.containsLexemeFamily(
                            lexeme,
                            in: sentence.speechText
                        ),
                    itemID: sentence.id,
                    message: "linked lexeme form is absent from sentence text",
                    issues: &issues
                )
                require(
                    lexeme.sentenceIDs.contains(sentence.id),
                    itemID: sentence.id,
                    message: "linked lexeme does not link back",
                    issues: &issues
                )
            }
        }

        if sentences.count > 1 {
            let distinctLinkCounts = Set(
                sentences.map { $0.lexemeIDs.count }
            )
            let requiredVariety = min(3, sentences.count)
            require(
                distinctLinkCounts.count >= requiredVariety,
                itemID: "catalog.sentences",
                message: "sentence link counts must vary",
                issues: &issues
            )
        }

        if let trialSlice {
            issues += validate(
                trialSlice: trialSlice,
                lexemesByID: lexemesByID
            )
        }
        if !topics.isEmpty || !longTermManifest.sourceRoot.isEmpty {
            issues += validateLongTermContent()
        }

        return issues
    }

    private func validateLongTermContent() -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        let topicIDs = Set(topics.map(\.id))
        let topicPaths = Set(topics.map(\.sourcePath))
        let expectedNumbers = Set(1...32)
        require(
            topics.count == 32
                && Set(topics.map(\.number)) == expectedNumbers,
            itemID: "longTerm.topics",
            message: "topic numbers must be exactly 1 through 32",
            issues: &issues
        )
        require(
            topicIDs.count == topics.count,
            itemID: "longTerm.topics",
            message: "topic IDs must be unique",
            issues: &issues
        )
        require(
            topicPaths.count == topics.count,
            itemID: "longTerm.topics",
            message: "topic source paths must be unique",
            issues: &issues
        )

        let sentenceIDs = Set(longTermSentences.map(\.id))
        require(
            sentenceIDs.count == longTermSentences.count,
            itemID: "longTerm.sentences",
            message: "long-term sentence IDs must be unique",
            issues: &issues
        )
        let allowedStatuses: Set<ReviewStatus> = [.reviewed, .verified]
        for sentence in longTermSentences {
            require(
                sentence.topicID.map(topicIDs.contains) == true,
                itemID: sentence.id,
                message: "missing or unknown topic ID",
                issues: &issues
            )
            require(
                Self.isNonempty(sentence.sourceHash)
                    && sentence.sourceHash?.count == 64,
                itemID: sentence.id,
                message: "missing source SHA-256",
                issues: &issues
            )
            require(
                !sentence.sourcePath.isEmpty
                    && !sentence.sourceText.isEmpty,
                itemID: sentence.id,
                message: "missing source trace",
                issues: &issues
            )
            require(
                !sentence.practiceRu.isEmpty
                    && !sentence.speechText.isEmpty
                    && Self.isCleanRussianSpeech(sentence.practiceRu)
                    && Self.isCleanRussianSpeech(sentence.speechText),
                itemID: sentence.id,
                message: "unclean Russian practice or speech text",
                issues: &issues
            )
            require(
                Self.isNonempty(sentence.dialogueAct)
                    && Self.isNonempty(sentence.speakerRole)
                    && sentence.register != nil
                    && sentence.addressForm != nil
                    && Self.isNonempty(sentence.expectedReply),
                itemID: sentence.id,
                message: "missing pragmatic metadata",
                issues: &issues
            )
            require(
                allowedStatuses.contains(sentence.reviewStatus),
                itemID: sentence.id,
                message: "unreviewed sentence cannot enter long-term content",
                issues: &issues
            )
            require(
                sentence.provenanceType != .aiGenerated,
                itemID: sentence.id,
                message: "AI-generated source is not eligible",
                issues: &issues
            )
        }

        if longTermManifest.contentGateClosed {
            require(
                longTermSentences.count >= 200,
                itemID: "longTerm.sentences",
                message: "closed content gate requires at least 200 sentences",
                issues: &issues
            )
            let counts = Dictionary(
                grouping: longTermSentences,
                by: \.topicID
            ).mapValues(\.count)
            for topic in topics {
                require(
                    counts[topic.id, default: 0] >= 4,
                    itemID: topic.id,
                    message: "closed content gate requires four sentences",
                    issues: &issues
                )
            }
        }
        return issues
    }

    private func validate(
        trialSlice: TrialContentSlice,
        lexemesByID: [String: Lexeme]
    ) -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        let allowedStatuses: Set<ReviewStatus> = [.reviewed, .verified]
        let disqualifyingFlags: Set<ContentQualityFlag> = [
            .typo,
            .grammarSuspect,
            .unnatural,
            .ambiguousTranslation,
            .incomplete,
            .emptyDialogue,
            .possiblyDated,
            .needsNativeReview,
        ]
        let sentenceIDs = Set(trialSlice.sentences.map(\.id))
        let allCardIDs = sentenceIDs.union(
            trialSlice.lexemeReviews.map(\.lexemeID)
        )

        require(
            trialSlice.schemaVersion == 1,
            itemID: "trialSlice",
            message: "unsupported schema version",
            issues: &issues
        )
        require(
            trialSlice.sourceRoot == Self.allowedTrialSourceRoot,
            itemID: "trialSlice",
            message: "trial source root is not allowlisted",
            issues: &issues
        )
        require(
            (50...80).contains(trialSlice.cardCount),
            itemID: "trialSlice",
            message: "trial slice must contain 50 through 80 cards",
            issues: &issues
        )
        require(
            sentenceIDs.count == trialSlice.sentences.count,
            itemID: "trialSlice.sentences",
            message: "trial sentence IDs must be unique",
            issues: &issues
        )
        require(
            trialSlice.lexemeIDs.count == trialSlice.lexemeReviews.count,
            itemID: "trialSlice.lexemes",
            message: "trial lexeme IDs must be unique",
            issues: &issues
        )
        require(
            Set(trialSlice.manualReviewSampleIDs).count >= 30,
            itemID: "trialSlice.manualReviewSampleIDs",
            message: "at least 30 distinct cards require manual readback",
            issues: &issues
        )
        for cardID in trialSlice.manualReviewSampleIDs
        where !allCardIDs.contains(cardID) {
            issues.append(
                CatalogIssue(
                    itemID: cardID,
                    message: "manual review ID is outside the trial slice"
                )
            )
        }

        let trialSentencesByID = trialSlice.sentences.reduce(
            into: [String: SentenceCard]()
        ) { result, sentence in
            if result[sentence.id] == nil {
                result[sentence.id] = sentence
            }
        }
        for sentence in trialSlice.sentences {
            require(
                allowedStatuses.contains(sentence.reviewStatus),
                itemID: sentence.id,
                message: "trial content must be reviewed or verified",
                issues: &issues
            )
            require(
                sentence.provenanceType == .courseMaterial
                    || sentence.provenanceType == .userNote
                    || sentence.provenanceType == .derived,
                itemID: sentence.id,
                message: "trial provenance is missing or unsafe",
                issues: &issues
            )
            require(
                Set(sentence.qualityFlags)
                    .isDisjoint(with: disqualifyingFlags),
                itemID: sentence.id,
                message: "trial sentence has a disqualifying quality flag",
                issues: &issues
            )
            require(
                Self.isNonempty(sentence.practiceRu)
                    && Self.isNonempty(sentence.stressedForm)
                    && Self.isNonempty(sentence.speechText),
                itemID: sentence.id,
                message: "trial display or speech text is empty",
                issues: &issues
            )
            require(
                Self.isCleanRussianSpeech(sentence.practiceRu)
                    && Self.isCleanRussianSpeech(
                        sentence.stressedForm ?? ""
                    )
                    && Self.isCleanRussianSpeech(sentence.speechText),
                itemID: sentence.id,
                message: "trial speech contains annotation or an unsplit variant",
                issues: &issues
            )
            require(
                Self.isNonempty(sentence.sourcePath)
                    && sentence.sourcePath.hasPrefix(
                        "具体场景对话/"
                    )
                    && !sentence.sourcePath
                        .split(separator: "/")
                        .contains("..")
                    && !sentence.sourcePath.lowercased().contains("conflict")
                    && !sentence.sourcePath.lowercased().contains("ai生成"),
                itemID: sentence.id,
                message: "trial source path is missing or outside the allowlist",
                issues: &issues
            )
            require(
                Self.isNonempty(sentence.sourceText),
                itemID: sentence.id,
                message: "trial source text is empty",
                issues: &issues
            )
            require(
                Self.isNonempty(sentence.dialogueAct)
                    && sentence.register != nil
                    && Self.isNonempty(sentence.speakerRole)
                    && sentence.addressForm != nil
                    && Self.isNonempty(sentence.expectedReply),
                itemID: sentence.id,
                message: "trial pragmatic metadata is incomplete",
                issues: &issues
            )
            require(
                sentence.expectedReply.map(
                    Self.isCleanRussianSpeech
                ) ?? false,
                itemID: sentence.id,
                message: "expected reply is not clean Russian",
                issues: &issues
            )
            for replyID in sentence.alternativeReplyIDs
            where !sentenceIDs.contains(replyID) {
                issues.append(
                    CatalogIssue(
                        itemID: sentence.id,
                        message: "missing alternative reply \(replyID)"
                    )
                )
            }
            for lexemeID in sentence.lexemeIDs {
                guard let lexeme = lexemesByID[lexemeID] else {
                    issues.append(
                        CatalogIssue(
                            itemID: sentence.id,
                            message: "missing trial lexeme \(lexemeID)"
                        )
                    )
                    continue
                }
                require(
                    Self.containsLexemeFamily(
                        lexeme,
                        in: sentence.practiceRu
                    )
                        && Self.containsLexemeFamily(
                            lexeme,
                            in: sentence.speechText
                        ),
                    itemID: sentence.id,
                    message: "trial lexeme form is absent from speech text",
                    issues: &issues
                )
            }
        }

        for review in trialSlice.lexemeReviews {
            guard let lexeme = lexemesByID[review.lexemeID] else {
                issues.append(
                    CatalogIssue(
                        itemID: review.lexemeID,
                        message: "trial lexeme does not exist"
                    )
                )
                continue
            }
            guard let sentence = trialSentencesByID[
                review.supportingSentenceID
            ] else {
                issues.append(
                    CatalogIssue(
                        itemID: review.lexemeID,
                        message: "supporting trial sentence is missing"
                    )
                )
                continue
            }
            require(
                allowedStatuses.contains(review.reviewStatus),
                itemID: review.lexemeID,
                message: "trial lexeme must be reviewed or verified",
                issues: &issues
            )
            require(
                review.provenanceType != .aiGenerated
                    && Set(review.qualityFlags)
                        .isDisjoint(with: disqualifyingFlags),
                itemID: review.lexemeID,
                message: "trial lexeme review is unsafe",
                issues: &issues
            )
            require(
                sentence.lexemeIDs.contains(review.lexemeID)
                    && Self.containsLexemeFamily(
                        lexeme,
                        in: sentence.practiceRu
                    ),
                itemID: review.lexemeID,
                message: "trial lexeme lacks a real supporting sentence",
                issues: &issues
            )
            require(
                !lexeme.collocations.isEmpty
                    && !lexeme.sentenceIDs.isEmpty,
                itemID: review.lexemeID,
                message: "trial lexeme lacks a collocation or scene",
                issues: &issues
            )
        }

        issues += validateWordAnalyses(
            trialSlice: trialSlice,
            lexemesByID: lexemesByID,
            allowedStatuses: allowedStatuses,
            disqualifyingFlags: disqualifyingFlags
        )

        return issues
    }

    private func validateWordAnalyses(
        trialSlice: TrialContentSlice,
        lexemesByID: [String: Lexeme],
        allowedStatuses: Set<ReviewStatus>,
        disqualifyingFlags: Set<ContentQualityFlag>
    ) -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        let entryIDs = Set(trialSlice.wordEntries.map(\.id))
        let entriesByID = trialSlice.wordEntries.reduce(
            into: [String: TrialWordEntry]()
        ) { result, entry in
            if result[entry.id] == nil {
                result[entry.id] = entry
            }
        }
        let sentenceIDs = Set(trialSlice.sentences.map(\.id))

        require(
            !trialSlice.wordEntries.isEmpty,
            itemID: "trialSlice.wordEntries",
            message: "trial word entries are missing",
            issues: &issues
        )
        require(
            entryIDs.count == trialSlice.wordEntries.count,
            itemID: "trialSlice.wordEntries",
            message: "trial word entry IDs must be unique",
            issues: &issues
        )
        for entry in trialSlice.wordEntries {
            require(
                Self.isNonempty(entry.id)
                    && Self.isNonempty(entry.lookupForm)
                    && Self.isNonempty(entry.stressedForm)
                    && Self.isNonempty(entry.lemma)
                    && Self.isNonempty(entry.glossZh)
                    && Self.isNonempty(entry.partOfSpeech)
                    && Self.isNonempty(entry.usageNote),
                itemID: entry.id,
                message: "trial word entry has missing core fields",
                issues: &issues
            )
            require(
                allowedStatuses.contains(entry.reviewStatus),
                itemID: entry.id,
                message: "trial word entry must be reviewed or verified",
                issues: &issues
            )
            require(
                entry.provenanceType != .aiGenerated
                    && Set(entry.qualityFlags)
                        .isDisjoint(with: disqualifyingFlags),
                itemID: entry.id,
                message: "trial word entry is unsafe",
                issues: &issues
            )
            require(
                RussianWordTokenizer.words(in: entry.lookupForm).count == 1
                    && RussianWordTokenizer.words(
                        in: entry.stressedForm
                    ).count == 1,
                itemID: entry.id,
                message: "trial word entry must describe one Russian word",
                issues: &issues
            )
            if let lexemeID = entry.lexemeID {
                require(
                    lexemesByID[lexemeID] != nil,
                    itemID: entry.id,
                    message: "trial word entry references missing lexeme",
                    issues: &issues
                )
            }
        }

        for token in trialSlice.sentenceWordTokens {
            require(
                sentenceIDs.contains(token.cardID),
                itemID: "\(token.cardID):\(token.tokenIndex)",
                message: "word token references missing sentence",
                issues: &issues
            )
            require(
                entriesByID[token.wordEntryID] != nil,
                itemID: "\(token.cardID):\(token.tokenIndex)",
                message: "word token references missing entry",
                issues: &issues
            )
            require(
                token.tokenIndex >= 0
                    && Self.isNonempty(token.surfaceText)
                    && Self.isNonempty(token.morphology),
                itemID: "\(token.cardID):\(token.tokenIndex)",
                message: "word token has missing contextual fields",
                issues: &issues
            )
            if let entry = entriesByID[token.wordEntryID] {
                require(
                    Self.normalizedForm(token.surfaceText)
                        == Self.normalizedForm(entry.lookupForm),
                    itemID: "\(token.cardID):\(token.tokenIndex)",
                    message: "word token surface does not match entry",
                    issues: &issues
                )
            }
        }

        for sentence in trialSlice.sentences {
            let words = RussianWordTokenizer.words(in: sentence.practiceRu)
            let tokens = trialSlice.sentenceWordTokens
                .filter { $0.cardID == sentence.id }
                .sorted { $0.tokenIndex < $1.tokenIndex }
            require(
                tokens.count == words.count,
                itemID: sentence.id,
                message: "every Russian word needs one analysis",
                issues: &issues
            )
            require(
                tokens.map(\.tokenIndex) == Array(words.indices),
                itemID: sentence.id,
                message: "word analysis indices must be complete and unique",
                issues: &issues
            )
            require(
                zip(tokens.map(\.surfaceText), words).allSatisfy {
                    Self.normalizedForm($0)
                        == Self.normalizedForm($1)
                },
                itemID: sentence.id,
                message: "word analysis surface does not match sentence",
                issues: &issues
            )
        }

        return issues
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        resource: String,
        resourceDirectory: URL,
        decoder: JSONDecoder
    ) throws -> Value {
        let url = resourceDirectory
            .appendingPathComponent(resource, isDirectory: false)
            .appendingPathExtension("json")
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ContentCatalogError.missingResource(resource)
        }
        return try decoder.decode(Value.self, from: Data(contentsOf: url))
    }

    private static func isCleanRussianSpeech(_ value: String) -> Bool {
        guard !value.contains(where: { character in
            "[]()（）/*_#`".contains(character)
        }) else {
            return false
        }
        return !value.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
    }

    private static func containsLexeme(
        _ lexeme: Lexeme,
        in text: String
    ) -> Bool {
        let textTokens = tokens(in: text)
        return ([lexeme.lemma] + lexeme.surfaceForms).contains {
            contains(tokens(in: $0), in: textTokens)
        }
    }

    private static func containsLexemeFamily(
        _ lexeme: Lexeme,
        in text: String
    ) -> Bool {
        if containsLexeme(lexeme, in: text) {
            return true
        }
        guard let aspectPair = lexeme.aspectPair else {
            return false
        }
        return contains(
            tokens(in: aspectPair),
            in: tokens(in: text)
        )
    }

    private static func contains(
        _ formTokens: [String],
        in textTokens: [String]
    ) -> Bool {
        guard !formTokens.isEmpty, textTokens.count >= formTokens.count else {
            return false
        }

        for start in 0...(textTokens.count - formTokens.count) {
            let end = start + formTokens.count
            if Array(textTokens[start..<end]) == formTokens {
                return true
            }
        }
        return false
    }

    private static func tokens(in value: String) -> [String] {
        normalizedText(value)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    private static let forbiddenCollocationEndings: Set<String> = [
        "в", "на", "к", "с", "из", "от", "до", "для", "без",
        "о", "об", "по", "за", "у", "при", "через", "перед",
        "между", "и", "или",
    ]

    private static let allowedGrammaticalGenders: Set<String> = [
        "masculine", "feminine", "neuter", "plural",
    ]

    private static let allowedVerbalAspects: Set<String> = [
        "perfective", "imperfective", "biaspectual",
    ]

    private static let allowedTrialSourceRoot =
        "/Users/Openclawworkspace/Library/CloudStorage/" +
        "OneDrive-个人/Documents/20-语言学习与专业/" +
        "大学知识库（俄语学习+专业）/01-按学期/" +
        "大一下——莫斯科/口语Диалоги"

    private static func isNonempty(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func hasBalancedQuotes(_ value: String) -> Bool {
        var guillemetDepth = 0
        var asciiQuoteCount = 0
        for character in value {
            switch character {
            case "«":
                guillemetDepth += 1
            case "»":
                guard guillemetDepth > 0 else {
                    return false
                }
                guillemetDepth -= 1
            case "\"":
                asciiQuoteCount += 1
            default:
                continue
            }
        }
        return guillemetDepth == 0 && asciiQuoteCount.isMultiple(of: 2)
    }

    private static func normalizedForm(_ value: String) -> String {
        tokens(in: value).joined(separator: " ")
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .decomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\u{301}", with: "")
            .precomposedStringWithCanonicalMapping
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func require(
        _ condition: Bool,
        itemID: String,
        message: String,
        issues: inout [CatalogIssue]
    ) {
        guard !condition else {
            return
        }
        issues.append(CatalogIssue(itemID: itemID, message: message))
    }
}
