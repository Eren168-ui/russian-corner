import CryptoKit
import Foundation
import RussianCornerCore

public struct SourceFileSnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let relativePath: String
    public let sha256: String
    public let modifiedAt: Date

    public init(
        relativePath: String,
        sha256: String,
        modifiedAt: Date
    ) {
        self.relativePath = relativePath
        self.sha256 = sha256
        self.modifiedAt = modifiedAt
    }
}

public struct CandidateExpression:
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let topicID: String
    public let sourcePath: String
    public let sourceText: String
    public let practiceRu: String
    public let status: ReviewStatus
    public let qualityFlags: [ContentQualityFlag]

    public init(
        id: String,
        topicID: String,
        sourcePath: String,
        sourceText: String,
        practiceRu: String,
        status: ReviewStatus,
        qualityFlags: [ContentQualityFlag]
    ) {
        self.id = id
        self.topicID = topicID
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.practiceRu = practiceRu
        self.status = status
        self.qualityFlags = qualityFlags
    }
}

public enum SourceSyncResult: Equatable, Sendable {
    case unchanged
    case updated(candidateCount: Int, changedFileCount: Int)
    case unavailableUsingBundledCorpus(String)
}

public struct SourceCorpusScanOutput: Equatable, Sendable {
    public let result: SourceSyncResult
    public let snapshots: [SourceFileSnapshot]
    public let candidates: [CandidateExpression]

    public init(
        result: SourceSyncResult,
        snapshots: [SourceFileSnapshot],
        candidates: [CandidateExpression]
    ) {
        self.result = result
        self.snapshots = snapshots
        self.candidates = candidates
    }
}

public struct SourceCorpusScanner: Sendable {
    public init() {}

    public func scan(
        sourceRoot: URL,
        topics: [TopicDefinition],
        previousSnapshots: [SourceFileSnapshot]
    ) -> SourceCorpusScanOutput {
        do {
            let rootMetadata = try sourceRoot.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard rootMetadata.isDirectory == true,
                  rootMetadata.isSymbolicLink != true
            else {
                return unavailable(
                    "source root is unavailable or symbolic"
                )
            }
            let previousByPath = Dictionary(
                uniqueKeysWithValues: previousSnapshots.map {
                    ($0.relativePath, $0)
                }
            )
            var snapshots: [SourceFileSnapshot] = []
            var candidates: [CandidateExpression] = []
            var changedFileCount = 0

            for topic in topics.sorted(by: {
                $0.number < $1.number
            }) {
                let pathKey = topic.sourcePath.lowercased()
                guard !pathKey.contains("conflict"),
                      !pathKey.contains("ai生成")
                else {
                    continue
                }
                let fileURL = sourceRoot.appendingPathComponent(
                    topic.sourcePath
                )
                let standardizedRoot = sourceRoot
                    .standardizedFileURL.path
                let standardizedFile = fileURL
                    .standardizedFileURL.path
                guard standardizedFile.hasPrefix(
                    standardizedRoot + "/"
                ) else {
                    return unavailable("source path escaped root")
                }
                let metadata = try fileURL.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                        .contentModificationDateKey,
                    ]
                )
                guard metadata.isRegularFile == true,
                      metadata.isSymbolicLink != true
                else {
                    return unavailable(
                        "symbolic or non-file source rejected"
                    )
                }
                let bytes = try Data(contentsOf: fileURL)
                let digest = SHA256.hash(data: bytes)
                    .map { String(format: "%02x", $0) }
                    .joined()
                let snapshot = SourceFileSnapshot(
                    relativePath: topic.sourcePath,
                    sha256: digest,
                    modifiedAt: metadata.contentModificationDate
                        ?? .distantPast
                )
                snapshots.append(snapshot)
                if previousByPath[topic.sourcePath]?.sha256 == digest {
                    continue
                }
                changedFileCount += 1
                candidates += extract(
                    from: bytes,
                    topic: topic
                )
            }

            let result: SourceSyncResult =
                changedFileCount == 0
                ? .unchanged
                : .updated(
                    candidateCount: candidates.count,
                    changedFileCount: changedFileCount
                )
            return SourceCorpusScanOutput(
                result: result,
                snapshots: snapshots,
                candidates: candidates
            )
        } catch {
            return unavailable(
                "source unavailable: \(error.localizedDescription)"
            )
        }
    }

    private func extract(
        from bytes: Data,
        topic: TopicDefinition
    ) -> [CandidateExpression] {
        guard let content = String(data: bytes, encoding: .utf8)
        else {
            return []
        }
        return content
            .split(whereSeparator: \.isNewline)
            .enumerated()
            .compactMap { index, lineValue in
                let sourceText = String(lineValue)
                guard let practiceRu = russianPrefix(
                    in: sourceText
                ) else {
                    return nil
                }
                let identifierData = Data(
                    "\(topic.id)\0\(index + 1)\0\(sourceText)".utf8
                )
                let identifier = SHA256.hash(
                    data: identifierData
                )
                .prefix(6)
                .map { String(format: "%02x", $0) }
                .joined()
                return CandidateExpression(
                    id: "candidate-\(topic.id)-\(identifier)",
                    topicID: topic.id,
                    sourcePath: topic.sourcePath,
                    sourceText: sourceText,
                    practiceRu: practiceRu,
                    status: .draft,
                    qualityFlags: [.mixedAnnotation]
                )
            }
    }

    private func russianPrefix(in line: String) -> String? {
        guard let numbered = line.range(
            of: #"^\s*\d+[.)]\s*"#,
            options: .regularExpression
        ) else {
            return nil
        }
        let body = String(line[numbered.upperBound...])
        guard let chinese = body.firstIndex(where: {
            $0.unicodeScalars.contains {
                (0x3400...0x4DBF).contains($0.value)
                    || (0x4E00...0x9FFF).contains($0.value)
            }
        }) else {
            return nil
        }
        let russian = body[..<chinese]
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard russian.range(
            of: #"[А-Яа-яЁё]"#,
            options: .regularExpression
        ) != nil,
            russian.range(
                of: #"[()[\]（）]"#,
                options: .regularExpression
            ) == nil
        else {
            return nil
        }
        return russian
    }

    private func unavailable(
        _ reason: String
    ) -> SourceCorpusScanOutput {
        SourceCorpusScanOutput(
            result: .unavailableUsingBundledCorpus(reason),
            snapshots: [],
            candidates: []
        )
    }
}
