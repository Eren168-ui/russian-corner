import Foundation
import RussianCornerPlatform

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(
        Data(
            "Usage: RussianCornerEnglishAudit <source-root> <output-json>\n"
                .utf8
        )
    )
    exit(64)
}

let sourceRoot = URL(
    fileURLWithPath: arguments[1],
    isDirectory: true
)
let outputURL = URL(fileURLWithPath: arguments[2])
let scanner = EnglishSourceCorpusScanner()

do {
    let first = try scanner.scan(sourceRoot: sourceRoot)
    let second = try scanner.scan(sourceRoot: sourceRoot)
    guard first.snapshots == second.snapshots else {
        throw CocoaError(
            .fileReadCorruptFile,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Source hashes changed during the read-only audit",
            ]
        )
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(first)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: outputURL, options: .atomic)
    print(
        "English corpus audit: \(first.totalMarkdownFileCount) files, "
            + "\(first.excludedFileCount) excluded, "
            + "\(first.candidates.count) draft candidates"
    )
    print("Report: \(outputURL.path)")
} catch {
    FileHandle.standardError.write(
        Data("Audit failed: \(error.localizedDescription)\n".utf8)
    )
    exit(1)
}
