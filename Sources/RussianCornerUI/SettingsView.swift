import RussianCornerCore
import SwiftUI

public struct RussianCornerSettingsView: View {
  @Bindable private var runtime: AppRuntime
  @Bindable private var appModel: AppModel

  public init(runtime: AppRuntime) {
    self.runtime = runtime
    appModel = runtime.appModel
  }

  public var body: some View {
    Form {
      Section("悬浮卡") {
        if availableScreens.isEmpty {
          LabeledContent("显示器", value: "当前不可用")
        } else {
          Picker(
            "显示器",
            selection: $appModel.preferredScreenIdentifier
          ) {
            ForEach(availableScreens) { screen in
              Text(screenLabel(screen))
                .tag(Optional(screen.identifier))
            }
          }
        }
        Picker("吸附位置", selection: $appModel.corner) {
          ForEach(FloatingCorner.allCases, id: \.self) {
            Text($0.title).tag($0)
          }
        }
        Slider(value: $appModel.opacity, in: 0.55...1, step: 0.05) {
          Text("不透明度")
        } minimumValueLabel: {
          Text("55%")
        } maximumValueLabel: {
          Text("100%")
        }
        Slider(value: $appModel.fontScale, in: 0.85...1.35, step: 0.05) {
          Text("字号")
        } minimumValueLabel: {
          Text("小")
        } maximumValueLabel: {
          Text("大")
        }
      }

      Section("练习") {
        Stepper(
          "每日 \(appModel.dailyCardCount) 卡",
          value: $appModel.dailyCardCount,
          in: 5...10
        )
        Picker("练习方式", selection: $appModel.mode) {
          Text("安静默读").tag(PracticeMode.quiet)
          Text("开口练习").tag(PracticeMode.speaking)
        }
        .pickerStyle(.segmented)
      }

      Section("提醒") {
        DatePicker(
          "上午提醒",
          selection: reminderBinding(\.morningReminder),
          displayedComponents: .hourAndMinute
        )
        DatePicker(
          "下午提醒",
          selection: reminderBinding(\.eveningReminder),
          displayedComponents: .hourAndMinute
        )
        Button("保存并更新提醒") {
          Task { await runtime.saveReminderSettings() }
        }
      }

      if let status = appModel.transientStatus {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityLabel(status)
      }
    }
    .formStyle(.grouped)
    .frame(width: 470, height: 550)
    .navigationTitle("Russian Corner 设置")
    .onChange(of: appModel.dailyCardCount) {
      try? runtime.reloadPractice()
    }
    .onChange(of: appModel.mode) {
      runtime.practice?.mode = appModel.mode
    }
  }

  private var availableScreens: [ScreenDescriptor] {
    ScreenPlacement.systemScreens()
  }

  private func screenLabel(_ screen: ScreenDescriptor) -> String {
    screen.isMain ? "\(screen.name) · 主屏" : screen.name
  }

  private func reminderBinding(
    _ keyPath: ReferenceWritableKeyPath<AppModel, ReminderTime>
  ) -> Binding<Date> {
    Binding {
      let reminder = appModel[keyPath: keyPath]
      return Calendar.current.date(
        bySettingHour: reminder.hour,
        minute: reminder.minute,
        second: 0,
        of: Date()
      ) ?? Date()
    } set: { value in
      let components = Calendar.current.dateComponents(
        [.hour, .minute],
        from: value
      )
      appModel[keyPath: keyPath] = ReminderTime(
        hour: components.hour ?? 0,
        minute: components.minute ?? 0
      )
    }
  }
}
