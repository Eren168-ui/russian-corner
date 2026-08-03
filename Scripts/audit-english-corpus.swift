#!/usr/bin/env swift

import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(
        Data(
            "Usage: swift Scripts/audit-english-corpus.swift <source-root> <output-json>\n"
                .utf8
        )
    )
    exit(64)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = [
    "swift",
    "run",
    "RussianCornerEnglishAudit",
    arguments[1],
    arguments[2],
]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
