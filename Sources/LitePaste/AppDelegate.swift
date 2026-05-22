import AppKit
import Combine
import LitePasteCore

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
  private var privacyModeMenuItem: NSMenuItem?
  private var ignoreApplicationMenuItem: NSMenuItem?
  private var monitor: ClipboardMonitor?
  private var writer: PasteboardWriter?
  private var panelCoordinator: PanelCoordinator?
  private var hotkeyController: GlobalHotkeyController?
  private var pinnedHotkeyController: PinnedHotkeyController?
  private var registeredPanelHotkey: String?
  private let clipboardWriteTracker = ClipboardWriteTracker()
  private let launchAtLoginController = LaunchAtLoginController()
  private let activeApplicationTracker = ActiveApplicationTracker.shared
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    let writer = PasteboardWriter(store: store, writeTracker: clipboardWriteTracker)
    let panelCoordinator = PanelCoordinator(store: store, writer: writer)
    let monitor = ClipboardMonitor(
      store: store,
      writeTracker: clipboardWriteTracker,
      privacyFilter: PrivacyFilter(
        privacyMode: settingsStore.settings.privacyMode,
        ignoredApps: settingsStore.settings.ignoredApps,
        ignoredPasteboardTypes: settingsStore.settings.ignoredPasteboardTypes
      ),
      enabledTypes: settingsStore.settings.enabledTypes
    )

    self.writer = writer
    self.panelCoordinator = panelCoordinator
    self.monitor = monitor

    configureStatusItem()
    configureHotkey()
    configurePinnedHotkeys()
    observeSettings()
    observeBackupImports()
    launchAtLoginController.sync(with: settingsStore.settings.launchAtLogin)
    activeApplicationTracker.start()
    monitor.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    monitor?.stop()
    activeApplicationTracker.stop()
    hotkeyController?.unregister()
    pinnedHotkeyController?.unregister()
  }

  private func configureStatusItem() {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = StatusItemIcon.makeImage()
    statusItem.button?.toolTip = "Lite Paste"
    statusItem.button?.target = self
    statusItem.button?.action = #selector(handleStatusItemClick(_:))
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    self.statusItem = statusItem
    configureStatusMenu()
  }

  private func configureStatusMenu() {
    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(
      NSMenuItem(
        title: "打开 Lite Paste",
        action: #selector(openPanelFromMenu),
        keyEquivalent: ""
      )
    )
    let privacyModeItem = NSMenuItem(
      title: "私密模式",
      action: #selector(togglePrivacyModeFromMenu),
      keyEquivalent: ""
    )
    menu.addItem(privacyModeItem)
    self.privacyModeMenuItem = privacyModeItem

    let ignoreApplicationItem = NSMenuItem(
      title: "忽略当前应用",
      action: #selector(ignoreCurrentApplicationFromMenu),
      keyEquivalent: ""
    )
    menu.addItem(ignoreApplicationItem)
    self.ignoreApplicationMenuItem = ignoreApplicationItem

    menu.addItem(
      NSMenuItem(
        title: "设置...",
        action: #selector(openSettings),
        keyEquivalent: ","
      )
    )
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "退出 Lite Paste",
        action: #selector(quit),
        keyEquivalent: "q"
      )
    )

    for item in menu.items {
      item.target = self
    }

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
    let hotkeyController = controller ?? self.hotkeyController
    guard registeredPanelHotkey != hotkey else {
      return
    }

    hotkeyController?.register(hotkey: hotkey)
    registeredPanelHotkey = hotkey
  }

  private func configurePinnedHotkeys() {
    let pinnedHotkeyController = PinnedHotkeyController { [weak self] recordID in
      self?.pastePinnedRecord(recordID)
    }
    pinnedHotkeyController.update(records: store.pinnedShortcutRecords())
    self.pinnedHotkeyController = pinnedHotkeyController

    store.$records
      .sink { [weak self] _ in
        guard let self else {
          return
        }
        pinnedHotkeyController.update(records: store.pinnedShortcutRecords())
      }
      .store(in: &cancellables)
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
        privacyMode: settings.privacyMode,
        ignoredApps: settings.ignoredApps,
        ignoredPasteboardTypes: settings.ignoredPasteboardTypes
      )
    )
    monitor?.updateEnabledTypes(settings.enabledTypes)
    store.updateMaxHistoryCount(settings.maxHistoryCount)
    store.updateRetentionDays(settings.retentionDays)
    store.updateMoveDuplicatesToTop(settings.moveDuplicatesToTop)
    registerPanelHotkey(settings.hotkey)
    launchAtLoginController.sync(with: settings.launchAtLogin)
  }

  private func reloadImportedBackup() {
    settingsStore.reload()
    apply(settingsStore.settings)

    do {
      try store.reload()
    } catch {
      showAlert(title: "导入后刷新失败", message: error.localizedDescription)
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

  @objc private func togglePrivacyModeFromMenu() {
    settingsStore.update { settings in
      settings.privacyMode.toggle()
    }
    updateStatusMenuState()
  }

  @objc private func ignoreCurrentApplicationFromMenu() {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return
    }

    settingsStore.update { settings in
      settings.ignoredApps.insert(application.bundleIdentifier)
    }
    updateStatusMenuState()
  }

  @objc private func openSettings() {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func togglePanel() {
    panelCoordinator?.toggle(relativeTo: statusItem?.button)
  }

  private func updateStatusMenuState() {
    let privacyMode = settingsStore.settings.privacyMode
    privacyModeMenuItem?.state = privacyMode ? .on : .off
    updateIgnoreApplicationMenuItem()
    statusItem?.button?.toolTip = privacyMode ? "Lite Paste - 私密模式已开启" : "Lite Paste"
  }

  private func updateIgnoreApplicationMenuItem() {
    guard let item = ignoreApplicationMenuItem else {
      return
    }

    guard let application = activeApplicationTracker.lastExternalApplication else {
      item.title = "忽略当前应用"
      item.isEnabled = false
      item.state = .off
      return
    }

    let isIgnored = settingsStore.settings.ignoredApps.contains(application.bundleIdentifier)
    item.title = isIgnored ? "已忽略 \(application.name)" : "忽略 \(application.name)"
    item.isEnabled = !isIgnored
    item.state = isIgnored ? .on : .off
  }

  private func pastePinnedRecord(_ recordID: ClipboardRecord.ID) {
    guard let record = store.record(id: recordID) else {
      return
    }

    let targetApplication = NSWorkspace.shared.frontmostApplication
    let result = writer?.paste(
      record,
      targetApplication: targetApplication,
      asPlainText: settingsStore.settings.pastePlainByDefault,
      restorePreviousClipboard: settingsStore.settings.restoreClipboardAfterPaste
    )

    if result == .accessibilityPermissionRequired {
      showAccessibilityPermissionAlert()
    }
  }

  private func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = "Lite Paste 已复制该内容。授予辅助功能权限后，可以使用置顶快捷键自动粘贴。"
    alert.addButton(withTitle: "打开系统设置")
    alert.addButton(withTitle: "稍后")
    alert.alertStyle = .informational

    if alert.runModal() == .alertFirstButtonReturn {
      AccessibilityPermissionController.openSystemSettings()
    }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.alertStyle = .informational
    alert.runModal()
  }
}

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    updateStatusMenuState()
  }
}
