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
            let issues = catalog.validate()
            guard issues.isEmpty else {
                throw ProbeError(
                    message: issues.map {
                        "\($0.itemID): \($0.message)"
                    }.joined(separator: "; ")
                )
            }
            guard catalog.lexemes.count == 440,
                catalog.sentences.count == 72,
                catalog.trialSlice?.cardCount == 50,
                catalog.topics.count == 32,
                catalog.longTermSentences.count == 274,
                catalog.supplementalLexemes.count == 80,
                catalog.supplementalSentences.count == 60,
                catalog.speakingChallenges.count == 24,
                catalog.supplementalLoadIssue == nil
            else {
                throw ProbeError(
                    message:
                        "unexpected resource counts " +
                        "\(catalog.lexemes.count)/\(catalog.sentences.count)/" +
                        "\(catalog.trialSlice?.cardCount ?? 0)/" +
                        "\(catalog.topics.count)/" +
                        "\(catalog.longTermSentences.count)"
                )
            }
            print(
                "resource_probe=PASS lexemes=440 sentences=72 trial=50 " +
                    "topics=32 long_term_sentences=274 " +
                    "supplemental_lexemes=80 " +
                    "supplemental_sentences=60 speaking_challenges=24 " +
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
