import Foundation
import RussianCornerCore

@main
struct RussianCornerResourceProbe {
    static func main() {
        do {
            guard CommandLine.arguments.count == 2 else {
                throw ProbeError(
                    message: "expected one resource directory argument"
                )
            }
            let resourceDirectory = URL(
                fileURLWithPath: CommandLine.arguments[1],
                isDirectory: true
            )
            let catalog = try ContentCatalog(
                resourceDirectory: resourceDirectory
            )
            guard catalog.lexemes.count == 360,
                catalog.sentences.count == 72
            else {
                throw ProbeError(
                    message:
                        "unexpected resource counts " +
                        "\(catalog.lexemes.count)/\(catalog.sentences.count)"
                )
            }
            print(
                "resource_probe=PASS lexemes=360 sentences=72 " +
                    "directory=\(resourceDirectory.path)"
            )
        } catch {
            FileHandle.standardError.write(
                Data("resource_probe=FAIL \(error)\n".utf8)
            )
            exit(EXIT_FAILURE)
        }
    }
}

private struct ProbeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
