import RussianCornerCore
import SwiftUI

public struct DailyReflectionView: View {
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
        VStack(alignment: .leading, spacing: embedded ? 9 : 14) {
            header
            Divider().overlay(palette.border)
            blockedField
            naturalSpeechField
            completionField
            if let status = model.statusMessage {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            controls
        }
        .padding(embedded ? 16 : 22)
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日反馈")
                    .font(
                        .system(
                            size: embedded ? 17 : 21,
                            weight: .semibold,
                            design: .serif
                        )
                    )
                Text("只记录真实感受，不自动给你下结论。")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            Text("每项最多 200 字")
                .font(.system(size: 9))
                .foregroundStyle(palette.muted)
        }
    }

    private var blockedField: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldTitle("今天最卡的地方是什么？")
            TextField(
                "例如：知道意思，但临时想不起动词搭配",
                text: $model.mostBlocked,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(embedded ? 1...2 : 2...3)
            .onChange(of: model.mostBlocked) { _, value in
                limit(&model.mostBlocked, value: value)
            }
        }
    }

    private var naturalSpeechField: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldTitle("今天有没有一句真正脱口而出？")
            HStack(spacing: 10) {
                Picker("", selection: $model.spokeNaturally) {
                    Text("是").tag(true as Bool?)
                    Text("否").tag(false as Bool?)
                    Text("不确定").tag(nil as Bool?)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)

                TextField(
                    "可补一句说明",
                    text: $model.spokeNaturallyNote
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.spokeNaturallyNote) { _, value in
                    limit(&model.spokeNaturallyNote, value: value)
                }
            }
        }
    }

    private var completionField: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldTitle("今天完成或提前退出的原因？")
            HStack(spacing: 10) {
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
                .frame(width: 120)

                TextField(
                    "可补充具体原因",
                    text: $model.completionReasonNote
                )
                .textFieldStyle(.roundedBorder)
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

            Button(model.hasSavedToday ? "更新反馈" : "保存") {
                if model.saveToday() {
                    onLayoutChanged()
                    if !embedded { dismiss() }
                }
            }
            .buttonStyle(ReflectionSaveButtonStyle(palette: palette))
        }
    }

    private func fieldTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: embedded ? 11 : 12, weight: .semibold))
            .foregroundStyle(palette.secondary)
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
