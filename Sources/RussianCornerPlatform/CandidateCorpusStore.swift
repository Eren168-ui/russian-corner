import Foundation

public struct CandidateCorpusState:
    Codable,
    Equatable,
    Sendable
{
    public let snapshots: [SourceFileSnapshot]
    public let candidates: [CandidateExpression]
    public let lastSyncedAt: Date?

    public init(
        snapshots: [SourceFileSnapshot],
        candidates: [CandidateExpression],
        lastSyncedAt: Date?
    ) {
        self.snapshots = snapshots
        self.candidates = candidates
        self.lastSyncedAt = lastSyncedAt
    }

    public static let empty = CandidateCorpusState(
        snapshots: [],
        candidates: [],
        lastSyncedAt: nil
    )
}

public struct CandidateCorpusStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL(
        fileManager: FileManager = .default
    ) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport
            .appendingPathComponent(
                "com.openclaw.russiancorner",
                isDirectory: true
            )
            .appendingPathComponent("CandidateCorpus.json")
    }

    public func load() throws -> CandidateCorpusState {
        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(
            CandidateCorpusState.self,
            from: data
        )
    }

    public func save(_ state: CandidateCorpusState) throws {
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let temporaryURL = directory.appendingPathComponent(
            ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        do {
            try data.write(
                to: temporaryURL,
                options: [.atomic, .completeFileProtection]
            )
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(
                    fileURL,
                    withItemAt: temporaryURL
                )
            } else {
                try fileManager.moveItem(
                    at: temporaryURL,
                    to: fileURL
                )
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }
}
