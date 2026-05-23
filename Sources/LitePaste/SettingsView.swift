import AppKit
import LitePasteCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject private var store = AppSettingsStore.shared
  @ObservedObject private var activeApplicationTracker = ActiveApplicationTracker.shared
  @State private var backupCoordinator = BackupCoordinator()
  @State private var launchAtLoginController = LaunchAtLoginController()
  @State private var accessibilityTrusted = AccessibilityPermissionController.isTrusted
  @State private var historyCount: Int?
  @State private var storageSizeText = "正在读取"
  @State private var statusErrorMessage: String?
  @State private var settingsSaveErrorMessage: String?

  var body: some View {
    Form {
      Section("通用") {
        Toggle("开机启动", isOn: launchAtLogin)

        Picker("打开面板快捷键", selection: panelHotkey) {
          ForEach(PanelHotkeyCatalog.hotkeys, id: \.self) { hotkey in
            Text(PanelHotkeyCatalog.displayName(for: hotkey)).tag(hotkey)
          }
        }

        Picker("默认视图", selection: viewMode) {
          Text("卡片").tag(ClipboardPanelViewMode.card)
          Text("列表").tag(ClipboardPanelViewMode.list)
        }

        Picker("面板位置", selection: panelPosition) {
          ForEach(PanelPosition.allCases) { position in
            Text(position.displayName).tag(position)
          }
        }

        Toggle("打开面板时清空搜索", isOn: clearSearchOnOpen)
        Toggle("打开面板时聚焦搜索", isOn: focusSearchOnOpen)
      }

      Section("状态") {
        LabeledContent("剪贴板记录", value: recordingStatusTitle)
        LabeledContent("自动粘贴", value: accessibilityTrusted ? "可用" : "需要辅助功能权限")
        LabeledContent("最近应用", value: currentApplicationTitle)
        LabeledContent("历史数量", value: historyCount.map { "\($0) 条" } ?? "正在读取")
        LabeledContent("数据占用", value: storageSizeText)

        if let statusErrorMessage {
          Label(statusErrorMessage, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        }

        if let settingsSaveErrorMessage {
          Label(settingsSaveErrorMessage, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        }

        HStack {
          Button {
            refreshStatus()
          } label: {
            Label("刷新状态", systemImage: "arrow.clockwise")
          }

          Button {
            revealDataDirectory()
          } label: {
            Label("显示数据目录", systemImage: "folder")
          }
        }
      }

      Section("权限") {
        HStack {
          Label(accessibilityStatusTitle, systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(accessibilityTrusted ? .green : .orange)

          Spacer()

          Button {
            refreshAccessibilityStatus()
          } label: {
            Label("刷新", systemImage: "arrow.clockwise")
          }
        }

        HStack {
          Button {
            AccessibilityPermissionController.requestPermission()
            refreshAccessibilityStatus()
          } label: {
            Label("请求辅助功能权限", systemImage: "hand.raised")
          }

          Button {
            AccessibilityPermissionController.openSystemSettings()
          } label: {
            Label("打开系统设置", systemImage: "gearshape")
          }
        }
      }

      Section("剪贴板") {
        Toggle("默认纯文本粘贴", isOn: pastePlainByDefault)
        Toggle("自动粘贴后恢复原剪贴板", isOn: restoreClipboardAfterPaste)

        Picker("默认操作", selection: autoPasteMode) {
          Text("仅复制").tag(AutoPasteMode.copyOnly)
          Text("自动粘贴").tag(AutoPasteMode.paste)
        }

        Toggle("重复复制时移到顶部", isOn: moveDuplicatesToTop)

        Stepper("最大历史数量: \(store.settings.maxHistoryCount)", value: maxHistoryCount, in: 50...10_000, step: 50)
        Stepper(retentionDaysLabel, value: retentionDays, in: 0...365, step: 1)

        VStack(alignment: .leading, spacing: 8) {
          Text("记录类型")
            .font(.headline)

          ForEach(recordableKinds) { kind in
            Toggle(kind.displayName, isOn: enabledTypeBinding(kind))
          }
        }
      }

      Section("隐私") {
        Toggle("私密模式", isOn: privacyMode)

        Button {
          addLastExternalApplicationToIgnoredApps()
        } label: {
          Label(addCurrentApplicationLabel, systemImage: "app.badge")
        }
        .disabled(activeApplicationTracker.lastExternalApplication == nil)

        EditableStringList(
          title: "忽略应用 Bundle ID",
          placeholder: "com.example.SecretApp",
          values: ignoredApps
        )

        Button {
          resetIgnoredApps()
        } label: {
          Label("恢复默认忽略应用", systemImage: "arrow.counterclockwise")
        }

        EditableStringList(
          title: "忽略剪贴板类型",
          placeholder: "org.nspasteboard.TransientType",
          values: ignoredPasteboardTypes
        )

        Button {
          resetIgnoredPasteboardTypes()
        } label: {
          Label("恢复默认忽略类型", systemImage: "arrow.counterclockwise")
        }
      }

      Section("备份") {
        HStack {
          Button {
            backupCoordinator.exportBackup()
          } label: {
            Label("导出", systemImage: "square.and.arrow.up")
          }

          Button {
            backupCoordinator.importBackup(mode: .merge)
          } label: {
            Label("合并导入", systemImage: "arrow.triangle.merge")
          }

          Button {
            backupCoordinator.importBackup(mode: .replace)
          } label: {
            Label("覆盖导入", systemImage: "arrow.down.doc")
          }
        }
      }

      Section("关于") {
        LabeledContent("应用", value: AppMetadata.displayName)
        LabeledContent("版本", value: AppMetadata.versionSummary)
        LabeledContent("Bundle ID", value: AppMetadata.bundleIdentifier)
        LabeledContent("最低系统", value: "macOS \(AppMetadata.minimumMacOSVersion)+")
      }
    }
    .padding(24)
    .frame(width: 520)
    .onAppear {
      refreshStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteHistoryChanged)) { _ in
      refreshHistoryStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteBackupImported)) { _ in
      refreshStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteSettingsSaveFailed)) { notification in
      handleSettingsSaveFailure(notification)
    }
  }

  private var launchAtLogin: Binding<Bool> {
    Binding {
      store.settings.launchAtLogin
    } set: { value in
      do {
        try launchAtLoginController.setEnabled(value)
        store.update { $0.launchAtLogin = value }
      } catch {
        showAlert(title: "无法更新开机启动", message: error.localizedDescription)
      }
    }
  }

  private var panelHotkey: Binding<String> {
    Binding {
      store.settings.hotkey
    } set: { value in
      store.update { $0.hotkey = value }
    }
  }

  private var pastePlainByDefault: Binding<Bool> {
    Binding {
      store.settings.pastePlainByDefault
    } set: { value in
      store.update { $0.pastePlainByDefault = value }
    }
  }

  private var restoreClipboardAfterPaste: Binding<Bool> {
    Binding {
      store.settings.restoreClipboardAfterPaste
    } set: { value in
      store.update { $0.restoreClipboardAfterPaste = value }
    }
  }

  private var clearSearchOnOpen: Binding<Bool> {
    Binding {
      store.settings.clearSearchOnOpen
    } set: { value in
      store.update { $0.clearSearchOnOpen = value }
    }
  }

  private var focusSearchOnOpen: Binding<Bool> {
    Binding {
      store.settings.focusSearchOnOpen
    } set: { value in
      store.update { $0.focusSearchOnOpen = value }
    }
  }

  private var moveDuplicatesToTop: Binding<Bool> {
    Binding {
      store.settings.moveDuplicatesToTop
    } set: { value in
      store.update { $0.moveDuplicatesToTop = value }
    }
  }

  private var viewMode: Binding<ClipboardPanelViewMode> {
    Binding {
      store.settings.viewMode
    } set: { value in
      store.update { $0.viewMode = value }
    }
  }

  private var panelPosition: Binding<PanelPosition> {
    Binding {
      store.settings.panelPosition
    } set: { value in
      store.update { $0.panelPosition = value }
    }
  }

  private var maxHistoryCount: Binding<Int> {
    Binding {
      store.settings.maxHistoryCount
    } set: { value in
      store.update { $0.maxHistoryCount = value }
    }
  }

  private var retentionDays: Binding<Int> {
    Binding {
      store.settings.retentionDays
    } set: { value in
      store.update { $0.retentionDays = value }
    }
  }

  private var retentionDaysLabel: String {
    if store.settings.retentionDays == 0 {
      "历史保留: 永久"
    } else {
      "历史保留: \(store.settings.retentionDays) 天"
    }
  }

  private var privacyMode: Binding<Bool> {
    Binding {
      store.settings.privacyMode
    } set: { value in
      store.update { $0.privacyMode = value }
    }
  }

  private var ignoredApps: Binding<Set<String>> {
    Binding {
      store.settings.ignoredApps
    } set: { value in
      store.update { $0.ignoredApps = value }
    }
  }

  private var ignoredPasteboardTypes: Binding<Set<String>> {
    Binding {
      store.settings.ignoredPasteboardTypes
    } set: { value in
      store.update { $0.ignoredPasteboardTypes = value }
    }
  }

  private var autoPasteMode: Binding<AutoPasteMode> {
    Binding {
      store.settings.autoPasteMode
    } set: { value in
      store.update { $0.autoPasteMode = value }
    }
  }

  private var accessibilityStatusTitle: String {
    accessibilityTrusted ? "辅助功能权限已授权" : "自动粘贴需要辅助功能权限"
  }

  private var recordingStatusTitle: String {
    if store.settings.privacyMode {
      return "私密模式已开启"
    }

    if let application = activeApplicationTracker.lastExternalApplication,
       store.settings.ignoredApps.contains(application.bundleIdentifier) {
      return "\(application.name) 已被忽略"
    }

    return "正在记录"
  }

  private var currentApplicationTitle: String {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return "暂无"
    }

    return "\(application.name) (\(application.bundleIdentifier))"
  }

  private var recordableKinds: [ClipboardKind] {
    [.text, .richText, .html, .image, .files, .url, .email, .color]
  }

  private func enabledTypeBinding(_ kind: ClipboardKind) -> Binding<Bool> {
    Binding {
      store.settings.enabledTypes.contains(kind)
    } set: { enabled in
      store.update { settings in
        if enabled {
          settings.enabledTypes.insert(kind)
        } else {
          settings.enabledTypes.remove(kind)
        }
      }
    }
  }

  private func resetIgnoredPasteboardTypes() {
    store.update { $0.ignoredPasteboardTypes = PrivacyFilter.defaultIgnoredPasteboardTypes }
  }

  private func resetIgnoredApps() {
    store.update { $0.ignoredApps = PrivacyFilter.defaultIgnoredApps }
  }

  private var addCurrentApplicationLabel: String {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return "添加最近使用的应用"
    }

    return "忽略 \(application.name)"
  }

  private func addLastExternalApplicationToIgnoredApps() {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return
    }

    store.update { $0.ignoredApps.insert(application.bundleIdentifier) }
  }

  private func refreshAccessibilityStatus() {
    accessibilityTrusted = AccessibilityPermissionController.isTrusted
  }

  private func refreshStatus() {
    refreshAccessibilityStatus()
    refreshHistoryStatus()
  }

  private func handleSettingsSaveFailure(_ notification: Notification) {
    let message = notification.userInfo?[SettingsNotificationUserInfoKey.errorMessage] as? String ?? "未知错误"
    settingsSaveErrorMessage = "无法保存设置：\(message)"
    showAlert(title: "无法保存设置", message: "本次设置变更已在当前运行中生效，但没有写入磁盘。\(message)")
  }

  private func refreshHistoryStatus() {
    statusErrorMessage = nil

    do {
      historyCount = try SQLiteClipboardHistoryRepository().count(ClipboardHistoryQuery())
    } catch {
      historyCount = nil
      statusErrorMessage = "无法读取历史数量：\(error.localizedDescription)"
    }

    do {
      storageSizeText = Self.byteCountFormatter.string(
        fromByteCount: Int64(try totalSizeOfDataDirectory())
      )
    } catch {
      storageSizeText = "读取失败"
      statusErrorMessage = "无法读取数据目录：\(error.localizedDescription)"
    }
  }

  private func revealDataDirectory() {
    do {
      try AppPaths.ensureApplicationSupportDirectoryExists()
      NSWorkspace.shared.activateFileViewerSelecting([AppPaths.applicationSupportDirectory])
    } catch {
      showAlert(title: "无法打开数据目录", message: error.localizedDescription)
    }
  }

  private func totalSizeOfDataDirectory() throws -> UInt64 {
    let directory = AppPaths.applicationSupportDirectory
    guard FileManager.default.fileExists(atPath: directory.path) else {
      return 0
    }

    let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
    guard let enumerator = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: Array(resourceKeys),
      options: [.skipsHiddenFiles]
    ) else {
      return 0
    }

    return try enumerator.reduce(UInt64(0)) { total, item in
      guard let url = item as? URL else {
        return total
      }

      let values = try url.resourceValues(forKeys: resourceKeys)
      guard values.isRegularFile == true else {
        return total
      }

      return total + UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.alertStyle = .warning
    alert.runModal()
  }

  private static let byteCountFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter
  }()
}
