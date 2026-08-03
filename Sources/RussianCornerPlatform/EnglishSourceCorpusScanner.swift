import CryptoKit
import Foundation
import RussianCornerCore

public struct EnglishSourceCorpusScanner: Sendable {
    private static let excludedFragments: [(fragment: String, reason: String)] = [
        ("conflict", "conflictCopy"),
        ("ai整理", "aiGenerated"),
        ("双链报告", "report"),
        ("补链报告", "report"),
        ("顶层补链报告", "report"),
    ]

    public init() {}

    public func scan(sourceRoot: URL) throws -> EnglishCorpusAudit {
        let rootValues = try sourceRoot.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true
        else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        let rootPath = sourceRoot.standardizedFileURL.path
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        let markdownFiles = (enumerator.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.path < $1.path }
        var excludedReasons: [String: Int] = [:]
        var snapshots: [EnglishSourceSnapshot] = []
        var candidates: [EnglishCandidateContent] = []

        for fileURL in markdownFiles {
            let standardizedPath = fileURL.standardizedFileURL.path
            guard standardizedPath.hasPrefix(rootPath + "/") else {
                excludedReasons["escapedRoot", default: 0] += 1
                continue
            }
            let relativePath = String(
                standardizedPath.dropFirst(rootPath.count + 1)
            )
            let values = try fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values.isSymbolicLink != true else {
                excludedReasons["symbolicLink", default: 0] += 1
                continue
            }
            guard values.isRegularFile == true else {
                excludedReasons["nonRegularFile", default: 0] += 1
                continue
            }
            if let reason = exclusionReason(for: relativePath) {
                excludedReasons[reason, default: 0] += 1
                continue
            }

            let data = try Data(contentsOf: fileURL)
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            snapshots.append(
                EnglishSourceSnapshot(
                    relativePath: relativePath,
                    sha256: digest
                )
            )
            candidates.append(
                contentsOf: extract(
                    data: data,
                    relativePath: relativePath
                )
            )
        }

        let explicitlyExcluded = excludedReasons
            .filter { $0.key != "symbolicLink" && $0.key != "nonRegularFile" }
            .map(\.value)
            .reduce(0, +)
        return EnglishCorpusAudit(
            totalMarkdownFileCount: markdownFiles.count,
            excludedFileCount: explicitlyExcluded,
            excludedReasons: excludedReasons,
            snapshots: snapshots,
            candidates: candidates
        )
    }

    private func exclusionReason(for relativePath: String) -> String? {
        let normalized = relativePath
            .folding(options: [.caseInsensitive], locale: .current)
        return Self.excludedFragments.first {
            normalized.contains(
                $0.fragment.folding(
                    options: [.caseInsensitive],
                    locale: .current
                )
            )
        }?.reason
    }

    private func extract(
        data: Data,
        relativePath: String
    ) -> [EnglishCandidateContent] {
        guard let contents = String(data: data, encoding: .utf8) else {
            return []
        }
        let isMnemonicSource =
            relativePath.lowercased().contains("roots_data_lite")
            || relativePath.contains("词根")
        return contents
            .split(whereSeparator: \.isNewline)
            .enumerated()
            .compactMap { lineIndex, lineValue in
                let sourceText = String(lineValue)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sourceText.isEmpty,
                      sourceText.range(
                        of: #"[A-Za-z]"#,
                        options: .regularExpression
                      ) != nil
                else {
                    return nil
                }
                var targetText = sourceText.replacingOccurrences(
                    of: #"^\s*(?:[-*+]|\d+[.)])\s*"#,
                    with: "",
                    options: .regularExpression
                )
                var flags: [ContentQualityFlag] = []
                if containsChinese(targetText) {
                    flags.append(.mixedAnnotation)
                    if !isMnemonicSource,
                       let chineseIndex = targetText.firstIndex(
                        where: containsChinese
                       ) {
                        targetText = String(targetText[..<chineseIndex])
                    }
                }
                targetText = targetText
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if hasUnbalancedDelimiters(targetText) {
                    flags.append(.incomplete)
                }
                let identifierData = Data(
                    "\(relativePath)\0\(lineIndex)\0\(sourceText)".utf8
                )
                let identifier = SHA256.hash(data: identifierData)
                    .prefix(8)
                    .map { String(format: "%02x", $0) }
                    .joined()
                return EnglishCandidateContent(
                    id: "english-candidate-\(identifier)",
                    kind: isMnemonicSource ? .mnemonic : .expression,
                    targetText: targetText,
                    sourcePath: relativePath,
                    sourceText: sourceText,
                    qualityFlags: flags
                )
            }
    }

    private func containsChinese(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
        }
    }

    private func containsChinese(_ text: String) -> Bool {
        text.contains(where: containsChinese)
    }

    private func hasUnbalancedDelimiters(_ text: String) -> Bool {
        let pairs: [(Character, Character)] = [
            ("(", ")"),
            ("[", "]"),
            ("{", "}"),
        ]
        return pairs.contains { opening, closing in
            text.filter { $0 == opening }.count
                != text.filter { $0 == closing }.count
        }
    }
}
