import Foundation
import RussianCornerCore
import SwiftUI

public enum InteractiveRussianTextBuilder {
    public static func make(
        text: String,
        analyses: [ResolvedWordAnalysis],
        selectedTokenIndex: Int?
    ) -> AttributedString {
        _ = analyses
        return InteractiveTargetTextBuilder.make(
            text: text,
            language: .russian,
            selectedTokenIndex: selectedTokenIndex
        )
    }

    public static func tokenIndex(from url: URL) -> Int? {
        InteractiveTargetTextBuilder.tokenIndex(from: url)
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
