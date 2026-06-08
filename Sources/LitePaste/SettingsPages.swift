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
  @Binding var copySoundEnabled: Bool
  @Binding var imageOCREnabled: Bool
  @Binding var copyPlainTextByDefault: Bool
  @Binding var pastePlainTextByDefault: Bool
  @Binding var visibleQuickActions: Set<ClipboardQuickAction>
  @Binding var autoFavoriteAfterNote: Bool
  @Binding var restoreClipboardAfterPaste: Bool
  @Binding var moveDuplicatesToTop: Bool
  let panelPositionDescription: String
  @State private var showsQuickActionEditor = false

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("窗口设置", "Window")) {
        SettingsRow(title: AppText.value("窗口位置", "Position"), detail: panelPositionDescription) {
          Picker("", selection: $panelPosition) {
            ForEach(PanelPosition.allCases) { position in
              Text(position.localizedDisplayName).tag(position)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsRow(title: AppText.value("默认视图", "Default View")) {
          Picker("", selection: $viewMode) {
            Text(AppText.value("卡片", "Cards")).tag(ClipboardPanelViewMode.card)
            Text(AppText.value("列表", "List")).tag(ClipboardPanelViewMode.list)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.segmentedWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("贴边时覆盖菜单栏", "Cover Menu Bar At Edges"),
          detail: AppText.value(
            "靠上、靠左和靠右时尝试覆盖系统菜单栏区域。",
            "When attached to the top, left, or right edge, the panel can use the menu bar area."
          ),
          isOn: $coverMenuBarWhenEdgeAttached
        )
      }

      SettingsSectionCard(title: AppText.value("音效设置", "Sound")) {
        SettingsSwitchRow(
          title: AppText.value("复制音效", "Copy Sound"),
          detail: AppText.value("新内容进入历史记录时播放提示音。", "Play a sound when new content is saved."),
          isOn: $copySoundEnabled
        )
      }

      SettingsSectionCard(title: AppText.value("搜索设置", "Search")) {
        SettingsSwitchRow(
          title: AppText.value("默认聚焦", "Focus Search"),
          detail: AppText.value("打开面板时自动聚焦搜索框。", "Focus the search field when the panel opens."),
          isOn: $focusSearchOnOpen
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动清除", "Clear On Open"),
          detail: AppText.value("打开面板时清除上一次搜索内容。", "Clear the previous search when the panel opens."),
          isOn: $clearSearchOnOpen
        )
      }

      SettingsSectionCard(title: AppText.value("内容设置", "Content")) {
        SettingsRow(
          title: AppText.value("默认操作", "Default Action"),
          detail: AppText.value("选择记录后的默认行为。", "Choose what happens when an item is selected.")
        ) {
          Picker("", selection: $autoPasteMode) {
            Text(AppText.value("仅复制", "Copy Only")).tag(AutoPasteMode.copyOnly)
            Text(AppText.value("自动粘贴", "Auto Paste")).tag(AutoPasteMode.paste)
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动识别图片文字", "Auto Image OCR"),
          detail: AppText.value(
            "复制新图片时后台识别文字并加入搜索；手动复制图片文字不受此开关影响。",
            "Recognize text in newly copied images for search. Manual image text actions still work when this is off."
          ),
          isOn: $imageOCREnabled
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("复制为纯文本", "Copy Plain Text"),
          detail: AppText.value(
            "富文本和 HTML 默认复制时仅保留纯文本内容。",
            "Rich text and HTML are copied as plain text by default."
          ),
          isOn: $copyPlainTextByDefault
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("粘贴为纯文本", "Paste Plain Text"),
          detail: AppText.value(
            "富文本和 HTML 默认粘贴时仅保留纯文本内容。",
            "Rich text and HTML are pasted as plain text by default."
          ),
          isOn: $pastePlainTextByDefault
        )

        SettingsDivider()

        SettingsRow(
          title: AppText.value("操作按钮", "Action Buttons"),
          detail: quickActionSummary
        ) {
          Button {
            showsQuickActionEditor = true
          } label: {
            Label(AppText.value("自定义", "Customize"), systemImage: "slider.horizontal.3")
          }
        }
        .sheet(isPresented: $showsQuickActionEditor) {
          QuickActionSettingsSheet(visibleQuickActions: $visibleQuickActions)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动收藏", "Auto Favorite"),
          detail: AppText.value(
            "新增或编辑备注后自动收藏该记录。",
            "Favorite an item automatically after a note is added or edited."
          ),
          isOn: $autoFavoriteAfterNote
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("恢复原剪贴板", "Restore Clipboard"),
          detail: AppText.value(
            "自动粘贴后恢复执行前的剪贴板内容。",
            "Restore the previous clipboard content after auto paste."
          ),
          isOn: $restoreClipboardAfterPaste
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动排序", "Move Duplicates To Top"),
          detail: AppText.value("复制已存在内容时移动到最前面。", "Move existing content to the top when copied again."),
          isOn: $moveDuplicatesToTop
        )
      }
    }
  }

  private var quickActionSummary: String {
    let names = ClipboardQuickAction.displayOrder
      .filter { visibleQuickActions.contains($0) }
      .map(\.localizedDisplayName)

    if names.isEmpty {
      return AppText.value("仅显示更多菜单。", "Only the More menu is shown.")
    }

    return names.joined(separator: AppText.value("、", ", "))
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
    SettingsSectionCard(title: AppText.value("历史设置", "History")) {
      SettingsRow(
        title: AppText.value("最大历史数量", "Maximum Items"),
        detail: AppText.value("超过数量后会自动清理旧记录。", "Older items are removed automatically after this limit.")
      ) {
        SettingsNumberStepperField(
          value: $maxHistoryCount,
          range: 50...10_000,
          step: 50,
          unit: AppText.value("条", "items")
        )
      }

      SettingsDivider()

      SettingsRow(
        title: AppText.value("历史保留", "Retention"),
        detail: AppText.value("输入 0 表示永久，不会按天数清理。", "Use 0 to keep history permanently.")
      ) {
        SettingsNumberStepperField(
          value: $retentionDays,
          range: 0...365,
          step: 1,
          unit: AppText.value("天", "days")
        )
      }

      SettingsDivider()

      SettingsSwitchRow(
        title: AppText.value("大表格原始格式", "Preserve Large Table Formats"),
        detail: AppText.value(
          "复制大型表格时保留更多原始格式，粘回表格软件时更可能保留公式；会增加内存和磁盘占用。",
          "Keep richer formats for large copied tables. This can improve fidelity when pasting back into spreadsheet apps, but uses more memory and disk space."
        ),
        isOn: $preserveLargeRichTextFormats
      )
    }
  }

  private var recordTypesCard: some View {
    SettingsSectionCard(title: AppText.value("记录类型", "Recorded Types")) {
      ForEach(Array(recordableKinds.enumerated()), id: \.element) { index, kind in
        SettingsSwitchRow(title: kind.localizedDisplayName, isOn: enabledTypeBinding(kind))

        if index < recordableKinds.count - 1 {
          SettingsDivider()
        }
      }
    }
  }

  private var privacySettingsCard: some View {
    SettingsSectionCard(title: AppText.value("监听与过滤", "Monitoring And Filters")) {
      SettingsSwitchRow(
        title: AppText.value("停止监听", "Pause Monitoring"),
        detail: AppText.value(
          "开启后不再监听系统剪贴板，也不会保存新的历史记录。",
          "When enabled, Lite Paste stops watching the system clipboard and will not save new history."
        ),
        isOn: $isMonitoringPaused
      )

      SettingsDivider()

      SettingsActionRow {
        Button(action: addCurrentApplication) {
          Label(addCurrentApplicationLabel, systemImage: "app.badge")
        }
        .disabled(!canAddCurrentApplication)

        Button(action: resetIgnoredApps) {
          Label(AppText.value("恢复默认应用", "Restore Default Apps"), systemImage: "arrow.counterclockwise")
        }
      }

      SettingsDivider()

      EditableStringList(
        title: AppText.value("忽略应用 Bundle ID", "Ignored App Bundle IDs"),
        placeholder: "com.example.SecretApp",
        values: $ignoredApps
      )
      .padding(16)

      SettingsDivider()

      EditableStringList(
        title: AppText.value("忽略剪贴板类型", "Ignored Pasteboard Types"),
        placeholder: "org.nspasteboard.TransientType",
        values: $ignoredPasteboardTypes
      )
      .padding(16)

      SettingsDivider()

      SettingsActionRow {
        Button(action: resetIgnoredPasteboardTypes) {
          Label(AppText.value("恢复默认忽略类型", "Restore Default Types"), systemImage: "arrow.counterclockwise")
        }
      }
    }
  }

  private var dataStatusCard: some View {
    SettingsSectionCard(title: AppText.value("数据状态", "Data Status")) {
      SettingsInfoRow(title: AppText.value("历史数量", "History Items"), value: historyCountText)
      SettingsDivider()
      SettingsInfoRow(title: AppText.value("数据占用", "Storage Used"), value: storageSizeText)
      SettingsDivider()
      SettingsActionRow {
        Button(action: refreshStatus) {
          Label(AppText.value("刷新状态", "Refresh Status"), systemImage: "arrow.clockwise")
        }

        Button(action: revealDataDirectory) {
          Label(AppText.value("显示数据目录", "Show Data Folder"), systemImage: "folder")
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
  @Binding var showMenuBarIcon: Bool
  @Binding var showDockIcon: Bool
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
      SettingsSectionCard(title: AppText.value("应用设置", "App")) {
        SettingsSwitchRow(title: AppText.value("开机启动", "Launch At Login"), isOn: $launchAtLogin)
        SettingsDivider()
        SettingsSwitchRow(
          title: AppText.value("显示菜单栏图标", "Show Menu Bar Icon"),
          detail: AppText.value(
            "关闭后仍可通过全局快捷键打开面板。",
            "When hidden, the panel can still be opened with the global shortcut."
          ),
          isOn: $showMenuBarIcon
        )
        SettingsDivider()
        SettingsSwitchRow(
          title: AppText.value("显示 Dock 图标", "Show Dock Icon"),
          detail: AppText.value(
            "菜单栏和 Dock 至少保留一个可见入口。",
            "At least one visible entry point is kept between the menu bar and Dock."
          ),
          isOn: $showDockIcon
        )
      }

      SettingsSectionCard(title: AppText.value("运行状态", "Status")) {
        SettingsInfoRow(title: AppText.value("剪贴板记录", "Clipboard Recording"), value: recordingStatusTitle)
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("最近应用", "Recent App"), value: currentApplicationTitle)

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

      SettingsSectionCard(title: AppText.value("权限", "Permissions")) {
        SettingsInfoRow(
          title: AppText.value("辅助功能", "Accessibility"),
          value: accessibilityStatusTitle,
          systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
          tint: accessibilityTrusted ? .green : .orange
        )

        SettingsDivider()

        SettingsActionRow {
          Button(action: requestAccessibilityPermission) {
            Label(AppText.value("请求权限", "Request Permission"), systemImage: "hand.raised")
          }

          Button(action: openAccessibilitySettings) {
            Label(AppText.value("打开系统设置", "Open System Settings"), systemImage: "gearshape")
          }

          Button(action: refreshAccessibilityStatus) {
            Label(AppText.value("刷新", "Refresh"), systemImage: "arrow.clockwise")
          }
        }
      }
    }
  }
}

struct AppearanceSettingsPage: View {
  @Binding var interfaceLanguage: AppLanguage
  @Binding var themeMode: AppThemeMode

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("外观设置", "Appearance")) {
        SettingsRow(title: AppText.value("界面语言", "Interface Language")) {
          Picker("", selection: $interfaceLanguage) {
            ForEach(AppLanguage.allCases) { language in
              Text(language.localizedDisplayName).tag(language)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsRow(title: AppText.value("主题模式", "Theme")) {
          Picker("", selection: $themeMode) {
            ForEach(AppThemeMode.allCases) { mode in
              Text(mode.localizedDisplayName).tag(mode)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }
      }
    }
  }
}

struct QuickActionSettingsSheet: View {
  @Binding var visibleQuickActions: Set<ClipboardQuickAction>
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(AppText.value("操作按钮", "Action Buttons"))
        .font(.system(size: 18, weight: .bold))

      Text(AppText.value(
        "最多显示 4 个快捷按钮，更多操作始终保留在菜单中。",
        "Show up to 4 quick buttons. All actions remain available in the More menu."
      ))
      .font(.system(size: 12))
      .foregroundStyle(.secondary)

      VStack(spacing: 0) {
        ForEach(ClipboardQuickAction.displayOrder) { action in
          Toggle(isOn: binding(for: action)) {
            Label(action.localizedDisplayName, systemImage: action.iconName)
          }
          .toggleStyle(.checkbox)
          .disabled(!visibleQuickActions.contains(action) && visibleQuickActions.count >= 4)
          .padding(.vertical, 7)
        }
      }

      HStack {
        Spacer()
        Button(AppText.value("完成", "Done")) {
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(22)
    .frame(width: 360)
  }

  private func binding(for action: ClipboardQuickAction) -> Binding<Bool> {
    Binding {
      visibleQuickActions.contains(action)
    } set: { enabled in
      if enabled {
        visibleQuickActions.insert(action)
      } else {
        visibleQuickActions.remove(action)
      }
    }
  }
}

struct HotkeySettingsPage: View {
  @Binding var panelHotkey: String

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("全局快捷键", "Global Shortcut")) {
        SettingsRow(title: AppText.value("打开面板", "Open Panel")) {
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

      SettingsSectionCard(title: AppText.value("面板快捷键", "Panel Shortcuts")) {
        SettingsInfoRow(title: AppText.value("选择条目", "Select Item"), value: AppText.value("⌘1 到 ⌘6", "⌘1 to ⌘6"))
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("确认粘贴", "Paste Selected"), value: "Return")
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("复制条目", "Copy Selected"), value: "⌘C")
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("删除条目", "Delete Selected"), value: "Delete")
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
      SettingsSectionCard(title: AppText.value("数据备份", "Local Backups")) {
        SettingsActionRow {
          Button(action: exportBackup) {
            Label(AppText.value("导出", "Export"), systemImage: "square.and.arrow.up")
          }

          Button(action: mergeImport) {
            Label(AppText.value("合并导入", "Merge Import"), systemImage: "arrow.triangle.merge")
          }

          Button(action: replaceImport) {
            Label(AppText.value("覆盖导入", "Replace Import"), systemImage: "arrow.down.doc")
          }
        }
      }

      SettingsSectionCard(title: AppText.value("iCloud 备份", "iCloud Backup")) {
        SettingsInfoRow(title: AppText.value("状态", "Status"), value: iCloudStatusText)

        SettingsDivider()

        SettingsActionRow {
          Button(action: exportICloudBackup) {
            Label(AppText.value("备份到 iCloud", "Back Up To iCloud"), systemImage: "icloud.and.arrow.up")
          }

          Button(action: refreshICloudStatus) {
            Label(AppText.value("刷新", "Refresh"), systemImage: "arrow.clockwise")
          }

          Button(action: revealICloudBackupsDirectory) {
            Label(AppText.value("显示目录", "Show Folder"), systemImage: "folder")
          }
        }

        SettingsDivider()

        SettingsActionRow {
          Button(action: mergeImportICloudBackup) {
            Label(AppText.value("从 iCloud 合并", "Merge From iCloud"), systemImage: "icloud.and.arrow.down")
          }

          Button(action: replaceImportICloudBackup) {
            Label(AppText.value("从 iCloud 覆盖", "Replace From iCloud"), systemImage: "arrow.down.doc")
          }
        }
      }
    }
  }
}

struct AboutSettingsPage: View {
  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("应用信息", "App Info")) {
        SettingsInfoRow(title: AppText.value("应用", "App"), value: AppMetadata.displayName)
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("版本", "Version"), value: AppMetadata.versionSummary)
        SettingsDivider()
        SettingsInfoRow(title: "Bundle ID", value: AppMetadata.bundleIdentifier)
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("最低系统", "Minimum macOS"), value: "macOS \(AppMetadata.minimumMacOSVersion)+")
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("许可证", "License"), value: AppMetadata.licenseName)
        SettingsDivider()
        SettingsActionRow {
          Button {
            NSWorkspace.shared.open(AppMetadata.repositoryURL)
          } label: {
            Label(AppText.value("打开项目仓库", "Open Repository"), systemImage: "arrow.up.right.square")
          }
        }
      }
    }
  }
}
