import RussianCornerCore
import RussianCornerPlatform
import SwiftUI

public struct RussianCornerSettingsView: View {
  @Bindable private var runtime: AppRuntime
  @Bindable private var appModel: AppModel
  @State private var dailyCardCountDraft: Int
  @State private var morningDraft: Date
  @State private var eveningDraft: Date
  @State private var dictionaryKeyDraft = ""
  @State private var dictionaryKeyStatus = "正在检查…"

  public init(runtime: AppRuntime) {
    self.runtime = runtime
    appModel = runtime.appModel
    _dailyCardCountDraft = State(
      initialValue: runtime.appModel.dailyCardCount
    )
    _morningDraft = State(
      initialValue: Self.date(from: runtime.appModel.morningReminder)
    )
    _eveningDraft = State(
      initialValue: Self.date(from: runtime.appModel.eveningReminder)
    )
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
        Picker("定位方式", selection: $appModel.placementMode) {
          ForEach(FloatingPlacementMode.allCases, id: \.self) {
            Text($0.title).tag($0)
          }
        }
        Picker(
          "吸附位置",
          selection: Binding(
            get: { appModel.corner },
            set: { appModel.snap(to: $0) }
          )
        ) {
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
          "每日 \(dailyCardCountDraft) 卡",
          value: $dailyCardCountDraft,
          in: 5...10
        )
        Button("应用每日卡数") {
          let coordinator = DailyCardCountCoordinator {
            try runtime.reloadPractice()
          }
          let applied = coordinator.apply(
            proposed: dailyCardCountDraft,
            to: appModel
          )
          if !applied {
            dailyCardCountDraft = appModel.dailyCardCount
          }
        }
        Picker("练习方式", selection: $appModel.mode) {
          Text("安静默读").tag(PracticeMode.quiet)
          Text("开口练习").tag(PracticeMode.speaking)
        }
        .pickerStyle(.segmented)
        LabeledContent(
          "长期语料",
          value: "\(runtime.topics.count) 个话题"
        )
        LabeledContent(
          "待人工审核候选",
          value: "\(runtime.pendingCandidateCount) 条"
        )
        if let syncText {
          Text(syncText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section("在线词典（可选）") {
        LabeledContent("Yandex Dictionary", value: dictionaryKeyStatus)
        SecureField("粘贴新的 API key", text: $dictionaryKeyDraft)
          .textContentType(.password)
        HStack {
          Button("保存密钥") {
            saveDictionaryKey()
          }
          .disabled(
            dictionaryKeyDraft.trimmingCharacters(
              in: .whitespacesAndNewlines
            ).isEmpty
          )
          Button("移除密钥", role: .destructive) {
            deleteDictionaryKey()
          }
        }
        Text("密钥只保存在 macOS 钥匙串；点击句中单词时仅发送该词原形，不上传句子和学习记录。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("提醒") {
        DatePicker(
          "上午提醒",
          selection: $morningDraft,
          displayedComponents: .hourAndMinute
        )
        DatePicker(
          "下午提醒",
          selection: $eveningDraft,
          displayedComponents: .hourAndMinute
        )
        Button("保存并更新提醒") {
          Task {
            let proposed = RussianCornerSettings(
              morningReminder: Self.reminder(from: morningDraft),
              eveningReminder: Self.reminder(from: eveningDraft)
            )
            let applied = await runtime.saveReminderSettings(proposed)
            if !applied {
              morningDraft = Self.date(from: appModel.morningReminder)
              eveningDraft = Self.date(from: appModel.eveningReminder)
            }
          }
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
    .onAppear {
      refreshDictionaryKeyStatus()
    }
    .frame(width: 470, height: 550)
    .navigationTitle("Russian Corner 设置")
    .onChange(of: appModel.mode) {
      runtime.practice?.mode = appModel.mode
    }
  }

  private var syncText: String? {
    switch runtime.sourceSyncResult {
    case .unchanged:
      return "原始笔记无变化，继续使用已审核语料。"
    case .updated(let candidateCount, let changedFileCount):
      return "发现 \(changedFileCount) 个文件变化，\(candidateCount) 条内容已隔离为待审核候选，不会直接投放。"
    case .unavailableUsingBundledCorpus:
      return "当前无法读取原始笔记，已安全使用应用内已审核语料。"
    case nil:
      return nil
    }
  }

  private func refreshDictionaryKeyStatus() {
    do {
      let key = try YandexDictionaryKeychainStore().loadKey()
      dictionaryKeyStatus =
        key?.isEmpty == false ? "已配置" : "未配置（使用本地解析）"
    } catch {
      dictionaryKeyStatus = "钥匙串不可用"
    }
  }

  private func saveDictionaryKey() {
    do {
      try YandexDictionaryKeychainStore().saveKey(dictionaryKeyDraft)
      dictionaryKeyDraft = ""
      dictionaryKeyStatus = "已配置"
    } catch {
      dictionaryKeyStatus = "保存失败"
    }
  }

  private func deleteDictionaryKey() {
    do {
      try YandexDictionaryKeychainStore().deleteKey()
      dictionaryKeyDraft = ""
      dictionaryKeyStatus = "未配置（使用本地解析）"
    } catch {
      dictionaryKeyStatus = "移除失败"
    }
  }

  private var availableScreens: [ScreenDescriptor] {
    ScreenPlacement.systemScreens()
  }

  private func screenLabel(_ screen: ScreenDescriptor) -> String {
    screen.isMain ? "\(screen.name) · 主屏" : screen.name
  }

  private static func date(from reminder: ReminderTime) -> Date {
    Calendar.current.date(
      bySettingHour: reminder.hour,
      minute: reminder.minute,
      second: 0,
      of: Date()
    ) ?? Date()
  }

  private static func reminder(from date: Date) -> ReminderTime {
    let components = Calendar.current.dateComponents(
      [.hour, .minute],
      from: date
    )
    return ReminderTime(
      hour: components.hour ?? 0,
      minute: components.minute ?? 0
    )
  }
}
