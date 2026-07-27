import Foundation
import RussianCornerCore
import XCTest

@testable import RussianCornerPlatform

final class SourceCorpusScannerTests: XCTestCase {
    func testCandidateStoreRoundTripsOutsideSourceCorpus() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = CandidateCorpusStore(
            fileURL: directory.appendingPathComponent(
                "CandidateCorpus.json"
            )
        )
        let state = CandidateCorpusState(
            snapshots: [
                SourceFileSnapshot(
                    relativePath: "topic.md",
                    sha256: String(repeating: "a", count: 64),
                    modifiedAt: Date(timeIntervalSince1970: 10)
                ),
            ],
            candidates: [],
            lastSyncedAt: Date(timeIntervalSince1970: 20)
        )

        try store.save(state)

        XCTAssertEqual(try store.load(), state)
    }

    func testFirstScanFindsDraftCandidatesWithoutChangingSource() throws {
        let fixture = try makeFixture()
        let before = try Data(contentsOf: fixture.sourceURL)

        let output = SourceCorpusScanner().scan(
            sourceRoot: fixture.root,
            topics: [fixture.topic],
            previousSnapshots: []
        )

        XCTAssertEqual(
            output.result,
            .updated(candidateCount: 1, changedFileCount: 1)
        )
        XCTAssertEqual(output.candidates.count, 1)
        XCTAssertEqual(output.candidates.first?.status, .draft)
        XCTAssertEqual(
            try Data(contentsOf: fixture.sourceURL),
            before
        )
    }

    func testUnchangedHashDoesNotReparseFile() throws {
        let fixture = try makeFixture()
        let scanner = SourceCorpusScanner()
        let first = scanner.scan(
            sourceRoot: fixture.root,
            topics: [fixture.topic],
            previousSnapshots: []
        )

        let second = scanner.scan(
            sourceRoot: fixture.root,
            topics: [fixture.topic],
            previousSnapshots: first.snapshots
        )

        XCTAssertEqual(second.result, .unchanged)
        XCTAssertTrue(second.candidates.isEmpty)
    }

    func testMissingSourceUsesBundledCorpus() {
        let output = SourceCorpusScanner().scan(
            sourceRoot: URL(
                fileURLWithPath: "/missing/russian-corner-source",
                isDirectory: true
            ),
            topics: [],
            previousSnapshots: []
        )

        guard case .unavailableUsingBundledCorpus =
            output.result
        else {
            return XCTFail("expected bundled fallback")
        }
    }

    func testSymbolicLinkSourceIsRejected() throws {
        let fixture = try makeFixture()
        let linkURL = fixture.root.appendingPathComponent(
            "linked.md"
        )
        try FileManager.default.createSymbolicLink(
            at: linkURL,
            withDestinationURL: fixture.sourceURL
        )
        let topic = TopicDefinition(
            id: "topic-02",
            number: 2,
            titleRu: "Ссылка",
            titleZh: "链接",
            sourcePath: "linked.md"
        )

        let output = SourceCorpusScanner().scan(
            sourceRoot: fixture.root,
            topics: [topic],
            previousSnapshots: []
        )

        guard case .unavailableUsingBundledCorpus(let reason) =
            output.result
        else {
            return XCTFail("expected safe fallback")
        }
        XCTAssertTrue(reason.contains("symbolic"))
    }

    private func makeFixture() throws -> (
        root: URL,
        sourceURL: URL,
        topic: TopicDefinition
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let sourceURL = root.appendingPathComponent("Тема 1.md")
        try Data(
            "1. Мне нужно уточнить время. 我需要确认时间。\n".utf8
        ).write(to: sourceURL)
        let topic = TopicDefinition(
            id: "topic-01",
            number: 1,
            titleRu: "Встреча",
            titleZh: "见面",
            sourcePath: "Тема 1.md"
        )
        return (root, sourceURL, topic)
    }
}
