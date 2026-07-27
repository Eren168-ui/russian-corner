import Foundation
import RussianCornerCore
import SwiftUI

public enum InteractiveRussianTextBuilder {
    private static let scheme = "russian-corner-word"
    private static let host = "token"

    public static func make(
        text: String,
        analyses: [ResolvedWordAnalysis],
        selectedTokenIndex: Int?
    ) -> AttributedString {
        _ = analyses
        var output = AttributedString()
        var buffer = ""
        var word = ""
        var tokenIndex = 0

        func plain(_ value: String) -> AttributedString {
            AttributedString(value)
        }

        func linked(_ value: String, index: Int) -> AttributedString {
            var result = AttributedString(value)
            if let url = URL(string: "\(scheme)://\(host)/\(index)") {
                result.link = url
                result.underlineStyle = .single
                if selectedTokenIndex == index {
                    result.inlinePresentationIntent = .stronglyEmphasized
                }
            }
            return result
        }

        for character in text {
            if isRussianWordCharacter(character) {
                if !buffer.isEmpty {
                    output.append(plain(buffer))
                    buffer = ""
                }
                word.append(character)
            } else {
                if !word.isEmpty {
                    output.append(linked(word, index: tokenIndex))
                    tokenIndex += 1
                    word = ""
                }
                buffer.append(character)
            }
        }
        if !word.isEmpty {
            output.append(linked(word, index: tokenIndex))
        }
        if !buffer.isEmpty {
            output.append(plain(buffer))
        }
        return output
    }

    public static func tokenIndex(from url: URL) -> Int? {
        guard url.scheme == scheme, url.host == host else {
            return nil
        }
        return Int(url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private static func isRussianWordCharacter(
        _ character: Character
    ) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            (0x0410...0x044F).contains(scalar.value)
                || scalar.value == 0x0401
                || scalar.value == 0x0451
                || scalar.value == 0x0301
        }
    }
}

public struct InteractiveRussianText: View {
    private let value: AttributedString
    private let accessibilityText: String
    private let onSelect: (Int) -> Void

    public init(
        text: String,
        analyses: [ResolvedWordAnalysis],
        selectedTokenIndex: Int?,
        onSelect: @escaping (Int) -> Void
    ) {
        value = InteractiveRussianTextBuilder.make(
            text: text,
            analyses: analyses,
            selectedTokenIndex: selectedTokenIndex
        )
        accessibilityText = text
        self.onSelect = onSelect
    }

    public var body: some View {
        Text(value)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    guard let index =
                        InteractiveRussianTextBuilder.tokenIndex(from: url)
                    else {
                        return .systemAction
                    }
                    onSelect(index)
                    return .handled
                }
            )
            .accessibilityLabel("答案：\(accessibilityText)。每个俄语词都可点击查看解析")
    }
}
