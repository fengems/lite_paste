import AppKit
import LitePasteCore
import SwiftUI

struct SettingsView: View {
  private enum ICloudBackupAction {
    case exportBackup
    case importLatest(BackupImportMode)
    case revealDirectory
  }

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
      panelPosition: settingsBindings.panelPosition,
      viewMode: settingsBindings.viewMode,
      coverMenuBarWhenEdgeAttached: settingsBindings.coverMenuBarWhenEdgeAttached,
      focusSearchOnOpen: settingsBindings.focusSearchOnOpen,
      clearSearchOnOpen: settingsBindings.clearSearchOnOpen,
      autoPasteMode: settingsBindings.autoPasteMode,
      copySoundEnabled: settingsBindings.copySoundEnabled,
      imageOCREnabled: settingsBindings.imageOCREnabled,
      copyPlainTextByDefault: settingsBindings.copyPlainTextByDefault,
      pastePlainTextByDefault: settingsBindings.pastePlainTextByDefault,
      visibleQuickActions: settingsBindings.visibleQuickActions,
      autoFavoriteAfterNote: settingsBindings.autoFavoriteAfterNote,
      restoreClipboardAfterPaste: settingsBindings.restoreClipboardAfterPaste,
      moveDuplicatesToTop: settingsBindings.moveDuplicatesToTop,
      panelPositionDescription: SettingsText.panelPositionDescription(for: store.settings.panelPosition)
    )
  }

  private var historySettingsPage: some View {
    HistorySettingsPage(
      maxHistoryCount: settingsBindings.maxHistoryCount,
      retentionDays: settingsBindings.retentionDays,
      preserveLargeRichTextFormats: settingsBindings.preserveLargeRichTextFormats,
      isMonitoringPaused: settingsBindings.isMonitoringPaused,
      historyCountText: SettingsText.historyCount(historyCount),
      storageSizeText: storageSizeText,
      refreshStatus: refreshStatus,
      revealDataDirectory: revealDataDirectory
    )
  }

  private var generalSettingsPage: some View {
    GeneralSettingsPage(
      launchAtLogin: settingsBindings.launchAtLogin,
      showMenuBarIcon: settingsBindings.showMenuBarIcon,
      showDockIcon: settingsBindings.showDockIcon,
      recordingStatusTitle: SettingsText.recordingStatusTitle(isMonitoringPaused: store.settings.isMonitoringPaused),
      currentApplicationTitle: SettingsText.currentApplicationTitle(activeApplicationTracker.lastExternalApplication),
      statusErrorMessage: statusErrorMessage,
      historyPersistenceErrorMessage: historyPersistenceErrorMessage,
      settingsSaveErrorMessage: settingsSaveErrorMessage,
      accessibilityStatusTitle: SettingsText.accessibilityStatusTitle(isTrusted: accessibilityTrusted),
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
    AppearanceSettingsPage(interfaceLanguage: settingsBindings.interfaceLanguage, themeMode: settingsBindings.themeMode)
  }

  private var hotkeySettingsPage: some View {
    HotkeySettingsPage(panelHotkey: settingsBindings.panelHotkey)
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

  private var settingsBindings: SettingsBindings {
    SettingsBindings(
      store: store,
      launchAtLoginController: launchAtLoginController
    )
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
    performICloudBackupAction(.exportBackup)
  }

  private func importLatestICloudBackup(mode: BackupImportMode) {
    performICloudBackupAction(.importLatest(mode))
  }

  private func revealICloudBackupsDirectory() {
    performICloudBackupAction(.revealDirectory)
  }

  private func performICloudBackupAction(_ action: ICloudBackupAction) {
    Task {
      switch action {
      case .exportBackup:
        await backupCoordinator.exportICloudBackup()
      case let .importLatest(mode):
        await backupCoordinator.importLatestICloudBackup(mode: mode)
      case .revealDirectory:
        await backupCoordinator.revealICloudBackupsDirectory()
      }
      refreshICloudBackupStatus()
    }
  }

  private func handleSettingsSaveFailure(_ notification: Notification) {
    let message = notificationValue(
      notification,
      key: SettingsNotificationUserInfoKey.errorMessage,
      fallback: AppText.value("未知错误", "Unknown error")
    )
    settingsSaveErrorMessage = AppText.value("无法保存设置：\(message)", "Unable to save settings: \(message)")
    UserAlerts.showMessage(
      title: AppText.value("无法保存设置", "Unable To Save Settings"),
      message: AppText.value(
        "本次设置变更已在当前运行中生效，但没有写入磁盘。\(message)",
        "This change is active for the current run, but was not written to disk. \(message)"
      ),
      style: .warning
    )
  }

  private func handleHistoryPersistenceFailure(_ notification: Notification) {
    let operation = notificationValue(
      notification,
      key: HistoryNotificationUserInfoKey.operation,
      fallback: AppText.value("保存历史", "Save History")
    )
    let message = notificationValue(
      notification,
      key: HistoryNotificationUserInfoKey.errorMessage,
      fallback: AppText.value("未知错误", "Unknown error")
    )
    historyPersistenceErrorMessage = AppText.value("\(operation)失败：\(message)", "\(operation) failed: \(message)")
    guard operation != "更新使用记录" else {
      return
    }
    UserAlerts.showMessage(
      title: AppText.value("\(operation)失败", "\(operation) Failed"),
      message: AppText.value(
        "本次历史变更可能没有写入磁盘。\(message)",
        "This history change may not have been written to disk. \(message)"
      ),
      style: .warning
    )
  }

  private func notificationValue(_ notification: Notification, key: String, fallback: String) -> String {
    notification.userInfo?[key] as? String ?? fallback
  }

  private func refreshHistoryStatus() {
    statusErrorMessage = nil

    do {
      historyCount = try SettingsDataStatusReader.historyCount()
    } catch {
      historyCount = nil
      statusErrorMessage = AppText.value(
        "无法读取历史数量：\(error.localizedDescription)",
        "Unable to read history count: \(error.localizedDescription)"
      )
    }

    do {
      storageSizeText = try SettingsDataStatusReader.storageSizeText()
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
      UserAlerts.showMessage(
        title: AppText.value("无法打开数据目录", "Unable To Open Data Folder"),
        message: error.localizedDescription,
        style: .warning
      )
    }
  }
}
