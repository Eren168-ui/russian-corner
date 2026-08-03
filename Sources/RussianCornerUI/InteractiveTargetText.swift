import Foundation
import RussianCornerCore
import SwiftUI

public enum InteractiveTargetTextBuilder {
    private static let scheme = "language-corner-word"
    private static let host = "token"

    public static func make(
        text: String,
        language: StudyLanguage,
        selectedTokenIndex: Int?
    ) -> AttributedString {
        var output = AttributedString()
        for segment in TargetLanguageTokenizer.segments(
            in: text,
            language: language
        ) {
            var value = AttributedString(segment.text)
            if let index = segment.tokenIndex,
               let url = URL(string: "\(scheme)://\(host)/\(index)") {
                value.link = url
                value.underlineStyle = .single
                if selectedTokenIndex == index {
                    value.inlinePresentationIntent = .stronglyEmphasized
                }
            }
            output.append(value)
        }
        return output
    }

    public static func tokenIndex(from url: URL) -> Int? {
        guard url.scheme == scheme, url.host == host else {
            return nil
        }
        return Int(
            url.path.trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )
        )
    }
}

public struct InteractiveTargetText: View {
    private let value: AttributedString
    private let accessibilityText: String
    private let accessibilityLanguageName: String
    private let onSelect: (Int) -> Void

    public init(
        text: String,
        language: StudyLanguage,
        selectedTokenIndex: Int?,
        onSelect: @escaping (Int) -> Void
    ) {
        value = InteractiveTargetTextBuilder.make(
            text: text,
            language: language,
            selectedTokenIndex: selectedTokenIndex
        )
        accessibilityText = text
        accessibilityLanguageName = language == .english ? "英语" : "俄语"
        self.onSelect = onSelect
    }

    public var body: some View {
        Text(value)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    guard let index =
                        InteractiveTargetTextBuilder.tokenIndex(from: url)
                    else {
                        return .systemAction
                    }
                    onSelect(index)
                    return .handled
                }
            )
            .accessibilityLabel(
                "答案：\(accessibilityText)。每个\(accessibilityLanguageName)词都可点击查看解析"
            )
    }
}
