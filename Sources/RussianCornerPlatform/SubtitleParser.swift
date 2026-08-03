import Foundation

public struct SubtitleSegment:
    Identifiable,
    Equatable,
    Sendable
{
    public let id: Int
    public let text: String

    public init(id: Int, text: String) {
        self.id = id
        self.text = text
    }
}

public struct SubtitleParseResult: Equatable, Sendable {
    public let sourcePath: String
    public let sourceText: String
    public let segments: [SubtitleSegment]

    public init(
        sourcePath: String,
        sourceText: String,
        segments: [SubtitleSegment]
    ) {
        self.sourcePath = sourcePath
        self.sourceText = sourceText
        self.segments = segments
    }
}

public enum SubtitleParser {
    public static func parse(fileURL: URL) throws -> SubtitleParseResult {
        let data = try Data(contentsOf: fileURL)
        let text =
            String(data: data, encoding: .utf8)
            ?? String(decoding: data, as: UTF8.self)
        return parse(
            text: text,
            fileExtension: fileURL.pathExtension,
            sourcePath: fileURL.path
        )
    }

    public static func parse(
        text: String,
        fileExtension: String,
        sourcePath: String
    ) -> SubtitleParseResult {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let extensionName = fileExtension.lowercased()
        let values: [String]
        if extensionName == "srt" || extensionName == "vtt" {
            values = timelineSegments(from: normalized)
        } else {
            values = plainTextSegments(from: normalized)
        }
        let unique = values.reduce(into: [String]()) { result, value in
            guard !result.contains(value) else { return }
            result.append(value)
        }
        return SubtitleParseResult(
            sourcePath: sourcePath,
            sourceText: text,
            segments: unique.enumerated().map {
                SubtitleSegment(id: $0.offset, text: $0.element)
            }
        )
    }

    private static func timelineSegments(from text: String) -> [String] {
        let normalizedBlocks = text.replacingOccurrences(
            of: #"\n[ \t]*\n"#,
            with: "\n\n",
            options: .regularExpression
        )
        let blocks = normalizedBlocks.components(
            separatedBy: "\n\n"
        )
        var output: [String] = []
        for block in blocks {
            var lines = block.components(separatedBy: "\n")
                .map {
                    $0.trimmingCharacters(
                        in: CharacterSet.whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }
            if lines.first?.uppercased() == "WEBVTT" {
                lines.removeFirst()
            }
            if lines.first?.allSatisfy({ $0.isNumber }) == true {
                lines.removeFirst()
            }
            if let timelineIndex = lines.firstIndex(where: isTimeline) {
                lines = Array(lines.dropFirst(timelineIndex + 1))
            } else {
                lines.removeAll {
                    $0.contains("-->")
                }
            }
            let joined = clean(
                lines.joined(separator: " ")
            )
            if !joined.isEmpty {
                output.append(joined)
            }
        }
        return output.isEmpty ? plainTextSegments(from: text) : output
    }

    private static func plainTextSegments(from text: String) -> [String] {
        text.components(separatedBy: "\n").compactMap { line in
            var value = line.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !value.isEmpty,
                  value.uppercased() != "WEBVTT",
                  !value.allSatisfy(\.isNumber),
                  !value.contains("-->")
            else {
                return nil
            }
            value = value.replacingOccurrences(
                of: #"^\s*(?:#{1,6}|[-*+>])\s+"#,
                with: "",
                options: .regularExpression
            )
            value = value.replacingOccurrences(
                of: #"^\s*\[[ xX]\]\s+"#,
                with: "",
                options: .regularExpression
            )
            let cleaned = clean(value)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    private static func isTimeline(_ value: String) -> Bool {
        value.range(
            of: #"^\d{1,2}:\d{2}(?::\d{2})?[,.]\d{3}\s+-->\s+\d{1,2}:\d{2}(?::\d{2})?[,.]\d{3}"#,
            options: .regularExpression
        ) != nil
    }

    private static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: #"<[^>]+>"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
