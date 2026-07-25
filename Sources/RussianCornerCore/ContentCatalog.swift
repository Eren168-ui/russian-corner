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
        let decoder = JSONDecoder()
        let lexemes = try Self.decode(
            [Lexeme].self,
            resource: "lexemes",
            decoder: decoder
        )
        let sentences = try Self.decode(
            [SentenceCard].self,
            resource: "sentences",
            decoder: decoder
        )
        self.init(lexemes: lexemes, sentences: sentences)
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
        let excludedSourceFragments = [
            "professional", "生物", "化学", "物理", "组织学",
            "conflict", "双链报告", "ai计划",
        ]
        var seenLemmas: Set<String> = []

        for lexeme in lexemes {
            let normalizedLemma = lexeme.lemma
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
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
        }

        return issues
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        resource: String,
        decoder: JSONDecoder
    ) throws -> Value {
        guard let url = Bundle.module.url(
            forResource: resource,
            withExtension: "json"
        ) else {
            throw ContentCatalogError.missingResource(resource)
        }
        return try decoder.decode(Value.self, from: Data(contentsOf: url))
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
