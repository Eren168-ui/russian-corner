import CryptoKit
import Foundation
import XCTest
@testable import RussianCornerCore
@testable import RussianCornerPlatform

final class EnglishSourceCorpusScannerTests: XCTestCase {
    func testScannerExcludesUnsafeSourcesAndPreservesOriginals() throws {
        let root = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let before = try aggregateHash(root)

        let output = try EnglishSourceCorpusScanner().scan(
            sourceRoot: root
        )

        XCTAssertEqual(try aggregateHash(root), before)
        XCTAssertEqual(output.totalMarkdownFileCount, 6)
        XCTAssertEqual(output.excludedFileCount, 3)
        XCTAssertEqual(
            Set(output.candidates.map(\.sourcePath)),
            [
                "Notes/useful.md",
                "Roots_Data_Lite/clar.md",
                "Notes/malformed.md",
            ]
        )
        XCTAssertTrue(
            output.candidates.allSatisfy {
                $0.reviewStatus == .draft
                    && !$0.sourceText.isEmpty
            }
        )
        XCTAssertEqual(
            output.candidates.first {
                $0.sourcePath.contains("Roots_Data_Lite")
            }?.kind,
            .mnemonic
        )
        XCTAssertTrue(
            output.candidates.first {
                $0.sourcePath.hasSuffix("malformed.md")
            }?.qualityFlags.contains(.incomplete) == true
        )
    }

    func testScannerRejectsSymbolicFiles() throws {
        let root = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("linked.md"),
            withDestinationURL: root.appendingPathComponent(
                "Notes/useful.md"
            )
        )

        let output = try EnglishSourceCorpusScanner().scan(
            sourceRoot: root
        )

        XCTAssertEqual(output.excludedReasons["symbolicLink"], 1)
        XCTAssertFalse(
            output.candidates.contains {
                $0.sourcePath == "linked.md"
            }
        )
    }

    private func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let files: [String: String] = [
            "Notes/useful.md":
                "- I was just about to call you. 我正要给你打电话。",
            "Roots_Data_Lite/clar.md":
                "clar = clear：clarify 可以联想为弄清楚",
            "Notes/malformed.md":
                "- I couldn't quite [",
            "AI整理/generated.md":
                "You should memorize this generated answer.",
            "archive/topic conflict.md":
                "This conflict copy must not enter the corpus.",
            "00-双语顶层补链报告.md":
                "This report is not learning content.",
        ]
        for (relativePath, contents) in files {
            let url = root.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: url)
        }
        return root
    }

    private func aggregateHash(_ root: URL) throws -> String {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let files = (enumerator?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.path < $1.path }
        var bytes = Data()
        for file in files {
            bytes.append(Data(file.path.utf8))
            bytes.append(try Data(contentsOf: file))
        }
        return SHA256.hash(data: bytes)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
