import Foundation

public struct CatalogIssue: Equatable, Sendable {
    public let itemID: String
    public let message: String

    public init(itemID: String, message: String) {
        self.itemID = itemID
        self.message = message
    }
}

public enum ContentCatalogError: Error, Equatable {
    case missingResource(String)
}

public struct ContentCatalog: Sendable {
    public let lexemes: [Lexeme]
    public let sentences: [SentenceCard]

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
        self.init(lexemes: lexemes, sentences: sentences)
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

    public init(lexemes: [Lexeme], sentences: [SentenceCard]) {
        let allowedStatuses: Set<ReviewStatus> = [.reviewed, .verified]
        self.lexemes = lexemes.filter {
            allowedStatuses.contains($0.reviewStatus)
        }
        self.sentences = sentences.filter {
            allowedStatuses.contains($0.reviewStatus)
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
                    Self.containsLexeme(lexeme, in: sentence.practiceRu)
                        && Self.containsLexeme(
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
                    Self.containsLexeme(lexeme, in: sentence.practiceRu)
                        && Self.containsLexeme(
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

    private static func containsLexeme(
        _ lexeme: Lexeme,
        in text: String
    ) -> Bool {
        let textTokens = tokens(in: text)
        return ([lexeme.lemma] + lexeme.surfaceForms).contains {
            contains(tokens(in: $0), in: textTokens)
        }
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
