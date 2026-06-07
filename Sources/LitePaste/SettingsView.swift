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
  @State private var storageSizeText = AppText.value("正在读取", "Reading")
  @State private var statusErrorMessage: String?
  @State private var historyPersistenceErrorMessage: String?
  @State private var settingsSaveErrorMessage: String?
  @State private var selectedPage: SettingsPage = .clipboard
  @State private var iCloudBackupStatusText = AppText.value("正在检查", "Checking")

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      SettingsVerticalDivider()
      detailPane
    }
    .frame(
      minWidth: 780,
      idealWidth: 860,
      maxWidth: .infinity,
      minHeight: 560,
      idealHeight: 600,
      maxHeight: .infinity
    )
    .background(SettingsSurface.windowBackground)
    .onAppear {
      refreshStatus()
      refreshICloudBackupStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteHistoryChanged)) { _ in
      refreshHistoryStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteHistoryPersistenceFailed)) { notification in
      handleHistoryPersistenceFailure(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteBackupImported)) { _ in
      refreshStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteSettingsSaveFailed)) { notification in
      handleSettingsSaveFailure(notification)
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(SettingsPage.allCases) { page in
        SettingsSidebarButton(
          page: page,
          isSelected: selectedPage == page
        ) {
          selectedPage = page
        }
      }

      Spacer()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 16)
    .frame(width: 198)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(SettingsSurface.sidebarBackground)
  }

  private var detailPane: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        SettingsPageHeader(page: selectedPage)
        selectedPageContent
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 20)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .scrollIndicators(.visible)
    .tint(selectedPage.accentColor)
  }

  @ViewBuilder
  private var selectedPageContent: some View {
    switch selectedPage {
    case .clipboard:
      clipboardSettingsPage
    case .history:
      historySettingsPage
    case .general:
      generalSettingsPage
    case .appearance:
      appearanceSettingsPage
    case .hotkeys:
      hotkeySettingsPage
    case .backup:
      backupSettingsPage
    case .about:
      aboutSettingsPage
    }
  }

  private var clipboardSettingsPage: some View {
    ClipboardSettingsPage(
      panelPosition: panelPosition,
      viewMode: viewMode,
      coverMenuBarWhenEdgeAttached: coverMenuBarWhenEdgeAttached,
      focusSearchOnOpen: focusSearchOnOpen,
      clearSearchOnOpen: clearSearchOnOpen,
      autoPasteMode: autoPasteMode,
      copySoundEnabled: copySoundEnabled,
      imageOCREnabled: imageOCREnabled,
      copyPlainTextByDefault: copyPlainTextByDefault,
      pastePlainTextByDefault: pastePlainTextByDefault,
      visibleQuickActions: visibleQuickActions,
      autoFavoriteAfterNote: autoFavoriteAfterNote,
      restoreClipboardAfterPaste: restoreClipboardAfterPaste,
      moveDuplicatesToTop: moveDuplicatesToTop,
      panelPositionDescription: panelPositionDescription
    )
  }

  private var historySettingsPage: some View {
    HistorySettingsPage(
      maxHistoryCount: maxHistoryCount,
      retentionDays: retentionDays,
      preserveLargeRichTextFormats: preserveLargeRichTextFormats,
      recordableKinds: recordableKinds,
      enabledTypeBinding: enabledTypeBinding,
      isMonitoringPaused: isMonitoringPaused,
      addCurrentApplicationLabel: addCurrentApplicationLabel,
      canAddCurrentApplication: activeApplicationTracker.lastExternalApplication != nil,
      addCurrentApplication: addLastExternalApplicationToIgnoredApps,
      resetIgnoredApps: resetIgnoredApps,
      ignoredApps: ignoredApps,
      ignoredPasteboardTypes: ignoredPasteboardTypes,
      resetIgnoredPasteboardTypes: resetIgnoredPasteboardTypes,
      historyCountText: historyCount.map(AppText.itemCount) ?? AppText.value("正在读取", "Reading"),
      storageSizeText: storageSizeText,
      refreshStatus: refreshStatus,
      revealDataDirectory: revealDataDirectory
    )
  }

  private var generalSettingsPage: some View {
    GeneralSettingsPage(
      launchAtLogin: launchAtLogin,
      showMenuBarIcon: showMenuBarIcon,
      showDockIcon: showDockIcon,
      recordingStatusTitle: recordingStatusTitle,
      currentApplicationTitle: currentApplicationTitle,
      statusErrorMessage: statusErrorMessage,
      historyPersistenceErrorMessage: historyPersistenceErrorMessage,
      settingsSaveErrorMessage: settingsSaveErrorMessage,
      accessibilityStatusTitle: accessibilityStatusTitle,
      accessibilityTrusted: accessibilityTrusted,
      requestAccessibilityPermission: {
        AccessibilityPermissionController.requestPermission()
        refreshAccessibilityStatus()
      },
      openAccessibilitySettings: AccessibilityPermissionController.openSystemSettings,
      refreshAccessibilityStatus: refreshAccessibilityStatus
    )
  }

  private var appearanceSettingsPage: some View {
    AppearanceSettingsPage(themeMode: themeMode)
  }

  private var hotkeySettingsPage: some View {
    HotkeySettingsPage(panelHotkey: panelHotkey)
  }

  private var backupSettingsPage: some View {
    BackupSettingsPage(
      exportBackup: backupCoordinator.exportBackup,
      mergeImport: { backupCoordinator.importBackup(mode: .merge) },
      replaceImport: { backupCoordinator.importBackup(mode: .replace) },
      iCloudStatusText: iCloudBackupStatusText,
      refreshICloudStatus: refreshICloudBackupStatus,
      exportICloudBackup: exportICloudBackup,
      mergeImportICloudBackup: { importLatestICloudBackup(mode: .merge) },
      replaceImportICloudBackup: { importLatestICloudBackup(mode: .replace) },
      revealICloudBackupsDirectory: revealICloudBackupsDirectory
    )
  }

  private var aboutSettingsPage: some View {
    AboutSettingsPage()
  }

  private var launchAtLogin: Binding<Bool> {
    Binding {
      store.settings.launchAtLogin
    } set: { value in
      do {
        try launchAtLoginController.setEnabled(value)
        store.update { $0.launchAtLogin = value }
      } catch {
        showAlert(title: AppText.value("无法更新开机启动", "Unable To Update Launch At Login"), message: error.localizedDescription)
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

  private var copySoundEnabled: Binding<Bool> {
    Binding {
      store.settings.copySoundEnabled
    } set: { value in
      store.update { $0.copySoundEnabled = value }
    }
  }

  private var imageOCREnabled: Binding<Bool> {
    Binding {
      store.settings.imageOCREnabled
    } set: { value in
      store.update { $0.imageOCREnabled = value }
    }
  }

  private var copyPlainTextByDefault: Binding<Bool> {
    Binding {
      store.settings.copyPlainTextByDefault
    } set: { value in
      store.update { $0.copyPlainTextByDefault = value }
    }
  }

  private var pastePlainTextByDefault: Binding<Bool> {
    Binding {
      store.settings.pastePlainTextByDefault
    } set: { value in
      store.update { $0.pastePlainTextByDefault = value }
    }
  }

  private var visibleQuickActions: Binding<Set<ClipboardQuickAction>> {
    Binding {
      store.settings.visibleQuickActions
    } set: { value in
      store.update { $0.visibleQuickActions = value }
    }
  }

  private var autoFavoriteAfterNote: Binding<Bool> {
    Binding {
      store.settings.autoFavoriteAfterNote
    } set: { value in
      store.update { $0.autoFavoriteAfterNote = value }
    }
  }

  private var restoreClipboardAfterPaste: Binding<Bool> {
    Binding {
      store.settings.restoreClipboardAfterPaste
    } set: { value in
      store.update { $0.restoreClipboardAfterPaste = value }
    }
  }

  private var preserveLargeRichTextFormats: Binding<Bool> {
    Binding {
      store.settings.preserveLargeRichTextFormats
    } set: { value in
      store.update { $0.preserveLargeRichTextFormats = value }
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

  private var coverMenuBarWhenEdgeAttached: Binding<Bool> {
    Binding {
      store.settings.coverMenuBarWhenEdgeAttached
    } set: { value in
      store.update { $0.coverMenuBarWhenEdgeAttached = value }
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

  private var showMenuBarIcon: Binding<Bool> {
    Binding {
      store.settings.showMenuBarIcon
    } set: { value in
      store.update { $0.showMenuBarIcon = value }
    }
  }

  private var showDockIcon: Binding<Bool> {
    Binding {
      store.settings.showDockIcon
    } set: { value in
      store.update { $0.showDockIcon = value }
    }
  }

  private var themeMode: Binding<AppThemeMode> {
    Binding {
      store.settings.themeMode
    } set: { value in
      store.update { $0.themeMode = value }
    }
  }

  private var panelPosition: Binding<PanelPosition> {
    Binding {
      store.settings.panelPosition
    } set: { value in
      store.update { $0.panelPosition = value }
    }
  }

  private var panelPositionDescription: String {
    switch store.settings.panelPosition {
    case .edgeBottom:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的底部和左右边缘。",
        "The panel attaches to the bottom and side edges of the current pointer screen."
      )
    case .edgeTop:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的顶部和左右边缘。",
        "The panel attaches to the top and side edges of the current pointer screen."
      )
    case .edgeLeft:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的左侧、顶部和底部。",
        "The panel attaches to the left, top, and bottom edges of the current pointer screen."
      )
    case .edgeRight:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的右侧、顶部和底部。",
        "The panel attaches to the right, top, and bottom edges of the current pointer screen."
      )
    case .cursor:
      AppText.value(
        "面板优先出现在鼠标右下角，空间不足时自动移动到完整可见的位置。",
        "The panel opens near the pointer and moves automatically when space is limited."
      )
    case .screenCenter:
      AppText.value(
        "面板在当前鼠标所在屏幕的可见区域居中显示。",
        "The panel is centered in the visible area of the current pointer screen."
      )
    case .bottomDrawer, .statusItem:
      AppText.value("旧版位置会自动迁移为靠下。", "Legacy positions are migrated to the bottom edge.")
    case .mouseScreenCenter:
      AppText.value("旧版居中位置会自动迁移为跟随鼠标指针。", "Legacy centered position is migrated to near pointer.")
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

  private var isMonitoringPaused: Binding<Bool> {
    Binding {
      store.settings.isMonitoringPaused
    } set: { value in
      store.update { $0.isMonitoringPaused = value }
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
    accessibilityTrusted
      ? AppText.value("辅助功能权限已授权", "Accessibility permission granted")
      : AppText.value("自动粘贴需要辅助功能权限", "Auto paste requires Accessibility permission")
  }

  private var recordingStatusTitle: String {
    if store.settings.isMonitoringPaused {
      return AppText.value("已停止监听剪贴板", "Clipboard monitoring paused")
    }

    if let application = activeApplicationTracker.lastExternalApplication,
       store.settings.ignoredApps.contains(application.bundleIdentifier) {
      return AppText.value("\(application.name) 已被忽略", "\(application.name) is ignored")
    }

    return AppText.value("正在记录", "Recording")
  }

  private var currentApplicationTitle: String {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return AppText.value("暂无", "None")
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
      return AppText.value("添加最近使用的应用", "Add Recent App")
    }

    return AppText.value("忽略 \(application.name)", "Ignore \(application.name)")
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

  private func refreshICloudBackupStatus() {
    iCloudBackupStatusText = AppText.value("正在检查", "Checking")
    Task {
      iCloudBackupStatusText = await backupCoordinator.iCloudBackupStatusText()
    }
  }

  private func exportICloudBackup() {
    Task {
      await backupCoordinator.exportICloudBackup()
      refreshICloudBackupStatus()
    }
  }

  private func importLatestICloudBackup(mode: BackupImportMode) {
    Task {
      await backupCoordinator.importLatestICloudBackup(mode: mode)
      refreshICloudBackupStatus()
    }
  }

  private func revealICloudBackupsDirectory() {
    Task {
      await backupCoordinator.revealICloudBackupsDirectory()
      refreshICloudBackupStatus()
    }
  }

  private func handleSettingsSaveFailure(_ notification: Notification) {
    let message = notification.userInfo?[SettingsNotificationUserInfoKey.errorMessage] as? String ??
      AppText.value("未知错误", "Unknown error")
    settingsSaveErrorMessage = AppText.value("无法保存设置：\(message)", "Unable to save settings: \(message)")
    showAlert(
      title: AppText.value("无法保存设置", "Unable To Save Settings"),
      message: AppText.value(
        "本次设置变更已在当前运行中生效，但没有写入磁盘。\(message)",
        "This change is active for the current run, but was not written to disk. \(message)"
      )
    )
  }

  private func handleHistoryPersistenceFailure(_ notification: Notification) {
    let operation = notification.userInfo?[HistoryNotificationUserInfoKey.operation] as? String ??
      AppText.value("保存历史", "Save History")
    let message = notification.userInfo?[HistoryNotificationUserInfoKey.errorMessage] as? String ??
      AppText.value("未知错误", "Unknown error")
    historyPersistenceErrorMessage = AppText.value("\(operation)失败：\(message)", "\(operation) failed: \(message)")
    guard operation != "更新使用记录" else {
      return
    }
    showAlert(
      title: AppText.value("\(operation)失败", "\(operation) Failed"),
      message: AppText.value(
        "本次历史变更可能没有写入磁盘。\(message)",
        "This history change may not have been written to disk. \(message)"
      )
    )
  }

  private func refreshHistoryStatus() {
    statusErrorMessage = nil

    do {
      historyCount = try SQLiteClipboardHistoryRepository().count(ClipboardHistoryQuery())
    } catch {
      historyCount = nil
      statusErrorMessage = AppText.value(
        "无法读取历史数量：\(error.localizedDescription)",
        "Unable to read history count: \(error.localizedDescription)"
      )
    }

    do {
      storageSizeText = Self.byteCountFormatter.string(
        fromByteCount: Int64(try totalSizeOfDataDirectory())
      )
    } catch {
      storageSizeText = AppText.value("读取失败", "Failed to read")
      statusErrorMessage = AppText.value(
        "无法读取数据目录：\(error.localizedDescription)",
        "Unable to read data folder: \(error.localizedDescription)"
      )
    }
  }

  private func revealDataDirectory() {
    do {
      try AppPaths.ensureApplicationSupportDirectoryExists()
      NSWorkspace.shared.activateFileViewerSelecting([AppPaths.applicationSupportDirectory])
    } catch {
      showAlert(title: AppText.value("无法打开数据目录", "Unable To Open Data Folder"), message: error.localizedDescription)
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
    alert.addButton(withTitle: AppText.value("好", "OK"))
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
