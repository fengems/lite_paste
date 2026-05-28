import AppKit
import LitePasteCore
import SwiftUI

struct ClipboardSettingsPage: View {
  @Binding var panelPosition: PanelPosition
  @Binding var viewMode: ClipboardPanelViewMode
  @Binding var coverMenuBarWhenEdgeAttached: Bool
  @Binding var focusSearchOnOpen: Bool
  @Binding var clearSearchOnOpen: Bool
  @Binding var autoPasteMode: AutoPasteMode
  @Binding var pastePlainByDefault: Bool
  @Binding var restoreClipboardAfterPaste: Bool
  @Binding var moveDuplicatesToTop: Bool
  let panelPositionDescription: String

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: "窗口设置") {
        SettingsRow(title: "窗口位置", detail: panelPositionDescription) {
          Picker("", selection: $panelPosition) {
            ForEach(PanelPosition.allCases) { position in
              Text(position.displayName).tag(position)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 160)
        }

        SettingsDivider()

        SettingsRow(title: "默认视图") {
          Picker("", selection: $viewMode) {
            Text("卡片").tag(ClipboardPanelViewMode.card)
            Text("列表").tag(ClipboardPanelViewMode.list)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .frame(width: 150)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: "贴边时覆盖菜单栏",
          detail: "靠上、靠左和靠右时尝试覆盖系统菜单栏区域。",
          isOn: $coverMenuBarWhenEdgeAttached
        )
      }

      SettingsSectionCard(title: "搜索设置") {
        SettingsSwitchRow(
          title: "默认聚焦",
          detail: "打开面板时自动聚焦搜索框。",
          isOn: $focusSearchOnOpen
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: "自动清除",
          detail: "打开面板时清除上一次搜索内容。",
          isOn: $clearSearchOnOpen
        )
      }

      SettingsSectionCard(title: "内容设置") {
        SettingsRow(title: "默认操作", detail: "选择记录后的默认行为。") {
          Picker("", selection: $autoPasteMode) {
            Text("仅复制").tag(AutoPasteMode.copyOnly)
            Text("自动粘贴").tag(AutoPasteMode.paste)
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 150)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: "粘贴为纯文本",
          detail: "自动粘贴时默认只保留纯文本内容。",
          isOn: $pastePlainByDefault
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: "恢复原剪贴板",
          detail: "自动粘贴后恢复执行前的剪贴板内容。",
          isOn: $restoreClipboardAfterPaste
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: "自动排序",
          detail: "复制已存在内容时移动到最前面。",
          isOn: $moveDuplicatesToTop
        )
      }
    }
  }
}

struct HistorySettingsPage: View {
  @Binding var maxHistoryCount: Int
  @Binding var retentionDays: Int
  let maxHistoryCountValueText: String
  let retentionDaysValueText: String
  let recordableKinds: [ClipboardKind]
  let enabledTypeBinding: (ClipboardKind) -> Binding<Bool>
  @Binding var privacyMode: Bool
  let addCurrentApplicationLabel: String
  let canAddCurrentApplication: Bool
  let addCurrentApplication: () -> Void
  let resetIgnoredApps: () -> Void
  @Binding var ignoredApps: Set<String>
  @Binding var ignoredPasteboardTypes: Set<String>
  let resetIgnoredPasteboardTypes: () -> Void
  let historyCountText: String
  let storageSizeText: String
  let refreshStatus: () -> Void
  let revealDataDirectory: () -> Void

  var body: some View {
    SettingsPageStack {
      historySettingsCard
      recordTypesCard
      privacySettingsCard
      dataStatusCard
    }
  }

  private var historySettingsCard: some View {
    SettingsSectionCard(title: "历史设置") {
      SettingsRow(title: "最大历史数量", detail: "超过数量后会自动清理旧记录。") {
        stepperValue(text: maxHistoryCountValueText) {
          Stepper("", value: $maxHistoryCount, in: 50...10_000, step: 50)
            .labelsHidden()
        }
      }

      SettingsDivider()

      SettingsRow(title: "历史保留", detail: "设为永久时不会按天数清理。") {
        stepperValue(text: retentionDaysValueText) {
          Stepper("", value: $retentionDays, in: 0...365, step: 1)
            .labelsHidden()
        }
      }
    }
  }

  private var recordTypesCard: some View {
    SettingsSectionCard(title: "记录类型") {
      ForEach(Array(recordableKinds.enumerated()), id: \.element) { index, kind in
        SettingsSwitchRow(title: kind.displayName, isOn: enabledTypeBinding(kind))

        if index < recordableKinds.count - 1 {
          SettingsDivider()
        }
      }
    }
  }

  private var privacySettingsCard: some View {
    SettingsSectionCard(title: "隐私设置") {
      SettingsSwitchRow(
        title: "私密模式",
        detail: "开启后暂停记录新的剪贴板内容。",
        isOn: $privacyMode
      )

      SettingsDivider()

      SettingsActionRow {
        Button(action: addCurrentApplication) {
          Label(addCurrentApplicationLabel, systemImage: "app.badge")
        }
        .disabled(!canAddCurrentApplication)

        Button(action: resetIgnoredApps) {
          Label("恢复默认应用", systemImage: "arrow.counterclockwise")
        }
      }

      SettingsDivider()

      EditableStringList(
        title: "忽略应用 Bundle ID",
        placeholder: "com.example.SecretApp",
        values: $ignoredApps
      )
      .padding(16)

      SettingsDivider()

      EditableStringList(
        title: "忽略剪贴板类型",
        placeholder: "org.nspasteboard.TransientType",
        values: $ignoredPasteboardTypes
      )
      .padding(16)

      SettingsDivider()

      SettingsActionRow {
        Button(action: resetIgnoredPasteboardTypes) {
          Label("恢复默认忽略类型", systemImage: "arrow.counterclockwise")
        }
      }
    }
  }

