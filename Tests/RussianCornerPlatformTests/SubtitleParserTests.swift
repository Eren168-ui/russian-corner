import CryptoKit
import Foundation
import XCTest

@testable import RussianCornerPlatform

final class SubtitleParserTests: XCTestCase {
  func testParsesSRTAndRemovesIndexesAndTimestamps() throws {
    let text = """
      1
      00:00:01,000 --> 00:00:03,000
      I was just about to call you.

      2
      00:00:04,000 --> 00:00:06,000
      Could you give me a second?
      """

    let result = SubtitleParser.parse(
      text: text,
      fileExtension: "srt",
      sourcePath: "/tmp/example.srt"
    )

    XCTAssertEqual(
      result.segments.map(\.text),
      [
        "I was just about to call you.",
        "Could you give me a second?",
      ]
    )
    XCTAssertFalse(result.segments.map(\.text).joined().contains("-->"))
  }

  func testParsesVTTAndPlainTextFormats() {
    let vtt = SubtitleParser.parse(
      text: """
        WEBVTT

        00:00:01.000 --> 00:00:02.500
        That works for me.
        """,
      fileExtension: "vtt",
      sourcePath: "clip.vtt"
    )
    let markdown = SubtitleParser.parse(
      text: """
        # Useful expressions
        - I haven't made up my mind yet.
        - Let me get back to you.
        """,
      fileExtension: "md",
      sourcePath: "notes.md"
    )

    XCTAssertEqual(vtt.segments.map(\.text), ["That works for me."])
    XCTAssertEqual(
      markdown.segments.map(\.text),
      [
        "Useful expressions",
        "I haven't made up my mind yet.",
        "Let me get back to you.",
      ]
    )
  }

  func testMalformedTimelineFallsBackToPlainText() {
    let result = SubtitleParser.parse(
      text: """
        00:xx:broken --> 00:00:04
        I can work with that.
        """,
      fileExtension: "srt",
      sourcePath: "broken.srt"
    )

    XCTAssertTrue(
      result.segments.contains {
        $0.text == "I can work with that."
      }
    )
  }

  func testReadingSubtitleNeverChangesOriginalBytes() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("clip.srt")
    let data = Data(
      """
      1
      00:00:01,000 --> 00:00:03,000
      I was just about to call you.
      """.utf8
    )
    try data.write(to: file)
    let before = SHA256.hash(data: try Data(contentsOf: file))

    _ = try SubtitleParser.parse(fileURL: file)

    let after = SHA256.hash(data: try Data(contentsOf: file))
    XCTAssertEqual(Data(before), Data(after))
  }
}
