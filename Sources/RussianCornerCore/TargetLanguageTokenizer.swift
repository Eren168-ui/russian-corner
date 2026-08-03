import Foundation

public struct TargetTextSegment: Equatable, Sendable {
    public let text: String
    public let tokenIndex: Int?

    public init(text: String, tokenIndex: Int?) {
        self.text = text
        self.tokenIndex = tokenIndex
    }
}

public enum TargetLanguageTokenizer {
    public static func words(
        in text: String,
        language: StudyLanguage
    ) -> [String] {
        segments(in: text, language: language)
            .filter { $0.tokenIndex != nil }
            .map(\.text)
    }

    public static func segments(
        in text: String,
        language: StudyLanguage
    ) -> [TargetTextSegment] {
        let characters = Array(text)
        var result: [TargetTextSegment] = []
        var buffer = ""
        var bufferIsWord: Bool?
        var tokenIndex = 0

        func appendBuffer() {
            guard !buffer.isEmpty, let bufferIsWord else {
                return
            }
            result.append(
                TargetTextSegment(
                    text: buffer,
                    tokenIndex: bufferIsWord ? tokenIndex : nil
                )
            )
            if bufferIsWord {
                tokenIndex += 1
            }
            buffer = ""
        }

        for index in characters.indices {
            let isWord = isWordCharacter(
                characters[index],
                at: index,
                in: characters,
                language: language
            )
            if bufferIsWord != isWord {
                appendBuffer()
                bufferIsWord = isWord
            }
            buffer.append(characters[index])
        }
        appendBuffer()
        return result
    }

    private static func isWordCharacter(
        _ character: Character,
        at index: Int,
        in characters: [Character],
        language: StudyLanguage
    ) -> Bool {
        switch language {
        case .russian:
            return character.unicodeScalars.allSatisfy(isRussianScalar)
        case .english:
            if character.unicodeScalars.allSatisfy(isLatinScalarOrMark) {
                return true
            }
            guard isEnglishConnector(character),
                  index > characters.startIndex,
                  index < characters.index(before: characters.endIndex)
            else {
                return false
            }
            return characters[index - 1].unicodeScalars.allSatisfy(
                isLatinScalarOrMark
            ) && characters[index + 1].unicodeScalars.allSatisfy(
                isLatinScalarOrMark
            )
        }
    }

    private static func isRussianScalar(_ scalar: UnicodeScalar) -> Bool {
        (0x0410...0x044F).contains(scalar.value)
            || scalar.value == 0x0401
            || scalar.value == 0x0451
            || scalar.value == 0x0301
    }

    private static func isLatinScalarOrMark(
        _ scalar: UnicodeScalar
    ) -> Bool {
        (0x0041...0x005A).contains(scalar.value)
            || (0x0061...0x007A).contains(scalar.value)
            || (0x00C0...0x024F).contains(scalar.value)
            || (0x1E00...0x1EFF).contains(scalar.value)
            || (0x0300...0x036F).contains(scalar.value)
    }

    private static func isEnglishConnector(
        _ character: Character
    ) -> Bool {
        character == "'" || character == "’" || character == "-"
    }
}
