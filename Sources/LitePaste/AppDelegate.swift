import AppKit
import Combine
import LitePasteCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settingsStore = AppSettingsStore.shared
  lazy var store = HistoryStore(
    maxHistoryCount: settingsStore.settings.maxHistoryCount,
    retentionDays: settingsStore.settings.retentionDays,
    moveDuplicatesToTop: settingsStore.settings.moveDuplicatesToTop,
    initialLoadLimit: 80
  )

  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private var pauseMonitoringMenuItem: NSMenuItem?
  private var ignoreApplicationMenuItem: NSMenuItem?
  private var monitor: ClipboardMonitor?
  private var panelCoordinator: PanelCoordinator?
  private var settingsWindow: NSWindow?
  private var permissionGuideWindow: NSWindow?
  private var hotkeyController: GlobalHotkeyController?
  private var registeredPanelHotkey: String?
  private var isRevertingPanelHotkey = false
  private var permissionGuideState = PermissionGuideState()
  private let clipboardWriteTracker = ClipboardWriteTracker()
  private let launchAtLoginController = LaunchAtLoginController()
  private let activeApplicationTracker = ActiveApplicationTracker.shared
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppText.updateInterfaceLanguage(settingsStore.settings.interfaceLanguage)
    applyThemeMode(settingsStore.settings.themeMode)
    applyActivationPolicy(settingsStore.settings)

    let writer = PasteboardWriter(store: store, writeTracker: clipboardWriteTracker)
    let panelCoordinator = PanelCoordinator(store: store, writer: writer)
    let monitor = ClipboardMonitor(
      store: store,
      writeTracker: clipboardWriteTracker,
      privacyFilter: PrivacyFilter(
        isMonitoringPaused: settingsStore.settings.isMonitoringPaused,
        ignoredApps: settingsStore.settings.ignoredApps,
        ignoredPasteboardTypes: settingsStore.settings.ignoredPasteboardTypes
      ),
      enabledTypes: settingsStore.settings.enabledTypes,
      preserveLargeRichTextFormats: settingsStore.settings.preserveLargeRichTextFormats,
      copySoundEnabled: settingsStore.settings.copySoundEnabled,
      imageOCREnabled: settingsStore.settings.imageOCREnabled
    )

    self.panelCoordinator = panelCoordinator
    self.monitor = monitor

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
    hotkeyController?.unregister()
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

  private func configureStatusMenu() {
    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(
      NSMenuItem(
        title: AppText.value("打开 \(AppMetadata.displayName)", "Open \(AppMetadata.displayName)"),
        action: #selector(openPanelFromMenu),
        keyEquivalent: ""
      )
    )
    let pauseMonitoringItem = NSMenuItem(
      title: AppText.value("停止监听剪贴板", "Pause Clipboard Monitoring"),
      action: #selector(toggleMonitoringPausedFromMenu),
      keyEquivalent: ""
    )
    menu.addItem(pauseMonitoringItem)
    self.pauseMonitoringMenuItem = pauseMonitoringItem

    let ignoreApplicationItem = NSMenuItem(
      title: AppText.value("忽略当前应用", "Ignore Current App"),
      action: #selector(ignoreCurrentApplicationFromMenu),
      keyEquivalent: ""
    )
    menu.addItem(ignoreApplicationItem)
    self.ignoreApplicationMenuItem = ignoreApplicationItem

    let settingsItem = NSMenuItem(
      title: AppText.value("设置...", "Settings..."),
      action: #selector(openSettings),
      keyEquivalent: ""
    )
    menu.addItem(settingsItem)
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: AppText.value("退出 \(AppMetadata.displayName)", "Quit \(AppMetadata.displayName)"),
        action: #selector(quit),
        keyEquivalent: "q"
      )
    )

    for item in menu.items {
      item.target = self
    }
    removeMenuItemImages(in: menu)

    statusMenu = menu
  }

  private func configureHotkey() {
    let hotkeyController = GlobalHotkeyController { [weak self] in
      self?.togglePanel()
    }
    registerPanelHotkey(settingsStore.settings.hotkey, controller: hotkeyController)
    self.hotkeyController = hotkeyController
  }

  private func registerPanelHotkey(_ hotkey: String, controller: GlobalHotkeyController? = nil) {
    guard let hotkeyController = controller ?? self.hotkeyController else {
      return
    }

    guard registeredPanelHotkey != hotkey else {
      return
    }

    let previousHotkey = registeredPanelHotkey
    let result = hotkeyController.register(hotkey: hotkey)
    guard result.isRegistered else {
      let restoredPreviousHotkey = restorePreviousPanelHotkey(previousHotkey, controller: hotkeyController)
      showPanelHotkeyRegistrationAlert(
        hotkey: hotkey,
        result: result,
        restoredPreviousHotkey: restoredPreviousHotkey
      )
      revertPanelHotkeySetting(to: restoredPreviousHotkey ?? AppSettings().hotkey)
      return
    }

    registeredPanelHotkey = hotkey
  }

  private func restorePreviousPanelHotkey(
    _ previousHotkey: String?,
    controller: GlobalHotkeyController
  ) -> String? {
    guard let previousHotkey else {
      return nil
    }

    if controller.register(hotkey: previousHotkey).isRegistered {
      registeredPanelHotkey = previousHotkey
      return previousHotkey
    }

    registeredPanelHotkey = nil
    return nil
  }

  private func revertPanelHotkeySetting(to hotkey: String) {
    guard settingsStore.settings.hotkey != hotkey else {
      return
    }

    isRevertingPanelHotkey = true
    settingsStore.update { $0.hotkey = hotkey }
    isRevertingPanelHotkey = false
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
    monitor?.updatePrivacyFilter(
      PrivacyFilter(
        isMonitoringPaused: settings.isMonitoringPaused,
        ignoredApps: settings.ignoredApps,
        ignoredPasteboardTypes: settings.ignoredPasteboardTypes
      )
    )
    monitor?.updateEnabledTypes(settings.enabledTypes)
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
    if !isRevertingPanelHotkey {
      registerPanelHotkey(settings.hotkey)
    }
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
      showAlert(title: AppText.value("导入后刷新失败", "Refresh Failed After Import"), message: error.localizedDescription)
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
    guard NSApp.currentEvent?.type == .rightMouseUp,
          let statusItem,
          let statusMenu else {
      togglePanel()
      return
    }

    statusItem.menu = statusMenu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @objc private func openPanelFromMenu() {
    panelCoordinator?.show(relativeTo: statusItem?.button)
  }

  @objc private func toggleMonitoringPausedFromMenu() {
    settingsStore.update { settings in
      settings.isMonitoringPaused.toggle()
    }
    updateStatusMenuState()
  }

  @objc private func ignoreCurrentApplicationFromMenu() {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return
    }

    settingsStore.update { settings in
      if settings.ignoredApps.contains(application.bundleIdentifier) {
        settings.ignoredApps.remove(application.bundleIdentifier)
      } else {
        settings.ignoredApps.insert(application.bundleIdentifier)
      }
    }
    updateStatusMenuState()
  }

  @objc private func openSettings() {
    panelCoordinator?.hide()
    let window = settingsWindow ?? makeSettingsWindow()
    settingsWindow = window
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func togglePanel() {
    panelCoordinator?.toggle(relativeTo: statusItem?.button)
  }

  private func makeSettingsWindow() -> NSWindow {
    let hostingController = NSHostingController(rootView: SettingsView())
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = AppText.value("\(AppMetadata.displayName) 设置", "\(AppMetadata.displayName) Settings")
    window.contentViewController = hostingController
    window.minSize = NSSize(width: 780, height: 560)
    window.backgroundColor = .windowBackgroundColor
    window.isOpaque = true
    window.delegate = self
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }

  private func presentPermissionGuideIfNeeded() {
    let accessibilityTrusted = AccessibilityPermissionController.isTrusted
    guard permissionGuideState.shouldPresent(accessibilityTrusted: accessibilityTrusted) else {
      if accessibilityTrusted {
        closePermissionGuideWindow()
      }
      return
    }

    let window = permissionGuideWindow ?? makePermissionGuideWindow()
    permissionGuideWindow = window
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func makePermissionGuideWindow() -> NSWindow {
    let hostingController = NSHostingController(
      rootView: PermissionGuideView(
        isAccessibilityTrusted: { AccessibilityPermissionController.isTrusted },
        requestPermission: { AccessibilityPermissionController.requestPermission() },
        openSystemSettings: { AccessibilityPermissionController.openSystemSettings() },
        dismissForSession: { [weak self] in
          self?.permissionGuideState.dismissForSession()
          self?.closePermissionGuideWindow()
        },
        completeGuide: { [weak self] in
          self?.closePermissionGuideWindow()
        }
      )
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = AppText.value("\(AppMetadata.displayName) 权限设置", "\(AppMetadata.displayName) Permission Setup")
    window.contentViewController = hostingController
    window.isReleasedWhenClosed = false
    window.center()
    return window
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
    updateIgnoreApplicationMenuItem()
    statusItem?.button?.toolTip = isMonitoringPaused
      ? AppText.value(
        "\(AppMetadata.displayName) - 已停止监听剪贴板",
        "\(AppMetadata.displayName) - Clipboard Monitoring Paused"
      )
      : AppMetadata.displayName
  }

  private func updateIgnoreApplicationMenuItem() {
    guard let item = ignoreApplicationMenuItem else {
      return
    }

    guard let application = activeApplicationTracker.lastExternalApplication else {
      item.title = AppText.value("忽略当前应用", "Ignore Current App")
      item.isEnabled = false
      item.state = .off
      return
    }

    let isIgnored = settingsStore.settings.ignoredApps.contains(application.bundleIdentifier)
    item.title = isIgnored
      ? AppText.value("取消忽略当前应用：\(application.name)", "Stop Ignoring Current App: \(application.name)")
      : AppText.value("忽略当前应用：\(application.name)", "Ignore Current App: \(application.name)")
    item.isEnabled = true
    item.state = .off
  }

  private func removeMenuItemImages(in menu: NSMenu) {
    for item in menu.items {
      item.image = nil
    }
  }

  private func showAccessibilityPermissionAlert() {
    UserAlerts.showAccessibilityPermissionRequired(
      message: AppText.value(
        "Lite Paste 已复制该内容。授予辅助功能权限后，可以自动回到目标应用并粘贴。",
        "Lite Paste copied the content. Grant Accessibility permission to return to the target app and paste automatically."
      )
    )
  }

  private func showMissingContentAlert() {
    showAlert(
      title: AppText.value("无法恢复该内容", "Unable To Restore This Content"),
      message: AppText.value(
        "该历史记录引用的文件或媒体数据已经不存在。你可以删除这条记录，或从备份恢复缺失的 Blobs 数据。",
        "The file or media data referenced by this history item no longer exists. Delete the item or restore the missing Blobs data from a backup."
      )
    )
  }

  private func showTargetApplicationUnavailableAlert() {
    showAlert(
      title: AppText.value("无法自动粘贴", "Unable To Auto Paste"),
      message: AppText.value(
        "Lite Paste 已复制该内容，但无法回到目标应用。你可以手动按 ⌘V 粘贴。",
        "Lite Paste copied the content, but could not return to the target app. Press ⌘V manually to paste."
      )
    )
  }

  private func showPanelHotkeyRegistrationAlert(
    hotkey: String,
    result: GlobalHotkeyRegistrationResult,
    restoredPreviousHotkey: String?
  ) {
    let requestedHotkey = PanelHotkeyCatalog.displayName(for: hotkey)
    let restoredMessage = restoredPreviousHotkey.map {
      AppText.value(
        "已恢复为之前可用的快捷键 \(PanelHotkeyCatalog.displayName(for: $0))。",
        "Restored the previous available shortcut \(PanelHotkeyCatalog.displayName(for: $0))."
      )
    } ?? AppText.value(
      "当前没有可用的面板快捷键，请在设置中选择其他组合。",
      "No panel shortcut is currently available. Choose another combination in Settings."
    )

    showAlert(
      title: AppText.value("无法注册面板快捷键", "Unable To Register Panel Shortcut"),
      message: AppText.value(
        "\(requestedHotkey) 无法注册。\(panelHotkeyFailureReason(for: result)) \(restoredMessage)",
        "\(requestedHotkey) could not be registered. \(panelHotkeyFailureReason(for: result)) \(restoredMessage)"
      )
    )
  }

  private func panelHotkeyFailureReason(for result: GlobalHotkeyRegistrationResult) -> String {
    switch result {
    case .registered:
      AppText.value("快捷键已注册。", "Shortcut registered.")
    case .invalidHotkey:
      AppText.value("该快捷键格式无效。", "The shortcut format is invalid.")
    case let .registrationFailed(status):
      AppText.value(
        "可能已被其他应用或系统快捷键占用。系统状态码：\(status)。",
        "It may already be used by another app or a system shortcut. System status: \(status)."
      )
    case let .handlerFailed(status):
      AppText.value(
        "快捷键事件监听无法启动。系统状态码：\(status)。",
        "Shortcut event monitoring could not start. System status: \(status)."
      )
    }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: AppText.value("好", "OK"))
    alert.alertStyle = .informational
    alert.runModal()
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
    removeMenuItemImages(in: menu)
  }
}
