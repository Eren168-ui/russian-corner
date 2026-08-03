#!/usr/bin/env swift

import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let repositoryRoot = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let resourceDirectory = repositoryRoot
    .appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("RussianCornerCore", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
let process = Process()
process.currentDirectoryURL = repositoryRoot
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = [
    "swift",
    "run",
    "RussianCornerResourceProbe",
    resourceDirectory.path,
]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
