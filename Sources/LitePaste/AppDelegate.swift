import AppKit
import Combine
import LitePasteCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private enum Startup {
    static let initialHistoryLoadLimit = 80
  }

  let settingsStore = AppSettingsStore.shared
  lazy var store = HistoryStore(
    maxHistoryCount: settingsStore.settings.maxHistoryCount,
    retentionDays: settingsStore.settings.retentionDays,
    moveDuplicatesToTop: settingsStore.settings.moveDuplicatesToTop,
    initialLoadLimit: Startup.initialHistoryLoadLimit
  )

  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private var pauseMonitoringMenuItem: NSMenuItem?
  private var monitor: ClipboardMonitor?
  private var panelCoordinator: PanelCoordinator?
  private var settingsWindow: NSWindow?
  private var permissionGuideWindow: NSWindow?
  private var hotkeyCoordinator: PanelHotkeyCoordinator?
  private var permissionGuideState = PermissionGuideState()
  private let clipboardWriteTracker = ClipboardWriteTracker()
  private let launchAtLoginController = LaunchAtLoginController()
  private let activeApplicationTracker = ActiveApplicationTracker.shared
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppText.updateInterfaceLanguage(settingsStore.settings.interfaceLanguage)
    applyThemeMode(settingsStore.settings.themeMode)
    applyActivationPolicy(settingsStore.settings)

    configureClipboardPipeline()
    syncStatusItemVisibility(showMenuBarIcon: settingsStore.settings.showMenuBarIcon)
    configureHotkey()
    observeSettings()
    observeBackupImports()
    launchAtLoginController.sync(with: settingsStore.settings.launchAtLogin)
    activeApplicationTracker.start()
    updateMonitoringActivity(isPaused: settingsStore.settings.isMonitoringPaused)
    presentPermissionGuideIfNeeded()
  }

  func applicationWillTerminate(_ notification: Notification) {
    monitor?.stop()
    activeApplicationTracker.stop()
    hotkeyCoordinator?.stop()
  }

  private func configureStatusItem() {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = StatusItemIcon.makeImage()
    statusItem.button?.toolTip = AppMetadata.displayName
    statusItem.button?.target = self
    statusItem.button?.action = #selector(handleStatusItemClick(_:))
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    self.statusItem = statusItem
    configureStatusMenu()
    updateStatusMenuState()
  }

  private func configureClipboardPipeline() {
    let writer = PasteboardWriter(store: store, writeTracker: clipboardWriteTracker)
    panelCoordinator = PanelCoordinator(
      store: store,
      writer: writer,
      openSettingsAction: { [weak self] in
        self?.openSettings()
      }
    )
    monitor = ClipboardMonitor(
      store: store,
      writeTracker: clipboardWriteTracker,
      monitoringPolicy: ClipboardMonitoringPolicy(
        isMonitoringPaused: settingsStore.settings.isMonitoringPaused
      ),
      preserveLargeRichTextFormats: settingsStore.settings.preserveLargeRichTextFormats,
      copySoundEnabled: settingsStore.settings.copySoundEnabled,
      imageOCREnabled: settingsStore.settings.imageOCREnabled
    )
  }

  private func configureStatusMenu() {
    let configuration = AppStatusMenuFactory.makeMenu(
      target: self,
      delegate: self,
      openPanelAction: #selector(openPanelFromMenu),
      toggleMonitoringAction: #selector(toggleMonitoringPausedFromMenu),
      openSettingsAction: #selector(openSettings),
      quitAction: #selector(quit)
    )
    pauseMonitoringMenuItem = configuration.pauseMonitoringItem
    statusMenu = configuration.menu
  }

  private func configureHotkey() {
    let hotkeyCoordinator = PanelHotkeyCoordinator(settingsStore: settingsStore) { [weak self] in
      self?.togglePanel()
    }
    hotkeyCoordinator.start()
    self.hotkeyCoordinator = hotkeyCoordinator
  }

  private func observeSettings() {
    settingsStore.settingsPublisher
      .dropFirst()
      .sink { [weak self] settings in
        self?.apply(settings)
      }
      .store(in: &cancellables)
  }

  private func observeBackupImports() {
    NotificationCenter.default.publisher(for: .litePasteBackupImported)
      .sink { [weak self] _ in
        self?.reloadImportedBackup()
      }
      .store(in: &cancellables)
  }

  private func apply(_ settings: AppSettings) {
    monitor?.updateMonitoringPolicy(
      ClipboardMonitoringPolicy(
        isMonitoringPaused: settings.isMonitoringPaused
      )
    )
    monitor?.updatePreserveLargeRichTextFormats(settings.preserveLargeRichTextFormats)
    monitor?.updateCopySoundEnabled(settings.copySoundEnabled)
    monitor?.updateImageOCREnabled(settings.imageOCREnabled)
    AppText.updateInterfaceLanguage(settings.interfaceLanguage)
    applyThemeMode(settings.themeMode)
    applyActivationPolicy(settings)
    syncStatusItemVisibility(showMenuBarIcon: settings.showMenuBarIcon)
    updateMonitoringActivity(isPaused: settings.isMonitoringPaused)
    store.updateMaxHistoryCount(settings.maxHistoryCount)
    store.updateRetentionDays(settings.retentionDays)
    store.updateMoveDuplicatesToTop(settings.moveDuplicatesToTop)
    hotkeyCoordinator?.apply(settings.hotkey)
    launchAtLoginController.sync(with: settings.launchAtLogin)
    updateStatusMenuState()
  }

  private func applyThemeMode(_ themeMode: AppThemeMode) {
    switch themeMode {
    case .system:
      NSApp.appearance = nil
    case .light:
      NSApp.appearance = NSAppearance(named: .aqua)
    case .dark:
      NSApp.appearance = NSAppearance(named: .darkAqua)
    }
  }

  private func applyActivationPolicy(_ settings: AppSettings) {
    NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
  }

  private func syncStatusItemVisibility(showMenuBarIcon: Bool) {
    if showMenuBarIcon {
      if statusItem == nil {
        configureStatusItem()
      } else {
        updateStatusMenuState()
      }
      return
    }

    if let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }

  private func reloadImportedBackup() {
    settingsStore.reload()
    apply(settingsStore.settings)

    do {
      try store.reload()
    } catch {
      UserAlerts.showMessage(
        title: AppText.value("导入后刷新失败", "Refresh Failed After Import"),
        message: error.localizedDescription
      )
    }
  }

  private func updateMonitoringActivity(isPaused: Bool) {
    if isPaused {
      monitor?.stop()
    } else {
      monitor?.start()
    }
  }

  @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    showStatusMenu()
  }

  private func showStatusMenu() {
    guard let statusItem, let statusMenu else {
      return
    }
    statusItem.menu = statusMenu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @objc private func openPanelFromMenu() {
    panelCoordinator?.show()
  }

  @objc private func toggleMonitoringPausedFromMenu() {
    settingsStore.update { settings in
      settings.isMonitoringPaused.toggle()
    }
    updateStatusMenuState()
  }

  @objc private func openSettings() {
    panelCoordinator?.hide()
    let window = settingsWindow ?? AppWindowFactory.makeSettingsWindow(delegate: self)
    settingsWindow = window
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func togglePanel() {
    panelCoordinator?.toggle()
  }

  private func presentPermissionGuideIfNeeded() {
    let accessibilityTrusted = AccessibilityPermissionController.isTrusted
    guard permissionGuideState.shouldPresent(accessibilityTrusted: accessibilityTrusted) else {
      if accessibilityTrusted {
        closePermissionGuideWindow()
      }
      return
    }

    let window = permissionGuideWindow ?? AppWindowFactory.makePermissionGuideWindow(
      dismissForSession: { [weak self] in
        self?.permissionGuideState.dismissForSession()
        self?.closePermissionGuideWindow()
      },
      completeGuide: { [weak self] in
        self?.closePermissionGuideWindow()
      }
    )
    permissionGuideWindow = window
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func closePermissionGuideWindow() {
    permissionGuideWindow?.orderOut(nil)
  }

  private func updateStatusMenuState() {
    let isMonitoringPaused = settingsStore.settings.isMonitoringPaused
    pauseMonitoringMenuItem?.title = isMonitoringPaused
      ? AppText.value("恢复监听剪贴板", "Resume Clipboard Monitoring")
      : AppText.value("停止监听剪贴板", "Pause Clipboard Monitoring")
    pauseMonitoringMenuItem?.state = .off
    statusItem?.button?.toolTip = isMonitoringPaused
      ? AppText.value(
        "\(AppMetadata.displayName) - 已停止监听剪贴板",
        "\(AppMetadata.displayName) - Clipboard Monitoring Paused"
      )
      : AppMetadata.displayName
  }

}

extension AppDelegate: NSWindowDelegate {
  func windowDidBecomeKey(_ notification: Notification) {
    guard let window = notification.object as? NSWindow,
          window === settingsWindow else {
      return
    }

    panelCoordinator?.hide()
  }
}

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    updateStatusMenuState()
    AppStatusMenuFactory.removeItemImages(in: menu)
  }
}
