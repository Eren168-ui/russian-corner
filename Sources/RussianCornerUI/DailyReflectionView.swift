import RussianCornerCore
import SwiftUI

public struct DailyReflectionView: View {
    public static let sectionTitles = [
        "今天卡在哪里",
        "有没有一句真正脱口而出",
        "今天为什么结束",
    ]
    public static let primaryActionTitle = "保存今日反馈"

    @Bindable private var model: DailyReflectionViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let embedded: Bool
    private let onLayoutChanged: () -> Void

    public init(
        model: DailyReflectionViewModel,
        embedded: Bool = false,
        onLayoutChanged: @escaping () -> Void = {}
    ) {
        self.model = model
        self.embedded = embedded
        self.onLayoutChanged = onLayoutChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: embedded ? 8 : 10) {
            header
            blockedField
            naturalSpeechField
            completionField
            if let status = model.statusMessage {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
            controls
        }
        .padding(embedded ? 14 : 20)
        .foregroundStyle(palette.primary)
        .background(palette.background)
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
        .frame(
            width: embedded ? 430 : 500,
            height: embedded ? 386 : 470
        )
        .onAppear {
            if !embedded {
                model.openForEditing()
            }
        }
    }

    private var palette: CardThemePalette {
        CardTheme.palette(for: colorScheme)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    "\(model.languageLabel) · "
                        + Date.now.formatted(
                            .dateTime.month().day().weekday(.wide)
                        )
                )
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(palette.accent)
                Text("今天，留下些什么？")
                    .font(
                        .system(
                            size: embedded ? 18 : 24,
                            weight: .semibold,
                            design: .serif
                        )
                    )
                Text("用一分钟记下今天真正发生的事。")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: embedded ? 20 : 26))
                .foregroundStyle(palette.accent.opacity(0.9))
        }
    }

    private var blockedField: some View {
        feedbackCard(
            number: "01",
            symbol: "bolt.slash",
            title: Self.sectionTitles[0]
        ) {
            TextField(
                "例如：知道意思，但临时想不起动词搭配",
                text: $model.mostBlocked,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(inputSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .lineLimit(embedded ? 1...2 : 2...3)
            .onChange(of: model.mostBlocked) { _, value in
                limit(&model.mostBlocked, value: value)
            }
        }
    }

    private var naturalSpeechField: some View {
        feedbackCard(
            number: "02",
            symbol: "sparkles",
            title: Self.sectionTitles[1]
        ) {
            VStack(alignment: .leading, spacing: 7) {
                Picker("", selection: $model.spokeNaturally) {
                    Text("有").tag(true as Bool?)
                    Text("还没有").tag(false as Bool?)
                    Text("不确定").tag(nil as Bool?)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(palette.accent)
                .frame(maxWidth: 280)

                TextField(
                    "是哪一句，或者卡在了哪里？（可不填）",
                    text: $model.spokeNaturallyNote
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(inputSurface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .onChange(of: model.spokeNaturallyNote) { _, value in
                    limit(&model.spokeNaturallyNote, value: value)
                }
            }
        }
    }

    private var completionField: some View {
        feedbackCard(
            number: "03",
            symbol: "flag.checkered",
            title: Self.sectionTitles[2]
        ) {
            VStack(alignment: .leading, spacing: 7) {
                Picker(
                    "原因",
                    selection: $model.completionReason
                ) {
                    ForEach(
                        DailyCompletionReason.allCases,
                        id: \.self
                    ) { reason in
                        Text(reason.titleZh).tag(reason)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180, alignment: .leading)
                .tint(palette.accent)

                TextField(
                    "补充具体原因（可不填）",
                    text: $model.completionReasonNote
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(inputSurface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .onChange(of: model.completionReasonNote) { _, value in
                    limit(&model.completionReasonNote, value: value)
                }
            }
        }
    }

    private var controls: some View {
        HStack {
            Button("暂不填写") {
                model.dismissCompletionOffer()
                onLayoutChanged()
                if !embedded { dismiss() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.muted)

            Spacer()

            Button(
                model.hasSavedToday
                    ? "更新今日反馈" : Self.primaryActionTitle
            ) {
                if model.saveToday() {
                    onLayoutChanged()
                    if !embedded { dismiss() }
                }
            }
            .buttonStyle(ReflectionSaveButtonStyle(palette: palette))
        }
    }

    private var inputSurface: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color.black.opacity(0.035)
    }

    private func feedbackCard<Content: View>(
        number: String,
        symbol: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: embedded ? 5 : 7) {
            HStack(spacing: 7) {
                Text(number)
                    .font(.system(size: 8, weight: .bold).monospacedDigit())
                    .foregroundStyle(palette.accent)
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text(title)
                    .font(
                        .system(
                            size: embedded ? 11 : 12,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(palette.secondary)
            }
            content()
        }
        .padding(.horizontal, embedded ? 10 : 12)
        .padding(.vertical, embedded ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.035)
                : Color.black.opacity(0.025)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.border.opacity(0.8), lineWidth: 1)
        }
    }

    private func limit(_ field: inout String, value: String) {
        let limited = String(value.prefix(200))
        if field != limited {
            field = limited
        }
    }
}

private struct ReflectionSaveButtonStyle: ButtonStyle {
    let palette: CardThemePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 30)
            .background(
                palette.accent.opacity(configuration.isPressed ? 0.78 : 1)
            )
            .clipShape(Capsule())
    }
}
