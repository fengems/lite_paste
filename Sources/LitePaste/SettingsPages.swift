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
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsRow(title: "默认视图") {
          Picker("", selection: $viewMode) {
            Text("卡片").tag(ClipboardPanelViewMode.card)
            Text("列表").tag(ClipboardPanelViewMode.list)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.segmentedWidth, alignment: .trailing)
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
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
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
  @Binding var preserveLargeRichTextFormats: Bool
  let recordableKinds: [ClipboardKind]
  let enabledTypeBinding: (ClipboardKind) -> Binding<Bool>
  @Binding var isMonitoringPaused: Bool
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
        SettingsNumberStepperField(
          value: $maxHistoryCount,
          range: 50...10_000,
          step: 50,
          unit: "条"
        )
      }

      SettingsDivider()

      SettingsRow(title: "历史保留", detail: "输入 0 表示永久，不会按天数清理。") {
        SettingsNumberStepperField(
          value: $retentionDays,
          range: 0...365,
          step: 1,
          unit: "天"
        )
      }

      SettingsDivider()

      SettingsSwitchRow(
        title: "大表格原始格式",
        detail: "复制大型表格时保留更多原始格式，粘回表格软件时更可能保留公式；会增加内存和磁盘占用。",
        isOn: $preserveLargeRichTextFormats
      )
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
    SettingsSectionCard(title: "监听与过滤") {
      SettingsSwitchRow(
        title: "停止监听",
        detail: "开启后不再监听系统剪贴板，也不会保存新的历史记录。",
        isOn: $isMonitoringPaused
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

}

private struct SettingsNumberStepperField: View {
  @Binding var value: Int
  let range: ClosedRange<Int>
  let step: Int
  let unit: String
  @State private var draftText = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 8) {
      TextField("", text: $draftText)
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .multilineTextAlignment(.trailing)
        .textFieldStyle(.plain)
        .focused($isFocused)
        .frame(width: 58, height: 24)
        .padding(.horizontal, 7)
        .background(SettingsSurface.fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(SettingsSurface.border.opacity(0.50), lineWidth: 1)
        )
        .onSubmit(commitDraft)
        .onAppear(perform: syncDraft)
        .onChange(of: draftText) { _, newText in
          keepDigitsOnly(newText)
        }
        .onChange(of: isFocused) { _, focused in
          if focused {
            syncDraft()
          } else {
            commitDraft()
          }
        }
        .onChange(of: value) {
          syncDraft()
        }

      Text(unit)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 14, alignment: .leading)

      Stepper("", value: clampedValue, in: range, step: step)
        .labelsHidden()
        .controlSize(.small)
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private var clampedValue: Binding<Int> {
    Binding {
      clamp(value)
    } set: { newValue in
      value = clamp(newValue)
    }
  }

  private func keepDigitsOnly(_ text: String) {
    let filtered = text.filter(\.isNumber)
    if filtered != text {
      draftText = String(filtered)
    }
  }

  private func commitDraft() {
    guard let parsedValue = Int(draftText) else {
      syncDraft()
      return
    }

    value = clamp(parsedValue)
    syncDraft()
  }

  private func syncDraft() {
    draftText = "\(clamp(value))"
  }

  private func clamp(_ candidate: Int) -> Int {
    min(max(candidate, range.lowerBound), range.upperBound)
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
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }
      }

      SettingsSectionCard(title: "面板快捷键") {
        SettingsInfoRow(title: "选择条目", value: "⌘1 到 ⌘6")
        SettingsDivider()
        SettingsInfoRow(title: "确认粘贴", value: "Return")
        SettingsDivider()
        SettingsInfoRow(title: "复制条目", value: "⌘C")
        SettingsDivider()
        SettingsInfoRow(title: "删除条目", value: "Delete")
      }
    }
  }
}

struct BackupSettingsPage: View {
  let exportBackup: () -> Void
  let mergeImport: () -> Void
  let replaceImport: () -> Void
  let iCloudStatusText: String
  let refreshICloudStatus: () -> Void
  let exportICloudBackup: () -> Void
  let mergeImportICloudBackup: () -> Void
  let replaceImportICloudBackup: () -> Void
  let revealICloudBackupsDirectory: () -> Void

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

      SettingsSectionCard(title: "iCloud 备份") {
        SettingsInfoRow(title: "状态", value: iCloudStatusText)

        SettingsDivider()

        SettingsActionRow {
          Button(action: exportICloudBackup) {
            Label("备份到 iCloud", systemImage: "icloud.and.arrow.up")
          }

          Button(action: refreshICloudStatus) {
            Label("刷新", systemImage: "arrow.clockwise")
          }

          Button(action: revealICloudBackupsDirectory) {
            Label("显示目录", systemImage: "folder")
          }
        }

        SettingsDivider()

        SettingsActionRow {
          Button(action: mergeImportICloudBackup) {
            Label("从 iCloud 合并", systemImage: "icloud.and.arrow.down")
          }

          Button(action: replaceImportICloudBackup) {
            Label("从 iCloud 覆盖", systemImage: "arrow.down.doc")
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