  private var dataStatusCard: some View {
    SettingsSectionCard(title: "数据状态") {
      SettingsInfoRow(title: "历史数量", value: historyCountText)
      SettingsDivider()
      SettingsInfoRow(title: "数据占用", value: storageSizeText)
      SettingsDivider()
      SettingsActionRow {
        Button(action: refreshStatus) {
          Label("刷新状态", systemImage: "arrow.clockwise")
        }

        Button(action: revealDataDirectory) {
          Label("显示数据目录", systemImage: "folder")
        }
      }
    }
  }

  private func stepperValue<Content: View>(
    text: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: 10) {
      Text(text)
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary)
        .frame(width: 82, alignment: .trailing)

      content()
    }
  }
}

struct GeneralSettingsPage: View {
  @Binding var launchAtLogin: Bool
  let recordingStatusTitle: String
  let currentApplicationTitle: String
  let statusErrorMessage: String?
  let historyPersistenceErrorMessage: String?
  let settingsSaveErrorMessage: String?
  let accessibilityStatusTitle: String
  let accessibilityTrusted: Bool
  let requestAccessibilityPermission: () -> Void
  let openAccessibilitySettings: () -> Void
  let refreshAccessibilityStatus: () -> Void

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: "应用设置") {
        SettingsSwitchRow(title: "开机启动", isOn: $launchAtLogin)
      }

      SettingsSectionCard(title: "运行状态") {
        SettingsInfoRow(title: "剪贴板记录", value: recordingStatusTitle)
        SettingsDivider()
        SettingsInfoRow(title: "最近应用", value: currentApplicationTitle)

        if let statusErrorMessage {
          SettingsDivider()
          SettingsWarningRow(message: statusErrorMessage)
        }

        if let historyPersistenceErrorMessage {
          SettingsDivider()
          SettingsWarningRow(message: historyPersistenceErrorMessage)
        }

        if let settingsSaveErrorMessage {
          SettingsDivider()
          SettingsWarningRow(message: settingsSaveErrorMessage)
        }
      }

      SettingsSectionCard(title: "权限") {
        SettingsInfoRow(
          title: "辅助功能",
          value: accessibilityStatusTitle,
          systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
          tint: accessibilityTrusted ? .green : .orange
        )

        SettingsDivider()

        SettingsActionRow {
          Button(action: requestAccessibilityPermission) {
            Label("请求权限", systemImage: "hand.raised")
          }

          Button(action: openAccessibilitySettings) {
            Label("打开系统设置", systemImage: "gearshape")
          }

          Button(action: refreshAccessibilityStatus) {
            Label("刷新", systemImage: "arrow.clockwise")
          }
        }
      }
    }
  }
}

struct HotkeySettingsPage: View {
  @Binding var panelHotkey: String

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: "全局快捷键") {
        SettingsRow(title: "打开面板") {
          Picker("", selection: $panelHotkey) {
            ForEach(PanelHotkeyCatalog.hotkeys, id: \.self) { hotkey in
              Text(PanelHotkeyCatalog.displayName(for: hotkey)).tag(hotkey)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 170)
        }
      }

      SettingsSectionCard(title: "置顶快捷键") {
        SettingsInfoRow(title: "支持范围", value: "⌘⌥1 到 ⌘⌥9")
        SettingsDivider()
        SettingsInfoRow(title: "配置入口", value: "记录更多菜单")
      }
    }
  }
}

struct BackupSettingsPage: View {
  let exportBackup: () -> Void
  let mergeImport: () -> Void
  let replaceImport: () -> Void

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: "数据备份") {
        SettingsActionRow {
          Button(action: exportBackup) {
            Label("导出", systemImage: "square.and.arrow.up")
          }

          Button(action: mergeImport) {
            Label("合并导入", systemImage: "arrow.triangle.merge")
          }

          Button(action: replaceImport) {
            Label("覆盖导入", systemImage: "arrow.down.doc")
          }
        }
      }
    }
  }
}

struct AboutSettingsPage: View {
  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: "应用信息") {
        SettingsInfoRow(title: "应用", value: AppMetadata.displayName)
        SettingsDivider()
        SettingsInfoRow(title: "版本", value: AppMetadata.versionSummary)
        SettingsDivider()
        SettingsInfoRow(title: "Bundle ID", value: AppMetadata.bundleIdentifier)
        SettingsDivider()
        SettingsInfoRow(title: "最低系统", value: "macOS \(AppMetadata.minimumMacOSVersion)+")
        SettingsDivider()
        SettingsInfoRow(title: "许可证", value: AppMetadata.licenseName)
        SettingsDivider()
        SettingsActionRow {
          Button {
            NSWorkspace.shared.open(AppMetadata.repositoryURL)
          } label: {
            Label("打开项目仓库", systemImage: "arrow.up.right.square")
          }
        }
      }
    }
  }
}
